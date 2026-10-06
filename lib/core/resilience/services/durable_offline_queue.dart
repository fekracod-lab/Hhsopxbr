import '../entities/offline_queue_item.dart';
import '../enums/resilience_enums.dart';

/// طابور العمليات غير المتصلة الدائم المقاوم لإعادة تشغيل النظام (Durable Offline Queue)
class DurableOfflineQueue {
  final Map<String, OfflineQueueItem> _storage = {};

  DurableOfflineQueue();

  int get length => _storage.length;
  List<OfflineQueueItem> get allItems => _storage.values.toList();

  /// إضافة عنصر إلى طابور التخزين الدائم
  Future<void> enqueue(OfflineQueueItem item) async {
    _storage[item.queueId] = item;
  }

  /// جلب العناصر المؤهلة للإرسال مرتبة حسب الأولوية ثم FIFO
  List<OfflineQueueItem> getPendingItems({DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    final pending = _storage.values.where((item) {
      return item.status == QueueItemStatus.pending &&
          !item.nextRetryAt.isAfter(currentTime);
    }).toList();

    // ترتيب: الأولوية الأعلى أولاً (10 -> 5 -> 1)، ثم الأقدم زمناً (FIFO)
    pending.sort((a, b) {
      if (b.priority != a.priority) {
        return b.priority.compareTo(a.priority);
      }
      return a.createdAt.compareTo(b.createdAt);
    });

    return pending;
  }

  /// تمييز العنصر كمكتمل بعد استلام الـ Server ACK
  Future<void> markCompleted(String queueId, {DateTime? now}) async {
    final item = _storage[queueId];
    if (item != null) {
      _storage[queueId] = item.copyWith(
        status: QueueItemStatus.completed,
        updatedAt: now ?? DateTime.now(),
      );
    }
  }

  /// تسجيل فشل المحاولة وجدولة المحاولة التالية أو تحويله لـ Dead-Letter
  Future<void> markFailed(String queueId, {String? error, Duration? backoffDelay, DateTime? now}) async {
    final item = _storage[queueId];
    if (item == null) return;

    final currentTime = now ?? DateTime.now();
    final newAttemptCount = item.attemptCount + 1;

    if (newAttemptCount >= item.maxAttempts) {
      // تجاوز الحد الأقصى للمحاولات -> تحويله إلى Dead-Letter
      _storage[queueId] = item.copyWith(
        status: QueueItemStatus.deadLetter,
        attemptCount: newAttemptCount,
        lastError: error ?? 'Max retry attempts exhausted',
        updatedAt: currentTime,
      );
    } else {
      final delay = backoffDelay ?? Duration(seconds: 2 * newAttemptCount);
      _storage[queueId] = item.copyWith(
        status: QueueItemStatus.pending,
        attemptCount: newAttemptCount,
        nextRetryAt: currentTime.add(delay),
        lastError: error,
        updatedAt: currentTime,
      );
    }
  }

  /// استرجاع العناصر المحولة إلى Dead-Letter للفحص والتدقيق
  List<OfflineQueueItem> getDeadLetterItems() {
    return _storage.values
        .where((item) => item.status == QueueItemStatus.deadLetter)
        .toList();
  }

  /// مسح العناصر المكتملة
  Future<int> purgeCompleted() async {
    final completedKeys = _storage.entries
        .where((e) => e.value.status == QueueItemStatus.completed)
        .map((e) => e.key)
        .toList();

    for (final k in completedKeys) {
      _storage.remove(k);
    }
    return completedKeys.length;
  }

  void clear() {
    _storage.clear();
  }
}
