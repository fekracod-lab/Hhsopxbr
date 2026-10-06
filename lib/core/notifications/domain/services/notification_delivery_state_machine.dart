import '../enums/notification_enums.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

/// آلة حالات تسليم الإشعارات الحتمية (Notification Delivery State Machine)
class NotificationDeliveryStateMachine {
  const NotificationDeliveryStateMachine();

  static const Map<DeliveryStatus, List<DeliveryStatus>> _legalTransitions = {
    DeliveryStatus.pending: [
      DeliveryStatus.queued,
      DeliveryStatus.sending,
      DeliveryStatus.suppressed,
      DeliveryStatus.expired,
    ],
    DeliveryStatus.queued: [
      DeliveryStatus.sending,
      DeliveryStatus.suppressed,
      DeliveryStatus.expired,
    ],
    DeliveryStatus.sending: [
      DeliveryStatus.sent,
      DeliveryStatus.retrying,
      DeliveryStatus.failed,
      DeliveryStatus.delivered,
    ],
    DeliveryStatus.retrying: [
      DeliveryStatus.sending,
      DeliveryStatus.failed,
    ],
    DeliveryStatus.sent: [
      DeliveryStatus.delivered,
      DeliveryStatus.failed,
      DeliveryStatus.read,
    ],
    DeliveryStatus.delivered: [
      DeliveryStatus.read,
    ],
    DeliveryStatus.read: [], // Terminal
    DeliveryStatus.failed: [], // Terminal
    DeliveryStatus.expired: [], // Terminal
    DeliveryStatus.suppressed: [], // Terminal
  };

  /// هل الانتقال بين الحالتين قانوني؟
  static bool canTransition(DeliveryStatus current, DeliveryStatus next) {
    if (current == next) return true;
    final allowed = _legalTransitions[current] ?? [];
    return allowed.contains(next);
  }

  /// التحقق الصارم من صحة الانتقال مع رمي استثناء أمني عند المخالفة
  static void assertValidTransition(DeliveryStatus current, DeliveryStatus next) {
    if (!canTransition(current, next)) {
      throw SecurityViolationException(
        'انتقال غير قانوني في حالة تسليم الإشعار من ${current.key} إلى ${next.key}',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'deliveryStatus',
      );
    }
  }
}
