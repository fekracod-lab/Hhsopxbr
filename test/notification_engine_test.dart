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

class MockNotificationRepository implements INotificationRepository {
  final Map<String, NotificationEvent> events = {};
  final Map<String, NotificationDelivery> deliveries = {};
  final Map<String, NotificationPreference> preferences = {};
  final List<NotificationAuditRecord> auditRecords = [];
  final Set<String> idempotencyKeys = {};
  NotificationPolicy policy = const NotificationPolicy();
  bool shouldDeliverSucceed = true;

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
  Future<NotificationDelivery?> getDelivery(String deliveryId) async {
    return deliveries[deliveryId];
  }

  @override
  Future<NotificationPreference> getPreference(String userId) async {
    return preferences[userId] ?? NotificationPreference(userId: userId);
  }

  @override
  Future<void> savePreference(NotificationPreference preference) async {
    preferences[preference.userId] = preference;
  }

  @override
  Future<NotificationPolicy> getPolicy() async {
    return policy;
  }

  @override
  Future<void> saveAuditRecord(NotificationAuditRecord record) async {
    auditRecords.add(record);
  }

  @override
  Future<bool> verifyIdempotencyKey(String idempotencyKey) async {
    if (idempotencyKeys.contains(idempotencyKey)) return false;
    idempotencyKeys.add(idempotencyKey);
    return true;
  }

  @override
  Future<bool> deliverViaChannel({
    required NotificationDelivery delivery,
    required NotificationMessage message,
  }) async {
    return shouldDeliverSucceed;
  }
}

void main() {
  group('Notification Intelligence Engine Comprehensive Pipeline Tests', () {
    test('1. Dispatches high priority order notification successfully to target user', () async {
      final mockRepo = MockNotificationRepository();
      final engine = NotificationEngine(repository: mockRepo);

      final event = NotificationEvent(
        eventId: 'evt_order_1',
        eventType: NotificationEventType.orderAssigned,
        entityId: 'ord_100',
        actorId: 'system',
        target: const NotificationTarget(targetUserIds: ['user_customer_1']),
        priority: NotificationPriority.high,
        message: const NotificationMessage(
          title: 'تم تعيين كابتن لطلبك',
          body: 'الكابتن علي في طريقه إلى المطعم لاستلام طلبك',
          category: NotificationCategory.orders,
        ),
        idempotencyKey: 'idemp_evt_order_1',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
      );

      final results = await engine.dispatchEvent(event);

      expect(results.length, equals(1));
      expect(results.first.status, equals(DeliveryStatus.delivered));
      expect(mockRepo.deliveries.containsKey('del-evt_order_1-user_customer_1'), isTrue);
      expect(mockRepo.auditRecords.length, equals(1));
      expect(mockRepo.auditRecords.first.status, equals(DeliveryStatus.delivered));
    });

    test('2. Deduplicates event with same idempotency key', () async {
      final mockRepo = MockNotificationRepository();
      final engine = NotificationEngine(repository: mockRepo);

      final event = NotificationEvent(
        eventId: 'evt_dedup',
        eventType: NotificationEventType.paymentCompleted,
        entityId: 'pay_99',
        actorId: 'system',
        target: const NotificationTarget(targetUserIds: ['user_cust_2']),
        priority: NotificationPriority.normal,
        message: const NotificationMessage(
          title: 'تم الدفع بنجاح',
          body: 'تم استلام مبلغ 15,000 د.ع',
          category: NotificationCategory.financial,
        ),
        idempotencyKey: 'idemp_same_key_99',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
      );

      // First dispatch succeeds
      final firstRun = await engine.dispatchEvent(event);
      expect(firstRun.length, equals(1));

      // Second dispatch with same idempotency key is suppressed by deduplication engine
      final secondRun = await engine.dispatchEvent(event);
      expect(secondRun, isEmpty);
    });

    test('3. Suppresses notifications if disabled by user preferences (except Critical)', () async {
      final mockRepo = MockNotificationRepository();
      // Disable marketing notifications for user
      mockRepo.preferences['user_opt_out'] = const NotificationPreference(
        userId: 'user_opt_out',
        marketingEnabled: false,
      );

      final engine = NotificationEngine(repository: mockRepo);

      final promoEvent = NotificationEvent(
        eventId: 'evt_promo',
        eventType: NotificationEventType.marketing,
        entityId: 'promo_1',
        actorId: 'system',
        target: const NotificationTarget(targetUserIds: ['user_opt_out']),
        priority: NotificationPriority.low,
        message: const NotificationMessage(
          title: 'عرض خاص',
          body: 'خصم 20% على أول طلب',
          category: NotificationCategory.marketing,
        ),
        idempotencyKey: 'idemp_promo_1',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
      );

      final results = await engine.dispatchEvent(promoEvent);
      expect(results.length, equals(1));
      expect(results.first.status, equals(DeliveryStatus.suppressed));
    });

    test('4. Handles delivery failure and initiates retry state', () async {
      final mockRepo = MockNotificationRepository();
      mockRepo.shouldDeliverSucceed = false; // Network delivery fails

      final engine = NotificationEngine(repository: mockRepo);

      final event = NotificationEvent(
        eventId: 'evt_fail_retry',
        eventType: NotificationEventType.orderDelivered,
        entityId: 'ord_fail',
        actorId: 'system',
        target: const NotificationTarget(targetUserIds: ['user_retry_1']),
        priority: NotificationPriority.normal,
        message: const NotificationMessage(
          title: 'تم التوصيل',
          body: 'تم تسليم طلبك بنجاح',
          category: NotificationCategory.orders,
        ),
        idempotencyKey: 'idemp_fail_1',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
      );

      final results = await engine.dispatchEvent(event);
      expect(results.length, equals(1));
      expect(results.first.status, equals(DeliveryStatus.retrying));
      expect(results.first.retryCount, equals(1));
    });
  });
}
