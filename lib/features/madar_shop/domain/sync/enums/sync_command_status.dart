// حالات أوامر المزامنة وحالتها في الطابور المحلي (MADAR SHOP Sync Command Status)
// Pure Dart — Zero UI Dependencies

enum SyncCommandStatus {
  localOnly,
  queued,
  syncing,
  synced,
  failed,
  conflict,
  requiresReview,
  cancelled;

  bool get isPending => this == queued || this == syncing;
  bool get isTerminal => this == synced || this == cancelled;
  bool get canRetry => this == failed || this == queued;
}
