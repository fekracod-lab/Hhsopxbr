import 'package:cloud_firestore/cloud_firestore.dart';

/// مستودع طلبات المطاعم المنفصل (Restaurant Orders Repository)
/// يستعلم حصرياً من مجموعة orders فقط (المصدر الرسمي لطلبات المطاعم) دون خلط مع المتاجر.
class RestaurantOrdersRepository {
  final FirebaseFirestore _firestore;

  RestaurantOrdersRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// دفق جميع طلبات المطاعم
  Stream<QuerySnapshot<Map<String, dynamic>>> streamRestaurantOrders({String? status, String? restaurantId}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true);

    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    if (restaurantId != null && restaurantId.isNotEmpty) {
      query = query.where('restaurantId', isEqualTo: restaurantId);
    }

    return query.snapshots();
  }

  /// جلب طلب مطعم محدد
  Future<DocumentSnapshot<Map<String, dynamic>>?> getRestaurantOrder(String orderId) async {
    final doc = await _firestore.collection('orders').doc(orderId).get();
    if (!doc.exists) return null;
    return doc;
  }

  /// تحديث حالة طلب مطعم
  Future<void> updateRestaurantOrderStatus(String orderId, String newStatus, {Map<String, dynamic>? extraData}) async {
    final payload = <String, dynamic>{
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (extraData != null) {
      payload.addAll(extraData);
    }
    await _firestore.collection('orders').doc(orderId).update(payload);
  }

  /// دفق إجمالي عدد طلبات المطاعم
  Stream<int> streamRestaurantOrdersCount({String? status}) {
    Query<Map<String, dynamic>> query = _firestore.collection('orders');
    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots().map((s) => s.docs.length);
  }
}
