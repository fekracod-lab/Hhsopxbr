// منسق المزامنة وإدارة العمليات بدون اتصال المركزي (MADAR SHOP Sync Coordinator)
// Pure Dart — Zero UI Dependencies — Central Application Facade

import 'dart:async';
import '../../../domain/sync/contracts/i_cache_repository.dart';
import '../../../domain/sync/contracts/i_conflict_repository.dart';
import '../../../domain/sync/contracts/i_connectivity_service.dart';
import '../../../domain/sync/contracts/i_inbox_repository.dart';
import '../../../domain/sync/contracts/i_outbox_repository.dart';
import '../../../domain/sync/entities/sync_command_envelope.dart';
import '../../../domain/sync/enums/conflict_resolution_status.dart';
import '../../../domain/sync/enums/connectivity_state.dart';
import '../../../domain/sync/enums/sync_command_status.dart';
import '../../../domain/sync/failures/sync_failures.dart';
import '../../../domain/sync/value_objects/offline_policy.dart';
import '../../../domain/sync/value_objects/sync_status_snapshot.dart';
import '../../../domain/sync/value_objects/sync_ack.dart';
import '../../../domain/printing/entities/print_job.dart';
import '../../../domain/printing/enums/print_job_status.dart';
import '../../../domain/printing/enums/print_trigger_type.dart';
import '../../../domain/printing/contracts/i_print_job_repository.dart';
import '../commands/sync_commands.dart';
import '../events/sync_events.dart';
import '../services/local_transaction_runner.dart';
import '../services/offline_stock_allocator.dart';
import '../workers/sync_worker.dart';

class SyncCoordinator {
  final IOutboxRepository _outboxRepo;
  final IInboxRepository _inboxRepo;
  final IConflictRepository _conflictRepo;
  final ICacheRepository _cacheRepo;
  final IConnectivityService _connectivity;
  final SyncWorker _syncWorker;
  final LocalTransactionRunner _txRunner;
  final OfflineStockAllocator _stockAllocator;
  final IPrintJobRepository? _printJobRepo;
  final OfflinePolicy _policy;

  final StreamController<SyncEvent> _eventController = StreamController<SyncEvent>.broadcast();
  int _sequenceCounter = 1000;
  DateTime? _lastSuccessfulSyncAt;
  String? _lastError;

  SyncCoordinator({
    required IOutboxRepository outboxRepo,
    required IInboxRepository inboxRepo,
    required IConflictRepository conflictRepo,
    required ICacheRepository cacheRepo,
    required IConnectivityService connectivity,
    required SyncWorker syncWorker,
    required LocalTransactionRunner txRunner,
    required OfflineStockAllocator stockAllocator,
    IPrintJobRepository? printJobRepo,
    OfflinePolicy? policy,
  })  : _outboxRepo = outboxRepo,
        _inboxRepo = inboxRepo,
        _conflictRepo = conflictRepo,
        _cacheRepo = cacheRepo,
        _connectivity = connectivity,
        _syncWorker = syncWorker,
        _txRunner = txRunner,
        _stockAllocator = stockAllocator,
        _printJobRepo = printJobRepo,
        _policy = policy ?? const OfflinePolicy() {
    // الاستماع لأحداث عامل المزامنة وإعادة بثها
    _syncWorker.events.listen((event) {
      if (event is SyncCompletedEvent) {
        _lastSuccessfulSyncAt = event.timestamp;
      } else if (event is SyncFailedEvent) {
        _lastError = event.error;
      }
      _eventController.add(event);
    });
  }

  Stream<SyncEvent> get events => _eventController.stream;

  /// تنفيذ عملية بيع أوفلاين مع فحص المخزون، الحجز المحلي، وحفظ الأمر في الصادر ذرياً
  Future<SyncCommandEnvelope> checkoutOffline({
    required String commandId,
    required String saleId,
    required String businessId,
    required String branchId,
    required String terminalId,
    required String sessionId,
    required String idempotencyKey,
    required bool isCash,
    required Map<String, dynamic> cartPayload,
    required Map<String, double> itemsQuantity, // productId -> quantity
    bool autoPrint = false,
  }) async {
    // 1. فحص سياسة العمليات بدون اتصال
    final permission = isCash ? _policy.cashSale : _policy.creditSale;
    if (permission.isBlocked) {
      throw SyncOfflineBlockedFailure(isCash ? 'Cash Sale' : 'Credit Sale');
    }

    // 2. التحقق من المخزون المحلي وحجزه مؤقتاً
    for (final entry in itemsQuantity.entries) {
      await _stockAllocator.reserveStockOffline(
        productId: entry.key,
        branchId: branchId,
        requestedQuantity: entry.value,
      );
    }

    // 3. بناء غلاف أمر المزامنة
    final envelope = SyncCommandEnvelope(
      commandId: commandId,
      commandType: 'CHECKOUT',
      entityType: 'SALE',
      entityId: saleId,
      businessId: businessId,
      branchId: branchId,
      terminalId: terminalId,
      sessionId: sessionId,
      createdAt: DateTime.now(),
      clientTimestamp: DateTime.now(),
      sequence: ++_sequenceCounter,
      idempotencyKey: idempotencyKey,
      payload: {
        ...cartPayload,
        'isCash': isCash,
        'itemsQuantity': itemsQuantity,
      },
      status: SyncCommandStatus.queued,
    );

    // 4. الحفظ الذري للأمر في قاعدة البيانات وصندوق الصادر
    await _txRunner.executeAtomic(
      envelope: envelope,
      localEntityMutation: (tx) async {
        // حفظ سجل الفاتورة محلياً في جدول المبيعات المحلية
        await tx.insert('local_sales', {
          'saleId': saleId,
          'commandId': commandId,
          'businessId': businessId,
          'branchId': branchId,
          'terminalId': terminalId,
          'isSynced': 0,
          'createdAt': envelope.createdAt.toIso8601String(),
        });
      },
    );

    _eventController.add(CommandQueuedEvent(
      commandId: commandId,
      entityType: 'SALE',
      entityId: saleId,
    ));

    // 5. تكامل الطباعة مع S6 محلياً دون الخلط بين نجاح الطباعة ونجاح المزامنة
    if (autoPrint && _printJobRepo != null) {
      final printJob = PrintJob(
        jobId: 'pjob_${DateTime.now().millisecondsSinceEpoch}_${envelope.sequence}',
        documentId: saleId,
        printerId: 'local_receipt_printer',
        businessId: businessId,
        branchId: branchId,
        status: PrintJobStatus.queued,
        triggerType: PrintTriggerType.autoPrint,
        createdAt: DateTime.now(),
        idempotencyKey: 'auto_print_sale_$saleId',
      );
      await _printJobRepo.saveJob(printJob);
    }

    return envelope;
  }

