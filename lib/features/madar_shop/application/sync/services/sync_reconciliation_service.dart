// خدمة مطابقة المزامنة واكتشاف الانحرافات (MADAR SHOP Sync Reconciliation Service)
// Pure Dart — Zero UI Dependencies — Strictly Forbids Silent Auto-Merge of Financial Divergence

import '../../../domain/sync/contracts/i_conflict_repository.dart';
import '../../../domain/sync/contracts/i_inbox_repository.dart';
import '../../../domain/sync/contracts/i_outbox_repository.dart';
import '../../../domain/sync/entities/sync_command_envelope.dart';
import '../../../domain/sync/entities/sync_conflict.dart';

class SyncReconciliationReport {
  final String businessId;
  final String branchId;
  final DateTime reconciledAt;
  final int pendingOutboxCount;
  final int unappliedInboxCount;
  final int unresolvedConflictCount;
  final List<String> divergedEntityIds;
  final List<String> warnings;
  final bool isBalanced;

  const SyncReconciliationReport({
    required this.businessId,
    required this.branchId,
    required this.reconciledAt,
    required this.pendingOutboxCount,
    required this.unappliedInboxCount,
    required this.unresolvedConflictCount,
    required this.divergedEntityIds,
    required this.warnings,
    required this.isBalanced,
  });

  Map<String, dynamic> toJson() => {
        'businessId': businessId,
        'branchId': branchId,
        'reconciledAt': reconciledAt.toIso8601String(),
        'pendingOutboxCount': pendingOutboxCount,
        'unappliedInboxCount': unappliedInboxCount,
        'unresolvedConflictCount': unresolvedConflictCount,
        'divergedEntityIds': divergedEntityIds,
        'warnings': warnings,
        'isBalanced': isBalanced,
      };
}

class SyncReconciliationService {
  final IOutboxRepository _outboxRepo;
  final IInboxRepository _inboxRepo;
  final IConflictRepository _conflictRepo;

  SyncReconciliationService({
    required IOutboxRepository outboxRepo,
    required IInboxRepository inboxRepo,
    required IConflictRepository conflictRepo,
  })  : _outboxRepo = outboxRepo,
        _inboxRepo = inboxRepo,
        _conflictRepo = conflictRepo;

  Future<SyncReconciliationReport> reconcile({
    required String businessId,
    required String branchId,
  }) async {
    final pendingCount = await _outboxRepo.countPending();
    final inFlightCount = await _outboxRepo.countInFlight();
    final unappliedInbox = await _inboxRepo.countUnapplied();
    final unresolvedConflicts = await _conflictRepo.getUnresolved();

    final warnings = <String>[];
    final divergedIds = <String>[];

    // فحص التعارضات العالقة
    for (final conflict in unresolvedConflicts) {
      divergedIds.add(conflict.entityId);
      if (conflict.entityType == 'FINANCIAL_ENTRY' || conflict.entityType == 'REFUND') {
        warnings.add('Critical financial conflict on ${conflict.entityId}: auto-merge forbidden');
      } else {
        warnings.add('Conflict on ${conflict.entityType} (${conflict.entityId}): ${conflict.conflictType.name}');
      }
    }

    // فحص الأوامر المعلقة منذ فترة طويلة
    if (inFlightCount > 0) {
      warnings.add('$inFlightCount commands are currently in-flight; check lease status if stuck');
    }

    final isBalanced = pendingCount == 0 &&
        inFlightCount == 0 &&
        unappliedInbox == 0 &&
        unresolvedConflicts.isEmpty;

    return SyncReconciliationReport(
      businessId: businessId,
      branchId: branchId,
      reconciledAt: DateTime.now(),
      pendingOutboxCount: pendingCount,
      unappliedInboxCount: unappliedInbox,
      unresolvedConflictCount: unresolvedConflicts.length,
      divergedEntityIds: divergedIds,
      warnings: warnings,
      isBalanced: isBalanced,
    );
  }
}
