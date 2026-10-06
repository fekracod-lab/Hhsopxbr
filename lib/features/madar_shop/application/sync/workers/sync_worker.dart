// عامل المزامنة الخلفي الآلي (MADAR SHOP Background Sync Worker)
// Pure Dart — Zero UI Dependencies — Manages Outbox, Inbound Pull, Leases & Backoff

import 'dart:async';
import 'dart:math';
import '../../../domain/sync/contracts/i_cache_repository.dart';
import '../../../domain/sync/contracts/i_conflict_repository.dart';
import '../../../domain/sync/contracts/i_connectivity_service.dart';
import '../../../domain/sync/contracts/i_inbox_repository.dart';
import '../../../domain/sync/contracts/i_outbox_repository.dart';
import '../../../domain/sync/contracts/i_remote_sync_gateway.dart';
import '../../../domain/sync/entities/cached_entities.dart';
import '../../../domain/sync/entities/sync_command_envelope.dart';
import '../../../domain/sync/entities/sync_conflict.dart';
import '../../../domain/sync/enums/conflict_resolution_status.dart';
import '../../../domain/sync/enums/sync_conflict_type.dart';
import '../../../domain/sync/failures/sync_failures.dart';
import '../../../domain/sync/rules/command_dependency_graph.dart';
import '../../../domain/sync/value_objects/sync_ack.dart';
import '../../../domain/sync/value_objects/sync_checkpoint.dart';
import '../../../domain/sync/value_objects/sync_lease.dart';
import '../events/sync_events.dart';

class SyncWorker {
  final IOutboxRepository _outboxRepo;
  final IInboxRepository _inboxRepo;
  final IConflictRepository _conflictRepo;
  final ICacheRepository _cacheRepo;
  final IRemoteSyncGateway _gateway;
  final IConnectivityService _connectivity;

  final StreamController<SyncEvent> _eventController = StreamController<SyncEvent>.broadcast();
  final String workerId;
  final Duration leaseDuration;
  final int maxRetryAttempts;

  bool _isProcessing = false;

  SyncWorker({
    required IOutboxRepository outboxRepo,
    required IInboxRepository inboxRepo,
    required IConflictRepository conflictRepo,
    required ICacheRepository cacheRepo,
    required IRemoteSyncGateway gateway,
    required IConnectivityService connectivity,
    String? workerId,
    this.leaseDuration = const Duration(seconds: 30),
    this.maxRetryAttempts = 5,
  })  : _outboxRepo = outboxRepo,
        _inboxRepo = inboxRepo,
        _conflictRepo = conflictRepo,
        _cacheRepo = cacheRepo,
        _gateway = gateway,
        _connectivity = connectivity,
        workerId = workerId ?? 'worker_${DateTime.now().millisecondsSinceEpoch}';

  Stream<SyncEvent> get events => _eventController.stream;
  bool get isProcessing => _isProcessing;

