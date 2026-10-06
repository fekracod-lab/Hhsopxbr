import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/realtime/application/realtime_operations_engine.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/location_sample.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/realtime_event.dart';
import 'package:dalal_alqaim/core/realtime/domain/enums/realtime_enums.dart';
import 'package:dalal_alqaim/core/realtime/domain/services/connection_recovery_engine.dart';
import 'helpers/realtime_test_helper.dart';

void main() {
  group('Realtime Concurrency and Chaos Tests', () {
    late InMemoryRealtimeRepository repo;
    late RealtimeOperationsEngine engine;

    setUp(() {
      repo = InMemoryRealtimeRepository();
      engine = RealtimeOperationsEngine(repository: repo);
    });

    test('1. Concurrency: 20 simultaneous location updates executed without state corruption', () async {
      final now = DateTime.now();

      final futures = List.generate(20, (i) {
        return engine.processDriverLocation(
          driverId: 'drv_concurrent_$i',
          sample: LocationSample(
            latitude: 33.3000 + (i * 0.001),
            longitude: 44.3000 + (i * 0.001),
            accuracy: 5.0,
            timestamp: now.add(Duration(seconds: i)),
          ),
          sequenceNumber: i + 1,
        );
      });

      final results = await Future.wait(futures);

      expect(results.length, equals(20));
      expect(repo.locations.length, equals(20));
      for (final loc in results) {
        expect(loc.confidence, equals(LocationConfidence.valid));
      }
    });

    test('2. Chaos: Network drop during active trip -> offline queueing -> reconnect & authoritative reconciliation', () async {
      final connectionEngine = ConnectionRecoveryEngine();

      // 1. Initial active session on server
      final initialSession = await engine.startTrackingSession(
        sessionId: 'sess_chaos_1',
        orderId: 'ord_chaos_1',
        serviceType: 'taxi',
        driverId: 'drv_chaos_1',
        customerId: 'cust_chaos_1',
        destinationLat: 33.3200,
        destinationLng: 44.3000,
        destinationAddress: 'Karrada, Baghdad',
      );

      // 2. Internet drops!
      connectionEngine.updateStatus(ConnectionStatus.disconnected);
      expect(connectionEngine.status, equals(ConnectionStatus.disconnected));

      // 3. Driver generates events while offline
      connectionEngine.enqueueOfflineEvent(
        RealtimeEvent(
          eventId: 'ev_off_1',
          eventType: 'location_update',
          entityId: 'drv_chaos_1',
          sequenceNumber: 1,
          occurredAt: DateTime.now(),
        ),
      );
      connectionEngine.enqueueOfflineEvent(
        RealtimeEvent(
          eventId: 'ev_off_2',
          eventType: 'location_update',
          entityId: 'drv_chaos_1',
          sequenceNumber: 2,
          occurredAt: DateTime.now(),
        ),
      );

      expect(connectionEngine.offlineQueue.length, equals(2));

      // 4. Internet reconnects after 30s
      final flushedEvents = connectionEngine.flushQueueOnReconnect();
      expect(flushedEvents.length, equals(2));
      expect(connectionEngine.status, equals(ConnectionStatus.connected));

      // 5. Authoritative server reconciliation
      final (reconciledSession, reconciliationResult) = await engine.reconcileTrackingSession(
        localSession: initialSession,
      );

      expect(reconciledSession.sessionId, equals('sess_chaos_1'));
      expect(reconciledSession.status, equals(TrackingSessionStatus.active));
      expect(reconciliationResult.isConsistent, isTrue);
    });
  });
}
