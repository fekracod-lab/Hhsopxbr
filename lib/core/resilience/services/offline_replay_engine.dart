import 'durable_offline_queue.dart';
import 'idempotency_engine.dart';
import '../entities/offline_queue_item.dart';
import '../enums/resilience_enums.dart';

/// محرك إعادة تشغيل وبث العمليات غير المتصلة عند استعادة الاتصال (Offline Replay Engine)
class OfflineReplayEngine {
  final DurableOfflineQueue queue;
  final IdempotencyEngine idempotencyEngine;

  const OfflineReplayEngine({
    required this.queue,
    required this.idempotencyEngine,
  });

  /// إعادة معالجة جميع العمليات المعلقة في الطابور وإرسالها للخادم
  Future<(int succeeded, int failed, int deadLettered)> replayPendingOperations({
    required Future<bool> Function(OfflineQueueItem item) serverSender,
    DateTime? now,
  }) async {
    int succeeded = 0;
    int failed = 0;
    int deadLettered = 0;

    final pendingItems = queue.getPendingItems(now: now);

    for (final item in pendingItems) {
      try {
        // تنفيذ الإرسال عبر محرك الـ Idempotency لضمان عدم التكرار على الخادم
        final isSuccess = await idempotencyEngine.executeIdempotent<bool>(
          idempotencyKey: item.idempotencyKey,
          operation: () async => await serverSender(item),
        );

        if (isSuccess) {
          await queue.markCompleted(item.queueId, now: now);
          succeeded++;
        } else {
          await queue.markFailed(item.queueId, error: 'Server rejected operation', now: now);
          failed++;
        }
      } catch (error) {
        await queue.markFailed(item.queueId, error: error.toString(), now: now);
        failed++;
      }

      // فحص إذا تحول العنصر إلى Dead-Letter بعد الفشل
      final updated = queue.allItems.firstWhere((i) => i.queueId == item.queueId);
      if (updated.status == QueueItemStatus.deadLetter) {
        deadLettered++;
      }
    }

    return (succeeded, failed, deadLettered);
  }
}
