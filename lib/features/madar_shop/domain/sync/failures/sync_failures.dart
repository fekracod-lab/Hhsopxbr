// تصنيفات أخطاء واستثناءات المزامنة والعمل بدون اتصال (MADAR SHOP Sync Failures)
// Pure Dart — Zero UI Dependencies

abstract class SyncFailure implements Exception {
  final String message;
  final String? code;

  const SyncFailure(this.message, [this.code]);

  @override
  String toString() => '$runtimeType: $message (${code ?? 'UNKNOWN'})';
}

class InvalidSyncStateTransitionFailure extends SyncFailure {
  InvalidSyncStateTransitionFailure(String message)
      : super(message, 'INVALID_SYNC_STATE_TRANSITION');
}

class SyncOfflineBlockedFailure extends SyncFailure {
  SyncOfflineBlockedFailure(String operation)
      : super('Operation $operation is blocked in offline mode by business policy', 'OFFLINE_OPERATION_BLOCKED');
}

class SyncConflictFailure extends SyncFailure {
  final String conflictId;
  SyncConflictFailure(String message, this.conflictId)
      : super(message, 'SYNC_CONFLICT');
}

class SyncVersionMismatchFailure extends SyncFailure {
  final int localVersion;
  final int serverVersion;
  SyncVersionMismatchFailure(this.localVersion, this.serverVersion)
      : super('Version mismatch: local $localVersion vs server $serverVersion', 'VERSION_MISMATCH');
}

class SyncInsufficientStockFailure extends SyncFailure {
  final String productId;
  final double requestedQuantity;
  final double availableQuantity;

  SyncInsufficientStockFailure(this.productId, this.requestedQuantity, this.availableQuantity)
      : super('Insufficient stock for product $productId: requested $requestedQuantity, available $availableQuantity', 'INSUFFICIENT_STOCK');
}

class SyncAuthBlockedFailure extends SyncFailure {
  SyncAuthBlockedFailure(String message)
      : super(message, 'SYNC_AUTH_BLOCKED');
}

class SyncTenantViolationFailure extends SyncFailure {
  SyncTenantViolationFailure(String message)
      : super(message, 'SYNC_TENANT_VIOLATION');
}

class SyncLeaseExpiredFailure extends SyncFailure {
  SyncLeaseExpiredFailure(String leaseId)
      : super('Sync lease $leaseId has expired', 'LEASE_EXPIRED');
}

class SyncDatabaseFailure extends SyncFailure {
  SyncDatabaseFailure(String message)
      : super(message, 'DATABASE_FAILURE');
}
