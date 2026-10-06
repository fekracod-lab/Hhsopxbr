import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RewardsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // جلب النقاط الحالية
  Future<int> getRewardsPoints(String driverId) async {
    try {
      final doc = await _firestore.collection('drivers').doc(driverId).get();
      return (doc.data()?['rewardsPoints'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('Error getting rewards points: $e');
      return 0;
    }
  }

  // الاستماع للنقاط الحالية (مباشر)
  Stream<int> getRewardsPointsStream(String driverId) {
    return _firestore.collection('drivers').doc(driverId).snapshots().map((doc) {
      return (doc.data()?['rewardsPoints'] as num?)?.toInt() ?? 0;
    });
  }

  // الاستماع لسجل العمليات (Transactions)
  Stream<QuerySnapshot> getTransactionsStream(String driverId) {
    return _firestore
        .collection('reward_transactions')
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // إضافة نقاط للسائق (تُستدعى عند إكمال الرحلة)
  Future<void> addPoints(String driverId, int points, String reason, {String? referenceId}) async {
    if (points <= 0) return;
    
    await _firestore.runTransaction((tx) async {
      final driverRef = _firestore.collection('drivers').doc(driverId);
      tx.update(driverRef, {
        'rewardsPoints': FieldValue.increment(points),
      });

      final transactionRef = _firestore.collection('reward_transactions').doc();
      tx.set(transactionRef, {
        'driverId': driverId,
        'amount': points,
        'type': 'earned',
        'reason': reason,
        'referenceId': referenceId, // رقم الطلب كمثال
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // استبدال النقاط بمكافأة
  Future<bool> redeemPoints(String driverId, int cost, String rewardName) async {
    if (cost <= 0) return false;

    try {
      final bool success = await _firestore.runTransaction<bool>((tx) async {
        final driverRef = _firestore.collection('drivers').doc(driverId);
        final snap = await tx.get(driverRef);
        
        if (!snap.exists) return false;
        
        final data = snap.data() ?? {};
        final currentPoints = (data['rewardsPoints'] as num?)?.toInt() ?? 0;

        if (currentPoints < cost) {
          return false; // الرصيد غير كافٍ
        }

        tx.update(driverRef, {
          'rewardsPoints': FieldValue.increment(-cost),
        });

        final transactionRef = _firestore.collection('reward_transactions').doc();
        tx.set(transactionRef, {
          'driverId': driverId,
          'amount': -cost,
          'type': 'redeemed',
          'reason': rewardName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        return true;
      });

      return success;
    } catch (e) {
      debugPrint('Error redeeming points: $e');
      return false;
    }
  }

  // جلب المكافآت المتاحة من الإدمن (Missions / Admin Rewards)
  Stream<QuerySnapshot> getAvailableRewardsStream() {
    return _firestore
        .collection('admin_rewards')
        .where('is_active', isEqualTo: true)
        .snapshots();
  }
}
