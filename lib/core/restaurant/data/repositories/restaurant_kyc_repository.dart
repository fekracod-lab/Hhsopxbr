import 'package:cloud_firestore/cloud_firestore.dart';

/// مستودع طلبات انضمام المطاعم (Restaurant KYC Repository)
/// يستعلم حصرياً من مجموعة restaurant_requests فقط دون خلط مع المتاجر.
class RestaurantKycRepository {
  final FirebaseFirestore _firestore;

  RestaurantKycRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// دفق طلبات انضمام المطاعم المعلقة
  Stream<QuerySnapshot<Map<String, dynamic>>> streamPendingRestaurantKyc() {
    return _firestore
        .collection('restaurant_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// دفق عدد طلبات المطاعم المعلقة
  Stream<int> streamPendingRestaurantKycCount() {
    return streamPendingRestaurantKyc().map((s) => s.docs.length);
  }

  /// اعتماد طلب انضمام مطعم
  Future<void> approveRestaurantKyc({
    required String docId,
    required Map<String, dynamic> requestData,
  }) async {
    final batch = _firestore.batch();
    final ownerId = requestData['ownerId'] ?? requestData['uid'] ?? docId;
    final restaurantId = requestData['restaurantId'] ?? ownerId;

    final reqRef = _firestore.collection('restaurant_requests').doc(docId);
    batch.update(reqRef, {
      'status': 'approved',
      'processedAt': FieldValue.serverTimestamp(),
    });

    final restRef = _firestore.collection('restaurants').doc(restaurantId);
    batch.set(restRef, {
      ...requestData,
      'restaurantId': restaurantId,
      'ownerId': ownerId,
      'status': 'active',
      'isApproved': true,
      'rating': 5.0,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final userRef = _firestore.collection('users').doc(ownerId);
    batch.update(userRef, {
      'role': 'restaurant',
      'status': 'active',
      'isApproved': true,
      'restaurantId': restaurantId,
      'approvedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// رفض طلب انضمام مطعم
  Future<void> rejectRestaurantKyc({
    required String docId,
    required String ownerId,
    String? reason,
  }) async {
    final batch = _firestore.batch();

    final reqRef = _firestore.collection('restaurant_requests').doc(docId);
    batch.update(reqRef, {
      'status': 'rejected',
      'rejectionReason': reason ?? 'لم يتم استيفاء الشروط المطلوبة',
      'processedAt': FieldValue.serverTimestamp(),
    });

    final userRef = _firestore.collection('users').doc(ownerId);
    batch.update(userRef, {
      'status': 'rejected',
      'isApproved': false,
      'rejectionReason': reason ?? 'لم يتم استيفاء الشروط المطلوبة',
      'rejectedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
