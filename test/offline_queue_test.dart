import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/entities/offline_queue_item.dart';
import 'package:dalal_alqaim/core/resilience/enums/resilience_enums.dart';
import 'package:dalal_alqaim/core/resilience/services/durable_offline_queue.dart';

void main() {
  group('Durable Offline Queue Dedicated Tests', () {
    test('1. Enqueues items and retrieves pending sorted by Priority then FIFO', () async {
      final queue = DurableOfflineQueue();
      final now = DateTime(2026, 8, 29, 12, 0, 0);

      final normalItem1 = OfflineQueueItem(
        queueId: 'q_ord_1',
        idempotencyKey: 'key_ord_1',
        operationType: 'create_order',
        payload: {'orderId': '1'},
        priority: 5,
        traceId: 'tr_1',
        correlationId: 'user_1',
        nextRetryAt: now,
        createdAt: now.add(const Duration(seconds: 1)),
        updatedAt: now,
      );

      final normalItem2 = OfflineQueueItem(
        queueId: 'q_ord_2',
        idempotencyKey: 'key_ord_2',
        operationType: 'create_order',
        payload: {'orderId': '2'},
        priority: 5,
        traceId: 'tr_2',
        correlationId: 'user_2',
        nextRetryAt: now,
        createdAt: now.add(const Duration(seconds: 2)),
        updatedAt: now,
      );

      final highPriorityItem = OfflineQueueItem(
        queueId: 'q_pay_1',
        idempotencyKey: 'key_pay_1',
        operationType: 'wallet_debit',
        payload: {'amount': 10000},
        priority: 10, // High Priority (Payment)
        traceId: 'tr_3',
        correlationId: 'user_1',
        nextRetryAt: now,
        createdAt: now.add(const Duration(seconds: 3)),
        updatedAt: now,
      );

      await queue.enqueue(normalItem1);
      await queue.enqueue(normalItem2);
      await queue.enqueue(highPriorityItem);

      final pending = queue.getPendingItems(now: now);
      expect(pending.length, equals(3));
      // First is payment (priority 10)
      expect(pending[0].queueId, equals('q_pay_1'));
      // Second is ord_1 (priority 5, older timestamp)
      expect(pending[1].queueId, equals('q_ord_1'));
      // Third is ord_2 (priority 5, newer timestamp)
      expect(pending[2].queueId, equals('q_ord_2'));
    });

    test('2. Marks completed items and purges cleanly', () async {
      final queue = DurableOfflineQueue();
      final now = DateTime(2026, 8, 29, 12, 0, 0);

      final item = OfflineQueueItem(
        queueId: 'q_1',
        idempotencyKey: 'key_1',
        operationType: 'ride_request',
        payload: {},
        traceId: 't1',
        correlationId: 'c1',
        nextRetryAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await queue.enqueue(item);
      expect(queue.getPendingItems(now: now).length, equals(1));

      await queue.markCompleted('q_1', now: now);
      expect(queue.getPendingItems(now: now).isEmpty, isTrue);

      final purged = await queue.purgeCompleted();
      expect(purged, equals(1));
      expect(queue.length, equals(0));
    });

    test('3. Retries failure and moves to Dead-Letter after exceeding max attempts', () async {
      final queue = DurableOfflineQueue();
      final now = DateTime(2026, 8, 29, 12, 0, 0);

      final item = OfflineQueueItem(
        queueId: 'q_failing',
        idempotencyKey: 'key_f',
        operationType: 'settlement',
        payload: {},
        maxAttempts: 3,
        attemptCount: 0,
        traceId: 't1',
        correlationId: 'c1',
        nextRetryAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await queue.enqueue(item);

      // Attempt 1 failure
      await queue.markFailed('q_failing', error: 'Internal 500', now: now);
      var current = queue.allItems.first;
      expect(current.status, equals(QueueItemStatus.pending));
      expect(current.attemptCount, equals(1));

      // Attempt 2 failure
      await queue.markFailed('q_failing', error: 'Internal 500', now: now);
      current = queue.allItems.first;
      expect(current.status, equals(QueueItemStatus.pending));
      expect(current.attemptCount, equals(2));

      // Attempt 3 failure -> Dead Letter!
      await queue.markFailed('q_failing', error: 'Internal 500', now: now);
      current = queue.allItems.first;
      expect(current.status, equals(QueueItemStatus.deadLetter));
      expect(current.attemptCount, equals(3));
      expect(queue.getDeadLetterItems().length, equals(1));
    });
  });
}
