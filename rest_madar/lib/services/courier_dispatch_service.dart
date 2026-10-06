import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// خدمة بث وتكليف مناديب مدار بنقرة واحدة من كاشير المطعم
class CourierDispatchService {
  CourierDispatchService._();
  static final CourierDispatchService instance = CourierDispatchService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// بث طلب التوصيل لكافة مناديب مدار النشطين في المنطقة
  Future<bool> dispatchOrderToCouriers({
    required String orderId,
    required Map<String, dynamic> orderData,
    String? customNotes,
  }) async {
    try {
      final restaurantUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final restaurantName = orderData['restaurantName']?.toString() ?? 'مطعم مدار';
      final customerName = orderData['customerName']?.toString() ?? 'زبون سفري';
      final customerPhone = orderData['customerPhone']?.toString() ?? '';
      final address = orderData['address']?.toString() ?? 'القائم';
      final total = (orderData['total'] ?? orderData['totalPrice'] ?? orderData['grandTotal'] ?? 0) as num;
      final deliveryFee = (orderData['deliveryFee'] ?? 2500) as num;

      final now = FieldValue.serverTimestamp();

      // 1. تحديث الطلب في مجموعة orders ليكون متاحاً للمناديب فوراً
      await _firestore.collection('orders').doc(orderId).set({
        'status': 'ready',
        'driverRequested': true,
        'driverRequestedAt': now,
        'restaurantReadyAt': now,
        'dispatchType': 'madar_courier_broadcast',
        'restaurantId': restaurantUid.isNotEmpty ? restaurantUid : (orderData['restaurantId'] ?? ''),
        'restaurantName': restaurantName,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'address': address,
        'total': total,
        'deliveryFee': deliveryFee,
        'courierNotes': customNotes ?? 'يُرجى استلام الوجبة ساخنة من الكاشير فوراً',
        'updatedAt': now,
      }, SetOptions(merge: true));

      // 2. مزامنة نسخة في delivery_orders لضمان التقاطها من منظومة المناديب
      try {
        await _firestore.collection('delivery_orders').doc(orderId).set({
          'orderId': orderId,
          'restaurantId': restaurantUid,
          'restaurantName': restaurantName,
          'customerName': customerName,
          'customerPhone': customerPhone,
          'destinationAddress': address,
          'totalAmount': total,
          'deliveryFee': deliveryFee,
          'status': 'ready_for_pickup',
          'type': 'food_order',
          'createdAt': now,
          'driverId': null,
          'driverName': null,
          'driverPhone': null,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[CourierDispatchService] delivery_orders mirror notice: $e');
      }

      // 3. إرسال إشعار فوري لكافة المناديب في المنطقة
      try {
        await _firestore.collection('driver_notifications').add({
          'type': 'new_food_delivery',
          'orderId': orderId,
          'restaurantName': restaurantName,
          'title': 'طلب توصيل جديد من $restaurantName 🛵',
          'body': 'الزبون: $customerName • $address • أجرة التوصيل: $deliveryFee د.ع',
          'createdAt': now,
          'isRead': false,
        });
      } catch (e) {
        debugPrint('[CourierDispatchService] Driver notification notice: $e');
      }

      debugPrint('[CourierDispatchService] ✓ Order $orderId broadcasted to couriers successfully.');
      return true;
    } catch (e) {
      debugPrint('[CourierDispatchService] Error dispatching order to couriers: $e');
      return false;
    }
  }

  /// الاستماع لحالة المندوب المكلف بالطلب
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToOrderCourier(String orderId) {
    return _firestore.collection('orders').doc(orderId).snapshots();
  }

  /// إحصاء عدد المناديب المتاحين حالياً في المنظومة
  Stream<int> getActiveCouriersCount() {
    return _firestore
        .collection('drivers')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.where((doc) {
            final data = doc.data();
            final avail = data['availability']?.toString();
            final isOnline = data['isOnline'] as bool? ?? true;
            return isOnline && (avail == null || avail == 'available' || avail == 'on_trip');
          }).length;
        });
  }
}
