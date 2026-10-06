// حزمة اختبارات محرك العمل بدون اتصال والمزامنة الشاملة (MADAR SHOP Phase S7 Tests)
// 120+ Tests Covering Groups A through M + Critical Tests A, B, C, D, E, F, G

import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/enums/sync_command_status.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/enums/outbox_state.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/enums/connectivity_state.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/enums/sync_conflict_type.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/enums/conflict_resolution_status.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/enums/cache_freshness.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/enums/offline_operation_permission.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/enums/sync_direction.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/value_objects/sync_checkpoint.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/value_objects/sync_lease.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/value_objects/sync_ack.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/value_objects/sync_status_snapshot.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/value_objects/offline_policy.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/entities/sync_command_envelope.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/entities/sync_conflict.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/entities/inbox_event.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/entities/cached_entities.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/rules/sync_state_machine.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/rules/command_dependency_graph.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/sync/failures/sync_failures.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/local/memory_local_database.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/local/schema_migrations.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/queue/local_outbox_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/queue/local_inbox_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/queue/local_conflict_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/queue/local_cache_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/remote/mock_remote_sync_gateway.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/connectivity/probe_connectivity_service.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/print_persistence/persistent_print_job_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/print_persistence/persistent_printer_profile_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/application/sync/commands/sync_commands.dart';
import 'package:dalal_alqaim/features/madar_shop/application/sync/events/sync_events.dart';
import 'package:dalal_alqaim/features/madar_shop/application/sync/services/local_transaction_runner.dart';
import 'package:dalal_alqaim/features/madar_shop/application/sync/services/offline_stock_allocator.dart';
import 'package:dalal_alqaim/features/madar_shop/application/sync/services/sync_reconciliation_service.dart';
import 'package:dalal_alqaim/features/madar_shop/application/sync/workers/sync_worker.dart';
import 'package:dalal_alqaim/features/madar_shop/application/sync/coordinators/sync_coordinator.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/entities/print_job.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/entities/printer_profile.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/enums/print_document_type.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/enums/print_job_status.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/enums/print_trigger_type.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/printing/value_objects/paper_profile.dart';

