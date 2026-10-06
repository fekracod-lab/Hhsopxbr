// أنواع تعارضات المزامنة بين الجهاز المحلي والخادم (MADAR SHOP Sync Conflict Types)
// Pure Dart — Zero UI Dependencies

enum SyncConflictType {
  versionConflict,
  quantityConflict,
  stateConflict,
  duplicateCommand,
  authorizationConflict,
  branchConflict,
  businessConflict,
  deletedRemote,
  staleData;

  String get code {
    switch (this) {
      case SyncConflictType.versionConflict:
        return 'VERSION_CONFLICT';
      case SyncConflictType.quantityConflict:
        return 'QUANTITY_CONFLICT';
      case SyncConflictType.stateConflict:
        return 'STATE_CONFLICT';
      case SyncConflictType.duplicateCommand:
        return 'DUPLICATE_COMMAND';
      case SyncConflictType.authorizationConflict:
        return 'AUTHORIZATION_CONFLICT';
      case SyncConflictType.branchConflict:
        return 'BRANCH_CONFLICT';
      case SyncConflictType.businessConflict:
        return 'BUSINESS_CONFLICT';
      case SyncConflictType.deletedRemote:
        return 'DELETED_REMOTE';
      case SyncConflictType.staleData:
        return 'STALE_DATA';
    }
  }
}
