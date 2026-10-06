import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/entities/offline_queue_item.dart';
import 'package:dalal_alqaim/core/resilience/services/durable_offline_queue.dart';
import 'package:dalal_alqaim/core/resilience/services/idempotency_engine.dart';
import 'package:dalal_alqaim/core/resilience/services/offline_replay_engine.dart';

void main() {
  group('Offline Replay Engine Dedicated Tests', () {
    test('1. Replays offline queue operations upon reconnection and updates status on server ACK', () async {
      final queue = DurableOfflineQueue();
      final idempotency = IdempotencyEngine();
      final replayEngine = OfflineReplayEngine(queue: queue, idempotencyEngine: idempotency);
      final now = DateTime(2026, 8, 29, 12, 0, 0);

      final item1 = OfflineQueueItem(
        queueId: 'q_1',
        idempotencyKey: 'key_1',
        operationType: 'create_order',
        payload: {'orderId': '101'},
        traceId: 'tr_1',
        correlationId: 'user_1',
        nextRetryAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final item2 = OfflineQueueItem(
        queueId: 'q_2',
        idempotencyKey: 'key_2',
        operationType: 'wallet_debit',
        payload: {'amount': 5000},
        traceId: 'tr_2',
        correlationId: 'user_1',
        nextRetryAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await queue.enqueue(item1);
      await queue.enqueue(item2);

      final sentPayloads = <String>[];

      final (succeeded, failed, deadLettered) = await replayEngine.replayPendingOperations(
        now: now,
        serverSender: (item) async {
          sentPayloads.add(item.queueId);
          return true; // Server ACK OK
        },
      );

      expect(succeeded, equals(2));
      expect(failed, equals(0));
      expect(deadLettered, equals(0));
      expect(sentPayloads, containsAll(['q_1', 'q_2']));
      expect(queue.getPendingItems(now: now).isEmpty, isTrue);
    });

    test('2. Prevents double-processing during replayed operations with Idempotency Engine', () async {
      final queue = DurableOfflineQueue();
      final idempotency = IdempotencyEngine();
      final replayEngine = OfflineReplayEngine(queue: queue, idempotencyEngine: idempotency);
      final now = DateTime(2026, 8, 29, 12, 0, 0);

      int actualServerMutations = 0;

      final item = OfflineQueueItem(
        queueId: 'q_dup',
        idempotencyKey: 'idemp_unique_tx',
        operationType: 'payment',
        payload: {},
        traceId: 'tr_1',
        correlationId: 'user_1',
        nextRetryAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await queue.enqueue(item);

      // First replay attempt
      await replayEngine.replayPendingOperations(
        now: now,
        serverSender: (it) async {
          actualServerMutations++;
          return true;
        },
      );

      expect(actualServerMutations, equals(1));

      // Re-enqueuing duplicate and replaying again
      await queue.enqueue(item.copyWith(queueId: 'q_dup_2'));
      await replayEngine.replayPendingOperations(
        now: now,
        serverSender: (it) async {
          actualServerMutations++;
          return true;
        },
      );

      // Server execution counter MUST NOT increase due to cached canonical result
      expect(actualServerMutations, equals(1));
    });
  });
}
