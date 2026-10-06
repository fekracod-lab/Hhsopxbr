import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/application/production_resilience_engine.dart';
import 'package:dalal_alqaim/core/resilience/enums/resilience_enums.dart';
import 'package:dalal_alqaim/core/resilience/entities/offline_queue_item.dart';
import 'helpers/resilience_test_helper.dart';

void main() {
  group('Production Resilience Engine Master Facade Tests', () {
    test('1. Facade coordinates retry, idempotency, and circuit breaker seamlessly', () async {
      final repository = InMemoryResilienceRepository();
      final engine = ProductionResilienceEngine(repository: repository);

      int executionCount = 0;

      final (res, attempts, err) = await engine.executeResilientOperation<String>(
        serviceKey: 'delivery_engine',
        operation: () async {
          executionCount++;
          return 'DELIVERY_DISPATCHED';
        },
      );

      expect(res, equals('DELIVERY_DISPATCHED'));
      expect(attempts.length, equals(1));
      expect(err, isNull);
      expect(executionCount, equals(1));
    });

    test('2. Checkpoint saving automatically sanitizes sensitive fields before persistence', () async {
      final repository = InMemoryResilienceRepository();
      final engine = ProductionResilienceEngine(repository: repository);
      final now = DateTime(2026, 8, 29, 12, 0, 0);

      final checkpoint = await engine.saveCheckpoint(
        operationId: 'op_ride_123',
        domainType: 'ride',
        state: 'trip_started',
        correlationId: 'user_omar',
        payload: {
          'driverId': 'drv_1',
          'password': 'PlainTextSecretPassword',
          'otp': '123456',
        },
        now: now,
      );

      expect(checkpoint.payload['driverId'], equals('drv_1'));
      expect(checkpoint.payload['password'], equals('[REDACTED_BY_SECURITY_LOCKDOWN]'));
      expect(checkpoint.payload['otp'], equals('[REDACTED_BY_SECURITY_LOCKDOWN]'));

      final stored = await repository.getCheckpoint('op_ride_123');
      expect(stored, isNotNull);
      expect(stored!.payload['password'], equals('[REDACTED_BY_SECURITY_LOCKDOWN]'));
    });

    test('3. Enqueues and replays offline operations and executes readiness audit audit', () async {
      final repository = InMemoryResilienceRepository();
      final engine = ProductionResilienceEngine(repository: repository);
      final now = DateTime(2026, 8, 29, 12, 0, 0);

      final queueItem = OfflineQueueItem(
        queueId: 'q_facade_1',
        idempotencyKey: 'key_facade_1',
        operationType: 'create_order',
        payload: {'orderId': 'ord_99', 'token': 'jwt_secret'},
        traceId: 'tr_1',
        correlationId: 'c1',
        nextRetryAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await engine.enqueueOfflineOperation(queueItem);
      expect(engine.offlineQueue.length, equals(1));
      // Verify payload was sanitized on enqueue
      expect(engine.offlineQueue.allItems.first.payload['token'], equals('[REDACTED_BY_SECURITY_LOCKDOWN]'));

      final (succ, fail, _) = await engine.replayOfflineOperations(
        serverSender: (_) async => true,
        now: now,
      );
      expect(succ, equals(1));
      expect(fail, equals(0));

      // Execute readiness audit
      final readiness = await engine.runProductionReadinessGateAudit(
        categoryScores: {for (var c in ReadinessCategory.values) c: 100.0},
        categoryBlockers: {for (var c in ReadinessCategory.values) c: <String>[]},
        categoryWarnings: {for (var c in ReadinessCategory.values) c: <String>[]},
        now: now,
      );

      expect(readiness.overallStatus, equals(ReadinessGateStatus.productionReady));
      final savedReadiness = await repository.getLatestProductionReadinessResult();
      expect(savedReadiness, isNotNull);
      expect(savedReadiness!.isProductionReady, isTrue);
    });
  });
}
