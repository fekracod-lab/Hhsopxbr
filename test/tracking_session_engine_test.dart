import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/driver_location.dart';
import 'package:dalal_alqaim/core/realtime/domain/enums/realtime_enums.dart';
import 'package:dalal_alqaim/core/realtime/domain/services/tracking_session_engine.dart';

void main() {
  group('Tracking Session Engine Dedicated Tests', () {
    test('1. Creates session and computes initial ETA if initial location provided', () {
      final initialLoc = DriverLocation(
        driverId: 'drv_1',
        latitude: 33.3000,
        longitude: 44.3000,
        timestamp: DateTime.now(),
      );

      final session = TrackingSessionEngine.createSession(
        sessionId: 'sess_1',
        orderId: 'ord_1',
        serviceType: 'food',
        driverId: 'drv_1',
        customerId: 'cust_1',
        destinationLat: 33.3200,
        destinationLng: 44.3000,
        destinationAddress: 'Mansour, Baghdad',
        initialLocation: initialLoc,
      );

      expect(session.status, equals(TrackingSessionStatus.active));
      expect(session.currentEtaSeconds, greaterThan(0));
      expect(session.version, equals(1));
    });

    test('2. Updates session location and recalculates ETA while incrementing version', () {
      final session = TrackingSessionEngine.createSession(
        sessionId: 'sess_2',
        orderId: 'ord_2',
        serviceType: 'taxi',
        driverId: 'drv_2',
        customerId: 'cust_2',
        destinationLat: 33.3200,
        destinationLng: 44.3000,
        destinationAddress: 'Karrada, Baghdad',
      );

      final newLoc = DriverLocation(
        driverId: 'drv_2',
        latitude: 33.3190, // Very close to destination
        longitude: 44.3000,
        timestamp: DateTime.now(),
      );

      final updated = TrackingSessionEngine.updateLocation(
        session: session,
        location: newLoc,
      );

      expect(updated.version, equals(2));
      expect(updated.currentLocation, equals(newLoc));
      expect(updated.currentEtaSeconds, greaterThan(0));
    });

    test('3. Completes and cancels tracking sessions', () {
      final session = TrackingSessionEngine.createSession(
        sessionId: 'sess_3',
        orderId: 'ord_3',
        serviceType: 'mersal',
        driverId: 'drv_3',
        customerId: 'cust_3',
        destinationLat: 33.3200,
        destinationLng: 44.3000,
        destinationAddress: 'Al-Qaim Center',
      );

      final completed = TrackingSessionEngine.completeSession(session);
      expect(completed.status, equals(TrackingSessionStatus.completed));
      expect(completed.version, equals(2));

      final cancelled = TrackingSessionEngine.cancelSession(session);
      expect(cancelled.status, equals(TrackingSessionStatus.cancelled));
      expect(cancelled.version, equals(2));
    });
  });
}
