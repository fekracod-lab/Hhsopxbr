import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/observability/domain/services/metrics_engine.dart';

void main() {
  group('Realtime Metrics Engine Dedicated Tests', () {
    test('1. Tracks orders per min and GPS update rates accurately', () {
      final engine = MetricsEngine();
      final now = DateTime(2026, 8, 28, 12, 0, 0);

      // 5 orders in last minute
      for (int i = 0; i < 5; i++) {
        engine.recordOrderCreated(now: now.subtract(Duration(seconds: i * 10)));
      }

      // 20 GPS updates in last 10 seconds -> 2.0 updates/sec
      for (int i = 0; i < 20; i++) {
        engine.recordGpsUpdate(now: now.subtract(const Duration(seconds: 2)));
      }

      engine.updateDriverCounts(online: 50, available: 30, busy: 20);
      engine.updateActiveOperations(activeRides: 15, activeDeliveries: 10);

      final snapshot = engine.generateSnapshot(now: now);

      expect(snapshot.ordersPerMin, equals(5.0));
      expect(snapshot.gpsUpdateRatePerSec, equals(2.0));
      expect(snapshot.onlineDrivers, equals(50));
      expect(snapshot.availableDrivers, equals(30));
      expect(snapshot.busyDrivers, equals(20));
      expect(snapshot.activeRides, equals(15));
      expect(snapshot.activeDeliveries, equals(10));
    });

    test('2. Computes cancellation rate and heartbeat success rate correctly', () {
      final engine = MetricsEngine();
      final now = DateTime(2026, 8, 28, 12, 0, 0);

      // 10 ride requests, 2 cancelled -> 20% cancellation rate
      for (int i = 0; i < 10; i++) {
        engine.recordRideRequested(now: now.subtract(Duration(minutes: i)));
      }
      engine.recordCancellation(now: now.subtract(const Duration(minutes: 2)));
      engine.recordCancellation(now: now.subtract(const Duration(minutes: 4)));

      // 8 successful heartbeats out of 10 -> 80% success
      for (int i = 0; i < 8; i++) {
        engine.recordHeartbeat(isSuccess: true);
      }
      engine.recordHeartbeat(isSuccess: false);
      engine.recordHeartbeat(isSuccess: false);

      final snapshot = engine.generateSnapshot(now: now);

      expect(snapshot.cancellationRate, closeTo(0.2, 0.01));
      expect(snapshot.heartbeatSuccessRate, closeTo(0.8, 0.01));
    });
  });
}
