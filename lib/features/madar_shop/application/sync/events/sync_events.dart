// أحداث الرصد وسجلات تدقيق المزامنة والعمل بدون اتصال (MADAR SHOP Sync Events & Audit)
// Pure Dart — Zero UI Dependencies

abstract class SyncEvent {
  final String eventName;
  final DateTime timestamp;

  SyncEvent(this.eventName, [DateTime? time]) : timestamp = time ?? DateTime.now();

  Map<String, dynamic> toJson();
}

class SyncStartedEvent extends SyncEvent {
  final String businessId;
  final String branchId;
  final int pendingCount;

  SyncStartedEvent({
    required this.businessId,
    required this.branchId,
    required this.pendingCount,
  }) : super('sync_started');

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'businessId': businessId,
        'branchId': branchId,
        'pendingCount': pendingCount,
        'timestamp': timestamp.toIso8601String(),
      };
}

class SyncCompletedEvent extends SyncEvent {
  final String businessId;
  final String branchId;
  final int syncedCount;
  final int conflictCount;
  final int failedCount;
  final int durationMs;

  SyncCompletedEvent({
    required this.businessId,
    required this.branchId,
    required this.syncedCount,
    required this.conflictCount,
    required this.failedCount,
    required this.durationMs,
  }) : super('sync_completed');

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'businessId': businessId,
        'branchId': branchId,
        'syncedCount': syncedCount,
        'conflictCount': conflictCount,
        'failedCount': failedCount,
        'durationMs': durationMs,
        'timestamp': timestamp.toIso8601String(),
      };
}

class SyncFailedEvent extends SyncEvent {
  final String businessId;
  final String branchId;
  final String error;

  SyncFailedEvent({
    required this.businessId,
    required this.branchId,
    required this.error,
  }) : super('sync_failed');

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'businessId': businessId,
        'branchId': branchId,
        'error': error,
        'timestamp': timestamp.toIso8601String(),
      };
}

class CommandQueuedEvent extends SyncEvent {
  final String commandId;
  final String entityType;
  final String entityId;

  CommandQueuedEvent({
    required this.commandId,
    required this.entityType,
    required this.entityId,
  }) : super('command_queued');

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'commandId': commandId,
        'entityType': entityType,
        'entityId': entityId,
        'timestamp': timestamp.toIso8601String(),
      };
}

class CommandSyncedEvent extends SyncEvent {
  final String commandId;
  final String entityId;
  final int newVersion;

  CommandSyncedEvent({
    required this.commandId,
    required this.entityId,
    required this.newVersion,
  }) : super('command_synced');

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'commandId': commandId,
        'entityId': entityId,
        'newVersion': newVersion,
        'timestamp': timestamp.toIso8601String(),
      };
}

class CommandConflictEvent extends SyncEvent {
  final String commandId;
  final String conflictId;
  final String conflictType;

  CommandConflictEvent({
    required this.commandId,
    required this.conflictId,
    required this.conflictType,
  }) : super('command_conflict');

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'commandId': commandId,
        'conflictId': conflictId,
        'conflictType': conflictType,
        'timestamp': timestamp.toIso8601String(),
      };
}

class ReconnectedEvent extends SyncEvent {
  final String connectivityState;

  ReconnectedEvent(this.connectivityState) : super('reconnect');

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'connectivityState': connectivityState,
        'timestamp': timestamp.toIso8601String(),
      };
}

class InboxAppliedEvent extends SyncEvent {
  final String eventId;
  final String entityType;
  final String entityId;

  InboxAppliedEvent({
    required this.eventId,
    required this.entityType,
    required this.entityId,
  }) : super('inbox_applied');

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'eventId': eventId,
        'entityType': entityType,
        'entityId': entityId,
        'timestamp': timestamp.toIso8601String(),
      };
}

class OutboxRecoveredEvent extends SyncEvent {
  final int recoveredCount;

  OutboxRecoveredEvent(this.recoveredCount) : super('outbox_recovered');

  @override
  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'recoveredCount': recoveredCount,
        'timestamp': timestamp.toIso8601String(),
      };
}

class SyncAuditRecord {
  final String id;
  final String action; // e.g. "COMMAND_ENQUEUED", "COMMAND_SYNCED", "CONFLICT_DETECTED", "CONFLICT_RESOLVED"
  final String entityType;
  final String entityId;
  final String actorId;
  final DateTime timestamp;
  final Map<String, dynamic> sanitizedDetails;

  const SyncAuditRecord({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.actorId,
    required this.timestamp,
    required this.sanitizedDetails,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        'actorId': actorId,
        'timestamp': timestamp.toIso8601String(),
        'sanitizedDetails': sanitizedDetails,
      };
}
