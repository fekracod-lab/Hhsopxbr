import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dalal_alqaim/core/app_globals.dart';
import 'package:dalal_alqaim/trip_screen.dart';
import 'package:dalal_alqaim/pages/my_orders_page.dart';
import 'package:dalal_alqaim/pages/transport_dashboard_page.dart';
import 'package:dalal_alqaim/pages/service_tracking_page.dart';
import 'package:dalal_alqaim/pages/notifications_page.dart';
import 'package:dalal_alqaim/pages/technical_support_chat_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/driver_dashboard_page.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/pages/restaurant_dashboard_page.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/store_dashboard_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/delivery_dashboard_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/parcel_tracking_page.dart';

/// موجه الإشعارات المركزي (Unified Notification Router)
/// يضمن فتح الصفحة والشاشة المناسبة مباشرة عند النقر على أي إشعار
class NotificationRouter {
  static final NotificationRouter _instance = NotificationRouter._internal();
  factory NotificationRouter() => _instance;
  NotificationRouter._internal();

  /// قائمة الانتظار للإشعارات التي يتم النقر عليها أثناء بدء تشغيل التطبيق
  static Map<String, dynamic>? _pendingRouteData;

  /// معالجة بيانات الإشعار والتوجيه الفوري للشاشة المعنية
  static void handleNotificationData(Map<String, dynamic>? rawData) {
    if (rawData == null || rawData.isEmpty) return;

    // تطبيع المفاتيح لتجنب اختلاف التسميات بين السيرفرات
    final Map<String, dynamic> data = {};
    rawData.forEach((key, value) {
      data[key.toString()] = value;
    });

    debugPrint(' [NotificationRouter] Handling notification routing: $data');

    final navState = appNavigatorKey.currentState;
    if (navState == null || isAppStarting) {
      debugPrint(' [NotificationRouter] App still initializing, saving pending route.');
      _pendingRouteData = data;
      return;
    }

    _navigate(navState, data);
  }

  /// معالجة وتفريغ أي إشعار كان بانتظار اكتمال بناء الواجهة
  static void processPendingNotification() {
    if (_pendingRouteData != null) {
      final data = _pendingRouteData!;
      _pendingRouteData = null;
      Future.delayed(const Duration(milliseconds: 600), () {
        final navState = appNavigatorKey.currentState;
        if (navState != null) {
          debugPrint(' [NotificationRouter] Processing deferred notification route: $data');
          _navigate(navState, data);
        }
      });
    }
  }

