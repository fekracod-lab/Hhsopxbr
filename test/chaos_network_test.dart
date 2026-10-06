import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/entities/failure_injection.dart';
import 'package:dalal_alqaim/core/resilience/entities/chaos_scenario.dart';
import 'package:dalal_alqaim/core/resilience/entities/offline_queue_item.dart';
import 'package:dalal_alqaim/core/resilience/enums/resilience_enums.dart';
import 'package:dalal_alqaim/core/resilience/services/failure_injection_engine.dart';
import 'package:dalal_alqaim/core/resilience/services/chaos_engine.dart';
import 'package:dalal_alqaim/core/resilience/services/durable_offline_queue.dart';
import 'package:dalal_alqaim/core/resilience/services/idempotency_engine.dart';
import 'package:dalal_alqaim/core/resilience/services/offline_replay_engine.dart';

void main() {
  group('Chaos Scenario 001 & 002: Network Failure & Flapping Tests', () {
    test('CHAOS-001: Network disconnect during active ride queues operations and replays seamlessly upon recovery', () async {
      final failureInjection = FailureInjectionEngine();
      final chaosEngine = ChaosEngine(failureInjectionEngine: failureInjection);
      final queue = DurableOfflineQueue();
      final idempotency = IdempotencyEngine();
      final replayEngine = OfflineReplayEngine(queue: queue, idempotencyEngine: idempotency);
      final now = DateTime(2026, 8, 29, 12, 0, 0);

      final scenario = ChaosScenario(
        scenarioId: 'CHAOS-001',
        name: 'Network Disconnect During Ride',
        description: 'Simulates complete cellular drop while user and driver interact during active ride',
        injections: [
          const FailureInjection(
            injectionId: 'inj_net_drop',
            type: FailureInjectionType.networkOffline,
            targetService: 'ride_telemetry',
            probability: 1.0,
          ),
        ],
        assertions: [
          'NO_LOST_OPERATIONS',
          'ALL_QUEUED_ITEMS_REPLAYED_AFTER_RECONNECT',
        ],
      );

      final (passed, passedAssertions, failedAssertions) = await chaosEngine.executeScenario(
        scenario: scenario,
        workload: () async {
          // Attempting to send while offline -> fails and enqueues to durable queue
          try {
            await failureInjection.evaluateAndInject('ride_telemetry');
          } catch (_) {
            await queue.enqueue(
              OfflineQueueItem(
                queueId: 'q_ride_loc_1',
                idempotencyKey: 'idemp_loc_1',
                operationType: 'driver_location_update',
                payload: {'lat': 33.3152, 'lng': 44.3661},
                traceId: 'tr_c1',
                correlationId: 'drv_1',
                nextRetryAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
        },
        assertionVerifier: (assertion) async {
          if (assertion == 'NO_LOST_OPERATIONS') {
            return queue.allItems.length == 1;
          }
          if (assertion == 'ALL_QUEUED_ITEMS_REPLAYED_AFTER_RECONNECT') {
            // Replay after network restored
            final (succ, fail, _) = await replayEngine.replayPendingOperations(
              now: now,
              serverSender: (_) async => true,
            );
            return succ == 1 && fail == 0;
          }
          return false;
        },
      );

      expect(passed, isTrue);
      expect(passedAssertions.length, equals(2));
      expect(failedAssertions.isEmpty, isTrue);
    });
  });
}
