import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:dalal_alqaim/models/rating_model.dart';

/// خدمة إدارة التقييمات المتكاملة (Multi-Role Rating Service)
class RatingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// تسجيل تقييم جديد مع تحديث المعدل التراكمي للطرف المُقيَّم
  static Future<bool> submitRating({
    required String targetId,
    required RatingTargetType targetType,
    required String targetName,
    required String authorId,
    required String authorName,
    required String authorRole,
    required String referenceId, // rideId or orderId
    required double rating,
    List<String> tags = const [],
    String comment = '',
  }) async {
    try {
      if (targetId.isEmpty || authorId.isEmpty) {
        debugPrint(' [RatingService] Missing targetId or authorId.');
        return false;
      }

      // 1. إنشاء وثيقة التقييم في كولكشن ratings
      final ratingRef = _firestore.collection('ratings').doc();
      final ratingData = {
        'id': ratingRef.id,
        'targetId': targetId,
        'targetType': targetType.name,
        'targetName': targetName,
        'authorId': authorId,
        'authorName': authorName,
        'authorRole': authorRole,
        'referenceId': referenceId,
        'rating': rating,
        'tags': tags,
        'comment': comment.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      final batch = _firestore.batch();
      batch.set(ratingRef, ratingData);

      // 2. تحديث وثيقة الرحلة أو الطلب لمنع تكرار التقييم
      if (referenceId.isNotEmpty) {
        if (targetType == RatingTargetType.captain || targetType == RatingTargetType.customer) {
          batch.set(
            _firestore.collection('ride_requests').doc(referenceId),
            {'isRated': true, 'ratedAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true),
          );
        } else if (targetType == RatingTargetType.restaurant) {
          batch.set(
            _firestore.collection('orders').doc(referenceId),
            {'isRated': true, 'ratedAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true),
          );
        } else if (targetType == RatingTargetType.store) {
          batch.set(
            _firestore.collectionGroup('madar_orders').where('orderId', isEqualTo: referenceId).firestore.doc(referenceId),
            {'isRated': true},
            SetOptions(merge: true),
          );
        }
      }

      await batch.commit();

      // 3. تحديث المعدل التراكمي في الخلفية للطرف المستهدف
      _updateTargetCumulativeRating(targetId, targetType);

      debugPrint(' [RatingService] Rating submitted successfully: ${ratingRef.id}');
      return true;
    } catch (e) {
      debugPrint(' [RatingService] Error submitting rating: $e');
      return false;
    }
  }

  /// حساب وتحديث المعدل التراكمي للهدف (سائق، مطعم، متجر، زبون)
  static Future<void> _updateTargetCumulativeRating(String targetId, RatingTargetType targetType) async {
    try {
      final snap = await _firestore.collection('ratings').where('targetId', isEqualTo: targetId).get();
      if (snap.docs.isEmpty) return;

      double totalScore = 0;
      for (final doc in snap.docs) {
        final r = (doc.data()['rating'] is num) ? (doc.data()['rating'] as num).toDouble() : 5.0;
        totalScore += r;
      }

      final count = snap.docs.length;
      final avg = double.parse((totalScore / count).toStringAsFixed(1));

      final updateData = {
        'rating': avg,
        'ratingAvg': avg,
        'ratingCount': count,
        'totalReviews': count,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (targetType == RatingTargetType.captain) {
        await _firestore.collection('drivers').doc(targetId).set(updateData, SetOptions(merge: true));
        await _firestore.collection('users').doc(targetId).set(updateData, SetOptions(merge: true));
      } else if (targetType == RatingTargetType.customer) {
        await _firestore.collection('users').doc(targetId).set(updateData, SetOptions(merge: true));
      } else if (targetType == RatingTargetType.restaurant) {
        await _firestore.collection('restaurants').doc(targetId).set(updateData, SetOptions(merge: true));
        await _firestore.collection('users').doc(targetId).set(updateData, SetOptions(merge: true));
      } else if (targetType == RatingTargetType.store) {
        await _firestore.collection('stores').doc(targetId).set(updateData, SetOptions(merge: true));
      }

      debugPrint(' [RatingService] Updated average for $targetId: $avg ($count reviews)');
    } catch (e) {
      debugPrint(' [RatingService] Error updating cumulative rating: $e');
    }
  }

  /// التحقق مما إذا كان المستخدم قد قيّم هذا المشوار أو الطلب مسبقاً
  static Future<bool> hasUserRated({
    required String referenceId,
    required String authorId,
  }) async {
    try {
      if (referenceId.isEmpty || authorId.isEmpty) return false;
      final snap = await _firestore
          .collection('ratings')
          .where('referenceId', isEqualTo: referenceId)
          .where('authorId', isEqualTo: authorId)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      debugPrint(' [RatingService] Error checking hasUserRated: $e');
      return false;
    }
  }

  /// دفق التقييمات لطرف معين (كابتن، مطعم، متجر)
  static Stream<List<RatingModel>> getRatingsStreamForTarget(String targetId) {
    return _firestore
        .collection('ratings')
        .where('targetId', isEqualTo: targetId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => RatingModel.fromFirestore(doc)).toList());
  }

  /// دفق كافة التقييمات للوحة تحكم الإدارة (Admin)
  static Stream<List<RatingModel>> getAllRatingsStreamForAdmin({int limit = 50}) {
    return _firestore
        .collection('ratings')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => RatingModel.fromFirestore(doc)).toList());
  }

  /// جلب التقييمات الضعيفة لمتابعة الشكاوى للإدارة
  static Stream<List<RatingModel>> getLowRatingsStream({double maxRating = 2.5, int limit = 50}) {
    return _firestore
        .collection('ratings')
        .where('rating', isLessThanOrEqualTo: maxRating)
        .orderBy('rating', descending: false)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => RatingModel.fromFirestore(doc)).toList());
  }

  /// الرد على تقييم (من قبل الكابتن، التاجر، أو الإدارة)
  static Future<bool> replyToRating(String ratingId, String replyText) async {
    try {
      await _firestore.collection('ratings').doc(ratingId).update({
        'reply': replyText.trim(),
        'repliedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint(' [RatingService] Error replying to rating: $e');
      return false;
    }
  }
}