  /// توجيه المستخدم للشاشة المناسبة بحسب نوع الإشعار والبيانات المرفقة
  static void _navigate(NavigatorState nav, Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? data['notification_type']?.toString();
    final rideId = data['rideId']?.toString() ?? data['ride_id']?.toString() ?? data['id']?.toString();
    final requestId = data['requestId']?.toString() ?? data['request_id']?.toString() ?? data['id']?.toString();
    final currentRole = currentUserRole?.toLowerCase() ?? 'customer';
    final userUid = FirebaseAuth.instance.currentUser?.uid;

    try {
      // 1. إشعارات التاكسي والرحلات
      if (type == 'new_ride' || type == 'ride_request' || type == 'taxi_request' || type == 'new_request') {
        final isCaptain = currentRole == 'taxi_captain' || currentRole == 'driver' || currentRole == 'captain' || currentRole == 'admin';
        if (isCaptain) {
          nav.push(MaterialPageRoute(builder: (_) => const DriverDashboardPage()));
        } else if (rideId != null && rideId.isNotEmpty) {
          nav.push(MaterialPageRoute(builder: (_) => TripScreen(rideId: rideId)));
        } else {
          nav.push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
        }
        return;
      }

      // 2. تحديثات حالة رحلة التاكسي
      if (type == 'ride_status' || type == 'ride_cancelled' || type == 'ride_accepted' || type == 'trip_completed' || type == 'ride_update') {
        if (rideId != null && rideId.isNotEmpty) {
          nav.push(MaterialPageRoute(builder: (_) => TripScreen(rideId: rideId)));
        } else {
          nav.push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
        }
        return;
      }

      // 3. إشعارات المطاعم وطلبات الطعام
      if (type == 'restaurant_order' || type == 'new_order') {
        final isRestaurantOwner = currentRole == 'restaurant' || currentRole == 'merchant' || currentRole == 'restaurant_owner' || currentRole == 'admin';
        if (isRestaurantOwner) {
          nav.push(MaterialPageRoute(builder: (_) => const RestaurantDashboardPage()));
        } else {
          nav.push(MaterialPageRoute(builder: (_) => const MyOrdersPage()));
        }
        return;
      }

      // 4. تحديثات حالة طلب الطعام للزبون
      if (type == 'order_status' || type == 'food_order_ready' || type == 'order_status_updated') {
        nav.push(MaterialPageRoute(builder: (_) => const MyOrdersPage()));
        return;
      }

      // 5. إشعارات المتاجر (Madar Stores)
      if (type == 'new_store_order' || type == 'store_order') {
        final isStoreOwner = currentRole == 'store_owner' || currentRole == 'merchant' || currentRole == 'admin';
        final storeId = data['storeId']?.toString() ?? data['store_id']?.toString() ?? userUid ?? '';
        if (isStoreOwner && storeId.isNotEmpty) {
          nav.push(MaterialPageRoute(builder: (_) => StoreDashboardPage(storeId: storeId)));
        } else {
          nav.push(MaterialPageRoute(builder: (_) => const MyOrdersPage()));
        }
        return;
      }

      // 6. طلب جاهز للتوصيل للكباتن والمندوبين
      if (type == 'store_order_ready' || type == 'food_order') {
        const deliveryRoles = ['delivery_captain', 'delivery_boy', 'delivery', 'delegate', 'delivery_driver', 'driver', 'taxi_captain', 'admin'];
        final isDelivery = deliveryRoles.contains(currentRole);
        if (isDelivery) {
          nav.push(MaterialPageRoute(builder: (_) => const DeliveryDashboardPage()));
        } else {
          nav.push(MaterialPageRoute(builder: (_) => const MyOrdersPage()));
        }
        return;
      }

      // 7. إشعارات الطرود (Parcel)
      if (type == 'parcel_request' || type == 'parcel_status') {
        if (requestId != null && requestId.isNotEmpty) {
          nav.push(MaterialPageRoute(builder: (_) => ParcelTrackingPage(requestId: requestId)));
        } else {
          nav.push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
        }
        return;
      }

      // 8. إشعارات مرسال (Mersal) والمندوب (Delegate)
      if (type == 'mersal_request' || type == 'mersal_status') {
        if (requestId != null && requestId.isNotEmpty) {
          nav.push(MaterialPageRoute(builder: (_) => ServiceTrackingPage(requestId: requestId, serviceType: 'mersal')));
        } else {
          nav.push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
        }
        return;
      }

      if (type == 'delegate_request' || type == 'delegate_status') {
        if (requestId != null && requestId.isNotEmpty) {
          nav.push(MaterialPageRoute(builder: (_) => ServiceTrackingPage(requestId: requestId, serviceType: 'delegate')));
        } else {
          nav.push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
        }
        return;
      }

      // 9. طلبات النقل الخارجي
      if (type == 'transport_request' || type == 'transport_status') {
        nav.push(MaterialPageRoute(builder: (_) => const TransportDashboardPage()));
        return;
      }

      // 10. رسائل الدعم الفني والمحادثات
      if (type == 'support_request' || type == 'support_message') {
        final targetChatUserId = data['userId']?.toString() ?? data['user_id']?.toString() ?? userUid ?? '';
        final userName = data['userName']?.toString() ?? 'المستخدم';
        nav.push(MaterialPageRoute(builder: (_) => TechnicalSupportChatPage(userId: targetChatUserId, userName: userName)));
        return;
      }

      // 11. التوجيه الافتراضي لصفحة التنبيهات
      nav.push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
    } catch (e) {
      debugPrint(' [NotificationRouter] Navigation error: $e');
      nav.push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
    }
  }

  /// فك تشفير البيانات من payload السلاسل النصية المحلية
  static Map<String, dynamic>? parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (e) {
      debugPrint(' [NotificationRouter] Error parsing json payload: $e');
    }
    return null;
  }
}
