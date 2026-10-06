import 'package:cloud_firestore/cloud_firestore.dart';

/// مصدر البيانات البعيد لإدارة وتحليلات المتاجر (Store Analytics Remote Datasource)
class StoreAnalyticsRemoteDatasource {
  final FirebaseFirestore _firestore;

  StoreAnalyticsRemoteDatasource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// بث طلبات المتاجر المالية (Store Orders Stream)
  Stream<List<Map<String, dynamic>>> getStoreOrdersStream() {
    return _firestore.collection('store_orders').snapshots().map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// بث مستخدمي وأصحاب المتاجر المسجلين
  Stream<List<Map<String, dynamic>>> getStoreUsersStream() {
    return _firestore
        .collection('users')
        .where('role', whereIn: ['store', 'merchant', 'store_owner'])
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['_source'] = 'users';
        return data;
      }).toList();
    });
  }

  /// بث طلبات انضمام المتاجر المباشرة
  Stream<List<Map<String, dynamic>>> getStoreRequestsStream() {
    return _firestore.collection('store_requests').snapshots().map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['_source'] = 'store_requests';
        return data;
      }).toList();
    });
  }

  /// الموافقة على متجر وتفعيل حسابه
  Future<void> approveStore(String storeId) async {
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(storeId);
    final storeRef = _firestore.collection('stores').doc(storeId);

    batch.set(userRef, {
      'isApproved': true,
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(storeRef, {
      'isApproved': true,
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// رفض طلب انضمام المتجر
  Future<void> rejectStore(String storeId) async {
    await _firestore.collection('users').doc(storeId).set({
      'isApproved': false,
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// تبديل حالة المتجر (تفعيل / تجميد)
  Future<void> toggleStoreStatus(String storeId, bool isApproved) async {
    final newStatus = isApproved ? 'active' : 'disabled';
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(storeId);
    final storeRef = _firestore.collection('stores').doc(storeId);

    batch.set(userRef, {
      'isApproved': isApproved,
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(storeRef, {
      'isApproved': isApproved,
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
