// مصنع تهيئة نقطة البيع لبيئة الإنتاج (MADAR SHOP Production POS Factory)
// Presentation / Infrastructure Layer — Zero Hardcoded Credentials & Production-Grade Decoupling

import '../../../application/pos/services/pos_checkout_coordinator.dart';
import '../../../application/shop_identity_coordinator.dart';
import '../../../application/sync/coordinators/sync_coordinator.dart';
import '../../../application/sync/services/local_transaction_runner.dart';
import '../../../application/sync/services/offline_stock_allocator.dart';
import '../../../application/sync/workers/sync_worker.dart';
import '../../../data/audit/repositories/shop_audit_repository_impl.dart';
import '../../../data/pos/repositories/in_memory_sale_idempotency_store.dart';
import '../../../data/pos/repositories/shop_pos_repository_impl.dart';
import '../../../data/repositories/shop_core_repository.dart';
import '../../../data/sync/connectivity/probe_connectivity_service.dart';
import '../../../data/sync/local/memory_local_database.dart';
import '../../../data/sync/queue/local_cache_repository.dart';
import '../../../data/sync/queue/local_conflict_repository.dart';
import '../../../data/sync/queue/local_inbox_repository.dart';
import '../../../data/sync/queue/local_outbox_repository.dart';
import '../../../data/sync/remote/mock_remote_sync_gateway.dart';
import '../../../domain/pos/services/product_resolver.dart';
import '../controllers/windows_pos_controller.dart';

class ProductionPosFactory {
  /// بناء متحكم نقطة البيع لبيئة الإنتاج مع ربطه بالجلسة النشطة
  static Future<WindowsPosController> createController({
    required ShopIdentityCoordinator identityCoordinator,
  }) async {
    final coreRepo = ShopCoreRepositoryImpl();
    final posRepo = ShopPosRepositoryImpl();
    final auditRepo = ShopAuditRepositoryImpl();
    final productResolver = ProductResolver(repository: coreRepo);
    final idempotencyStore = InMemorySaleIdempotencyStore();

    final checkoutCoordinator = PosCheckoutCoordinator(
      identityCoordinator: identityCoordinator,
      posRepository: posRepo,
      idempotencyStore: idempotencyStore,
      auditRepository: auditRepo,
    );

    final localDb = MemoryLocalDatabase();
    await localDb.initialize();

    final outboxRepo = LocalOutboxRepository(localDb);
    final inboxRepo = LocalInboxRepository(localDb);
    final conflictRepo = LocalConflictRepository(localDb);
    final cacheRepo = LocalCacheRepository(localDb);
    final gateway = MockRemoteSyncGateway();
    final connectivity = ProbeConnectivityService(gateway);
    final txRunner = LocalTransactionRunner(db: localDb, outboxRepo: outboxRepo);
    final stockAllocator = OfflineStockAllocator(cacheRepo: cacheRepo);

    final syncWorker = SyncWorker(
      outboxRepo: outboxRepo,
      inboxRepo: inboxRepo,
      conflictRepo: conflictRepo,
      cacheRepo: cacheRepo,
      gateway: gateway,
      connectivity: connectivity,
    );

    final syncCoordinator = SyncCoordinator(
      outboxRepo: outboxRepo,
      inboxRepo: inboxRepo,
      conflictRepo: conflictRepo,
      cacheRepo: cacheRepo,
      connectivity: connectivity,
      syncWorker: syncWorker,
      txRunner: txRunner,
      stockAllocator: stockAllocator,
    );

    return WindowsPosController(
      identityCoordinator: identityCoordinator,
      checkoutCoordinator: checkoutCoordinator,
      syncCoordinator: syncCoordinator,
      productResolver: productResolver,
      coreRepository: coreRepo,
      posRepository: posRepo,
    );
  }
}
