import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/notifications/domain/enums/notification_enums.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_event.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_message.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_target.dart';
import 'package:dalal_alqaim/core/notifications/domain/entities/notification_policy.dart';
import 'package:dalal_alqaim/core/notifications/domain/services/notification_grouping_engine.dart';

void main() {
  group('Notification Grouping Engine Dedicated Tests', () {
    test('1. Groups notifications when count reaches grouping threshold', () {
      final engine = NotificationGroupingEngine();
      const policy = NotificationPolicy(groupingThreshold: 3);

      NotificationEvent createEvent(int idx) => NotificationEvent(
        eventId: 'e_$idx',
        eventType: NotificationEventType.orderPreparing,
        entityId: 'ord_group_1',
        actorId: 'system',
        target: const NotificationTarget(targetUserIds: ['u_group']),
        priority: NotificationPriority.normal,
        message: NotificationMessage(title: 'تحديث $idx', body: 'تفاصيل $idx'),
        idempotencyKey: 'idemp_g_$idx',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(engine.shouldGroup(event: createEvent(1), targetUserId: 'u_group', policy: policy), isFalse);
      expect(engine.shouldGroup(event: createEvent(2), targetUserId: 'u_group', policy: policy), isFalse);
      expect(engine.shouldGroup(event: createEvent(3), targetUserId: 'u_group', policy: policy), isTrue);

      final groupedMessage = engine.createGroupedMessage(
        targetUserId: 'u_group',
        entityId: 'ord_group_1',
        categoryPrefix: 'طلب الطعام',
        count: 3,
      );

      expect(groupedMessage.body, contains('3 تحديثات'));
    });

    test('2. NEVER groups High or Critical priority notifications', () {
      final engine = NotificationGroupingEngine();
      const policy = NotificationPolicy(groupingThreshold: 1);

      final criticalEvent = NotificationEvent(
        eventId: 'e_crit',
        eventType: NotificationEventType.emergencySos,
        entityId: 'sos_1',
        actorId: 'system',
        target: const NotificationTarget(targetUserIds: ['u_admin']),
        priority: NotificationPriority.critical,
        message: const NotificationMessage(title: 'طوارئ', body: 'نداء استغاثة'),
        idempotencyKey: 'idemp_crit',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(engine.shouldGroup(event: criticalEvent, targetUserId: 'u_admin', policy: policy), isFalse);
    });
  });
}