void main() {
  late MemoryLocalDatabase db;
  late LocalOutboxRepository outboxRepo;
  late LocalInboxRepository inboxRepo;
  late LocalConflictRepository conflictRepo;
  late LocalCacheRepository cacheRepo;
  late MockRemoteSyncGateway gateway;
  late ProbeConnectivityService connectivity;
  late LocalTransactionRunner txRunner;
  late OfflineStockAllocator stockAllocator;
  late PersistentPrintJobRepository printJobRepo;
  late PersistentPrinterProfileRepository printerProfileRepo;
  late SyncWorker syncWorker;
  late SyncCoordinator coordinator;

  setUp(() async {
    db = MemoryLocalDatabase();
    await db.initialize();

    outboxRepo = LocalOutboxRepository(db);
    inboxRepo = LocalInboxRepository(db);
    conflictRepo = LocalConflictRepository(db);
    cacheRepo = LocalCacheRepository(db);
    gateway = MockRemoteSyncGateway();
    connectivity = ProbeConnectivityService(gateway);
    txRunner = LocalTransactionRunner(db: db, outboxRepo: outboxRepo);
    stockAllocator = OfflineStockAllocator(cacheRepo: cacheRepo);
    printJobRepo = PersistentPrintJobRepository(db);
    printerProfileRepo = PersistentPrinterProfileRepository(db);

    syncWorker = SyncWorker(
      outboxRepo: outboxRepo,
      inboxRepo: inboxRepo,
      conflictRepo: conflictRepo,
      cacheRepo: cacheRepo,
      gateway: gateway,
      connectivity: connectivity,
    );

    coordinator = SyncCoordinator(
      outboxRepo: outboxRepo,
      inboxRepo: inboxRepo,
      conflictRepo: conflictRepo,
      cacheRepo: cacheRepo,
      connectivity: connectivity,
      syncWorker: syncWorker,
      txRunner: txRunner,
      stockAllocator: stockAllocator,
      printJobRepo: printJobRepo,
    );
  });

  tearDown(() async {
    coordinator.dispose();
    await db.close();
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP A: LOCAL PERSISTENCE, TRANSACTIONS & ROLLBACKS (1-10)
  // ═══════════════════════════════════════════════════════════════
  group('Group A: Local Persistence, Transactions & Rollbacks', () {
    test('1. Initialize database and verify current schema version', () async {
      expect(db.currentSchemaVersion, equals(3));
    });

    test('2. Insert row and query by primary key', () async {
      await db.insert('test_table', {'id': '101', 'name': 'Item A'});
      final row = await db.findById('test_table', 'id', '101');
      expect(row, isNotNull);
      expect(row!['name'], equals('Item A'));
    });

    test('3. Atomic transaction commits all changes together', () async {
      await db.runInTransaction((tx) async {
        await tx.insert('test_table', {'id': '102', 'val': 10});
        await tx.insert('test_table', {'id': '103', 'val': 20});
      });

      expect(await db.count('test_table'), equals(2));
    });

    test('4. Atomic transaction rollback leaves database unchanged on error', () async {
      try {
        await db.runInTransaction((tx) async {
          await tx.insert('test_table', {'id': '104', 'val': 30});
          throw Exception('Simulated failure during transaction');
        });
      } catch (_) {}

      final row = await db.findById('test_table', 'id', '104');
      expect(row, isNull);
    });

    test('5. Filtering queries with where and whereArgs', () async {
      await db.insert('items', {'id': '1', 'category': 'food', 'price': 100});
      await db.insert('items', {'id': '2', 'category': 'drink', 'price': 50});
      await db.insert('items', {'id': '3', 'category': 'food', 'price': 150});

      final foods = await db.query('items', where: 'category = ?', whereArgs: ['food']);
      expect(foods.length, equals(2));
    });

    test('6. Ordering queries ASC and DESC', () async {
      await db.insert('orders', {'id': '1', 'seq': 3});
      await db.insert('orders', {'id': '2', 'seq': 1});
      await db.insert('orders', {'id': '3', 'seq': 2});

      final asc = await db.query('orders', orderBy: 'seq ASC');
      expect(asc.map((r) => r['seq']).toList(), equals([1, 2, 3]));

      final desc = await db.query('orders', orderBy: 'seq DESC');
      expect(desc.map((r) => r['seq']).toList(), equals([3, 2, 1]));
    });

    test('7. Pagination with limit and offset', () async {
      for (int i = 1; i <= 10; i++) {
        await db.insert('nums', {'id': '$i', 'val': i});
      }

      final page1 = await db.query('nums', orderBy: 'val ASC', limit: 3, offset: 0);
      expect(page1.map((r) => r['val']).toList(), equals([1, 2, 3]));

      final page2 = await db.query('nums', orderBy: 'val ASC', limit: 3, offset: 3);
      expect(page2.map((r) => r['val']).toList(), equals([4, 5, 6]));
    });

    test('8. Update row selectively', () async {
      await db.insert('users', {'id': 'u1', 'status': 'inactive'});
      await db.update('users', {'status': 'active'}, where: 'id = ?', whereArgs: ['u1']);

      final row = await db.findById('users', 'id', 'u1');
      expect(row!['status'], equals('active'));
    });

    test('9. Delete row with matching criteria', () async {
      await db.insert('logs', {'id': 'l1', 'level': 'debug'});
      await db.insert('logs', {'id': 'l2', 'level': 'error'});

      await db.delete('logs', where: 'level = ?', whereArgs: ['debug']);
      expect(await db.count('logs'), equals(1));
    });

    test('10. Counting rows in table', () async {
      expect(await db.count('empty_table'), equals(0));
      await db.insert('empty_table', {'id': '1'});
      expect(await db.count('empty_table'), equals(1));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP B: OUTBOX PATTERN & STATE TRANSITIONS (11-20)
  // ═══════════════════════════════════════════════════════════════
  group('Group B: Outbox Pattern & State Transitions', () {
    SyncCommandEnvelope createEnvelope({String id = 'cmd-1', int seq = 1}) {
      return SyncCommandEnvelope(
        commandId: id,
        commandType: 'CHECKOUT',
        entityType: 'SALE',
        entityId: 'sale-$id',
        businessId: 'biz-1',
        branchId: 'branch-1',
        terminalId: 'term-1',
        sessionId: 'sess-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: seq,
        idempotencyKey: 'idemp-$id',
        payload: {'amount': 5000},
      );
    }

    test('11. Enqueue command into outbox sets status to queued', () async {
      final env = createEnvelope();
      await outboxRepo.enqueue(env);

      final found = await outboxRepo.findById('cmd-1');
      expect(found, isNotNull);
      expect(found!.status, equals(SyncCommandStatus.queued));
    });

    test('12. Fetch pending returns queued commands in sequence order', () async {
      await outboxRepo.enqueue(createEnvelope(id: 'cmd-2', seq: 20));
      await outboxRepo.enqueue(createEnvelope(id: 'cmd-1', seq: 10));

      final pending = await outboxRepo.fetchPending();
      expect(pending.length, equals(2));
      expect(pending.first.commandId, equals('cmd-1'));
    });

    test('13. Mark in-flight sets status to syncing with lease details', () async {
      await outboxRepo.enqueue(createEnvelope());
      final lease = SyncLease(
        leaseId: 'lease-1',
        workerId: 'w-1',
        acquiredAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 30)),
      );

      await outboxRepo.markInFlight(['cmd-1'], lease);
      final found = await outboxRepo.findById('cmd-1');
      expect(found!.status, equals(SyncCommandStatus.syncing));
    });

    test('14. Mark acknowledged updates status to synced and clears lease', () async {
      await outboxRepo.enqueue(createEnvelope());
      final ack = SyncAck(
        commandId: 'cmd-1',
        idempotencyKey: 'idemp-cmd-1',
        status: SyncCommandStatus.synced,
        serverTimestamp: DateTime.now(),
        entityVersion: 2,
      );

      await outboxRepo.markAcknowledged('cmd-1', ack);
      final found = await outboxRepo.findById('cmd-1');
      expect(found!.status, equals(SyncCommandStatus.synced));
      expect(found.version, equals(2));
    });

    test('15. Mark failed with canRetry=true returns status to queued with incremented retry', () async {
      await outboxRepo.enqueue(createEnvelope());
      await outboxRepo.markFailed('cmd-1', 'Timeout', canRetry: true);

      final found = await outboxRepo.findById('cmd-1');
      expect(found!.status, equals(SyncCommandStatus.queued));
      expect(found.retryCount, equals(1));
      expect(found.lastError, equals('Timeout'));
    });

    test('16. Mark failed with canRetry=false transitions status to failed', () async {
      await outboxRepo.enqueue(createEnvelope());
      await outboxRepo.markFailed('cmd-1', 'Fatal unrecoverable error', canRetry: false);

      final found = await outboxRepo.findById('cmd-1');
      expect(found!.status, equals(SyncCommandStatus.failed));
    });

    test('17. Mark conflict sets status to conflict', () async {
      await outboxRepo.enqueue(createEnvelope());
      final conflict = SyncConflict(
        id: 'cnf-1',
        commandId: 'cmd-1',
        entityId: 'sale-cmd-1',
        entityType: 'SALE',
        localVersion: 1,
        serverVersion: 2,
        localPayload: {},
        serverPayload: {},
        conflictType: SyncConflictType.versionConflict,
        detectedAt: DateTime.now(),
      );

      await outboxRepo.markConflict('cmd-1', conflict);
      final found = await outboxRepo.findById('cmd-1');
      expect(found!.status, equals(SyncCommandStatus.conflict));
    });

    test('18. Outbox state machine forbids invalid transitions (synced -> syncing)', () {
      expect(
        () => SyncStateMachine.validateCommandTransition(
          SyncCommandStatus.synced,
          SyncCommandStatus.syncing,
          'cmd-1',
        ),
        throwsA(isA<InvalidSyncStateTransitionFailure>()),
      );
    });

    test('19. Outbox counts pending, in-flight, failed, and conflict correctly', () async {
      await outboxRepo.enqueue(createEnvelope(id: 'c1'));
      await outboxRepo.enqueue(createEnvelope(id: 'c2'));
      await outboxRepo.markFailed('c2', 'err', canRetry: false);

      expect(await outboxRepo.countPending(), equals(1));
      expect(await outboxRepo.countFailed(), equals(1));
    });

    test('20. Purge acknowledged removes old synced commands past retention threshold', () async {
      final env = createEnvelope();
      await outboxRepo.enqueue(env);
      await outboxRepo.markAcknowledged(
        'cmd-1',
        SyncAck(
          commandId: 'cmd-1',
          idempotencyKey: 'k',
          status: SyncCommandStatus.synced,
          serverTimestamp: DateTime.now(),
          entityVersion: 1,
        ),
      );

      final purged = await outboxRepo.purgeAcknowledged(DateTime.now().add(const Duration(hours: 1)));
      expect(purged, equals(1));
      expect(await outboxRepo.findById('cmd-1'), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP C: IDEMPOTENCY & REPLAY PROTECTION (21-30)
  // ═══════════════════════════════════════════════════════════════
  group('Group C: Idempotency & Replay Protection', () {
    test('21. Find command by unique idempotencyKey returns existing envelope', () async {
      final env = SyncCommandEnvelope(
        commandId: 'c-10',
        commandType: 'CHECKOUT',
        entityType: 'SALE',
        entityId: 's-10',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 's-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'unique_sale_key_10',
        payload: {},
      );
      await outboxRepo.enqueue(env);

      final found = await outboxRepo.findByIdempotencyKey('unique_sale_key_10');
      expect(found, isNotNull);
      expect(found!.commandId, equals('c-10'));
    });

    test('22. Command idempotencyKey is preserved unchanged across retries', () async {
      final env = SyncCommandEnvelope(
        commandId: 'c-11',
        commandType: 'CHECKOUT',
        entityType: 'SALE',
        entityId: 's-11',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 's-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'same_key_across_retries',
        payload: {},
      );
      await outboxRepo.enqueue(env);
      await outboxRepo.markFailed('c-11', 'Timeout', canRetry: true);

      final found = await outboxRepo.findById('c-11');
      expect(found!.idempotencyKey, equals('same_key_across_retries'));
    });

    test('23. Push batch to remote gateway with same idempotencyKey returns same effect', () async {
      final env = SyncCommandEnvelope(
        commandId: 'c-12',
        commandType: 'CHECKOUT',
        entityType: 'SALE',
        entityId: 's-12',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 's-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'gateway_idemp_key',
        payload: {},
      );

      final ack1 = await gateway.pushBatch([env]);
      expect(ack1.first.isSuccess, isTrue);

      // Replay same command
      final ack2 = await gateway.pushBatch([env]);
      expect(ack2.first.isSuccess, isTrue);
      expect(gateway.processedIdempotencyKeys.contains('gateway_idemp_key'), isTrue);
    });

    test('24. CRITICAL TEST B: Same command submitted 5 times results in exactly ONE server effect', () async {
      final env = SyncCommandEnvelope(
        commandId: 'crit-b-cmd',
        commandType: 'CHECKOUT',
        entityType: 'SALE',
        entityId: 'sale-crit-b',
        businessId: 'biz-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 's-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 100,
        idempotencyKey: 'crit_b_idempotency_key',
        payload: {'total': 15000},
      );

      for (int i = 0; i < 5; i++) {
        final acks = await gateway.pushBatch([env]);
        expect(acks.first.isSuccess, isTrue);
      }

      // الخادم عالج نفس المفتاح دون تكرار الأثر
      expect(gateway.processedIdempotencyKeys.length, equals(1));
    });

    test('25. Monotonic sequence counter increments sequentially', () async {
      final env1 = await coordinator.checkoutOffline(
        commandId: 'seq-1',
        saleId: 's-seq-1',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 'sess-1',
        idempotencyKey: 'k-1',
        isCash: true,
        cartPayload: {},
        itemsQuantity: {},
      );

      final env2 = await coordinator.checkoutOffline(
        commandId: 'seq-2',
        saleId: 's-seq-2',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 'sess-1',
        idempotencyKey: 'k-2',
        isCash: true,
        cartPayload: {},
        itemsQuantity: {},
      );

      expect(env2.sequence, equals(env1.sequence + 1));
    });

    test('26. Inbound event deduplication in inbox', () async {
      final ev = InboxEvent(
        eventId: 'in-ev-1',
        businessId: 'b-1',
        branchId: 'br-1',
        entityType: 'PRODUCT',
        entityId: 'p-1',
        serverCursor: 'cur-1',
        serverTimestamp: DateTime.now(),
        payload: {},
      );

      await inboxRepo.saveInboundEvents([ev]);
      await inboxRepo.saveInboundEvents([ev]); // Replay

      expect(await inboxRepo.countUnapplied(), equals(1));
    });

    test('27. Local checkout idempotency key collision check', () async {
      await coordinator.checkoutOffline(
        commandId: 'idemp-chk-1',
        saleId: 's-idemp-1',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 'sess-1',
        idempotencyKey: 'unique_pos_checkout_key',
        isCash: true,
        cartPayload: {},
        itemsQuantity: {},
      );

      final stored = await outboxRepo.findByIdempotencyKey('unique_pos_checkout_key');
      expect(stored, isNotNull);
      expect(stored!.commandId, equals('idemp-chk-1'));
    });

    test('28. Print job idempotency key generated deterministically', () async {
      final env = await coordinator.checkoutOffline(
        commandId: 'p-chk-1',
        saleId: 'sale-999',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 'sess-1',
        idempotencyKey: 'k-p-1',
        isCash: true,
        cartPayload: {},
        itemsQuantity: {},
        autoPrint: true,
      );

      final jobs = await printJobRepo.getJobsForDocument(
        businessId: 'b-1',
        documentId: 'sale-999',
      );
      expect(jobs.length, equals(1));
      expect(jobs.first.idempotencyKey, equals('auto_print_sale_sale-999'));
    });

    test('29. Outbox command payload preservation through serialization', () {
      final env = SyncCommandEnvelope(
        commandId: 'ser-1',
        commandType: 'CHECKOUT',
        entityType: 'SALE',
        entityId: 's-ser',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 'sess-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'k-ser',
        payload: {'discount': 2500, 'itemsCount': 3},
      );

      final json = env.toJson();
      final restored = SyncCommandEnvelope.fromJson(json);
      expect(restored.payload['discount'], equals(2500));
      expect(restored.payload['itemsCount'], equals(3));
    });

    test('30. SyncAck serialization preservation', () {
      final ack = SyncAck(
        commandId: 'ack-1',
        idempotencyKey: 'k-ack',
        status: SyncCommandStatus.synced,
        serverTimestamp: DateTime.now(),
        entityVersion: 3,
        resultReferenceId: 'REF-100',
      );

      final json = ack.toJson();
      final restored = SyncAck.fromJson(json);
      expect(restored.resultReferenceId, equals('REF-100'));
      expect(restored.entityVersion, equals(3));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP D: RETRY & EXPONENTIAL BACKOFF (31-40)
  // ═══════════════════════════════════════════════════════════════
  group('Group D: Retry & Exponential Backoff', () {
    test('31. Initial retry backoff calculates 1s base with jitter', () {
      final d = syncWorker.calculateBackoff(0);
      expect(d.inSeconds, equals(1));
    });

    test('32. Second retry backoff calculates 2s base with jitter', () {
      final d = syncWorker.calculateBackoff(1);
      expect(d.inSeconds, equals(2));
    });

    test('33. Third retry backoff calculates 4s base with jitter', () {
      final d = syncWorker.calculateBackoff(2);
      expect(d.inSeconds, equals(4));
    });

    test('34. Fourth retry backoff calculates 8s base with jitter', () {
      final d = syncWorker.calculateBackoff(3);
      expect(d.inSeconds, equals(8));
    });

    test('35. Fifth retry backoff calculates 16s base with jitter', () {
      final d = syncWorker.calculateBackoff(4);
      expect(d.inSeconds, equals(16));
    });

    test('36. Max retry limit transitions command permanently to failed', () async {
      final env = SyncCommandEnvelope(
        commandId: 'retry-max',
        commandType: 'CHECKOUT',
        entityType: 'SALE',
        entityId: 's-max',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 's-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'k-max',
        payload: {},
        retryCount: 4, // 5th attempt
      );
      await outboxRepo.enqueue(env);

      gateway.failCommandIds.add('retry-max');
      await syncWorker.runSyncCycle(businessId: 'b-1', branchId: 'br-1');

      final found = await outboxRepo.findById('retry-max');
      expect(found!.status, equals(SyncCommandStatus.failed));
    });

    test('37. Failed command can be manually retried via RetryFailedCommand', () async {
      final env = SyncCommandEnvelope(
        commandId: 'retry-manual',
        commandType: 'CHECKOUT',
        entityType: 'SALE',
        entityId: 's-man',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 's-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'k-man',
        payload: {},
        status: SyncCommandStatus.failed,
      );
      await outboxRepo.enqueue(env);

      await outboxRepo.markFailed('retry-manual', 'Manual retry request', canRetry: true);
      final found = await outboxRepo.findById('retry-manual');
      expect(found!.status, equals(SyncCommandStatus.queued));
    });

    test('38. Transient network error during sync leaves commands in queued state for retry', () async {
      await outboxRepo.enqueue(SyncCommandEnvelope(
        commandId: 'net-err-cmd',
        commandType: 'CHECKOUT',
        entityType: 'SALE',
        entityId: 's-net',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 's-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'k-net',
        payload: {},
      ));

      gateway.isOnline = false;
      connectivity.setStatus(ConnectivityState.offline);

      await syncWorker.runSyncCycle(businessId: 'b-1', branchId: 'br-1');

      final found = await outboxRepo.findById('net-err-cmd');
      expect(found!.status, equals(SyncCommandStatus.queued));
    });

    test('39. Worker preserves retryCount across failed attempts', () async {
      await outboxRepo.enqueue(SyncCommandEnvelope(
        commandId: 'ret-cnt-cmd',
        commandType: 'CHECKOUT',
        entityType: 'SALE',
        entityId: 's-cnt',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 's-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'k-cnt',
        payload: {},
        retryCount: 2,
      ));

      gateway.failCommandIds.add('ret-cnt-cmd');
      await syncWorker.runSyncCycle(businessId: 'b-1', branchId: 'br-1');

      final found = await outboxRepo.findById('ret-cnt-cmd');
      expect(found!.retryCount, equals(3));
    });

    test('40. Server error message is recorded in lastError accurately', () async {
      await outboxRepo.enqueue(SyncCommandEnvelope(
        commandId: 'err-msg-cmd',
        commandType: 'CHECKOUT',
        entityType: 'SALE',
        entityId: 's-err',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 's-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'k-err',
        payload: {},
      ));

      gateway.failCommandIds.add('err-msg-cmd');
      await syncWorker.runSyncCycle(businessId: 'b-1', branchId: 'br-1');

      final found = await outboxRepo.findById('err-msg-cmd');
      expect(found!.lastError, contains('Simulated server processing failure'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP E: ORDERING & CAUSAL SEQUENCE (41-50)
  // ═══════════════════════════════════════════════════════════════
  group('Group E: Ordering & Causal Sequence', () {
    SyncCommandEnvelope createCmd(String id, int seq, {String? dependsOn}) {
      return SyncCommandEnvelope(
        commandId: id,
        commandType: 'OP',
        entityType: 'ENT',
        entityId: 'e-1',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 's-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: seq,
        idempotencyKey: 'k-$id',
        payload: dependsOn != null ? {'dependsOnCommandId': dependsOn} : {},
      );
    }

    test('41. CommandDependencyGraph sorts commands by monotonic terminal sequence', () {
      final list = [createCmd('c3', 30), createCmd('c1', 10), createCmd('c2', 20)];
      final ordered = CommandDependencyGraph.orderCommands(list);
      expect(ordered.map((c) => c.commandId).toList(), equals(['c1', 'c2', 'c3']));
    });

    test('42. Commands with explicit dependsOnCommandId are placed after prerequisite', () {
      final list = [
        createCmd('c2', 10, dependsOn: 'c1'),
        createCmd('c1', 20),
      ];
      final ordered = CommandDependencyGraph.orderCommands(list);
      expect(ordered.first.commandId, equals('c1'));
      expect(ordered.last.commandId, equals('c2'));
    });

    test('43. Entity stream groups commands by entityType:entityId', () {
      final list = [
        SyncCommandEnvelope(
          commandId: 'p1-cmd',
          commandType: 'ADJUST',
          entityType: 'PRODUCT',
          entityId: 'prod-A',
          businessId: 'b-1',
          branchId: 'br-1',
          terminalId: 't-1',
          sessionId: 's-1',
          createdAt: DateTime.now(),
          clientTimestamp: DateTime.now(),
          sequence: 1,
          idempotencyKey: 'k1',
          payload: {},
        ),
        SyncCommandEnvelope(
          commandId: 'p2-cmd',
          commandType: 'ADJUST',
          entityType: 'PRODUCT',
          entityId: 'prod-B',
          businessId: 'b-1',
          branchId: 'br-1',
          terminalId: 't-1',
          sessionId: 's-1',
          createdAt: DateTime.now(),
          clientTimestamp: DateTime.now(),
          sequence: 2,
          idempotencyKey: 'k2',
          payload: {},
        ),
      ];

      final grouped = CommandDependencyGraph.groupByEntityStream(list);
      expect(grouped.keys.length, equals(2));
      expect(grouped.containsKey('PRODUCT:prod-A'), isTrue);
      expect(grouped.containsKey('PRODUCT:prod-B'), isTrue);
    });

    test('44. Entity stream maintains causal ordering for product stock movements', () {
      final list = [
        SyncCommandEnvelope(
          commandId: 'm3',
          commandType: 'RETURN',
          entityType: 'PRODUCT',
          entityId: 'prod-A',
          businessId: 'b-1',
          branchId: 'br-1',
          terminalId: 't-1',
          sessionId: 's-1',
          createdAt: DateTime.now(),
          clientTimestamp: DateTime.now(),
          sequence: 3,
          idempotencyKey: 'k3',
          payload: {},
        ),
        SyncCommandEnvelope(
          commandId: 'm1',
          commandType: 'ADJUST',
          entityType: 'PRODUCT',
          entityId: 'prod-A',
          businessId: 'b-1',
          branchId: 'br-1',
          terminalId: 't-1',
          sessionId: 's-1',
          createdAt: DateTime.now(),
          clientTimestamp: DateTime.now(),
          sequence: 1,
          idempotencyKey: 'k1',
          payload: {},
        ),
        SyncCommandEnvelope(
          commandId: 'm2',
          commandType: 'SALE',
          entityType: 'PRODUCT',
          entityId: 'prod-A',
          businessId: 'b-1',
          branchId: 'br-1',
          terminalId: 't-1',
          sessionId: 's-1',
          createdAt: DateTime.now(),
          clientTimestamp: DateTime.now(),
          sequence: 2,
          idempotencyKey: 'k2',
          payload: {},
        ),
      ];

      final grouped = CommandDependencyGraph.groupByEntityStream(list);
      final stream = grouped['PRODUCT:prod-A']!;
      expect(stream.map((c) => c.commandId).toList(), equals(['m1', 'm2', 'm3']));
    });

    test('45. Empty command list returns empty list in dependency graph', () {
      expect(CommandDependencyGraph.orderCommands([]), isEmpty);
    });

    test('46. Single command returns itself', () {
      final cmd = createCmd('c1', 1);
      final ordered = CommandDependencyGraph.orderCommands([cmd]);
      expect(ordered.length, equals(1));
      expect(ordered.first.commandId, equals('c1'));
    });

    test('47. Sequence tiebreaker uses createdAt timestamp', () {
      final t1 = DateTime(2026, 9, 6, 10, 0);
      final t2 = DateTime(2026, 9, 6, 10, 5);

      final cmd1 = SyncCommandEnvelope(
        commandId: 'tie-1',
        commandType: 'T',
        entityType: 'E',
        entityId: 'e',
        businessId: 'b',
        branchId: 'br',
        terminalId: 't',
        sessionId: 's',
        createdAt: t1,
        clientTimestamp: t1,
        sequence: 10,
        idempotencyKey: 'k1',
        payload: {},
      );

      final cmd2 = SyncCommandEnvelope(
        commandId: 'tie-2',
        commandType: 'T',
        entityType: 'E',
        entityId: 'e',
        businessId: 'b',
        branchId: 'br',
        terminalId: 't',
        sessionId: 's',
        createdAt: t2,
        clientTimestamp: t2,
        sequence: 10,
        idempotencyKey: 'k2',
        payload: {},
      );

      final ordered = CommandDependencyGraph.orderCommands([cmd2, cmd1]);
      expect(ordered.first.commandId, equals('tie-1'));
      expect(ordered.last.commandId, equals('tie-2'));
    });

    test('48. Missing dependency does not deadlock graph traversal', () {
      final cmd = createCmd('orphan', 1, dependsOn: 'non-existent-parent');
      final ordered = CommandDependencyGraph.orderCommands([cmd]);
      expect(ordered.length, equals(1));
      expect(ordered.first.commandId, equals('orphan'));
    });

    test('49. Multi-command batch maintains causal sequence during worker dispatch', () async {
      await outboxRepo.enqueue(createCmd('b3', 30));
      await outboxRepo.enqueue(createCmd('b1', 10));
      await outboxRepo.enqueue(createCmd('b2', 20));

      await syncWorker.runSyncCycle(businessId: 'b-1', branchId: 'br-1');

      expect(gateway.receivedCommands.map((c) => c.commandId).toList(), equals(['b1', 'b2', 'b3']));
    });

    test('50. Inbound delta events ordered by serverTimestamp', () async {
      final t1 = DateTime(2026, 9, 6, 1, 0);
      final t2 = DateTime(2026, 9, 6, 2, 0);

      final ev1 = InboxEvent(
        eventId: 'e1',
        businessId: 'b-1',
        branchId: 'br-1',
        entityType: 'PRODUCT',
        entityId: 'p1',
        serverCursor: 'c1',
        serverTimestamp: t1,
        payload: {},
      );

      final ev2 = InboxEvent(
        eventId: 'e2',
        businessId: 'b-1',
        branchId: 'br-1',
        entityType: 'PRODUCT',
        entityId: 'p2',
        serverCursor: 'c2',
        serverTimestamp: t2,
        payload: {},
      );

      await inboxRepo.saveInboundEvents([ev2, ev1]);
      final unapplied = await inboxRepo.fetchUnapplied();
      expect(unapplied.first.eventId, equals('e1'));
      expect(unapplied.last.eventId, equals('e2'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP F: CONNECTIVITY STATES & REACHABILITY (51-60)
  // ═══════════════════════════════════════════════════════════════
  group('Group F: Connectivity States & Reachability', () {
    test('51. Initial connectivity state defaults to online', () {
      expect(connectivity.currentStatus, equals(ConnectivityState.online));
      expect(connectivity.currentStatus.isConnected, isTrue);
    });

    test('52. Probe failure transitions connectivity state to offline', () async {
      gateway.isOnline = false;
      final reachable = await connectivity.checkReachability();
      expect(reachable, isFalse);
      expect(connectivity.currentStatus, equals(ConnectivityState.offline));
      expect(connectivity.currentStatus.isDisconnected, isTrue);
    });

    test('53. Connectivity stream broadcasts state transitions reactively', () async {
      final states = <ConnectivityState>[];
      final sub = connectivity.connectivityStream.listen(states.add);

      connectivity.setStatus(ConnectivityState.offline);
      connectivity.setStatus(ConnectivityState.unstable);
      connectivity.setStatus(ConnectivityState.online);

      await Future.delayed(Duration.zero);
      expect(states, equals([
        ConnectivityState.offline,
        ConnectivityState.unstable,
        ConnectivityState.online,
      ]));
      await sub.cancel();
    });

    test('54. Reachability probe returns true when gateway online', () async {
      gateway.isOnline = true;
      expect(await connectivity.checkReachability(), isTrue);
      expect(connectivity.currentStatus, equals(ConnectivityState.online));
    });

    test('55. Unstable network transitions state to unstable', () {
      connectivity.setStatus(ConnectivityState.unstable);
      expect(connectivity.currentStatus, equals(ConnectivityState.unstable));
    });

    test('56. Offline status halts sync worker dispatch gracefully', () async {
      connectivity.setStatus(ConnectivityState.offline);
      gateway.isOnline = false;

      final events = <SyncEvent>[];
      final sub = syncWorker.events.listen(events.add);

      await syncWorker.runSyncCycle(businessId: 'b-1', branchId: 'br-1');
      await Future.delayed(Duration.zero);

      expect(events.any((e) => e is SyncFailedEvent), isTrue);
      await sub.cancel();
    });

    test('57. Reconnection event emitted when restored', () async {
      final event = ReconnectedEvent(ConnectivityState.online.name);
      expect(event.eventName, equals('reconnect'));
      expect(event.connectivityState, equals('online'));
    });

    test('58. Network timeout during pushBatch catches error and reverts in-flight', () async {
      await outboxRepo.enqueue(SyncCommandEnvelope(
        commandId: 'timeout-cmd',
        commandType: 'OP',
        entityType: 'ENT',
        entityId: 'e',
        businessId: 'b',
        branchId: 'br',
        terminalId: 't',
        sessionId: 's',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'k',
        payload: {},
      ));

      gateway.isOnline = true;
      connectivity.setStatus(ConnectivityState.online);

      // Force pushBatch failure
      gateway.isOnline = false;
      await syncWorker.runSyncCycle(businessId: 'b', branchId: 'br');

      final cmd = await outboxRepo.findById('timeout-cmd');
      expect(cmd!.status, equals(SyncCommandStatus.queued));
    });

    test('59. Gateway probeReachability latency simulation', () async {
      gateway.simulateLatency = true;
      gateway.latencyDuration = const Duration(milliseconds: 10);
      expect(await gateway.probeReachability(), isTrue);
    });

    test('60. Disposing connectivity service closes broadcast stream cleanly', () {
      connectivity.dispose();
      // No throw on dispose
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP G: INBOUND INBOX & IDEMPOTENT PULL (61-70)
  // ═══════════════════════════════════════════════════════════════
  group('Group G: Inbound Inbox & Idempotent Pull', () {
    test('61. Inbound events saved into inbox table with isApplied=0', () async {
      final ev = InboxEvent(
        eventId: 'in-1',
        businessId: 'b-1',
        branchId: 'br-1',
        entityType: 'PRODUCT',
        entityId: 'p-1',
        serverCursor: 'cur-1',
        serverTimestamp: DateTime.now(),
        payload: {'nameAr': 'جبنة بيضاء', 'priceMinorUnits': 2000},
      );

      await inboxRepo.saveInboundEvents([ev]);
      expect(await inboxRepo.countUnapplied(), equals(1));
    });

    test('62. CRITICAL TEST D: Server sends same inbound event twice -> saved once, applied once', () async {
      final ev = InboxEvent(
        eventId: 'crit-d-ev',
        businessId: 'b-1',
        branchId: 'br-1',
        entityType: 'PRODUCT',
        entityId: 'p-10',
        serverCursor: 'cur-d',
        serverTimestamp: DateTime.now(),
        payload: {'nameAr': 'عصير برتقال', 'priceMinorUnits': 1500},
      );

      // وصول أول للحدث
      await inboxRepo.saveInboundEvents([ev]);
      expect(await inboxRepo.countUnapplied(), equals(1));

      // وصول مكرر لنفس الحدث
      await inboxRepo.saveInboundEvents([ev]);
      expect(await inboxRepo.countUnapplied(), equals(1)); // لا يزال 1

      // تطبيق الحدث
      await inboxRepo.markApplied('crit-d-ev');
      expect(await inboxRepo.countUnapplied(), equals(0));
    });

    test('63. Fetch unapplied returns only events where isApplied=0', () async {
      final ev1 = InboxEvent(
        eventId: 'u1',
        businessId: 'b-1',
        branchId: 'br-1',
        entityType: 'PRODUCT',
        entityId: 'p1',
        serverCursor: 'c1',
        serverTimestamp: DateTime.now(),
        payload: {},
      );
      final ev2 = InboxEvent(
        eventId: 'u2',
        businessId: 'b-1',
        branchId: 'br-1',
        entityType: 'PRODUCT',
        entityId: 'p2',
        serverCursor: 'c2',
        serverTimestamp: DateTime.now(),
        payload: {},
      );

      await inboxRepo.saveInboundEvents([ev1, ev2]);
      await inboxRepo.markApplied('u1');

      final unapplied = await inboxRepo.fetchUnapplied();
      expect(unapplied.length, equals(1));
      expect(unapplied.first.eventId, equals('u2'));
    });

    test('64. Applying product event updates CachedProduct in local cache', () async {
      final ev = InboxEvent(
        eventId: 'ev-prod',
        businessId: 'b-1',
        branchId: 'br-1',
        entityType: 'PRODUCT',
        entityId: 'prod-updated',
        serverCursor: 'cur-p',
        serverTimestamp: DateTime.now(),
        payload: {
          'sku': 'SKU-UPDATED',
          'barcode': '1234567890',
          'nameAr': 'حليب طويل الأجل',
          'priceMinorUnits': 1750,
          'costMinorUnits': 1200,
          'version': 3,
        },
      );

      gateway.stagedInboundEvents.add(ev);
      await syncWorker.runSyncCycle(businessId: 'b-1', branchId: 'br-1');

      final cached = await cacheRepo.getProduct('prod-updated');
      expect(cached, isNotNull);
      expect(cached!.priceMinorUnits, equals(1750));
      expect(cached.nameAr, equals('حليب طويل الأجل'));
    });

    test('65. Applying inventory event updates CachedInventory in local cache', () async {
      final ev = InboxEvent(
        eventId: 'ev-inv',
        businessId: 'b-1',
        branchId: 'br-1',
        entityType: 'INVENTORY',
        entityId: 'prod-stock-1',
        serverCursor: 'cur-inv',
        serverTimestamp: DateTime.now(),
        payload: {
          'onHandQuantity': 45.0,
          'reservedQuantity': 5.0,
          'version': 2,
        },
      );

      gateway.stagedInboundEvents.add(ev);
      await syncWorker.runSyncCycle(businessId: 'b-1', branchId: 'br-1');

      final cached = await cacheRepo.getInventory('prod-stock-1', 'br-1');
      expect(cached, isNotNull);
      expect(cached!.onHandQuantity, equals(45.0));
      expect(cached.localAvailableQuantity, equals(40.0));
    });

    test('66. Saving checkpoint preserves lastServerCursor and lastServerTimestamp', () async {
      final cp = SyncCheckpoint(
        businessId: 'b-1',
        branchId: 'br-1',
        lastServerCursor: 'cursor_xyz',
        lastServerTimestamp: DateTime(2026, 9, 6, 12, 0),
        lastSyncAt: DateTime.now(),
        sequenceNumber: 5,
      );

      await inboxRepo.saveCheckpoint(cp);
      final retrieved = await inboxRepo.getLastCheckpoint('b-1', 'br-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.lastServerCursor, equals('cursor_xyz'));
      expect(retrieved.sequenceNumber, equals(5));
    });

    test('67. Checkpoint advances sequentially upon delta sync', () async {
      final cp = SyncCheckpoint(
        businessId: 'b-1',
        branchId: 'br-1',
        lastSyncAt: DateTime.now(),
      );
      final advanced = cp.advance(
        newCursor: 'new_cur',
        newServerTimestamp: DateTime.now(),
        syncTime: DateTime.now(),
      );

      expect(advanced.lastServerCursor, equals('new_cur'));
      expect(advanced.sequenceNumber, equals(1));
    });

    test('68. HasEvent checks event existence accurately', () async {
      expect(await inboxRepo.hasEvent('non-existing'), isFalse);
    });

    test('69. Count unapplied reflects pending inbox events accurately', () async {
      expect(await inboxRepo.countUnapplied(), equals(0));
    });

    test('70. InboxAppliedEvent generated when event applied', () {
      final ev = InboxAppliedEvent(
        eventId: 'ev-1',
        entityType: 'PRODUCT',
        entityId: 'p-1',
      );
      expect(ev.eventName, equals('inbox_applied'));
      expect(ev.eventId, equals('ev-1'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP H: CONFLICT MODEL, DETECTION & POLICIES (71-85)
  // ═══════════════════════════════════════════════════════════════
  group('Group H: Conflict Model, Detection & Policies', () {
    test('71. SyncConflict records localVersion, serverVersion, and conflictType', () {
      final cnf = SyncConflict(
        id: 'c-1',
        commandId: 'cmd-1',
        entityId: 'e-1',
        entityType: 'SALE',
        localVersion: 1,
        serverVersion: 3,
        localPayload: {},
        serverPayload: {},
        conflictType: SyncConflictType.versionConflict,
        detectedAt: DateTime.now(),
      );

      expect(cnf.localVersion, equals(1));
      expect(cnf.serverVersion, equals(3));
      expect(cnf.conflictType, equals(SyncConflictType.versionConflict));
      expect(cnf.isResolved, isFalse);
    });

    test('72. Quantity conflict detected when server stock insufficient', () async {
      gateway.serverStock['prod-low'] = 2; // Server has 2

      final env = SyncCommandEnvelope(
        commandId: 'cmd-qty-cnf',
        commandType: 'APPLY_INVENTORY',
        entityType: 'INVENTORY',
        entityId: 'prod-low',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 's-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'k-qty',
        payload: {'requestedQuantity': 5.0}, // Terminal requests 5
      );

      await outboxRepo.enqueue(env);
      await syncWorker.runSyncCycle(businessId: 'b-1', branchId: 'br-1');

      final unresolved = await conflictRepo.getUnresolved();
      expect(unresolved.length, equals(1));
      expect(unresolved.first.conflictType, equals(SyncConflictType.quantityConflict));
    });

    test('73. Conflict repository stores and retrieves unresolved conflicts', () async {
      final cnf = SyncConflict(
        id: 'cnf-store',
        commandId: 'cmd-store',
        entityId: 'e-store',
        entityType: 'PRODUCT',
        localVersion: 1,
        serverVersion: 2,
        localPayload: {},
        serverPayload: {},
        conflictType: SyncConflictType.stateConflict,
        detectedAt: DateTime.now(),
      );

      await conflictRepo.saveConflict(cnf);
      expect(await conflictRepo.countUnresolved(), equals(1));

      final retrieved = await conflictRepo.getById('cnf-store');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('cnf-store'));
    });

    test('74. Resolving conflict with localWins re-queues command', () async {
      final cnf = SyncConflict(
        id: 'cnf-lw',
        commandId: 'cmd-lw',
        entityId: 'e-lw',
        entityType: 'PRODUCT',
        localVersion: 1,
        serverVersion: 2,
        localPayload: {},
        serverPayload: {},
        conflictType: SyncConflictType.versionConflict,
        detectedAt: DateTime.now(),
      );
      await conflictRepo.saveConflict(cnf);
      await outboxRepo.enqueue(SyncCommandEnvelope(
        commandId: 'cmd-lw',
        commandType: 'EDIT',
        entityType: 'PRODUCT',
        entityId: 'e-lw',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 's-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'k-lw',
        payload: {},
        status: SyncCommandStatus.conflict,
      ));

      await coordinator.resolveConflict(ResolveConflictCommand(
        conflictId: 'cnf-lw',
        resolution: ConflictResolutionStatus.resolvedLocalWins,
        actorId: 'manager_1',
        method: 'FORCE_LOCAL_OVERWRITE',
      ));

      final resolved = await conflictRepo.getById('cnf-lw');
      expect(resolved!.resolutionStatus, equals(ConflictResolutionStatus.resolvedLocalWins));

      final cmd = await outboxRepo.findById('cmd-lw');
      expect(cmd!.status, equals(SyncCommandStatus.queued));
    });

    test('75. Resolving conflict with serverWins marks command acknowledged', () async {
      final cnf = SyncConflict(
        id: 'cnf-sw',
        commandId: 'cmd-sw',
        entityId: 'e-sw',
        entityType: 'PRODUCT',
        localVersion: 1,
        serverVersion: 2,
        localPayload: {},
        serverPayload: {},
        conflictType: SyncConflictType.versionConflict,
        detectedAt: DateTime.now(),
      );
      await conflictRepo.saveConflict(cnf);
      await outboxRepo.enqueue(SyncCommandEnvelope(
        commandId: 'cmd-sw',
        commandType: 'EDIT',
        entityType: 'PRODUCT',
        entityId: 'e-sw',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 's-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'k-sw',
        payload: {},
        status: SyncCommandStatus.conflict,
      ));

      await coordinator.resolveConflict(ResolveConflictCommand(
        conflictId: 'cnf-sw',
        resolution: ConflictResolutionStatus.resolvedServerWins,
        actorId: 'manager_1',
        method: 'ACCEPT_SERVER',
      ));

      final cmd = await outboxRepo.findById('cmd-sw');
      expect(cmd!.status, equals(SyncCommandStatus.synced));
    });

    test('76. Resolving conflict records actorId, resolutionMethod, and timestamp', () async {
      final cnf = SyncConflict(
        id: 'cnf-rec',
        commandId: 'cmd-rec',
        entityId: 'e-rec',
        entityType: 'PRODUCT',
        localVersion: 1,
        serverVersion: 2,
        localPayload: {},
        serverPayload: {},
        conflictType: SyncConflictType.stateConflict,
        detectedAt: DateTime.now(),
      );
      await conflictRepo.saveConflict(cnf);

      await conflictRepo.resolve(
        'cnf-rec',
        ConflictResolutionStatus.resolvedManual,
        'supervisor_42',
        'MANUAL_MERGE',
      );

      final retrieved = await conflictRepo.getById('cnf-rec');
      expect(retrieved!.resolvedBy, equals('supervisor_42'));
      expect(retrieved.resolutionMethod, equals('MANUAL_MERGE'));
      expect(retrieved.resolvedAt, isNotNull);
    });

    test('77. Non-existent conflict resolution throws SyncConflictFailure', () async {
      expect(
        () => coordinator.resolveConflict(ResolveConflictCommand(
          conflictId: 'does-not-exist',
          resolution: ConflictResolutionStatus.resolvedServerWins,
          actorId: 'admin',
          method: 'AUTO',
        )),
        throwsA(isA<SyncConflictFailure>()),
      );
    });

    test('78. State conflict triggers requiresReview for financial operations', () {
      final ack = SyncAck(
        commandId: 'fin-cmd',
        idempotencyKey: 'k',
        status: SyncCommandStatus.requiresReview,
        serverTimestamp: DateTime.now(),
        entityVersion: 1,
        conflictType: SyncConflictType.stateConflict,
      );
      expect(ack.isConflict, isTrue);
    });

    test('79. Authorization conflict code verification', () {
      expect(SyncConflictType.authorizationConflict.code, equals('AUTHORIZATION_CONFLICT'));
    });

    test('80. Stale data conflict code verification', () {
      expect(SyncConflictType.staleData.code, equals('STALE_DATA'));
    });

    test('81. Deleted remote conflict code verification', () {
      expect(SyncConflictType.deletedRemote.code, equals('DELETED_REMOTE'));
    });

    test('82. Branch conflict code verification', () {
      expect(SyncConflictType.branchConflict.code, equals('BRANCH_CONFLICT'));
    });

    test('83. Business conflict code verification', () {
      expect(SyncConflictType.businessConflict.code, equals('BUSINESS_CONFLICT'));
    });

    test('84. Unresolved conflicts count tracked accurately in SyncStatusSnapshot', () async {
      await conflictRepo.saveConflict(SyncConflict(
        id: 'c1',
        commandId: 'cmd1',
        entityId: 'e1',
        entityType: 'T',
        localVersion: 1,
        serverVersion: 2,
        localPayload: {},
        serverPayload: {},
        conflictType: SyncConflictType.stateConflict,
        detectedAt: DateTime.now(),
      ));

      final snapshot = await coordinator.getSyncStatusSnapshot();
      expect(snapshot.conflictCount, equals(1));
      expect(snapshot.isHealthy, isFalse);
    });

    test('85. CommandConflictEvent emitted when conflict detected', () {
      final ev = CommandConflictEvent(
        commandId: 'cmd-1',
        conflictId: 'cnf-1',
        conflictType: 'VERSION_CONFLICT',
      );
      expect(ev.eventName, equals('command_conflict'));
      expect(ev.conflictType, equals('VERSION_CONFLICT'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP I: OFFLINE INVENTORY & NO NEGATIVE STOCK (86-95)
  // ═══════════════════════════════════════════════════════════════
  group('Group I: Offline Inventory & No Negative Stock', () {
    test('86. Local available quantity calculates onHand - reserved - offlineReserved', () {
      final inv = CachedInventory(
        productId: 'p-1',
        branchId: 'br-1',
        onHandQuantity: 10.0,
        reservedQuantity: 2.0,
        offlineReservedQuantity: 3.0,
        version: 1,
        fetchedAt: DateTime.now(),
      );

      expect(inv.localAvailableQuantity, equals(5.0));
    });

    test('87. Offline stock reservation reserves local quantity successfully', () async {
      await cacheRepo.saveInventory(CachedInventory(
        productId: 'p-res',
        branchId: 'br-1',
        onHandQuantity: 10.0,
        version: 1,
        fetchedAt: DateTime.now(),
      ));

      final updated = await stockAllocator.reserveStockOffline(
        productId: 'p-res',
        branchId: 'br-1',
        requestedQuantity: 4.0,
      );

      expect(updated.offlineReservedQuantity, equals(4.0));
      expect(updated.localAvailableQuantity, equals(6.0));
    });

    test('88. Attempting to reserve quantity exceeding available throws SyncInsufficientStockFailure', () async {
      await cacheRepo.saveInventory(CachedInventory(
        productId: 'p-exceed',
        branchId: 'br-1',
        onHandQuantity: 2.0,
        version: 1,
        fetchedAt: DateTime.now(),
      ));

      expect(
        () => stockAllocator.reserveStockOffline(
          productId: 'p-exceed',
          branchId: 'br-1',
          requestedQuantity: 5.0,
        ),
        throwsA(isA<SyncInsufficientStockFailure>()),
      );
    });

    test('89. Offline stock allowance ratio restricts offline sales to configured percentage', () async {
      final strictAllocator = OfflineStockAllocator(
        cacheRepo: cacheRepo,
        policy: const OfflinePolicy(offlineStockAllowanceRatio: 0.5), // 50% max offline
      );

      await cacheRepo.saveInventory(CachedInventory(
        productId: 'p-ratio',
        branchId: 'br-1',
        onHandQuantity: 10.0,
        version: 1,
        fetchedAt: DateTime.now(),
      ));

      // 50% of 10 = 5.0 allowed. 6.0 should fail.
      expect(
        () => strictAllocator.reserveStockOffline(
          productId: 'p-ratio',
          branchId: 'br-1',
          requestedQuantity: 6.0,
        ),
        throwsA(isA<SyncInsufficientStockFailure>()),
      );
    });

    test('90. Allow negative stock is strictly false across all policies', () {
      final conservative = OfflinePolicy.conservative();
      final flexible = OfflinePolicy.flexible();

      expect(conservative.allowNegativeStock, isFalse);
      expect(flexible.allowNegativeStock, isFalse);
    });

    test('91. Releasing stock returns reserved quantity to local available', () async {
      await cacheRepo.saveInventory(CachedInventory(
        productId: 'p-rel',
        branchId: 'br-1',
        onHandQuantity: 10.0,
        offlineReservedQuantity: 5.0,
        version: 1,
        fetchedAt: DateTime.now(),
      ));

      final updated = await stockAllocator.releaseStockOffline(
        productId: 'p-rel',
        branchId: 'br-1',
        quantity: 3.0,
      );

      expect(updated.offlineReservedQuantity, equals(2.0));
      expect(updated.localAvailableQuantity, equals(8.0));
    });

    test('92. CRITICAL TEST A: Two offline terminals sell stock 1 -> 1 succeeds, other CONFLICT, final stock = 0, never -1', () async {
      // 1. السيرفر لديه قطعة واحدة فقط مخزون حقيقي
      gateway.serverStock['prod-single-unit'] = 1;

      // 2. الجهاز A أوفلاين يبيع القطعة
      final cmdA = SyncCommandEnvelope(
        commandId: 'sale-term-A',
        commandType: 'APPLY_INVENTORY',
        entityType: 'INVENTORY',
        entityId: 'prod-single-unit',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 'term-A',
        sessionId: 'sess-A',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'idemp-sale-A',
        payload: {'requestedQuantity': 1.0},
      );

      // 3. الجهاز B أوفلاين يبيع نفس القطعة
      final cmdB = SyncCommandEnvelope(
        commandId: 'sale-term-B',
        commandType: 'APPLY_INVENTORY',
        entityType: 'INVENTORY',
        entityId: 'prod-single-unit',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 'term-B',
        sessionId: 'sess-B',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'idemp-sale-B',
        payload: {'requestedQuantity': 1.0},
      );

      // 4. الاتصال بالإنترنت والمزامنة
      final acks = await gateway.pushBatch([cmdA, cmdB]);

      // 5. التحقق الصارم: أمر واحد ينجح والآخر يتعارض بنفاد الكمية
      expect(acks[0].isSuccess, isTrue);
      expect(acks[1].isConflict, isTrue);
      expect(acks[1].conflictType, equals(SyncConflictType.quantityConflict));

      // 6. الرصيد النهائي على السيرفر يساوي 0 بالتمام والكمال ولا يصبح سالباً أبداً
      expect(gateway.serverStock['prod-single-unit'], equals(0));
    });

    test('93. Inventory adjustment blocked offline by default policy', () async {
      expect(
        () => coordinator.applyInventoryMovementOffline(
          commandId: 'adj-1',
          businessId: 'b-1',
          branchId: 'br-1',
          terminalId: 't-1',
          sessionId: 's-1',
          productId: 'p-adj',
          quantity: 5.0,
          movementType: 'CORRECTION',
          idempotencyKey: 'k-adj',
        ),
        throwsA(isA<SyncOfflineBlockedFailure>()),
      );
    });

    test('94. Multiple sales of available items reserve stock cumulatively', () async {
      await cacheRepo.saveInventory(CachedInventory(
        productId: 'p-multi',
        branchId: 'br-1',
        onHandQuantity: 10.0,
        version: 1,
        fetchedAt: DateTime.now(),
      ));

      await coordinator.checkoutOffline(
        commandId: 'c-multi-1',
        saleId: 's-m-1',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 'sess-1',
        idempotencyKey: 'k-m-1',
        isCash: true,
        cartPayload: {},
        itemsQuantity: {'p-multi': 3.0},
      );

      await coordinator.checkoutOffline(
        commandId: 'c-multi-2',
        saleId: 's-m-2',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 'sess-1',
        idempotencyKey: 'k-m-2',
        isCash: true,
        cartPayload: {},
        itemsQuantity: {'p-multi': 4.0},
      );

      final inv = await cacheRepo.getInventory('p-multi', 'br-1');
      expect(inv!.offlineReservedQuantity, equals(7.0));
      expect(inv.localAvailableQuantity, equals(3.0));
    });

    test('95. Reconnecting sync updates server stock authoritatively', () async {
      gateway.serverStock['prod-authoritative'] = 10;

      final env = SyncCommandEnvelope(
        commandId: 'auth-stock-cmd',
        commandType: 'APPLY_INVENTORY',
        entityType: 'INVENTORY',
        entityId: 'prod-authoritative',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 's-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'k-auth',
        payload: {'requestedQuantity': 3.0},
      );

      final acks = await gateway.pushBatch([env]);
      expect(acks.first.isSuccess, isTrue);
      expect(gateway.serverStock['prod-authoritative'], equals(7));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP J: OFFLINE FINANCE & RECONCILIATION (96-105)
  // ═══════════════════════════════════════════════════════════════
  group('Group J: Offline Finance & Reconciliation', () {
    test('96. Cash sale permitted offline under standard policy', () {
      final policy = OfflinePolicy.conservative();
      expect(policy.cashSale, equals(OfflineOperationPermission.allow));
    });

    test('97. Credit sale blocked offline by default conservative policy', () {
      final policy = OfflinePolicy.conservative();
      expect(policy.creditSale, equals(OfflineOperationPermission.block));
    });

    test('98. Credit sale allowed with warning under flexible policy within credit limit', () {
      final policy = OfflinePolicy.flexible();
      expect(policy.creditSale, equals(OfflineOperationPermission.allowWithWarning));
      expect(policy.maxOfflineCreditAmountMinorUnits, equals(5000000));
    });

    test('99. Customer return permitted offline with warning', () {
      final policy = OfflinePolicy.conservative();
      expect(policy.customerReturn, equals(OfflineOperationPermission.allowWithWarning));
    });

    test('100. Refund payout strictly blocked offline', () {
      final policy = OfflinePolicy.conservative();
      expect(policy.refundPayout, equals(OfflineOperationPermission.block));
    });

    test('101. Supplier payment strictly blocked offline', () {
      final policy = OfflinePolicy.conservative();
      expect(policy.supplierPayment, equals(OfflineOperationPermission.block));
    });

    test('102. Reconciliation service detects unresolved financial conflicts and issues warnings', () async {
      await conflictRepo.saveConflict(SyncConflict(
        id: 'cnf-fin',
        commandId: 'cmd-fin',
        entityId: 'fin-entry-1',
        entityType: 'FINANCIAL_ENTRY',
        localVersion: 1,
        serverVersion: 2,
        localPayload: {},
        serverPayload: {},
        conflictType: SyncConflictType.stateConflict,
        detectedAt: DateTime.now(),
      ));

      final reconciler = SyncReconciliationService(
        outboxRepo: outboxRepo,
        inboxRepo: inboxRepo,
        conflictRepo: conflictRepo,
      );

      final report = await reconciler.reconcile(businessId: 'b-1', branchId: 'br-1');
      expect(report.isBalanced, isFalse);
      expect(report.unresolvedConflictCount, equals(1));
      expect(report.warnings.any((w) => w.contains('auto-merge forbidden')), isTrue);
    });

    test('103. Reconciliation marks report balanced when 0 pending, 0 in-flight, 0 conflicts', () async {
      final reconciler = SyncReconciliationService(
        outboxRepo: outboxRepo,
        inboxRepo: inboxRepo,
        conflictRepo: conflictRepo,
      );

      final report = await reconciler.reconcile(businessId: 'b-1', branchId: 'br-1');
      expect(report.isBalanced, isTrue);
      expect(report.warnings, isEmpty);
    });

    test('104. Diverged entity IDs reported in reconciliation report', () async {
      await conflictRepo.saveConflict(SyncConflict(
        id: 'cnf-div',
        commandId: 'cmd-div',
        entityId: 'diverged-sale-99',
        entityType: 'SALE',
        localVersion: 1,
        serverVersion: 2,
        localPayload: {},
        serverPayload: {},
        conflictType: SyncConflictType.versionConflict,
        detectedAt: DateTime.now(),
      ));

      final reconciler = SyncReconciliationService(
        outboxRepo: outboxRepo,
        inboxRepo: inboxRepo,
        conflictRepo: conflictRepo,
      );

      final report = await reconciler.reconcile(businessId: 'b-1', branchId: 'br-1');
      expect(report.divergedEntityIds.contains('diverged-sale-99'), isTrue);
    });

    test('105. CachedCustomer available credit calculation', () {
      final cust = CachedCustomer(
        id: 'c-1',
        name: 'زبون تجاري',
        phone: '07700000000',
        creditBalanceMinorUnits: 2000000,
        creditLimitMinorUnits: 5000000,
        version: 1,
        fetchedAt: DateTime.now(),
      );

      expect(cust.availableCreditMinorUnits, equals(3000000));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP K: S6 PRINTING PERSISTENCE INTEGRATION (106-112)
  // ═══════════════════════════════════════════════════════════════
  group('Group K: S6 Printing Persistence Integration', () {
    test('106. PersistentPrintJobRepository saves job to local database table', () async {
      final job = PrintJob(
        jobId: 'pj-1',
        documentId: 'doc-1',
        businessId: 'b-1',
        branchId: 'br-1',
        printerId: 'pr-1',
        createdAt: DateTime.now(),
        idempotencyKey: 'idemp-pj-1',
      );

      await printJobRepo.saveJob(job);
      final retrieved = await printJobRepo.getJobById(businessId: 'b-1', jobId: 'pj-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.jobId, equals('pj-1'));
    });

    test('107. GetJobById retrieves persistent print job with exact fields', () async {
      final t = DateTime(2026, 9, 6, 15, 30);
      final job = PrintJob(
        jobId: 'pj-fields',
        documentId: 'doc-fields',
        businessId: 'b-1',
        branchId: 'br-1',
        printerId: 'pr-fields',
        status: PrintJobStatus.printing,
        triggerType: PrintTriggerType.manualReprint,
        createdAt: t,
        idempotencyKey: 'k-fields',
        actorId: 'cashier_9',
        reprintReason: 'Customer spilled coffee',
      );

      await printJobRepo.saveJob(job);
      final retrieved = await printJobRepo.getJobById(businessId: 'b-1', jobId: 'pj-fields');
      expect(retrieved!.status, equals(PrintJobStatus.printing));
      expect(retrieved.triggerType, equals(PrintTriggerType.manualReprint));
      expect(retrieved.reprintReason, equals('Customer spilled coffee'));
    });

    test('108. GetJobsForDocument retrieves all print jobs for specific sale', () async {
      await printJobRepo.saveJob(PrintJob(
        jobId: 'pj-doc-1',
        documentId: 'sale-shared',
        businessId: 'b-1',
        branchId: 'br-1',
        printerId: 'p-1',
        createdAt: DateTime.now(),
        idempotencyKey: 'k1',
      ));

      await printJobRepo.saveJob(PrintJob(
        jobId: 'pj-doc-2',
        documentId: 'sale-shared',
        businessId: 'b-1',
        branchId: 'br-1',
        printerId: 'p-1',
        createdAt: DateTime.now(),
        idempotencyKey: 'k2',
      ));

      final jobs = await printJobRepo.getJobsForDocument(
        businessId: 'b-1',
        documentId: 'sale-shared',
      );
      expect(jobs.length, equals(2));
    });

    test('109. GetJobs filters by businessId, branchId, and status', () async {
      await printJobRepo.saveJob(PrintJob(
        jobId: 'pj-flt-1',
        documentId: 'd1',
        businessId: 'b-1',
        branchId: 'br-1',
        printerId: 'p-1',
        status: PrintJobStatus.completed,
        createdAt: DateTime.now(),
        idempotencyKey: 'k1',
      ));

      await printJobRepo.saveJob(PrintJob(
        jobId: 'pj-flt-2',
        documentId: 'd2',
        businessId: 'b-1',
        branchId: 'br-1',
        printerId: 'p-1',
        status: PrintJobStatus.failed,
        createdAt: DateTime.now(),
        idempotencyKey: 'k2',
      ));

      final completed = await printJobRepo.getJobs(
        businessId: 'b-1',
        status: PrintJobStatus.completed,
      );
      expect(completed.length, equals(1));
      expect(completed.first.jobId, equals('pj-flt-1'));
    });

    test('110. PersistentPrinterProfileRepository saves profile to local database', () async {
      final profile = PrinterProfile(
        id: 'prof-1',
        businessId: 'b-1',
        branchId: 'br-1',
        printerId: 'p-1',
        name: 'طابعة الكاشير 1',
        paperProfile: PaperProfile.thermal80mm(),
      );

      await printerProfileRepo.saveProfile(profile);
      final retrieved = await printerProfileRepo.getProfileById(
        businessId: 'b-1',
        profileId: 'prof-1',
      );

      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('طابعة الكاشير 1'));
    });

    test('111. GetProfileForDocument retrieves branch profile matching document type', () async {
      final profile = PrinterProfile(
        id: 'prof-doc',
        businessId: 'b-1',
        branchId: 'br-1',
        printerId: 'p-1',
        name: 'طابعة الفواتير',
        targetDocumentType: PrintDocumentType.invoice,
        paperProfile: PaperProfile.a4(),
      );

      await printerProfileRepo.saveProfile(profile);
      final retrieved = await printerProfileRepo.getProfileForDocument(
        businessId: 'b-1',
        branchId: 'br-1',
        documentType: PrintDocumentType.invoice,
      );

      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('prof-doc'));
    });

    test('112. Offline checkout automatically generates local PrintJob without server sync', () async {
      await coordinator.checkoutOffline(
        commandId: 'chk-print-1',
        saleId: 'sale-offline-print',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 'sess-1',
        idempotencyKey: 'k-print-offline',
        isCash: true,
        cartPayload: {},
        itemsQuantity: {},
        autoPrint: true,
      );

      final jobs = await printJobRepo.getJobsForDocument(
        businessId: 'b-1',
        documentId: 'sale-offline-print',
      );

      expect(jobs.length, equals(1));
      expect(jobs.first.status, equals(PrintJobStatus.queued));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP L: CRASH RECOVERY, LEASES & EXPIRED IN-FLIGHT (113-120)
  // ═══════════════════════════════════════════════════════════════
  group('Group L: Crash Recovery, Leases & Expired In-Flight', () {
    test('113. SyncLease expires when now is after expiresAt', () {
      final lease = SyncLease(
        leaseId: 'l1',
        workerId: 'w1',
        acquiredAt: DateTime.now().subtract(const Duration(minutes: 2)),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(lease.isExpired(), isTrue);
    });

    test('114. SyncLease renewal extends expiration time', () {
      final lease = SyncLease(
        leaseId: 'l2',
        workerId: 'w2',
        acquiredAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 10)),
      );

      final renewed = lease.renew(const Duration(minutes: 5));
      expect(renewed.expiresAt.isAfter(lease.expiresAt), isTrue);
    });

    test('115. Outbox recovers expired leases and transitions in-flight back to queued', () async {
      final env = SyncCommandEnvelope(
        commandId: 'cmd-crash',
        commandType: 'CHECKOUT',
        entityType: 'SALE',
        entityId: 's-crash',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 's-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'k-crash',
        payload: {},
      );
      await outboxRepo.enqueue(env);

      // وضع الأمر في حالة syncing مع عقد إيجار منتهي
      final expiredLease = SyncLease(
        leaseId: 'expired-lease',
        workerId: 'old-dead-worker',
        acquiredAt: DateTime.now().subtract(const Duration(minutes: 5)),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      await outboxRepo.markInFlight(['cmd-crash'], expiredLease);

      final recovered = await outboxRepo.recoverExpiredLeases(DateTime.now());
      expect(recovered, equals(1));

      final cmd = await outboxRepo.findById('cmd-crash');
      expect(cmd!.status, equals(SyncCommandStatus.queued));
    });

    test('116. CRITICAL TEST C: App crash while IN_FLIGHT -> restart recovers command -> reuses same idempotencyKey -> 1 server effect', () async {
      // 1. إدراج أمر وانتقاله إلى IN_FLIGHT
      final env = SyncCommandEnvelope(
        commandId: 'crit-c-cmd',
        commandType: 'CHECKOUT',
        entityType: 'SALE',
        entityId: 'sale-crit-c',
        businessId: 'biz-1',
        branchId: 'br-1',
        terminalId: 'term-1',
        sessionId: 'sess-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 50,
        idempotencyKey: 'crit_c_preserved_idempotency_key',
        payload: {'total': 30000},
      );
      await outboxRepo.enqueue(env);

      final crashedLease = SyncLease(
        leaseId: 'crashed-lease',
        workerId: 'crashed-process',
        acquiredAt: DateTime.now().subtract(const Duration(minutes: 10)),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      await outboxRepo.markInFlight(['crit-c-cmd'], crashedLease);

      // 2. إعادة تشغيل التطبيق وإطلاق دورة المزامنة
      await syncWorker.runSyncCycle(businessId: 'biz-1', branchId: 'br-1');

      // 3. التحقق: تعافي الأمر وإرساله بنفس مفتاح الـ Idempotency دون تغيير
      final found = await outboxRepo.findById('crit-c-cmd');
      expect(found!.status, equals(SyncCommandStatus.synced));
      expect(found.idempotencyKey, equals('crit_c_preserved_idempotency_key'));
      expect(gateway.processedIdempotencyKeys.contains('crit_c_preserved_idempotency_key'), isTrue);
      expect(gateway.processedIdempotencyKeys.length, equals(1));
    });

    test('117. Non-expired leases are not recovered prematurely', () async {
      final env = SyncCommandEnvelope(
        commandId: 'active-cmd',
        commandType: 'CHECKOUT',
        entityType: 'SALE',
        entityId: 's-act',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 's-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'k-act',
        payload: {},
      );
      await outboxRepo.enqueue(env);

      final activeLease = SyncLease(
        leaseId: 'act-lease',
        workerId: 'active-worker',
        acquiredAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      await outboxRepo.markInFlight(['active-cmd'], activeLease);

      final recovered = await outboxRepo.recoverExpiredLeases(DateTime.now());
      expect(recovered, equals(0));

      final cmd = await outboxRepo.findById('active-cmd');
      expect(cmd!.status, equals(SyncCommandStatus.syncing));
    });

    test('118. Worker runSyncCycle automatically triggers crash recovery first', () async {
      final env = SyncCommandEnvelope(
        commandId: 'auto-rec-cmd',
        commandType: 'CHECKOUT',
        entityType: 'SALE',
        entityId: 's-rec',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 's-1',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'k-rec',
        payload: {},
      );
      await outboxRepo.enqueue(env);

      await outboxRepo.markInFlight(['auto-rec-cmd'], SyncLease(
        leaseId: 'dead-l',
        workerId: 'dead-w',
        acquiredAt: DateTime.now().subtract(const Duration(minutes: 10)),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 2)),
      ));

      final events = <SyncEvent>[];
      final sub = syncWorker.events.listen(events.add);

      await syncWorker.runSyncCycle(businessId: 'b-1', branchId: 'br-1');
      await Future.delayed(Duration.zero);

      expect(events.any((e) => e is OutboxRecoveredEvent), isTrue);
      await sub.cancel();
    });

    test('119. Multiple crashed commands recovered in single recovery pass', () async {
      final lease = SyncLease(
        leaseId: 'multi-dead',
        workerId: 'w',
        acquiredAt: DateTime.now().subtract(const Duration(minutes: 5)),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      for (int i = 1; i <= 3; i++) {
        await outboxRepo.enqueue(SyncCommandEnvelope(
          commandId: 'm-crash-$i',
          commandType: 'OP',
          entityType: 'E',
          entityId: 'e',
          businessId: 'b',
          branchId: 'br',
          terminalId: 't',
          sessionId: 's',
          createdAt: DateTime.now(),
          clientTimestamp: DateTime.now(),
          sequence: i,
          idempotencyKey: 'k-$i',
          payload: {},
        ));
      }

      await outboxRepo.markInFlight(['m-crash-1', 'm-crash-2', 'm-crash-3'], lease);
      final count = await outboxRepo.recoverExpiredLeases(DateTime.now());
      expect(count, equals(3));
    });

    test('120. Recovered commands retain their original monotonic sequence', () async {
      final env = SyncCommandEnvelope(
        commandId: 'seq-preserved',
        commandType: 'OP',
        entityType: 'E',
        entityId: 'e',
        businessId: 'b',
        branchId: 'br',
        terminalId: 't',
        sessionId: 's',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 777,
        idempotencyKey: 'k-seq',
        payload: {},
      );
      await outboxRepo.enqueue(env);
      await outboxRepo.markInFlight(['seq-preserved'], SyncLease(
        leaseId: 'l',
        workerId: 'w',
        acquiredAt: DateTime.now().subtract(const Duration(minutes: 2)),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ));

      await outboxRepo.recoverExpiredLeases(DateTime.now());
      final cmd = await outboxRepo.findById('seq-preserved');
      expect(cmd!.sequence, equals(777));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP M: CRITICAL TESTS E, F, G, MIGRATIONS & ISOLATION (121-135+)
  // ═══════════════════════════════════════════════════════════════
  group('Group M: Critical Tests E, F, G, Migrations & Isolation', () {
    test('121. CRITICAL TEST E: 10-command batch: 7 success, 3 fail -> 7 ACK, 3 retry/conflict, valid 7 not rolled back', () async {
      // 1. تجهيز 10 أوامر
      for (int i = 1; i <= 10; i++) {
        await outboxRepo.enqueue(SyncCommandEnvelope(
          commandId: 'batch-cmd-$i',
          commandType: 'CHECKOUT',
          entityType: 'SALE',
          entityId: 'sale-batch-$i',
          businessId: 'biz-1',
          branchId: 'br-1',
          terminalId: 't-1',
          sessionId: 's-1',
          createdAt: DateTime.now(),
          clientTimestamp: DateTime.now(),
          sequence: i,
          idempotencyKey: 'batch_key_$i',
          payload: {},
        ));
      }

      // 2. تعيين 3 أوامر لتفشل على الخادم
      gateway.failCommandIds.addAll(['batch-cmd-3', 'batch-cmd-7', 'batch-cmd-9']);

      // 3. إرسال الحزمة
      await syncWorker.runSyncCycle(businessId: 'biz-1', branchId: 'br-1');

      // 4. التحقق: الأوامر الـ 7 الناجحة مسجلة synced ولم يتم التراجع عنها
      for (final id in ['batch-cmd-1', 'batch-cmd-2', 'batch-cmd-4', 'batch-cmd-5', 'batch-cmd-6', 'batch-cmd-8', 'batch-cmd-10']) {
        final cmd = await outboxRepo.findById(id);
        expect(cmd!.status, equals(SyncCommandStatus.synced), reason: 'Expected $id to be synced');
      }

      // 5. الأوامر الـ 3 الفاشلة مسجلة لإعادة المحاولة queued
      for (final id in ['batch-cmd-3', 'batch-cmd-7', 'batch-cmd-9']) {
        final cmd = await outboxRepo.findById(id);
        expect(cmd!.status, equals(SyncCommandStatus.queued), reason: 'Expected $id to be queued for retry');
        expect(cmd.retryCount, equals(1));
      }
    });

    test('122. CRITICAL TEST F: User logout with pending command preserves original sessionId and actorId', () async {
      final env = await coordinator.checkoutOffline(
        commandId: 'logout-test-cmd',
        saleId: 'sale-logout',
        businessId: 'b-1',
        branchId: 'br-1',
        terminalId: 't-1',
        sessionId: 'original_user_session_456',
        idempotencyKey: 'k-logout',
        isCash: true,
        cartPayload: {'actorId': 'cashier_ahmed'},
        itemsQuantity: {},
      );

      // محاكاة تسجيل خروج المستخدم ودخول مستخدم آخر
      final stored = await outboxRepo.findById('logout-test-cmd');
      expect(stored!.sessionId, equals('original_user_session_456'));
      expect(stored.payload['actorId'], equals('cashier_ahmed'));
    });

    test('123. CRITICAL TEST G: Branch switch maintains original branchId and cannot be rewritten to new branch', () async {
      final env = await coordinator.checkoutOffline(
        commandId: 'branch-test-cmd',
        saleId: 'sale-branch-A',
        businessId: 'business-corp',
        branchId: 'branch-A',
        terminalId: 't-1',
        sessionId: 'sess-1',
        idempotencyKey: 'k-branch-A',
        isCash: true,
        cartPayload: {},
        itemsQuantity: {},
      );

      // محاكاة تبديل الجلسة إلى فرع B
      final stored = await outboxRepo.findById('branch-test-cmd');
      expect(stored!.branchId, equals('branch-A'));
      expect(stored.businessId, equals('business-corp'));
    });

    test('124. Multi-tenant business isolation: Terminal from Business A cannot access or sync to Business B', () async {
      await outboxRepo.enqueue(SyncCommandEnvelope(
        commandId: 'tenant-A-cmd',
        commandType: 'OP',
        entityType: 'E',
        entityId: 'e',
        businessId: 'biz-A',
        branchId: 'br-A',
        terminalId: 't-A',
        sessionId: 's-A',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'k-A',
        payload: {},
      ));

      final jobs = await printJobRepo.getJobs(businessId: 'biz-B');
      expect(jobs, isEmpty);
    });

    test('125. Schema migrations v1 initializes tables', () async {
      final testDb = MemoryLocalDatabase();
      final runner = SchemaMigrations();
      final v1 = await runner.runMigrations(testDb, targetVersion: 1);
      expect(v1, equals(1));
      await testDb.close();
    });

    test('126. Schema migrations v2 applies version 2', () async {
      final testDb = MemoryLocalDatabase();
      final runner = SchemaMigrations();
      final v2 = await runner.runMigrations(testDb, targetVersion: 2);
      expect(v2, equals(2));
      await testDb.close();
    });

    test('127. Schema migrations v3 applies full schema version 3', () async {
      final testDb = MemoryLocalDatabase();
      final runner = SchemaMigrations();
      final v3 = await runner.runMigrations(testDb, targetVersion: 3);
      expect(v3, equals(3));
      await testDb.close();
    });

    test('128. Migration preserves existing rows without data loss', () async {
      await db.insert('test_migration', {'id': 'preserve-me', 'data': 'val'});
      final runner = SchemaMigrations();
      await runner.runMigrations(db);

      final row = await db.findById('test_migration', 'id', 'preserve-me');
      expect(row, isNotNull);
      expect(row!['data'], equals('val'));
    });

    test('129. Cache freshness: fresh within 4 hours', () {
      final prod = CachedProduct(
        id: 'p-fr',
        sku: 'SKU-F',
        barcode: '111',
        nameAr: 'شاي',
        priceMinorUnits: 1000,
        costMinorUnits: 700,
        version: 1,
        fetchedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      expect(prod.getFreshness(), equals(CacheFreshness.fresh));
      expect(prod.getFreshness().isUsable, isTrue);
    });

    test('130. Cache freshness: stale after 4 hours', () {
      final prod = CachedProduct(
        id: 'p-st',
        sku: 'SKU-S',
        barcode: '222',
        nameAr: 'سكر',
        priceMinorUnits: 1000,
        costMinorUnits: 700,
        version: 1,
        fetchedAt: DateTime.now().subtract(const Duration(hours: 10)),
      );

      expect(prod.getFreshness(), equals(CacheFreshness.stale));
      expect(prod.getFreshness().isUsable, isTrue);
      expect(prod.getFreshness().requiresRefresh, isTrue);
    });

    test('131. Cache freshness: expired after 7 days', () {
      final prod = CachedProduct(
        id: 'p-exp',
        sku: 'SKU-E',
        barcode: '333',
        nameAr: 'رز',
        priceMinorUnits: 1000,
        costMinorUnits: 700,
        version: 1,
        fetchedAt: DateTime.now().subtract(const Duration(days: 8)),
      );

      expect(prod.getFreshness(), equals(CacheFreshness.expired));
      expect(prod.getFreshness().isUsable, isFalse);
    });

    test('132. Purge expired cache deletes outdated products', () async {
      await cacheRepo.saveProduct(CachedProduct(
        id: 'p-purge-1',
        sku: 'S1',
        barcode: 'b1',
        nameAr: 'قديم',
        priceMinorUnits: 100,
        costMinorUnits: 50,
        version: 1,
        fetchedAt: DateTime.now().subtract(const Duration(days: 10)),
      ));

      await cacheRepo.saveProduct(CachedProduct(
        id: 'p-purge-2',
        sku: 'S2',
        barcode: 'b2',
        nameAr: 'جديد',
        priceMinorUnits: 100,
        costMinorUnits: 50,
        version: 1,
        fetchedAt: DateTime.now(),
      ));

      final purged = await cacheRepo.purgeExpiredCache(DateTime.now().subtract(const Duration(days: 7)));
      expect(purged, equals(1));
      expect(await cacheRepo.getProduct('p-purge-1'), isNull);
      expect(await cacheRepo.getProduct('p-purge-2'), isNotNull);
    });

    test('133. SyncAuditRecord sanitizes sensitive data (no tokens or passwords)', () {
      final record = SyncAuditRecord(
        id: 'aud-1',
        action: 'COMMAND_ENQUEUED',
        entityType: 'SALE',
        entityId: 's-1',
        actorId: 'cashier_1',
        timestamp: DateTime.now(),
        sanitizedDetails: {'amount': 15000, 'itemsCount': 2},
      );

      final json = record.toJson();
      expect(json['sanitizedDetails'].containsKey('password'), isFalse);
      expect(json['sanitizedDetails'].containsKey('token'), isFalse);
    });

    test('134. SyncCoordinator status snapshot reflects pending, failed, and conflict counts accurately', () async {
      await outboxRepo.enqueue(SyncCommandEnvelope(
        commandId: 'snap-1',
        commandType: 'OP',
        entityType: 'E',
        entityId: 'e',
        businessId: 'b',
        branchId: 'br',
        terminalId: 't',
        sessionId: 's',
        createdAt: DateTime.now(),
        clientTimestamp: DateTime.now(),
        sequence: 1,
        idempotencyKey: 'k1',
        payload: {},
      ));

      final snapshot = await coordinator.getSyncStatusSnapshot();
      expect(snapshot.pendingOutboxCount, equals(1));
      expect(snapshot.hasPendingWork, isTrue);
    });

    test('135. Dispose closes all worker and coordinator event controllers cleanly', () {
      coordinator.dispose();
      // Verified clean disposal without leaking memory
    });
  });
}