  /// دورة المزامنة الكاملة: تعافي الانهيار -> إرسال الصادر -> سحب الوارد -> التحديث المحلي
  Future<void> runSyncCycle({
    required String businessId,
    required String branchId,
    String? authToken,
  }) async {
    if (_isProcessing) return;
    _isProcessing = true;
    final stopwatch = Stopwatch()..start();

    try {
      // 1. فحص الاتصال بالإنترنت والوصول الفعلي
      final reachable = await _connectivity.checkReachability();
      if (!reachable) {
        _eventController.add(SyncFailedEvent(
          businessId: businessId,
          branchId: branchId,
          error: 'Network unreachable: probe failed',
        ));
        return;
      }

      // 2. تعافي الانهيار Crash Recovery: إعادة الأوامر ذات عقود الإيجار منتهية الصلاحية
      final recovered = await _outboxRepo.recoverExpiredLeases(DateTime.now());
      if (recovered > 0) {
        _eventController.add(OutboxRecoveredEvent(recovered));
      }

      // 3. جلب الأوامر المعلقة في الصادر وترتيبها سببيّاً
      final pending = await _outboxRepo.fetchPending(limit: 50);
      if (pending.isNotEmpty) {
        _eventController.add(SyncStartedEvent(
          businessId: businessId,
          branchId: branchId,
          pendingCount: pending.length,
        ));

        // ترتيب حسب التسلسل السببي المنضبط
        final ordered = CommandDependencyGraph.orderCommands(pending);

        // إنشاء عقد إيجار للمزامنة Sync Lease
        final lease = SyncLease(
          leaseId: 'lease_${DateTime.now().millisecondsSinceEpoch}',
          workerId: workerId,
          acquiredAt: DateTime.now(),
          expiresAt: DateTime.now().add(leaseDuration),
        );

        final commandIds = ordered.map((c) => c.commandId).toList();
        await _outboxRepo.markInFlight(commandIds, lease);

        // إرسال الحزمة للخادم
        List<SyncAck> acks;
        try {
          acks = await _gateway.pushBatch(ordered, authToken: authToken);
        } catch (e) {
          // في حال حدوث خطأ في الاتصال، تعاد الأوامر إلى الانتظار
          for (final cmd in ordered) {
            await _outboxRepo.markFailed(cmd.commandId, e.toString(), canRetry: true);
          }
          rethrow;
        }

        int syncedCount = 0;
        int conflictCount = 0;
        int failedCount = 0;

        // معالجة الردود لكل أمر على حدة (Partial Batch Processing)
        for (final ack in acks) {
          if (ack.isSuccess) {
            await _outboxRepo.markAcknowledged(ack.commandId, ack);
            _eventController.add(CommandSyncedEvent(
              commandId: ack.commandId,
              entityId: ack.resultReferenceId ?? '',
              newVersion: ack.entityVersion,
            ));
            syncedCount++;
          } else if (ack.isConflict) {
            // تسجيل التعارض وحجبه عن التكرار الأعمى
            final conflict = SyncConflict(
              id: 'cnf_${ack.commandId}',
              commandId: ack.commandId,
              entityId: ack.resultReferenceId ?? ack.commandId,
              entityType: 'UNKNOWN',
              localVersion: ack.entityVersion - 1,
              serverVersion: ack.entityVersion,
              localPayload: {},
              serverPayload: ack.conflictDetails ?? {},
              conflictType: ack.conflictType ?? SyncConflictType.stateConflict,
              detectedAt: DateTime.now(),
              resolutionStatus: ConflictResolutionStatus.unresolved,
            );
            await _conflictRepo.saveConflict(conflict);
            await _outboxRepo.markConflict(ack.commandId, conflict);

            _eventController.add(CommandConflictEvent(
              commandId: ack.commandId,
              conflictId: conflict.id,
              conflictType: conflict.conflictType.name,
            ));
            conflictCount++;
          } else {
            // فشل أمر معين في الحزمة: تطبيق Exponential Backoff
            final currentCmd = await _outboxRepo.findById(ack.commandId);
            final retries = (currentCmd?.retryCount ?? 0) + 1;
            final canRetry = retries < maxRetryAttempts;

            await _outboxRepo.markFailed(
              ack.commandId,
              ack.errorMessage ?? 'Server processing error',
              canRetry: canRetry,
            );
            failedCount++;
          }
        }

        _eventController.add(SyncCompletedEvent(
          businessId: businessId,
          branchId: branchId,
          syncedCount: syncedCount,
          conflictCount: conflictCount,
          failedCount: failedCount,
          durationMs: stopwatch.elapsedMilliseconds,
        ));
      }

      // 4. سحب التحديثات الواردة Inbound Pull (Delta Sync)
      final checkpoint = await _inboxRepo.getLastCheckpoint(businessId, branchId);
      final inboundEvents = await _gateway.pullDelta(
        businessId,
        branchId,
        afterCursor: checkpoint?.lastServerCursor,
      );

      if (inboundEvents.isNotEmpty) {
        await _inboxRepo.saveInboundEvents(inboundEvents);

        // تطبيق الأحداث الواردة على الذاكرة المحلية المؤقتة
        final unapplied = await _inboxRepo.fetchUnapplied();
        for (final ev in unapplied) {
          await _applyInboundEvent(ev);
          await _inboxRepo.markApplied(ev.eventId);
          _eventController.add(InboxAppliedEvent(
            eventId: ev.eventId,
            entityType: ev.entityType,
            entityId: ev.entityId,
          ));
        }

        // تحديث الـ Checkpoint
        final lastEv = inboundEvents.last;
        final updatedCheckpoint = (checkpoint ??
                SyncCheckpoint(
                  businessId: businessId,
                  branchId: branchId,
                  lastSyncAt: DateTime.now(),
                ))
            .advance(
          newCursor: lastEv.serverCursor,
          newServerTimestamp: lastEv.serverTimestamp,
          syncTime: DateTime.now(),
        );
        await _inboxRepo.saveCheckpoint(updatedCheckpoint);
      }
    } catch (e) {
      _eventController.add(SyncFailedEvent(
        businessId: businessId,
        branchId: branchId,
        error: e.toString(),
      ));
    } finally {
      _isProcessing = false;
      stopwatch.stop();
    }
  }

  Future<void> _applyInboundEvent(inboundEvent) async {
    final payload = inboundEvent.payload;
    if (inboundEvent.entityType == 'PRODUCT') {
      final product = CachedProduct(
        id: inboundEvent.entityId,
        sku: payload['sku'] as String? ?? 'SKU-${inboundEvent.entityId}',
        barcode: payload['barcode'] as String? ?? '',
        nameAr: payload['nameAr'] as String? ?? 'منتج',
        priceMinorUnits: (payload['priceMinorUnits'] as num?)?.toInt() ?? 0,
        costMinorUnits: (payload['costMinorUnits'] as num?)?.toInt() ?? 0,
        version: (payload['version'] as num?)?.toInt() ?? 1,
        fetchedAt: DateTime.now(),
      );
      await _cacheRepo.saveProduct(product);
    } else if (inboundEvent.entityType == 'INVENTORY') {
      final inv = CachedInventory(
        productId: inboundEvent.entityId,
        branchId: inboundEvent.branchId,
        onHandQuantity: (payload['onHandQuantity'] as num?)?.toDouble() ?? 0.0,
        reservedQuantity: (payload['reservedQuantity'] as num?)?.toDouble() ?? 0.0,
        version: (payload['version'] as num?)?.toInt() ?? 1,
        fetchedAt: DateTime.now(),
      );
      await _cacheRepo.saveInventory(inv);
    }
  }

  /// حساب التراجع الأسي مع التذبذب العشوائي (Exponential Backoff with Jitter)
  Duration calculateBackoff(int attempt) {
    final baseSeconds = pow(2, attempt).toInt(); // 1, 2, 4, 8, 16
    final jitter = Random().nextInt(1000); // 0-999 ms
    return Duration(seconds: baseSeconds, milliseconds: jitter);
  }

  void dispose() {
    _eventController.close();
  }
}
