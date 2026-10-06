import 'dart:async';
import '../entities/domain_event.dart';

typedef DomainEventListener = FutureOr<void> Function(DomainEvent event);

/// ناقل الأحداث المركزي الموحد (Unified Domain Event Bus)
class DomainEventBus {
  static DomainEventBus? _instance;
  static DomainEventBus get instance => _instance ??= DomainEventBus();

  final Map<String, List<DomainEventListener>> _listeners = {};
  final Set<String> _processedEventIds = {};

  DomainEventBus();

  /// الاشتراك في نوع حدث معين
  void subscribe(String eventType, DomainEventListener listener) {
    _listeners.putIfAbsent(eventType, () => []).add(listener);
  }

  /// الاشتراك في كافة الأحداث (Global Listener)
  void subscribeAll(DomainEventListener listener) {
    _listeners.putIfAbsent('*', () => []).add(listener);
  }

  /// نشر حدث وإشعار كافة المشتركين ذرياً وحظر التكرار
  Future<void> publish(DomainEvent event) async {
    if (_processedEventIds.contains(event.eventId)) {
      return; // إسقاط الحدث المعالج مسبقاً (Event Idempotency)
    }
    _processedEventIds.add(event.eventId);

    final specificListeners = _listeners[event.eventType] ?? [];
    final globalListeners = _listeners['*'] ?? [];

    for (final listener in [...specificListeners, ...globalListeners]) {
      try {
        await listener(event);
      } catch (_) {
        // حماية المستمعين من التوقف
      }
    }
  }

  void clear() {
    _listeners.clear();
    _processedEventIds.clear();
  }
}