  /// تنفيذ حركة مخزنية أوفلاين مع تطبيق سياسة العمل
  Future<SyncCommandEnvelope> applyInventoryMovementOffline({
    required String commandId,
    required String businessId,
    required String branchId,
    required String terminalId,
    required String sessionId,
    required String productId,
    required double quantity,
    required String movementType,
    required String idempotencyKey,
  }) async {
    // فحص السياسة
    if (_policy.inventoryAdjustment.isBlocked) {
      throw SyncOfflineBlockedFailure('Inventory Adjustment');
    }

    final envelope = SyncCommandEnvelope(
      commandId: commandId,
      commandType: 'APPLY_INVENTORY',
      entityType: 'INVENTORY',
      entityId: productId,
      businessId: businessId,
      branchId: branchId,
      terminalId: terminalId,
      sessionId: sessionId,
      createdAt: DateTime.now(),
      clientTimestamp: DateTime.now(),
      sequence: ++_sequenceCounter,
      idempotencyKey: idempotencyKey,
      payload: {
        'productId': productId,
        'quantity': quantity,
        'movementType': movementType,
      },
      status: SyncCommandStatus.queued,
    );

    await _txRunner.executeAtomic(
      envelope: envelope,
      localEntityMutation: (tx) async {},
    );

    return envelope;
  }

  /// حل تعارض المزامنة
  Future<void> resolveConflict(ResolveConflictCommand command) async {
    final conflict = await _conflictRepo.getById(command.conflictId);
    if (conflict == null) {
      throw SyncConflictFailure('Conflict not found: ${command.conflictId}', command.conflictId);
    }

    await _conflictRepo.resolve(
      command.conflictId,
      command.resolution,
      command.actorId,
      command.method,
    );

    // تحديث حالة أمر الصادر المرتبط
    final envelope = await _outboxRepo.findById(conflict.commandId);
    if (envelope != null) {
      if (command.resolution == ConflictResolutionStatus.resolvedLocalWins) {
        // إعادة الأمر للطابور للإرسال بالنسخة المحدثة
        await _outboxRepo.markFailed(conflict.commandId, 'Resolved by ${command.actorId}', canRetry: true);
      } else {
        // رفض الأمر محلياً أو اعتماد الخادم
        await _outboxRepo.markAcknowledged(
          conflict.commandId,
          SyncAck(
            commandId: conflict.commandId,
            idempotencyKey: envelope.idempotencyKey,
            status: SyncCommandStatus.synced,
            serverTimestamp: DateTime.now(),
            entityVersion: conflict.serverVersion,
          ),
        );
      }
    }
  }

  /// جلب لقطة حالة المزامنة اللحظية
  Future<SyncStatusSnapshot> getSyncStatusSnapshot() async {
    final connectivity = _connectivity.currentStatus;
    final pending = await _outboxRepo.countPending();
    final inFlight = await _outboxRepo.countInFlight();
    final failed = await _outboxRepo.countFailed();
    final conflicts = await _conflictRepo.countUnresolved();
    final unappliedInbox = await _inboxRepo.countUnapplied();

    return SyncStatusSnapshot(
      connectivityState: connectivity,
      pendingOutboxCount: pending,
      inFlightCount: inFlight,
      failedCount: failed,
      conflictCount: conflicts,
      inboxPendingCount: unappliedInbox,
      lastSuccessfulSyncAt: _lastSuccessfulSyncAt,
      lastError: _lastError,
      isSyncing: _syncWorker.isProcessing,
    );
  }

  /// إطلاق دورة المزامنة
  Future<void> triggerSync(TriggerSyncCommand command) async {
    await _syncWorker.runSyncCycle(
      businessId: command.businessId,
      branchId: command.branchId,
      authToken: command.authToken,
    );
  }

  void dispose() {
    _eventController.close();
    _syncWorker.dispose();
  }
}
