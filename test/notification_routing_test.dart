import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/notifications/domain/enums/notification_enums.dart';
import 'package:dalal_alqaim/core/notifications/domain/services/notification_routing_engine.dart';

void main() {
  group('Notification Routing Engine Dedicated Tests', () {
    test('1. Routes driver offers to specific driver or driver role', () {
      final directTarget = NotificationRoutingEngine.resolveTarget(
        eventType: NotificationEventType.driverNewOffer,
        driverId: 'drv_100',
      );
      expect(directTarget.isDirectUser, isTrue);
      expect(directTarget.targetUserIds, contains('drv_100'));

      final roleTarget = NotificationRoutingEngine.resolveTarget(
        eventType: NotificationEventType.driverNewOffer,
        customRole: 'taxi_captain',
      );
      expect(roleTarget.targetRole, equals('taxi_captain'));
    });

    test('2. Routes order creation to merchant', () {
      final merchantTarget = NotificationRoutingEngine.resolveTarget(
        eventType: NotificationEventType.orderCreated,
        merchantId: 'merch_50',
      );
      expect(merchantTarget.targetUserIds, contains('merch_50'));
    });

    test('3. Routes customer status updates to customer', () {
      final customerTarget = NotificationRoutingEngine.resolveTarget(
        eventType: NotificationEventType.orderDelivered,
        customerId: 'cust_77',
      );
      expect(customerTarget.targetUserIds, contains('cust_77'));
    });

    test('4. Routes emergency SOS to contacts and admin role', () {
      final sosTarget = NotificationRoutingEngine.resolveTarget(
        eventType: NotificationEventType.emergencySos,
        emergencyContactIds: ['contact_1', 'contact_2'],
      );
      expect(sosTarget.targetUserIds.length, equals(2));
      expect(sosTarget.targetRole, equals('admin'));
    });
  });
}
