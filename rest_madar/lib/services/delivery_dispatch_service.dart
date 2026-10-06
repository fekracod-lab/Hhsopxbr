import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/database/local_database_service.dart';
import '../features/pos/domain/pos_order.dart';
import 'notification_service.dart';

/// نموذج مندوب وكابتن التوصيل في تطبيق مدار
class OnlineCourier {
  final String id;
  final String name;
  final String phone;
  final String? imageUrl;
  final String vehicleType;
  final bool isOnline;
  final double rating;
  final String? city;

  const OnlineCourier({
    required this.id,
    required this.name,
    required this.phone,
    this.imageUrl,
    this.vehicleType = 'دراجة نارية 🛵',
    this.isOnline = true,
    this.rating = 5.0,
    this.city,
  });

  factory OnlineCourier.fromFirestore(Map<String, dynamic> data, String id) {
    final rawRating = data['rating'] ?? data['rate'] ?? 5.0;
    double parsedRating = 5.0;
    if (rawRating is num) parsedRating = rawRating.toDouble();
    if (rawRating is String) parsedRating = double.tryParse(rawRating) ?? 5.0;

    final avail = (data['availability'] ?? data['status'] ?? '').toString().toLowerCase();
    final isAvail = avail == 'online' ||
        avail == 'available' ||
        (data['available'] == true) ||
        (data['isOnline'] == true) ||
        avail != 'offline';

    final veh = data['vehicleType'] ?? data['transportType'] ?? data['carType'];
    String vehicleDisplay = 'دراجة نارية 🛵';
    if (veh != null) {
      final vStr = veh.toString().toLowerCase();
      if (vStr.contains('car') || vStr.contains('سيارة')) {
        vehicleDisplay = 'سيارة 🚗';
      } else if (vStr.contains('bike') || vStr.contains('دراجة') || vStr.contains('motor')) {
        vehicleDisplay = 'دراجة نارية 🛵';
      }
    }

    return OnlineCourier(
      id: id,
      name: (data['name'] ?? data['fullName'] ?? data['driverName'] ?? 'كابتن مدار').toString(),
      phone: (data['phone'] ?? data['phoneNumber'] ?? data['mobile'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? data['photoUrl'] ?? data['avatar'])?.toString(),
      vehicleType: vehicleDisplay,
      isOnline: isAvail,
      rating: parsedRating.clamp(1.0, 5.0),
      city: data['city']?.toString() ?? 'القائم',
    );
  }
}

/// خدمة إسناد الطلبات والبحث عن مناديب مدار وإرسال الإشعارات الفورية
class DeliveryDispatchService {
  static final DeliveryDispatchService instance = DeliveryDispatchService._internal();
  DeliveryDispatchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// بث حي واستماع لقائمة المناديب والكباتن المتصلين في تطبيق مدار
  Stream<List<OnlineCourier>> getOnlineCouriersStream() {
    return _firestore.collection('drivers').snapshots().map((snapshot) {
      final List<OnlineCourier> list = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final courier = OnlineCourier.fromFirestore(data, doc.id);
        if (courier.isOnline) {
          list.add(courier);
        }
      }
      return list;
    });
  }

  /// إرسال إشعار فوري لجميع مناديب وكباتن مدار وتفعيل البحث عن سائق
  Future<bool> broadcastToAllCouriers({
    required PosOrder order,
    required String restaurantName,
  }) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final destination = order.deliveryAddress?.isNotEmpty == true
          ? order.deliveryAddress!
          : 'القائم';

      debugPrint('[DeliveryDispatchService] Broadcasting order #${order.orderId} to all couriers in Madar...');

      // 1. تحديث وثيقة الطلب في Firestore
      await _firestore.collection('orders').doc(order.orderId).update({
        'deliveryStatus': 'searching_driver',
        'broadcastToDrivers': true,
        'driverRequested': true,
        'driverRequestedAt': FieldValue.serverTimestamp(),
        'driverSearchTriggeredAt': FieldValue.serverTimestamp(),
        'restaurantName': restaurantName,
        'status': (order.status == 'new' || order.status == 'pending')
            ? 'preparing'
            : order.status,
      });

