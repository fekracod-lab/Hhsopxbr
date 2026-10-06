import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../models/notification_model.dart';

class NotificationService {
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  
  // Role Categories for filtering (فصل منظومة التوصيل عن التكسي بدقة)
  static const List<String> taxiCaptainRoles = ['taxi_captain', 'taxi_driver', 'taxi', 'captain'];
  static const List<String> deliveryDelegateRoles = ['delivery', 'delivery_captain', 'delivery_boy', 'delegate', 'delivery_driver', 'driver'];
  // captainRoles مدمج مع taxiCaptainRoles (نفس القيم)
  static const List<String> driverNotificationTypes = [
    'new_ride', 'ride_request', 'new_request', 'taxi_request'
  ];
  static const List<String> deliveryNotificationTypes = [
    'mersal_request', 'new_mersal_request', 'delegate_request', 'parcel_request', 
    'food_order', 'food_order_ready', 'store_order_ready', 'new_delivery_order'
  ];


  /// Primary method to trigger a server-side notification event.
  /// Refactored to write to a Firestore collection 'notification_requests' for secure backend FCM delivery.
  static Future<void> emitEvent({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    // 1. Connectivity check
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      debugPrint(" Event suppressed: No internet connection.");
      return;
    }

    try {
      debugPrint(" Emitting Event via Firestore Notification Request: $type");
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await _firestore.collection('notification_requests').add({
        'type': type,
        'payload': payload,
        'senderId': currentUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint(" Notification request created in Firestore");
    } catch (e) {
      debugPrint(" Unexpected error emitting notification request: $e");
    }
  }

  /// Sends a broadcast notification to all taxi drivers.
  static Future<void> sendTaxiBroadcast(String message) async {
    await emitEvent(
      type: 'taxi_broadcast',
      payload: {
        'title': 'تعميم جديد للسائقين',
        'body': message,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    // Also save to history for record keeping
    await _firestore.collection('notifications').add({
      'title': 'تعميم جديد للسائقين',
      'body': message,
      'type': 'broadcast',
      'target': 'taxi_drivers',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Legacy Support: Save a notification to Firestore history.
  /// This can be called from Flutter or the server can handle history itself.
  static Future<void> saveToHistory({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notification = AppNotification(
        id: '',
        userId: userId,
        title: title,
        body: body,
        type: type,
        data: data ?? {},
        createdAt: DateTime.now(),
      );
      await _firestore.collection('notifications').add(notification.toMap());
    } catch (e) {
      debugPrint(" Error saving notification history: $e");
    }
  }

  // --- Utility Methods (Still needed for the UI) ---

  static Stream<List<AppNotification>> getNotificationsStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => AppNotification.fromMap(doc.data(), doc.id)).toList();
        });
  }

  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({'isRead': true});
    } catch (e) {
      debugPrint(" Error marking as read: $e");
    }
  }

  static Future<void> markAllAsRead(String userId) async {
    try {
      final snap = await _firestore.collection('notifications').where('userId', isEqualTo: userId).where('isRead', isEqualTo: false).get();
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      debugPrint(" Marked all notifications as read for user: $userId");
    } catch (e) {
      debugPrint(" Error marking all as read: $e");
    }
  }

  static Future<void> clearAllNotifications(String userId) async {
    try {
      final snap = await _firestore.collection('notifications').where('userId', isEqualTo: userId).get();
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint(" Cleared all notifications for user: $userId");
    } catch (e) {
      debugPrint(" Error clearing all notifications: $e");
    }
  }

  /// Centralized filtering logic to prevent unauthorized/wrong-role notifications.
  /// Returns true if the notification SHOULD be displayed.
  static bool shouldDisplayNotification({
    required Map<String, dynamic> data,
    required String? currentRole,
    required String? currentUid,
  }) {
    final type = data['type']?.toString() ?? data['notification_type']?.toString();
    if (type == null) return true; // Show generic notifications

    // 0. Targeted notifications: If this notification was sent directly to the
    // current user via external_id (e.g. new_store_order to ownerId),
    // always allow it through regardless of role.
    final targetedTypes = {'new_store_order', 'restaurant_order_created', 'store_order_status_updated', 'order_status_updated'};
    if (targetedTypes.contains(type) && currentUid != null) {
      final targetId = data['ownerId'] ?? data['owner_id'] ?? data['userId'] ?? data['user_id'];
      if (targetId != null && currentUid == targetId.toString()) {
        debugPrint(' Allowing targeted notification "$type" for user: $currentUid');
        return true;
      }
    }

    final role = currentRole?.toLowerCase() ?? 'customer';

    // 1. Taxi Driver/Captain Notifications (Only for Taxi Captains)
    final taxiTypes = {'new_ride', 'ride_request', 'taxi_request', 'new_request'};
    if (taxiTypes.contains(type)) {
      final isTaxiCaptain = taxiCaptainRoles.contains(role) || role == 'admin';
      if (!isTaxiCaptain) {
        debugPrint(' Suppressed: Taxi notification "$type" for role: $role');
        return false;
      }
    }

    // 2. Delivery Delegate Notifications (Mersal & Parcel requests)
    final deliveryTypes = {'mersal_request', 'delegate_request', 'parcel_request'};
    if (deliveryTypes.contains(type)) {
      final isDeliveryDelegate = deliveryDelegateRoles.contains(role) || role == 'admin';
      if (!isDeliveryDelegate) {
        debugPrint(' Suppressed: Delivery notification "$type" for role: $role');
        return false;
      }
    }

    // 3. Restaurant/Merchant Notifications
    final merchantTypes = {'restaurant_order', 'new_order', 'store_order', 'new_store_order'};
    if (merchantTypes.contains(type)) {
      final isMerchant = role == 'merchant' || role == 'restaurant' || role == 'restaurant_owner' || role == 'store_owner' || role == 'admin';
      if (!isMerchant) {
        debugPrint(' Suppressed: Merchant notification "$type" for role: $role');
        return false;
      }
    }

    // 4. Food/Store Order Notifications (Exclusively for Delivery Delegates)
    if (type == 'food_order' || type == 'store_order_ready' || type == 'food_order_ready' || type == 'new_delivery_order') {
      final isDelivery = deliveryDelegateRoles.contains(role) || role == 'admin';
      if (!isDelivery) {
        debugPrint(' Suppressed: Order ready notification "$type" for role: $role');
        return false;
      }
    }

    // 5. Support Request Notifications (User to Support Agent)
    if (type == 'support_request') {
      final isSupportAgent = role == 'support' || role == 'admin';
      if (!isSupportAgent) {
        debugPrint(' Suppressed: Support request "$type" for role: $role');
        return false;
      }
    }

    // 6. Support Message Notifications (Support Agent to User)
    if (type == 'support_message') {
      final targetUserId = data['user_id'] ?? data['userId'];
      if (currentUid != null && targetUserId != null && currentUid != targetUserId.toString()) {
        debugPrint(' Suppressed: Support message not meant for current user UID: $currentUid');
        return false;
      }
    }

    // 7. Complaint Created Notifications (User to Complaint Admin)
    if (type == 'complaint_created' || type == 'new_complaint') {
      final isComplaintsAdmin = role == 'complaints_admin' || role == 'admin';
      if (!isComplaintsAdmin) {
        debugPrint(' Suppressed: Complaint notification "$type" for role: $role');
        return false;
      }
    }

    // 9. Admin Store Registration Request Notifications
    if (type == 'new_store_registration_request') {
      final isAdmin = role == 'admin' || role == 'main_admin' || role == 'limited_admin' || role == 'governorate_manager';
      if (!isAdmin) {
        debugPrint(' Suppressed: Admin notification "$type" for role: $role');
        return false;
      }
    }

    // 8. Self-notification filtering for requests (Don't notify the requester about their own request creation)
    final isRequestCreation = taxiTypes.contains(type) || 
                              deliveryTypes.contains(type) || 
                              merchantTypes.contains(type) || 
                              type == 'complaint_created' || 
                              type == 'new_complaint' ||
                              type == 'new_store_registration_request';
    if (isRequestCreation) {
      final requesterUid = data['userId'] ?? data['requesterId'] ?? data['customer_id'] ?? data['uid'] ?? data['senderId'];
      if (currentUid != null && requesterUid != null && currentUid == requesterUid.toString()) {
        debugPrint(' Filtering: Ignoring self-notification for UID: $currentUid');
        return false;
      }
    }

    return true;
  }
}
