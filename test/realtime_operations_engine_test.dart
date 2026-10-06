import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/realtime/application/realtime_operations_engine.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/location_sample.dart';
import 'package:dalal_alqaim/core/realtime/domain/enums/realtime_enums.dart';
import 'helpers/realtime_test_helper.dart';

void main() {
  group('Realtime Operations Engine Application Facade Tests', () {
    late InMemoryRealtimeRepository repo;
    late RealtimeOperationsEngine engine;

    setUp(() {
      repo = InMemoryRealtimeRepository();
      engine = RealtimeOperationsEngine(repository: repo);
    });

    test('1. Heartbeat reporting updates driver presence and stores record', () async {
      final now = DateTime.now();
      final record = await engine.processHeartbeat(
        driverId: 'drv_app_1',
        sessionId: 'sess_1',
        clientTimestamp: now,
        sequenceNumber: 1,
      );

      expect(record.status, equals(HeartbeatStatus.healthy));
      expect(repo.heartbeats.length, equals(1));

      final presence = await repo.getDriverPresence('drv_app_1');
      expect(presence, isNotNull);
      expect(presence!.state, equals(DriverPresenceState.available));

      final isEligible = await engine.isDriverEligibleForDispatch('drv_app_1');
      expect(isEligible, isTrue);
    });

    test('2. Processing driver location and updating active tracking session', () async {
      final now = DateTime.now();

      // 1. Report initial location
      await engine.processDriverLocation(
        driverId: 'drv_app_2',
        sample: LocationSample(
          latitude: 33.3000,
          longitude: 44.3000,
          accuracy: 5.0,
          timestamp: now,
        ),
        sequenceNumber: 1,
      );

      // 2. Start tracking session
      final session = await engine.startTrackingSession(
        sessionId: 'sess_live_1',
        orderId: 'ord_live_1',
        serviceType: 'taxi',
        driverId: 'drv_app_2',
        customerId: 'cust_live_1',
        destinationLat: 33.3200,
        destinationLng: 44.3000,
        destinationAddress: 'Mansour',
      );

      expect(session.currentLocation, isNotNull);
      expect(session.currentEtaSeconds, greaterThan(0));

      // 3. Move driver closer
      final updatedSession = await engine.updateTrackingSessionLocation(
        sessionId: 'sess_live_1',
        location: (await repo.getDriverLocation('drv_app_2'))!,
      );

      expect(updatedSession, isNotNull);
      expect(updatedSession!.version, equals(2));
    });
  });
}
