// لقطة حالة المزامنة اللحظية لعرضها في لوحة التحكم وتغذية واجهة POS في S8
// Pure Dart — Zero UI Dependencies

import '../enums/connectivity_state.dart';

class SyncStatusSnapshot {
  final ConnectivityState connectivityState;
  final int pendingOutboxCount;
  final int inFlightCount;
  final int failedCount;
  final int conflictCount;
  final int inboxPendingCount;
  final DateTime? lastSuccessfulSyncAt;
  final String? lastError;
  final bool isSyncing;

  const SyncStatusSnapshot({
    required this.connectivityState,
    this.pendingOutboxCount = 0,
    this.inFlightCount = 0,
    this.failedCount = 0,
    this.conflictCount = 0,
    this.inboxPendingCount = 0,
    this.lastSuccessfulSyncAt,
    this.lastError,
    this.isSyncing = false,
  });

  bool get isHealthy =>
      connectivityState == ConnectivityState.online &&
      failedCount == 0 &&
      conflictCount == 0;

  bool get hasPendingWork => pendingOutboxCount > 0 || inFlightCount > 0;

  Map<String, dynamic> toJson() => {
        'connectivityState': connectivityState.name,
        'pendingOutboxCount': pendingOutboxCount,
        'inFlightCount': inFlightCount,
        'failedCount': failedCount,
        'conflictCount': conflictCount,
        'inboxPendingCount': inboxPendingCount,
        'lastSuccessfulSyncAt': lastSuccessfulSyncAt?.toIso8601String(),
        'lastError': lastError,
        'isSyncing': isSyncing,
      };
}
