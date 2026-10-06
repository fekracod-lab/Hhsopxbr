import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/shop_online_order.dart';

/// خدمة مراقبة وإدارة طلبات تطبيق مدار الواردة إلى كاشير المتجر
class OnlineOrdersService extends ChangeNotifier {
  static final OnlineOrdersService instance = OnlineOrdersService._();
  OnlineOrdersService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _ordersSub;
  List<ShopOnlineOrder> _orders = [];

  List<ShopOnlineOrder> get orders => List.unmodifiable(_orders);
  int get pendingOrdersCount => _orders.where((o) => o.isPending).length;

  void startListening(String storeId) {
    if (storeId.isEmpty) return;
    _ordersSub?.cancel();
    _ordersSub = _firestore
        .collection('stores')
        .doc(storeId)
        .collection('madar_orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      _orders = snap.docs.map((d) => ShopOnlineOrder.fromFirestore(d)).toList();
      notifyListeners();
    }, onError: (err) {
      debugPrint('[OnlineOrdersService] listening error: $err');
    });
  }

  /// تحديث حالة الطلب (قبول، تجهيز، تسليم، إلغاء)
  Future<void> updateOrderStatus({
    required String storeId,
    required String orderId,
    required String newStatus,
  }) async {
    try {
      await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('madar_orders')
          .doc(orderId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[OnlineOrdersService] update status error: $e');
    }
  }

  void stopListening() {
    _ordersSub?.cancel();
    _orders = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    super.dispose();
  }
}