      // 1.1 مزامنة نسخة في delivery_orders لضمان التقاطها من شاشة طلبات المناديب
      try {
        await _firestore.collection('delivery_orders').doc(order.orderId).set({
          'orderId': order.orderId,
          'restaurantId': order.restaurantId,
          'restaurantName': restaurantName,
          'customerName': order.customerName ?? 'زبون سفري',
          'customerPhone': order.customerPhone ?? '',
          'destinationAddress': destination,
          'totalAmount': order.totalAmount,
          'deliveryFee': order.deliveryFee,
          'status': 'ready_for_pickup',
          'type': 'food_order',
          'createdAt': FieldValue.serverTimestamp(),
          'driverId': null,
          'driverName': null,
          'driverPhone': null,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[DeliveryDispatchService] delivery_orders mirror notice: $e');
      }

      // 1.2 إرسال تنبيه في driver_notifications
      try {
        await _firestore.collection('driver_notifications').add({
          'type': 'new_food_delivery',
          'orderId': order.orderId,
          'restaurantName': restaurantName,
          'title': 'طلب توصيل جديد من $restaurantName 🛵',
          'body': 'الزبون: ${order.customerName ?? "زبون"} • $destination • أجرة التوصيل: ${order.deliveryFee} د.ع',
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      } catch (e) {
        debugPrint('[DeliveryDispatchService] Driver notification notice: $e');
      }

      // 2. تحديث الطلب محلياً في SQLite
      try {
        final db = await LocalDatabaseService.instance.database;
        await db.update(
          'local_orders',
          {
            'status': (order.status == 'new' || order.status == 'pending')
                ? 'preparing'
                : order.status,
          },
          where: 'local_id = ? OR remote_id = ?',
          whereArgs: [order.orderId, order.orderId],
        );
      } catch (_) {}

      // 3. كتابة طلب إشعار FCM فوري في Firestore (سيرفر Cloud Functions يعالجها ويرسل الإشعار بكافة القنوات)
      await _firestore.collection('notification_requests').add({
        'type': 'food_order_ready',
        'channelId': 'madar_delivery_urgent_v2',
        'priority': 'high',
        'payload': {
          'orderId': order.orderId,
          'restaurantId': order.restaurantId,
          'restaurantName': restaurantName,
          'deliveryAddress': destination,
          'customerName': order.customerName ?? 'زبون مدار',
          'customerPhone': order.customerPhone ?? '',
          'totalAmount': order.totalAmount,
          'deliveryFee': order.deliveryFee,
          'title': '🛵 طلبية توصيل جديدة من $restaurantName!',
          'body': 'طلبية طعام جديدة جاهزة للتوصيل إلى ($destination). افتح التطبيق واستلم الطلب! ⚡',
        },
        'senderId': currentUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. استدعاء بوابة الإشعارات المركزية لمدار عبر Supabase Edge Functions
      try {
        await NotificationService.emitEvent(
          type: 'food_order_ready',
          payload: {
            'orderId': order.orderId,
            'restaurantId': order.restaurantId,
            'restaurantName': restaurantName,
            'deliveryAddress': destination,
            'customerName': order.customerName ?? 'الزبون',
            'title': '🛵 طلبية توصيل جديدة من $restaurantName!',
            'body': 'طلبية طعام جديدة جاهزة للتوصيل إلى ($destination). اضغط للمعاينة والاستلام!',
          },
        );
      } catch (e) {
        debugPrint('[DeliveryDispatchService] Supabase event emission notice: $e');
      }

      // 5. حفظ الإشعار في جدول الإشعارات العام للمناديب
      await _firestore.collection('notifications').add({
        'title': '🛵 طلبية توصيل طعام جديدة',
        'body': 'مطعم "$restaurantName" يطلب كابتن لتوصيل طلبية إلى ($destination).',
        'type': 'food_order_ready',
        'target': 'delivery_captains',
        'orderId': order.orderId,
        'restaurantId': order.restaurantId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('[DeliveryDispatchService] Broadcast successfully registered!');
      return true;
    } catch (e) {
      debugPrint('[DeliveryDispatchService] Error broadcasting to couriers: $e');
      return false;
    }
  }

  /// إسناد الطلب لمندوب محدد وإرسال إشعار خاص ومباشر له في تطبيق مدار
  Future<bool> assignSpecificCourier({
    required PosOrder order,
    required OnlineCourier courier,
    required String restaurantName,
  }) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final destination = order.deliveryAddress?.isNotEmpty == true
          ? order.deliveryAddress!
          : 'القائم';

      debugPrint('[DeliveryDispatchService] Assigning order #${order.orderId} to courier ${courier.name} (${courier.id})...');

      // 1. تحديث الطلب في Firestore
      await _firestore.collection('orders').doc(order.orderId).update({
        'driverId': courier.id,
        'driverName': courier.name,
        'driverPhone': courier.phone,
        'driverImage': courier.imageUrl,
        'deliveryStatus': 'assigned',
        'driverAssignedAt': FieldValue.serverTimestamp(),
        'status': 'on_way',
      });

      // 2. تحديث الطلب محلياً في SQLite
      try {
        final db = await LocalDatabaseService.instance.database;
        await db.update(
          'local_orders',
          {
            'status': 'on_way',
          },
          where: 'local_id = ? OR remote_id = ?',
          whereArgs: [order.orderId, order.orderId],
        );
      } catch (_) {}

      // 3. إرسال إشعار FCM مباشر وخاص إلى جهاز المندوب
      await _firestore.collection('notification_requests').add({
        'type': 'user_notification',
        'channelId': 'madar_delivery_urgent_v2',
        'priority': 'high',
        'payload': {
          'userId': courier.id,
          'orderId': order.orderId,
          'restaurantName': restaurantName,
          'title': '🛵 تم إسناد طلبية توصيل لك!',
          'body': 'مطعم "$restaurantName" قام بتعيينك لتوصيل طلبية #${order.orderId} إلى ($destination). يرجى التوجه للمطعم للاستلام 💨',
        },
        'senderId': currentUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. حفظ الإشعار في صندوق إشعارات المندوب داخل التطبيق
      await _firestore
          .collection('drivers')
          .doc(courier.id)
          .collection('notifications')
          .add({
        'title': '🛵 تم إسناد طلبية طعام لك!',
        'body': 'مطعم "$restaurantName" أسند لك توصيل طلبية #${order.orderId} إلى ($destination).',
        'orderId': order.orderId,
        'restaurantName': restaurantName,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      debugPrint('[DeliveryDispatchService] Courier assigned and notified successfully!');
      return true;
    } catch (e) {
      debugPrint('[DeliveryDispatchService] Error assigning courier: $e');
      return false;
    }
  }

  /// إلغاء البحث عن مندوب
  Future<bool> cancelCourierSearch(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'deliveryStatus': 'cancelled_search',
        'broadcastToDrivers': false,
        'driverId': null,
        'driverName': null,
        'driverPhone': null,
      });
      return true;
    } catch (e) {
      debugPrint('[DeliveryDispatchService] Error cancelling courier search: $e');
      return false;
    }
  }
}
