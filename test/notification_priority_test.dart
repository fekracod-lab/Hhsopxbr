import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/notifications/domain/enums/notification_enums.dart';
import 'package:dalal_alqaim/core/notifications/domain/services/notification_priority_engine.dart';

void main() {
  group('Notification Priority Engine Dedicated Tests', () {
    test('1. Resolves CRITICAL priority for SOS and Security violations', () {
      expect(
        NotificationPriorityEngine.resolvePriority(NotificationEventType.emergencySos),
        equals(NotificationPriority.critical),
      );
      expect(
        NotificationPriorityEngine.resolvePriority(NotificationEventType.securityViolation),
        equals(NotificationPriority.critical),
      );
    });

    test('2. Resolves HIGH priority for Driver Offers and Ride Requests', () {
      expect(
        NotificationPriorityEngine.resolvePriority(NotificationEventType.driverNewOffer),
        equals(NotificationPriority.high),
      );
      expect(
        NotificationPriorityEngine.resolvePriority(NotificationEventType.rideRequested),
        equals(NotificationPriority.high),
      );
      expect(
        NotificationPriorityEngine.resolvePriority(NotificationEventType.orderAssigned),
        equals(NotificationPriority.high),
      );
    });

    test('3. Resolves NORMAL priority for regular order and ride progress events', () {
      expect(
        NotificationPriorityEngine.resolvePriority(NotificationEventType.orderPreparing),
        equals(NotificationPriority.normal),
      );
      expect(
        NotificationPriorityEngine.resolvePriority(NotificationEventType.rideStarted),
        equals(NotificationPriority.normal),
      );
      expect(
        NotificationPriorityEngine.resolvePriority(NotificationEventType.chatMessage),
        equals(NotificationPriority.normal),
      );
    });

    test('4. Resolves LOW priority for marketing and broadcast events', () {
      expect(
        NotificationPriorityEngine.resolvePriority(NotificationEventType.marketing),
        equals(NotificationPriority.low),
      );
      expect(
        NotificationPriorityEngine.resolvePriority(NotificationEventType.systemBroadcast),
        equals(NotificationPriority.low),
      );
    });
  });
}
