import 'package:cloud_firestore/cloud_firestore.dart';

/// مستودع طلبات المتاجر المنفصل (Store Orders Repository)
/// يستعلم حصرياً من stores/{storeId}/madar_orders وعبر collectionGroup('madar_orders') دون خلط مع طلبات المطاعم.
class StoreOrdersRepository {
  final FirebaseFirestore _firestore;

  StoreOrdersRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// دفق جميع طلبات المتاجر عبر المجموعة المجمعة (Admin CollectionGroup Stream)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamStoreOrders({String? status}) {
    Query<Map<String, dynamic>> query = _firestore
        .collectionGroup('madar_orders')
        .orderBy('createdAt', descending: true);

    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots();
  }

  /// دفق طلبات متجر محدد
  Stream<QuerySnapshot<Map<String, dynamic>>> streamOrdersByStore(String storeId, {String? status}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('stores')
        .doc(storeId)
        .collection('madar_orders')
        .orderBy('createdAt', descending: true);

    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots();
  }

  /// جلب طلب متجر محدد
  Future<DocumentSnapshot<Map<String, dynamic>>?> getStoreOrder(String storeId, String orderId) async {
    final doc = await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('madar_orders')
        .doc(orderId)
        .get();
    if (!doc.exists) return null;
    return doc;
  }

  /// تحديث حالة طلب المتجر مع تحديث المرآة للعميل بشكل متزامن
  Future<void> updateStoreOrderStatus({
    required String storeId,
    required String customerId,
    required String orderId,
    required String newStatus,
  }) async {
    final batch = _firestore.batch();

    final storeOrderRef = _firestore
        .collection('stores')
        .doc(storeId)
        .collection('madar_orders')
        .doc(orderId);

    final userOrderRef = _firestore
        .collection('madar_orders')
        .doc(customerId)
        .collection('store_orders')
        .doc(orderId);

    final payload = <String, dynamic>{
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    batch.update(storeOrderRef, payload);
    batch.update(userOrderRef, payload);

    await batch.commit();
  }

  /// دفق إجمالي عدد طلبات المتاجر
  Stream<int> streamStoreOrdersCount({String? status}) {
    Query<Map<String, dynamic>> query = _firestore.collectionGroup('madar_orders');
    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots().map((s) => s.docs.length);
  }
}
