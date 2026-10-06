// أوامر إدارة المزامنة والعمل بدون اتصال (MADAR SHOP Sync Commands)
// Pure Dart — Zero UI Dependencies

import '../../../domain/sync/enums/conflict_resolution_status.dart';

class TriggerSyncCommand {
  final String businessId;
  final String branchId;
  final String? terminalId;
  final String? authToken;
  final bool forceFullSync;

  const TriggerSyncCommand({
    required this.businessId,
    required this.branchId,
    this.terminalId,
    this.authToken,
    this.forceFullSync = false,
  });
}

class ResolveConflictCommand {
  final String conflictId;
  final ConflictResolutionStatus resolution;
  final String actorId;
  final String method;
  final Map<String, dynamic>? customMergedPayload;

  const ResolveConflictCommand({
    required this.conflictId,
    required this.resolution,
    required this.actorId,
    required this.method,
    this.customMergedPayload,
  });
}

class RetryFailedCommand {
  final String commandId;
  final String actorId;
  final String? reason;

  const RetryFailedCommand({
    required this.commandId,
    required this.actorId,
    this.reason,
  });
}

class PurgeOutboxCommand {
  final Duration olderThan;

  const PurgeOutboxCommand({
    this.olderThan = const Duration(days: 30),
  });
}
