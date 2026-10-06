import '../entities/notification_event.dart';
import '../entities/notification_message.dart';
import '../entities/notification_delivery.dart';
import '../entities/notification_preference.dart';
import '../entities/notification_policy.dart';
import '../entities/notification_audit_record.dart';

/// العقد التجريدي لمستودع الإشعارات المركزي (INotificationRepository)
abstract class INotificationRepository {
  /// حفظ حدث إشعار جديد
  Future<NotificationEvent> saveEvent(NotificationEvent event);

  /// حفظ وتحديث سجل تسليم إشعار
  Future<NotificationDelivery> saveDelivery(NotificationDelivery delivery);

  /// جلب سجل تسليم محدد
  Future<NotificationDelivery?> getDelivery(String deliveryId);

  /// جلب تفضيلات المستخدم
  Future<NotificationPreference> getPreference(String userId);

  /// حفظ تفضيلات المستخدم
  Future<void> savePreference(NotificationPreference preference);

  /// جلب سياسة حوكمة الإشعارات النشطة
  Future<NotificationPolicy> getPolicy();

  /// حفظ سجل تدقيق للإشعار (Append-only audit)
  Future<void> saveAuditRecord(NotificationAuditRecord record);

  /// التحقق من مفتاح عدم التكرار
  Future<bool> verifyIdempotencyKey(String idempotencyKey);

  /// تسليم الإشعار عبر القناة المحددة (Push / In-App / Local)
  Future<bool> deliverViaChannel({
    required NotificationDelivery delivery,
    required NotificationMessage message,
  });
}
