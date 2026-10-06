import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/notifications/domain/enums/notification_enums.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_event.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_message.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_target.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_delivery.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_preference.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_policy.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_audit_record.dart';
import 'package:dalal_alqaim/core/notifications/domain/repositories/i_notification_repository.dart';
import 'package:dalal_alqaim/core/notifications/application/notification_engine.dart';
import 'package:dalal_alqaim/services/notification_service.dart';

class MockNotificationRegressionRepo implements INotificationRepository {
  final Map<String, NotificationEvent> events = {};
  final Map<String, NotificationDelivery> deliveries = {};
  final List<NotificationAuditRecord> auditLog = [];

  @override
  Future<NotificationEvent> saveEvent(NotificationEvent event) async {
    events[event.eventId] = event;
    return event;
  }

  @override
  Future<NotificationDelivery> saveDelivery(NotificationDelivery delivery) async {
    deliveries[delivery.deliveryId] = delivery;
    return delivery;
  }

  @override
  Future<NotificationDelivery?> getDelivery(String deliveryId) async => deliveries[deliveryId];

  @override
  Future<NotificationPreference> getPreference(String userId) async => NotificationPreference(userId: userId);

  @override
  Future<void> savePreference(NotificationPreference preference) async {}

  @override
  Future<NotificationPolicy> getPolicy() async => const NotificationPolicy();

  @override
  Future<void> saveAuditRecord(NotificationAuditRecord record) async {
    auditLog.add(record);
  }

  @override
  Future<bool> verifyIdempotencyKey(String idempotencyKey) async => true;

  @override
  Future<bool> deliverViaChannel({
    required NotificationDelivery delivery,
    required NotificationMessage message,
  }) async => true;
}

void main() {
  group('Notification Intelligence Engine Regression & Cross-System Tests', () {
    test('1. Preserves role filtering compatibility with existing taxi and delivery categories', () {
      expect(NotificationService.taxiCaptainRoles, contains('taxi_captain'));
      expect(NotificationService.taxiCaptainRoles, contains('captain'));
      expect(NotificationService.deliveryDelegateRoles, contains('delivery'));
      expect(NotificationService.deliveryDelegateRoles, contains('delegate'));

      expect(NotificationService.driverNotificationTypes, contains('new_ride'));
      expect(NotificationService.deliveryNotificationTypes, contains('food_order'));
    });

    test('2. NotificationEngine quick emission triggers audit and delivery records', () async {
      final repo = MockNotificationRegressionRepo();
      final engine = NotificationEngine(repository: repo);

      final deliveries = await engine.emitQuickNotification(
        eventType: NotificationEventType.orderCreated,
        entityId: 'ord_reg_900',
        targetUserId: 'merchant_900',
        title: 'طلب جديد',
        body: 'لديك طلب جديد قيد التأكيد',
        category: NotificationCategory.orders,
      );

      expect(deliveries.length, equals(1));
      expect(deliveries.first.status, equals(DeliveryStatus.delivered));
      expect(repo.events.length, equals(1));
      expect(repo.auditLog.length, equals(1));
      expect(repo.auditLog.first.eventType, equals(NotificationEventType.orderCreated));
    });

    test('3. Cross-system emergency SOS dispatch sets CRITICAL priority and bypasses all filters', () async {
      final repo = MockNotificationRegressionRepo();
      final engine = NotificationEngine(repository: repo);

      final sosEvent = NotificationEvent(
        eventId: 'evt_sos_reg',
        eventType: NotificationEventType.emergencySos,
        entityId: 'ride_emergency_1',
        actorId: 'customer_sos_1',
        target: const NotificationTarget(targetUserIds: ['admin_user_1', 'admin_user_2']),
        priority: NotificationPriority.critical,
        message: const NotificationMessage(
          title: 'نداء استغاثة طارئ (SOS)',
          body: 'طلب استغاثة عاجل من راكب في رحلة تكسي',
          category: NotificationCategory.emergency,
        ),
        idempotencyKey: 'idemp_sos_reg_1',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final results = await engine.dispatchEvent(sosEvent);

      expect(results.length, equals(2)); // Both admins delivered
      for (final delivery in results) {
        expect(delivery.status, equals(DeliveryStatus.delivered));
      }
      expect(repo.auditLog.length, equals(2));
      for (final audit in repo.auditLog) {
        expect(audit.priority, equals(NotificationPriority.critical));
      }
    });
  });
}
