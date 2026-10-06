import 'package:cloud_firestore/cloud_firestore.dart';

/// مستودع طلبات انضمام المتاجر (Store KYC Repository)
/// يستعلم حصرياً من مجموعة store_requests فقط دون خلط مع المطاعم.
class StoreKycRepository {
  final FirebaseFirestore _firestore;

  StoreKycRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// دفق طلبات انضمام المتاجر المعلقة
  Stream<QuerySnapshot<Map<String, dynamic>>> streamPendingStoreKyc() {
    return _firestore
        .collection('store_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// دفق عدد طلبات المتاجر المعلقة
  Stream<int> streamPendingStoreKycCount() {
    return streamPendingStoreKyc().map((s) => s.docs.length);
  }

  /// اعتماد طلب انضمام متجر
  Future<void> approveStoreKyc({
    required String docId,
    required Map<String, dynamic> requestData,
  }) async {
    final batch = _firestore.batch();
    final ownerId = requestData['ownerId'] ?? requestData['uid'] ?? docId;
    final storeId = requestData['storeId'] ?? ownerId;

    final reqRef = _firestore.collection('store_requests').doc(docId);
    batch.update(reqRef, {
      'status': 'approved',
      'processedAt': FieldValue.serverTimestamp(),
    });

    final storeRef = _firestore.collection('stores').doc(storeId);
    batch.set(storeRef, {
      ...requestData,
      'storeId': storeId,
      'ownerId': ownerId,
      'status': 'active',
      'isApproved': true,
      'rating': 5.0,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final userRef = _firestore.collection('users').doc(ownerId);
    batch.update(userRef, {
      'role': 'store',
      'status': 'active',
      'isApproved': true,
      'storeId': storeId,
      'approvedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// رفض طلب انضمام متجر
  Future<void> rejectStoreKyc({
    required String docId,
    required String ownerId,
    String? reason,
  }) async {
    final batch = _firestore.batch();

    final reqRef = _firestore.collection('store_requests').doc(docId);
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
