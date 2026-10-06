import '../enums/notification_enums.dart';

/// محرك تحديد أولوية الإشعارات الحتمي (Notification Priority Engine)
class NotificationPriorityEngine {
  const NotificationPriorityEngine();

  /// تحديد أولوية الحدث بناءً على طبيعته وتصنيفه الأمني والتشغيلي
  static NotificationPriority resolvePriority(NotificationEventType eventType) {
    switch (eventType) {
      // 1. Critical: طوارئ، أمان، خروقات
      case NotificationEventType.emergencySos:
      case NotificationEventType.securityViolation:
        return NotificationPriority.critical;

      // 2. High: عروض السائقين، تعيين الطلبات، فشل الدفع
      case NotificationEventType.driverNewOffer:
      case NotificationEventType.rideRequested:
      case NotificationEventType.rideAccepted:
      case NotificationEventType.orderAssigned:
      case NotificationEventType.paymentFailed:
        return NotificationPriority.high;

      // 3. Normal: تحديثات مسار الطلب، الرحلات، الدردشة، التسويات
      case NotificationEventType.orderCreated:
      case NotificationEventType.orderConfirmed:
      case NotificationEventType.orderPreparing:
      case NotificationEventType.orderReady:
      case NotificationEventType.orderPickedUp:
      case NotificationEventType.orderDelivered:
      case NotificationEventType.orderCancelled:
      case NotificationEventType.rideDriverArriving:
      case NotificationEventType.rideStarted:
      case NotificationEventType.rideCompleted:
      case NotificationEventType.rideCancelled:
      case NotificationEventType.paymentCompleted:
      case NotificationEventType.refundRequested:
      case NotificationEventType.refundCompleted:
      case NotificationEventType.walletDeposit:
      case NotificationEventType.walletWithdrawal:
      case NotificationEventType.chatMessage:
        return NotificationPriority.normal;

      // 4. Low: ترويجات، إعلانات، تحديثات عامة
      case NotificationEventType.driverOfferExpired:
      case NotificationEventType.driverOfferRejected:
      case NotificationEventType.systemBroadcast:
      case NotificationEventType.marketing:
        return NotificationPriority.low;
    }
  }
}
