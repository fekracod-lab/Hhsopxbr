import '../entities/notification_target.dart';
import '../enums/notification_enums.dart';

/// محرك توجيه واستهداف الإشعارات (Notification Routing Engine)
class NotificationRoutingEngine {
  const NotificationRoutingEngine();

  /// حل وتحديد مستلمي الإشعار بناءً على نوع الحدث والبيانات المرفقة
  static NotificationTarget resolveTarget({
    required NotificationEventType eventType,
    String? customerId,
    String? driverId,
    String? merchantId,
    String? customRole,
    List<String>? emergencyContactIds,
  }) {
    switch (eventType) {
      // 1. طلبات موجهة للكباتن والمناديب
      case NotificationEventType.driverNewOffer:
        if (driverId != null && driverId.isNotEmpty) {
          return NotificationTarget(targetUserIds: [driverId]);
        }
        return NotificationTarget(targetRole: customRole ?? 'driver');

      case NotificationEventType.rideRequested:
        return const NotificationTarget(targetRole: 'taxi_captain');

      // 2. طلبات موجهة للتجار والمطابخ
      case NotificationEventType.orderCreated:
        if (merchantId != null && merchantId.isNotEmpty) {
          return NotificationTarget(targetUserIds: [merchantId]);
        }
        return const NotificationTarget(targetRole: 'merchant');

      // 3. تحديثات موجهة للعميل صاحب الطلب أو الرحلة
      case NotificationEventType.orderConfirmed:
      case NotificationEventType.orderPreparing:
      case NotificationEventType.orderReady:
      case NotificationEventType.orderAssigned:
      case NotificationEventType.orderPickedUp:
      case NotificationEventType.orderDelivered:
      case NotificationEventType.orderCancelled:
      case NotificationEventType.rideAccepted:
      case NotificationEventType.rideDriverArriving:
      case NotificationEventType.rideStarted:
      case NotificationEventType.rideCompleted:
      case NotificationEventType.rideCancelled:
      case NotificationEventType.paymentCompleted:
      case NotificationEventType.paymentFailed:
      case NotificationEventType.refundRequested:
      case NotificationEventType.refundCompleted:
      case NotificationEventType.walletDeposit:
      case NotificationEventType.walletWithdrawal:
        return NotificationTarget(
          targetUserIds: customerId != null && customerId.isNotEmpty ? [customerId] : [],
        );

      // 4. إشعارات الطوارئ والأمان
      case NotificationEventType.emergencySos:
        final targets = <String>[];
        if (emergencyContactIds != null) {
          targets.addAll(emergencyContactIds.where((id) => id.isNotEmpty));
        }
        return NotificationTarget(
          targetUserIds: targets,
          targetRole: 'admin',
        );

      case NotificationEventType.securityViolation:
        return const NotificationTarget(targetRole: 'admin');

      // 5. رسائل الدردشة والتعميمات
      case NotificationEventType.chatMessage:
        final recipient = customerId ?? driverId ?? merchantId;
        return NotificationTarget(
          targetUserIds: recipient != null && recipient.isNotEmpty ? [recipient] : [],
        );

      case NotificationEventType.systemBroadcast:
      case NotificationEventType.marketing:
      case NotificationEventType.driverOfferExpired:
      case NotificationEventType.driverOfferRejected:
        return const NotificationTarget(topic: 'all_users');
    }
  }
}
