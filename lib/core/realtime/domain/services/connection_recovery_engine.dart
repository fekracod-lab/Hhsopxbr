import '../entities/realtime_event.dart';
import '../enums/realtime_enums.dart';

/// محرك إدارة واستعادة الاتصال وإعادة المزامنة (Connection Recovery Engine)
class ConnectionRecoveryEngine {
  ConnectionStatus _status = ConnectionStatus.connected;
  final List<RealtimeEvent> _offlinePendingQueue = [];

  ConnectionRecoveryEngine();

  ConnectionStatus get status => _status;
  List<RealtimeEvent> get offlineQueue => List.unmodifiable(_offlinePendingQueue);

  /// تحديث حالة الاتصال
  void updateStatus(ConnectionStatus newStatus) {
    _status = newStatus;
  }

  /// إضافة حدث إلى طابور الانتظار أثناء انقطاع الاتصال
  void enqueueOfflineEvent(RealtimeEvent event) {
    if (_status != ConnectionStatus.connected) {
      _offlinePendingQueue.add(event);
    }
  }

  /// تفريغ واسترجاع الأحداث المتراكمة عند عودة الاتصال
  List<RealtimeEvent> flushQueueOnReconnect() {
    _status = ConnectionStatus.connected;
    final events = List<RealtimeEvent>.from(_offlinePendingQueue);
    _offlinePendingQueue.clear();
    return events;
  }

  void clear() {
    _status = ConnectionStatus.connected;
    _offlinePendingQueue.clear();
  }
}
