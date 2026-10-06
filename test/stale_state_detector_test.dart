import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/driver_presence.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/tracking_session.dart';
import 'package:dalal_alqaim/core/realtime/domain/enums/realtime_enums.dart';
import 'package:dalal_alqaim/core/realtime/domain/services/stale_state_detector.dart';

void main() {
  group('Stale State Detector Dedicated Tests', () {
    test('1. Detects stale and offline driver states based on heartbeat TTL', () {
      final now = DateTime(2026, 8, 28, 12, 0, 0);

      final fresh = DriverPresence(
        driverId: 'drv_fresh',
        state: DriverPresenceState.available,
        lastHeartbeatAt: now.subtract(const Duration(seconds: 30)),
        lastLocationUpdate: now.subtract(const Duration(seconds: 30)),
        updatedAt: now,
      );
      expect(StaleStateDetector.isDriverStale(presence: fresh, now: now), isFalse);
      expect(StaleStateDetector.isDriverOffline(presence: fresh, now: now), isFalse);

      final stale = fresh.copyWith(
        lastHeartbeatAt: now.subtract(const Duration(seconds: 100)), // > 90s
      );
      expect(StaleStateDetector.isDriverStale(presence: stale, now: now), isTrue);
      expect(StaleStateDetector.isDriverOffline(presence: stale, now: now), isFalse);

      final offline = fresh.copyWith(
        lastHeartbeatAt: now.subtract(const Duration(minutes: 6)), // > 5m
      );
      expect(StaleStateDetector.isDriverStale(presence: offline, now: now), isTrue);
      expect(StaleStateDetector.isDriverOffline(presence: offline, now: now), isTrue);
    });

    test('2. Detects stale tracking session when no location updates for 15+ minutes', () {
      final now = DateTime(2026, 8, 28, 12, 0, 0);

      final session = TrackingSession(
        sessionId: 'sess_stale_check',
        orderId: 'ord_1',
        serviceType: 'food',
        driverId: 'drv_1',
        customerId: 'cust_1',
        destinationLat: 33.32,
        destinationLng: 44.30,
        destinationAddress: 'Mansour',
        startedAt: now.subtract(const Duration(minutes: 20)),
        lastLocationAt: now.subtract(const Duration(minutes: 18)), // > 15m ago
      );

      expect(StaleStateDetector.isTrackingSessionStale(session: session, now: now), isTrue);
    });
  });
}
