import '../../domain/entities/notification_event.dart';
import '../../domain/entities/notification_message.dart';
import '../../domain/entities/notification_delivery.dart';
import '../../domain/entities/notification_preference.dart';
import '../../domain/entities/notification_policy.dart';
import '../../domain/entities/notification_audit_record.dart';
import '../../domain/repositories/i_notification_repository.dart';
import '../datasources/notification_remote_datasource.dart';

/// تطبيق مستودع الإشعارات المركزي (NotificationRepository)
class NotificationRepository implements INotificationRepository {
  final NotificationRemoteDatasource _remoteDatasource;

  NotificationRepository({NotificationRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? NotificationRemoteDatasource();

  @override
  Future<NotificationEvent> saveEvent(NotificationEvent event) {
    return _remoteDatasource.saveEvent(event);
  }

  @override
  Future<NotificationDelivery> saveDelivery(NotificationDelivery delivery) {
    return _remoteDatasource.saveDelivery(delivery);
  }

  @override
  Future<NotificationDelivery?> getDelivery(String deliveryId) {
    return _remoteDatasource.getDelivery(deliveryId);
  }

  @override
  Future<NotificationPreference> getPreference(String userId) {
    return _remoteDatasource.getPreference(userId);
  }

  @override
  Future<void> savePreference(NotificationPreference preference) {
    return _remoteDatasource.savePreference(preference);
  }

  @override
  Future<NotificationPolicy> getPolicy() {
    return _remoteDatasource.getPolicy();
  }

  @override
  Future<void> saveAuditRecord(NotificationAuditRecord record) {
    return _remoteDatasource.saveAuditRecord(record);
  }

  @override
  Future<bool> verifyIdempotencyKey(String idempotencyKey) {
    return _remoteDatasource.verifyIdempotencyKey(idempotencyKey);
  }

  @override
  Future<bool> deliverViaChannel({
    required NotificationDelivery delivery,
    required NotificationMessage message,
  }) {
    return _remoteDatasource.deliverViaChannel(
      delivery: delivery,
      message: message,
    );
  }
}
