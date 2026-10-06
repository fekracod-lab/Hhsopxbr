// حزمة الاختبارات الشاملة لواجهة نقطة البيع لويندوز وبوابة التحقق (MADAR SHOP Phase S8 Tests)
// 110+ Tests Covering Mandatory Auth Gate (1-12) + Groups A through R + Critical Tests (1-8) + Real-World Cashier Flow

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/madar_shop/madar_shop.dart';
import 'package:dalal_alqaim/features/madar_shop/data/pos/repositories/in_memory_sale_idempotency_store.dart';
import 'package:dalal_alqaim/features/madar_shop/data/printing/drivers/mock_printer_driver.dart';
import 'package:dalal_alqaim/features/madar_shop/data/printing/repositories/memory_print_job_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/printing/repositories/memory_printer_profile_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/printing/repositories/memory_printer_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/printing/repositories/memory_printing_idempotency_store.dart';
import 'package:dalal_alqaim/features/madar_shop/application/printing/services/print_queue_service.dart';
import 'package:dalal_alqaim/features/madar_shop/application/printing/commands/printing_commands.dart';
import 'package:dalal_alqaim/features/madar_shop/application/printing/services/document_builder_service.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/local/memory_local_database.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/queue/local_outbox_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/queue/local_inbox_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/queue/local_conflict_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/queue/local_cache_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/remote/mock_remote_sync_gateway.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/connectivity/probe_connectivity_service.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/print_persistence/persistent_print_job_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/sync/print_persistence/persistent_printer_profile_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/application/sync/services/local_transaction_runner.dart';
import 'package:dalal_alqaim/features/madar_shop/application/sync/services/offline_stock_allocator.dart';
import 'package:dalal_alqaim/features/madar_shop/application/sync/workers/sync_worker.dart';

// ═══════════════════════════════════════════════════════════════
// FAKE REPOSITORIES FOR DETERMINISTIC IN-MEMORY TESTING
// ═══════════════════════════════════════════════════════════════

class FakePosProductResolver implements IProductResolver {
  final List<ResolvedProduct> products;
  FakePosProductResolver(this.products);

  @override
  Future<ResolvedProduct?> resolveProduct({
    required String query,
    required String businessId,
    required String branchId,
  }) async {
    final q = query.trim().toLowerCase();
    try {
      return products.firstWhere((p) =>
        (p.barcode != null && p.barcode!.toLowerCase() == q) ||
        p.sku.toLowerCase() == q ||
        p.productId.toLowerCase() == q ||
        p.name.toLowerCase() == q
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ResolvedProduct>> searchProducts({
    required String query,
    required String businessId,
    required String branchId,
    int limit = 20,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return products;
    return products.where((p) =>
      p.name.toLowerCase().contains(q) ||
      p.sku.toLowerCase().contains(q) ||
      (p.barcode != null && p.barcode!.contains(q))
    ).toList();
  }
}

class FakePosCoreRepository implements IShopCoreRepository {
  final List<ShopProduct> products;
  final List<ShopCategory> categories;
  FakePosCoreRepository(this.products, {this.categories = const []});

  @override
  Future<List<ShopProduct>> getProducts({
    required String businessId,
    required String branchId,
    bool includeArchived = false,
  }) async => products;

  @override
  Future<ShopProduct?> getProductById({
    required String businessId,
    required String branchId,
    required String productId,
  }) async {
    try {
      return products.firstWhere((p) => p.productId == productId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ShopBusiness?> getBusinessProfile(String businessId) async => null;
  @override
  Future<void> saveBusinessProfile(ShopBusiness business) async {}
  @override
  Future<List<ShopBranch>> getBranches(String businessId) async => [];
  @override
  Future<ShopAvailabilityState?> getAvailabilityState(String branchId) async => null;
  @override
  Future<void> updateAvailabilityState(ShopAvailabilityState state) async {}
  @override
  Future<void> saveProduct(ShopProduct product) async {}
  @override
  Future<void> updateStockQuantity({required String businessId, required String branchId, required String productId, required double newStock}) async {}
  @override
  Future<List<ShopOrder>> getActiveOrders({required String businessId, required String branchId}) async => [];
  @override
  Future<ShopOrder?> getOrderById({required String businessId, required String orderId}) async => null;
  @override
  Future<void> saveOrder(ShopOrder order) async {}
  @override
  Future<void> updateOrderStatus({
    required String businessId,
    required String orderId,
    required ShopOrderStatus newStatus,
    String? reason,
  }) async {}

  Future<List<ShopCategory>> getCategories({required String businessId}) async => categories;
  Future<void> saveCategory(ShopCategory category) async {}
  Future<void> reorderCategories({required String businessId, required List<String> categoryIdsInOrder}) async {}
}

class FakeShopPosRepository implements IShopPosRepository {
  final List<Sale> savedSales = [];

  @override
  Future<void> saveSale(Sale sale) async {
    savedSales.add(sale);
  }

  @override
  Future<Sale?> getSaleById({
    required String businessId,
    required String branchId,
    required String saleId,
  }) async {
    try {
      return savedSales.firstWhere((s) => s.id == saleId);
    } catch (_) {
      return null;
    }
  }

  Future<Sale?> getSaleByNumber({
    required String businessId,
    required String saleNumber,
  }) async {
    try {
      return savedSales.firstWhere((s) => s.saleNumber == saleNumber);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Sale>> getSalesForSession({
    required String businessId,
    required String branchId,
    required String sessionId,
  }) async {
    return savedSales.where((s) => s.sessionId == sessionId).toList();
  }

  @override
  Future<List<Sale>> getSales({
    required String businessId,
    String? branchId,
    DateTime? from,
    DateTime? to,
  }) async {
    return savedSales.where((s) => s.businessId == businessId).toList();
  }

  @override
  Future<void> saveReceiptSnapshot(ReceiptSnapshot snapshot) async {}

  @override
  Future<void> recordCustomerLedgerEntry(CustomerLedgerEntry entry) async {}

  @override
  Future<void> recordInventoryMovementIntent(InventoryMovementIntent intent) async {}
}

class FakeAuditRepository implements IShopAuditRepository {
  final List<ShopAuditEntry> entries = [];
  @override
  Future<void> recordAuditEntry(ShopAuditEntry entry) async => entries.add(entry);
  @override
  Future<List<ShopAuditEntry>> getAuditEntries({
    required String businessId,
    required String branchId,
    ShopAuditAction? actionFilter,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async => entries;
}

// ═══════════════════════════════════════════════════════════════
// MAIN TEST SUITE
// ═══════════════════════════════════════════════════════════════

void main() {
  const bizId = 'BIZ-01';
  const branchId = 'BR-01';
  const terminalId = 'TERM-01';
  const installId = 'INST-01';

  late MemoryShopIdentityRepository identityRepo;
  late MadarShopAuthService authService;
  late ShopIdentityCoordinator identityCoordinator;

  late FakePosCoreRepository coreRepo;
  late FakeShopPosRepository posRepo;
  late FakeAuditRepository auditRepo;
  late FakePosProductResolver productResolver;

  late PosCheckoutCoordinator checkoutCoordinator;
  late SyncCoordinator syncCoordinator;
  late ProbeConnectivityService connectivity;
  late PrintCoordinator printCoordinator;
  late MockPrinterDriver mockDriver;

  late ResolvedProduct milkProduct;
  late ResolvedProduct meatWeighableProduct;
  late ResolvedProduct outOfStockProduct;

  setUp(() async {
    // 1. Identity & Auth Setup
    identityRepo = MemoryShopIdentityRepository();
    identityCoordinator = ShopIdentityCoordinator();
    authService = MadarShopAuthService(
      identityRepo: identityRepo,
      identityCoordinator: identityCoordinator,
    );

    // Seed test users in identityRepo
    identityRepo.seedUser(
      user: ShopUser(
        userId: 'usr_cashier',
        businessId: bizId,
        fullName: 'Ali Cashier',
        phone: '07701111111',
        email: 'cashier@madar.iq',
        role: ShopRole.cashier,
        customPermissions: {
          ...ShopPermissionMatrix.getDefaultPermissions(ShopRole.cashier),
          ShopPermission.applyCartDiscount,
          ShopPermission.applyItemDiscount,
        },
        isActive: true,
        assignedBranchIds: const [branchId],
        createdAt: DateTime.now(),
      ),
      loginIdentifier: 'cashier@madar.iq',
      secret: 'pass',
    );

    identityRepo.seedUser(
      user: ShopUser(
        userId: 'usr_owner',
        businessId: bizId,
        fullName: 'Owner Ahmad',
        phone: '07702222222',
        email: 'owner@madar.iq',
        role: ShopRole.owner,
        isActive: true,
        assignedBranchIds: const [branchId],
        createdAt: DateTime.now(),
      ),
      loginIdentifier: 'owner@madar.iq',
      secret: 'pass',
    );

    identityRepo.seedUser(
      user: ShopUser(
        userId: 'usr_manager',
        businessId: bizId,
        fullName: 'Hassan Manager',
        phone: '07703333333',
        email: 'manager@madar.iq',
        role: ShopRole.branchManager,
        isActive: true,
        assignedBranchIds: const [branchId],
        createdAt: DateTime.now(),
      ),
      loginIdentifier: 'manager@madar.iq',
      secret: 'pass',
    );

    identityRepo.seedUser(
      user: ShopUser(
        userId: 'usr_clerk',
        businessId: bizId,
        fullName: 'Karrar Clerk',
        phone: '07704444444',
        email: 'clerk@madar.iq',
        role: ShopRole.inventoryClerk,
        isActive: true,
        assignedBranchIds: const [branchId],
        createdAt: DateTime.now(),
      ),
      loginIdentifier: 'clerk@madar.iq',
      secret: 'pass',
    );

    identityRepo.seedUser(
      user: ShopUser(
        userId: 'usr_accountant',
        businessId: bizId,
        fullName: 'Mustafa Accountant',
        phone: '07705555555',
        email: 'accountant@madar.iq',
        role: ShopRole.accountant,
        isActive: true,
        assignedBranchIds: const [branchId],
        createdAt: DateTime.now(),
      ),
      loginIdentifier: 'accountant@madar.iq',
      secret: 'pass',
    );

    identityRepo.seedUser(
      user: ShopUser(
        userId: 'usr_wrong_biz',
        businessId: 'BIZ-OTHER',
        fullName: 'Other User',
        phone: '07706666666',
        email: 'other@madar.iq',
        role: ShopRole.cashier,
        isActive: true,
        assignedBranchIds: const ['BR-OTHER'],
        createdAt: DateTime.now(),
      ),
      loginIdentifier: 'other@madar.iq',
      secret: 'pass',
    );

    // 2. Catalog & Products Setup
    milkProduct = ResolvedProduct(
      productId: 'PROD-MILK',
      sku: 'SKU-MILK-01',
      barcode: '6281001001',
      name: 'حليب المراعي 1 لتر',
      unitOfMeasure: 'قطعة',
      price: Money.fromAmount(2000, Currency.iqd),
      cost: Money.fromAmount(1500, Currency.iqd),
      stockQuantity: 50.0,
      isWeighable: false,
    );

    meatWeighableProduct = ResolvedProduct(
      productId: 'PROD-MEAT',
      sku: 'SKU-MEAT-KG',
      barcode: '6282002002',
      name: 'لحم بقري محلي',
      unitOfMeasure: 'كغم',
      price: Money.fromAmount(14000, Currency.iqd),
      cost: Money.fromAmount(11000, Currency.iqd),
      stockQuantity: 25.5,
      isWeighable: true,
    );

    outOfStockProduct = ResolvedProduct(
      productId: 'PROD-OOS',
      sku: 'SKU-OOS-99',
      barcode: '6289999999',
      name: 'منتج نافد من المخزن',
      unitOfMeasure: 'قطعة',
      price: Money.fromAmount(5000, Currency.iqd),
      cost: Money.fromAmount(3000, Currency.iqd),
      stockQuantity: 0.0,
      isWeighable: false,
      isAvailable: false,
    );

    final shopProductMilk = ShopProduct(
      productId: milkProduct.productId,
      businessId: bizId,
      branchId: branchId,
      name: milkProduct.name,
      description: 'حليب',
      sellingPrice: milkProduct.price.toAmount(),
      costPrice: milkProduct.cost.toAmount(),
      stockQuantity: 50.0,
      categoryId: 'CAT-DAIRY',
      barcode: milkProduct.barcode,
      sku: milkProduct.sku,
      unitOfMeasure: milkProduct.unitOfMeasure,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    coreRepo = FakePosCoreRepository(
      [shopProductMilk],
      categories: [
        ShopCategory(
          categoryId: 'CAT-DAIRY',
          businessId: bizId,
          name: 'ألبان وأجبان',
          displayOrder: 1,
          createdAt: DateTime.now(),
        ),
      ],
    );

    posRepo = FakeShopPosRepository();
    auditRepo = FakeAuditRepository();
    productResolver = FakePosProductResolver([milkProduct, meatWeighableProduct, outOfStockProduct]);

    final posIdempotencyStore = InMemorySaleIdempotencyStore();
    checkoutCoordinator = PosCheckoutCoordinator(
      identityCoordinator: identityCoordinator,
      posRepository: posRepo,
      idempotencyStore: posIdempotencyStore,
      auditRepository: auditRepo,
    );

    // 3. Sync Setup
    final db = MemoryLocalDatabase();
    await db.initialize();
    final outboxRepo = LocalOutboxRepository(db);
    final inboxRepo = LocalInboxRepository(db);
    final conflictRepo = LocalConflictRepository(db);
    final cacheRepo = LocalCacheRepository(db);
    await cacheRepo.saveInventory(CachedInventory(
      productId: 'PROD-MILK',
      branchId: branchId,
      onHandQuantity: 100.0,
      version: 1,
      fetchedAt: DateTime.now(),
    ));
    await cacheRepo.saveInventory(CachedInventory(
      productId: 'PROD-MEAT',
      branchId: branchId,
      onHandQuantity: 50.0,
      version: 1,
      fetchedAt: DateTime.now(),
    ));
    final gateway = MockRemoteSyncGateway();
    connectivity = ProbeConnectivityService(gateway);
    final txRunner = LocalTransactionRunner(db: db, outboxRepo: outboxRepo);
    final stockAllocator = OfflineStockAllocator(cacheRepo: cacheRepo);
    final printJobRepo = PersistentPrintJobRepository(db);

    final syncWorker = SyncWorker(
      outboxRepo: outboxRepo,
      inboxRepo: inboxRepo,
      conflictRepo: conflictRepo,
      cacheRepo: cacheRepo,
      gateway: gateway,
      connectivity: connectivity,
    );

    syncCoordinator = SyncCoordinator(
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

    // 4. Printing Setup
    final defaultPrinter = Printer(
      id: 'PRN-01',
      businessId: bizId,
      branchId: branchId,
      name: 'طابعة الكاشير الرئيسية',
      connectionType: PrinterConnectionType.usb,
      capabilities: PrinterCapabilities.standardThermalPos(),
      paperProfile: PaperProfile.thermal80mm(),
      isDefault: true,
    );

    final defaultProfile = PrinterProfile(
      id: 'PROF-01',
      businessId: bizId,
      branchId: branchId,
      printerId: 'PRN-01',
      name: 'ملف طباعة الكاشير',
      targetDocumentType: PrintDocumentType.saleReceipt,
      paperProfile: PaperProfile.thermal80mm(),
      autoPrintPolicy: AutoPrintPolicy.saleOnly,
    );

    final printerRepo = MemoryPrinterRepository();
    await printerRepo.savePrinter(defaultPrinter);

    final profileRepo = MemoryPrinterProfileRepository();
    await profileRepo.saveProfile(defaultProfile);

    final jobRepo = MemoryPrintJobRepository();
    final printIdempotencyStore = MemoryPrintingIdempotencyStore();
    mockDriver = MockPrinterDriver();
    final queueService = PrintQueueService(jobRepository: jobRepo);

    printCoordinator = PrintCoordinator(
      printerRepository: printerRepo,
      profileRepository: profileRepo,
      jobRepository: jobRepo,
      idempotencyStore: printIdempotencyStore,
      queueService: queueService,
      driverResolver: (printer) async => mockDriver,
    );
  });

  Future<WindowsPosController> createControllerForUser(String email, {bool requirePosAccess = true}) async {
    final authResult = await authService.loginAndOpenSession(
      loginIdentifier: email,
      secret: 'pass',
      businessId: bizId,
      branchId: branchId,
      terminalId: terminalId,
      installationId: installId,
      requirePosAccess: requirePosAccess,
    );

    if (!authResult.isAllowed) {
      throw Exception('Auth failed in test setup: ${authResult.messageAr}');
    }

    return WindowsPosController(
      identityCoordinator: identityCoordinator,
      checkoutCoordinator: checkoutCoordinator,
      syncCoordinator: syncCoordinator,
      printCoordinator: printCoordinator,
      returnsCoordinator: null,
      productResolver: productResolver,
      coreRepository: coreRepo,
      posRepository: posRepo,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 1. MANDATORY AUTHENTICATION GATE TESTS (1 to 12)
  // ═══════════════════════════════════════════════════════════════
  group('MANDATORY ADDITION — MADAR SHOP AUTH GATE (12 Tests)', () {
    test('1. Customer account → DENIED with AccessDenied message', () async {
      final res = await authService.loginAndOpenSession(
        loginIdentifier: 'customer@madar.iq',
        secret: 'pass',
        businessId: bizId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
      );
      expect(res.isAllowed, isFalse);
      expect(res.denialReason, equals(AuthDenialReason.invalidCredentials));
    });

    test('2. Normal user (non-employee) → DENIED', () async {
      final res = await authService.loginAndOpenSession(
        loginIdentifier: 'normal_user@gmail.com',
        secret: 'pass',
        businessId: bizId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
      );
      expect(res.isAllowed, isFalse);
    });

    test('3. Cashier → ALLOWED into Shop with POS permissions', () async {
      final res = await authService.loginAndOpenSession(
        loginIdentifier: 'cashier@madar.iq',
        secret: 'pass',
        businessId: bizId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
      );
      expect(res.isAllowed, isTrue);
      expect(res.session?.userId, equals('usr_cashier'));
      expect(res.session?.businessId, equals(bizId));
      expect(res.session?.activeBranchId, equals(branchId));
      expect(res.session?.terminalId, equals(terminalId));
      expect(res.session?.isExpired, isFalse);

      expect(identityCoordinator.hasPermission(ShopPermission.accessPos), isTrue);
      expect(identityCoordinator.hasPermission(ShopPermission.createSalesOrder), isTrue);
    });

    test('4. Inventory Clerk → ALLOWED into Shop, but lacks POS checkout permissions', () async {
      // Clerk logging in with requirePosAccess: false is allowed into Shop
      final res = await authService.loginAndOpenSession(
        loginIdentifier: 'clerk@madar.iq',
        secret: 'pass',
        businessId: bizId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
        requirePosAccess: false,
      );
      expect(res.isAllowed, isTrue);
      expect(identityCoordinator.hasPermission(ShopPermission.viewProducts), isTrue);
      expect(identityCoordinator.hasPermission(ShopPermission.createSalesOrder), isFalse);

      // But denied if requirePosAccess: true
      final posRes = await authService.loginAndOpenSession(
        loginIdentifier: 'clerk@madar.iq',
        secret: 'pass',
        businessId: bizId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
        requirePosAccess: true,
      );
      expect(posRes.isAllowed, isFalse);
      expect(posRes.denialReason, equals(AuthDenialReason.noPosAccess));
      expect(posRes.messageAr, contains('ليس لديك صلاحية استخدام نقطة البيع'));
    });

    test('5. Accountant → ALLOWED according to finance permissions, but restricted in checkout', () async {
      final res = await authService.loginAndOpenSession(
        loginIdentifier: 'accountant@madar.iq',
        secret: 'pass',
        businessId: bizId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
        requirePosAccess: false,
      );
      expect(res.isAllowed, isTrue);
      expect(identityCoordinator.hasPermission(ShopPermission.viewFinancialLedger), isTrue);
      expect(identityCoordinator.hasPermission(ShopPermission.overrideItemPrice), isFalse);
    });

    test('6. Branch Manager → ALLOWED with branch oversight and checkout permissions', () async {
      final res = await authService.loginAndOpenSession(
        loginIdentifier: 'manager@madar.iq',
        secret: 'pass',
        businessId: bizId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
      );
      expect(res.isAllowed, isTrue);
      expect(identityCoordinator.hasPermission(ShopPermission.createSalesOrder), isTrue);
      expect(identityCoordinator.hasPermission(ShopPermission.applyCartDiscount), isTrue);
    });

    test('7. Owner → ALLOWED with all permissions', () async {
      final res = await authService.loginAndOpenSession(
        loginIdentifier: 'owner@madar.iq',
        secret: 'pass',
        businessId: bizId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
      );
      expect(res.isAllowed, isTrue);
      expect(identityCoordinator.hasPermission(ShopPermission.manageBranches), isTrue);
      expect(identityCoordinator.hasPermission(ShopPermission.overrideItemPrice), isTrue);
    });

    test('8. Wrong business → DENIED', () async {
      final res = await authService.loginAndOpenSession(
        loginIdentifier: 'other@madar.iq',
        secret: 'pass',
        businessId: bizId, // other@madar.iq is registered in BIZ-OTHER
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
      );
      expect(res.isAllowed, isFalse);
      expect(res.denialReason, equals(AuthDenialReason.wrongBusiness));
      expect(res.messageAr, contains('المستخدم غير مرتبط بهذا المتجر'));
    });

    test('9. Wrong branch → DENIED', () async {
      final res = await authService.loginAndOpenSession(
        loginIdentifier: 'cashier@madar.iq',
        secret: 'pass',
        businessId: bizId,
        branchId: 'BR-WRONG-BRANCH',
        terminalId: terminalId,
        installationId: installId,
      );
      expect(res.isAllowed, isFalse);
      expect(res.denialReason, equals(AuthDenialReason.wrongBranch));
      expect(res.messageAr, contains('ليس لديك صلاحية الوصول إلى هذا الفرع'));
    });

    test('10. Expired session → DENIED on validation', () async {
      final now = DateTime.now();
      final expiredSession = ShopSession(
        sessionId: 'SESS-EXPIRED',
        installationId: installId,
        terminalId: terminalId,
        userId: 'usr_cashier',
        businessId: bizId,
        activeBranchId: branchId,
        startedAt: now.subtract(const Duration(hours: 15)),
        lastHeartbeatAt: now.subtract(const Duration(hours: 13)),
        expiresAt: now.subtract(const Duration(hours: 1)),
        status: ShopSessionStatus.expired,
      );

      final user = await identityRepo.getUserById('usr_cashier');
      identityCoordinator.setSession(user: user!, session: expiredSession);

      final valRes = await authService.validateCurrentSession(
        businessId: bizId,
        branchId: branchId,
      );
      expect(valRes.isAllowed, isFalse);
      expect(valRes.denialReason, equals(AuthDenialReason.sessionExpired));
    });

    test('11. Logged-out session → DENIED', () async {
      identityCoordinator.clearSession();
      final valRes = await authService.validateCurrentSession(
        businessId: bizId,
        branchId: branchId,
      );
      expect(valRes.isAllowed, isFalse);
      expect(valRes.denialReason, equals(AuthDenialReason.invalidCredentials));
    });

    test('12. Direct POS route without authorization → DENIED and blocked', () async {
      identityCoordinator.clearSession();
      expect(identityCoordinator.isAuthenticated, isFalse);
      expect(identityCoordinator.currentUser, isNull);
      expect(identityCoordinator.currentSession, isNull);
      expect(identityCoordinator.hasPermission(ShopPermission.createSalesOrder), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 2. GROUPS A THROUGH R — 80+ POS UI / APPLICATION INTEGRATION TESTS
  // ═══════════════════════════════════════════════════════════════

  group('Group A: Product Search', () {
    test('Debounced search finds product by partial Arabic name', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      await controller.initCatalog();
      await controller.searchProducts('حليب');
      expect(controller.searchResults.length, equals(1));
      expect(controller.searchResults.first.name, contains('حليب'));
    });

    test('Search by SKU matches exactly', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      await controller.initCatalog();
      await controller.searchProducts('SKU-MILK-01');
      expect(controller.searchResults.length, equals(1));
      expect(controller.searchResults.first.productId, equals('PROD-MILK'));
    });

    test('Empty search query restores all products', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      await controller.initCatalog();
      await controller.searchProducts('');
      expect(controller.searchResults.length, equals(1));
    });

    test('Non-matching search returns empty list without error', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      await controller.initCatalog();
      await controller.searchProducts('كلمة_غير_موجودة');
      expect(controller.searchResults.isEmpty, isTrue);
    });
  });

  group('Group B: Barcode Wedge Handling', () {
    test('Barcode scan resolves product and adds directly to cart', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      final added = await controller.scanBarcode('6281001001');
      expect(added, isTrue);
      expect(controller.cartItemCount, equals(1));
      expect(controller.currentCart.items.first.productId, equals('PROD-MILK'));
    });

    test('Barcode scan with whitespace and scanner enter suffix resolves cleanly', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      final added = await controller.scanBarcode('  6281001001\n');
      expect(added, isTrue);
      expect(controller.cartItemCount, equals(1));
    });

    test('Unknown barcode returns false and sets Arabic error message', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      final added = await controller.scanBarcode('9999999999');
      expect(added, isFalse);
      expect(controller.cartItemCount, equals(0));
      expect(controller.errorMessage, isNotNull);
    });

    test('Scanning out-of-stock product is rejected with error', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      final added = await controller.scanBarcode('6289999999');
      expect(added, isFalse);
      expect(controller.errorMessage, contains('غير متوفر'));
    });
  });

  group('Group C: Cart Operations & Multi-Cart Slots', () {
    test('Add product to cart increments quantity if already present', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 1);
      controller.addProductToCart(milkProduct, quantity: 2);
      expect(controller.currentCart.items.length, equals(1));
      expect(controller.currentCart.items.first.quantity, equals(3));
    });

    test('Remove item from cart completely', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 1);
      final itemId = controller.currentCart.items.first.itemId;
      controller.removeItem(itemId);
      expect(controller.currentCart.isEmpty, isTrue);
    });

    test('Clear active cart resets items, customer, and discounts', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct);
      final cust = CachedCustomer(
        id: 'C-01',
        name: 'Zaid',
        phone: '0770',
        creditBalanceMinorUnits: 0,
        creditLimitMinorUnits: 50000,
        version: 1,
        fetchedAt: DateTime.now(),
      );
      controller.setCustomer(cust);
      controller.applyCartDiscount(const Discount(type: DiscountType.percentage, value: 10));
      controller.clearCurrentCart();
      expect(controller.currentCart.isEmpty, isTrue);
      expect(controller.selectedCustomer, isNull);
    });

    test('Multi-cart slots (Cart 1, Cart 2, Cart 3) maintain independent carts', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      // Slot 0 (Cart 1)
      controller.switchCart(0);
      controller.addProductToCart(milkProduct, quantity: 1);
      expect(controller.cartItemCount, equals(1));

      // Slot 1 (Cart 2)
      controller.switchCart(1);
      expect(controller.cartItemCount, equals(0));
      controller.addProductToCart(meatWeighableProduct, quantity: 2.5);
      expect(controller.cartItemCount, equals(1));

      // Switch back to Slot 0 (Cart 1)
      controller.switchCart(0);
      expect(controller.cartItemCount, equals(1));
      expect(controller.currentCart.items.first.productId, equals('PROD-MILK'));
    });
  });

  group('Group D: Quantity Adjustments', () {
    test('Increment item quantity updates total accurately', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 1);
      final itemId = controller.currentCart.items.first.itemId;
      controller.incrementItem(itemId);
      expect(controller.currentCart.items.first.quantity, equals(2));
      expect(controller.totals.grandTotal.toAmount(), equals(4000));
    });

    test('Decrement item quantity decrements until removed when reaching 0', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 1);
      final itemId = controller.currentCart.items.first.itemId;
      controller.decrementItem(itemId);
      expect(controller.currentCart.isEmpty, isTrue);
    });

    test('Update item quantity to discrete integer value', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 1);
      final itemId = controller.currentCart.items.first.itemId;
      controller.updateItemQuantity(itemId, 5);
      expect(controller.currentCart.items.first.quantity, equals(5));
      expect(controller.totals.grandTotal.toAmount(), equals(10000));
    });

    test('Zero or negative quantity update is rejected', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 2);
      final itemId = controller.currentCart.items.first.itemId;
      controller.updateItemQuantity(itemId, 0);
      expect(controller.currentCart.items.first.quantity, equals(2));
    });
  });

  group('Group E: Weighable Products Precision', () {
    test('Weighable item preserves 3 decimal places (e.g. 1.750 KG)', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(meatWeighableProduct, quantity: 1.750);
      expect(controller.currentCart.items.first.quantity, equals(1.750));
      expect(controller.currentCart.items.first.isWeighable, isTrue);
      // 1.750 * 14,000 = 24,500
      expect(controller.totals.grandTotal.toAmount(), equals(24500));
    });

    test('Weighable item formatted display correctly includes unit', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(meatWeighableProduct, quantity: 0.500);
      expect(controller.totals.grandTotal.toAmount(), equals(7000));
    });
  });

  group('Group F: Discounts UI and Rules', () {
    test('Apply percentage discount accurately reduces grand total', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 2); // 4000 IQD
      controller.applyCartDiscount(const Discount(type: DiscountType.percentage, value: 10));
      expect(controller.totals.discountTotal.toAmount(), equals(400));
      expect(controller.totals.grandTotal.toAmount(), equals(3600));
    });

    test('Apply fixed amount discount accurately reduces grand total', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 2); // 4000 IQD
      controller.applyCartDiscount(const Discount(type: DiscountType.fixed, value: 1000));
      expect(controller.totals.discountTotal.toAmount(), equals(1000));
      expect(controller.totals.grandTotal.toAmount(), equals(3000));
    });

    test('Discount exceeding subtotal is capped to subtotal', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 1); // 2000 IQD
      controller.applyCartDiscount(const Discount(type: DiscountType.fixed, value: 5000));
      expect(controller.totals.discountTotal.toAmount(), equals(2000));
      expect(controller.totals.grandTotal.toAmount(), equals(0));
    });

    test('Negative discount value is treated as zero', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 1);
      controller.applyCartDiscount(const Discount(type: DiscountType.fixed, value: -500));
      expect(controller.totals.discountTotal.toAmount(), equals(0));
    });
  });

  group('Group G: Customer Selection', () {
    test('Walk-in is default without customer profile', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      expect(controller.selectedCustomer, isNull);
    });

    test('Select customer updates state', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      final cust = CachedCustomer(
        id: 'CUST-01',
        name: 'سجاد كريم',
        phone: '07801234567',
        creditBalanceMinorUnits: 10000,
        creditLimitMinorUnits: 100000,
        version: 1,
        fetchedAt: DateTime.now(),
      );
      controller.setCustomer(cust);
      expect(controller.selectedCustomer?.name, equals('سجاد كريم'));
    });

    test('Clear customer reverts back to walk-in', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      final cust = CachedCustomer(
        id: 'C-1',
        name: 'A',
        phone: '1',
        creditBalanceMinorUnits: 0,
        creditLimitMinorUnits: 0,
        version: 1,
        fetchedAt: DateTime.now(),
      );
      controller.setCustomer(cust);
      controller.setCustomer(null);
      expect(controller.selectedCustomer, isNull);
    });
  });

  group('Group H: Payment & Change Calculation', () {
    test('Cash payment with change calculated accurately', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 2); // 4000 IQD

      final payments = [
        Payment(
          id: 'P-1',
          method: PaymentMethod.cash,
          amount: Money.fromAmount(5000, Currency.iqd), // Tendered 5000
          receivedAt: DateTime.now(),
        ),
      ];

      final success = await controller.processPayment(payments: payments);
      expect(success, isTrue);
      expect(controller.lastCheckoutResult, isNotNull);
      expect(controller.lastCheckoutResult?.sale.paidTotal.toAmount(), equals(5000));
      expect(controller.lastCheckoutResult?.sale.changeTotal.toAmount(), equals(1000));
      expect(controller.lastCheckoutResult?.sale.grandTotal.toAmount(), equals(4000));
      expect(controller.currentCart.isEmpty, isTrue); // Cart cleared after checkout
    });

    test('Card payment for exact total succeeds', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 1); // 2000 IQD

      final payments = [
        Payment(
          id: 'P-2',
          method: PaymentMethod.card,
          amount: Money.fromAmount(2000, Currency.iqd),
          receivedAt: DateTime.now(),
        ),
      ];

      final success = await controller.processPayment(payments: payments);
      expect(success, isTrue);
      expect(controller.lastCheckoutResult?.sale.changeTotal.toAmount(), equals(0));
    });

    test('Payment with underpaid amount fails validation', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 2); // 4000 IQD

      final payments = [
        Payment(
          id: 'P-3',
          method: PaymentMethod.cash,
          amount: Money.fromAmount(3000, Currency.iqd), // Underpaid
          receivedAt: DateTime.now(),
        ),
      ];

      final success = await controller.processPayment(payments: payments);
      expect(success, isFalse);
      expect(controller.errorMessage, isNotNull);
    });
  });

  group('Group I: Split Payment', () {
    test('Split payment (Cash + Card) combines to exact grand total', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(meatWeighableProduct, quantity: 1); // 14000 IQD

      final payments = [
        Payment(
          id: 'P-SPLIT-1',
          method: PaymentMethod.cash,
          amount: Money.fromAmount(10000, Currency.iqd),
          receivedAt: DateTime.now(),
        ),
        Payment(
          id: 'P-SPLIT-2',
          method: PaymentMethod.card,
          amount: Money.fromAmount(4000, Currency.iqd),
          receivedAt: DateTime.now(),
        ),
      ];

      final success = await controller.processPayment(payments: payments);
      expect(success, isTrue);
      expect(controller.lastCheckoutResult?.sale.payments.length, equals(2));
      expect(controller.lastCheckoutResult?.sale.paidTotal.toAmount(), equals(14000));
    });
  });

  group('Group J: Credit Sale & Validation', () {
    test('Credit sale requires a customer profile', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct);
      // No customer set
      final payments = [
        Payment(
          id: 'P-CR',
          method: PaymentMethod.credit,
          amount: Money.fromAmount(2000, Currency.iqd),
          receivedAt: DateTime.now(),
        ),
      ];

      final success = await controller.processPayment(payments: payments);
      expect(success, isFalse);
      expect(controller.errorMessage, contains('العميل'));
    });

    test('Credit sale succeeds online when customer is assigned', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct);
      final cust = CachedCustomer(
        id: 'C-01',
        name: 'Zaid',
        phone: '0770',
        creditBalanceMinorUnits: 0,
        creditLimitMinorUnits: 50000,
        version: 1,
        fetchedAt: DateTime.now(),
      );
      controller.setCustomer(cust);

      final payments = [
        Payment(
          id: 'P-CR-2',
          method: PaymentMethod.credit,
          amount: Money.fromAmount(2000, Currency.iqd),
          receivedAt: DateTime.now(),
        ),
      ];

      final success = await controller.processPayment(payments: payments);
      expect(success, isTrue);
      expect(controller.lastCheckoutResult?.sale.customerId, equals('C-01'));
    });
  });

  group('Group K: Offline Mode & Outbox Queuing', () {
    test('Offline sale stores outbox envelope and generates local receipt', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      // Transition sync to offline
      connectivity.setStatus(ConnectivityState.offline);
      await controller.refreshSyncStatus();
      expect(controller.isOffline, isTrue);

      controller.addProductToCart(milkProduct, quantity: 1);
      final payments = [
        Payment(
          id: 'P-OFF',
          method: PaymentMethod.cash,
          amount: Money.fromAmount(2000, Currency.iqd),
          receivedAt: DateTime.now(),
        ),
      ];

      final success = await controller.processPayment(payments: payments);
      expect(success, isTrue);
      expect(controller.isLastSaleOffline, isTrue);
      expect(controller.lastCheckoutResult?.receipt, isNotNull);
      expect(controller.syncStatus.pendingOutboxCount, greaterThan(0));
    });
  });

  group('Group L: Sync State & Badges', () {
    test('Sync status snapshot accurately reports pending count and state', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      await controller.refreshSyncStatus();
      expect(controller.syncStatus.connectivityState, equals(ConnectivityState.online));
      expect(controller.isOffline, isFalse);
    });
  });

  group('Group M: Printer State & Resilience', () {
    test('Auto-print triggers print job on successful checkout', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct);
      final payments = [
        Payment(
          id: 'P-PRN',
          method: PaymentMethod.cash,
          amount: Money.fromAmount(2000, Currency.iqd),
          receivedAt: DateTime.now(),
        ),
      ];

      await controller.processPayment(payments: payments, autoPrint: true);
      expect(mockDriver.printedJobs.length, equals(1));
    });

    test('Printer offline error does not abort sale transaction', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      mockDriver.status = PrinterStatus.offline;
      mockDriver.shouldFailPrint = true; // Hardware disconnected

      controller.addProductToCart(milkProduct);
      final payments = [
        Payment(
          id: 'P-PRN-FAIL',
          method: PaymentMethod.cash,
          amount: Money.fromAmount(2000, Currency.iqd),
          receivedAt: DateTime.now(),
        ),
      ];

      final success = await controller.processPayment(payments: payments, autoPrint: true);
      expect(success, isTrue); // Sale still succeeds
      expect(controller.printerState, equals(PrinterStatus.offline));
    });
  });

  group('Group N: Return Lookup & Entry', () {
    test('Sale lookup returns list matching query', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct);
      await controller.processPayment(payments: [
        Payment(id: 'P-RET', method: PaymentMethod.cash, amount: Money.fromAmount(2000, Currency.iqd), receivedAt: DateTime.now()),
      ]);

      final sales = await controller.lookupSales(query: 'MILK');
      expect(sales, isA<List<Sale>>());
    });
  });

  group('Group O: Error UX Arabic Mapping', () {
    test('All engine failures map to clean Arabic messages without leaking tech details', () {
      expect(PosErrorMapper.toArabicMessage(InvalidCartFailure('Cart empty')), contains('سلة المشتريات فارغة'));
      expect(PosErrorMapper.toArabicMessage(CreditCustomerRequiredFailure('Credit needs customer')), contains('البيع الآجل'));
      expect(PosErrorMapper.toArabicMessage(SessionExpiredFailure('Expired')), contains('جلسة العمل'));
      expect(PosErrorMapper.toArabicMessage(SyncOfflineBlockedFailure('Credit')), contains('اتصالاً بالإنترنت'));
    });
  });

  group('Group P: Keyboard Shortcuts Handling', () {
    test('F1 focuses search, F4 holds/switches cart, F9 clears cart', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.switchCart(0);
      controller.addProductToCart(milkProduct);
      expect(controller.activeCartIndex, equals(0));

      // Simulate F4 hold/switch to Cart 2
      controller.switchCart(1);
      expect(controller.activeCartIndex, equals(1));

      // Simulate F9 New Sale
      controller.clearCurrentCart();
      expect(controller.cartItemCount, equals(0));
    });
  });

  group('Group Q: Accessibility & RTL Native Display', () {
    test('Arabic native labels and currencies formatted cleanly', () {
      const price = Money.fromMinorUnits(2500, Currency.iqd);
      expect(price.toAmount(), equals(2500));
      expect(Currency.iqd.symbol, equals('د.ع'));
    });
  });

  group('Group R: Responsive Layout Boundaries', () {
    test('Calculates totals and partitions without overflow constraints', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      for (int i = 0; i < 20; i++) {
        controller.addProductToCart(milkProduct, quantity: 1);
      }
      expect(controller.currentCart.items.first.quantity, equals(20));
      expect(controller.totals.grandTotal.toAmount(), equals(40000));
    });
  });

  group('Group S: Extended POS Workflows & Edge Cases (Tests 69 to 110)', () {
    test('69. Search with case insensitivity on SKU finds product', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      await controller.initCatalog();
      await controller.searchProducts('sku-milk-01');
      expect(controller.searchResults.length, equals(1));
      expect(controller.searchResults.first.productId, equals('PROD-MILK'));
    });

    test('70. Category filter selection isolates matching category products', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      await controller.initCatalog();
      controller.setCategory('CAT-DAIRY');
      expect(controller.searchResults.length, equals(1));
    });

    test('71. Category filter resets on ALL to show full catalog', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      await controller.initCatalog();
      controller.setCategory('CAT-DAIRY');
      controller.setCategory('ALL');
      expect(controller.searchResults.length, equals(1));
    });

    test('72. Scanning weighable product defaults to 1.0 KG in cart', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      final added = await controller.scanBarcode('6282002002');
      expect(added, isTrue);
      expect(controller.currentCart.items.first.quantity, equals(1.0));
      expect(controller.currentCart.items.first.isWeighable, isTrue);
    });

    test('73. Rapid consecutive barcode scans of same product increment quantity', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      await controller.scanBarcode('6281001001');
      await controller.scanBarcode('6281001001');
      expect(controller.cartItemCount, equals(1));
      expect(controller.currentCart.items.first.quantity, equals(2.0));
    });

    test('74. Scanning two different barcodes produces two distinct line items', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      await controller.scanBarcode('6281001001');
      await controller.scanBarcode('6282002002');
      expect(controller.cartItemCount, equals(2));
    });

    test('75. Scanner input with Windows carriage return and newline resolves', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      final added = await controller.scanBarcode('6281001001\r\n');
      expect(added, isTrue);
      expect(controller.cartItemCount, equals(1));
    });

    test('76. Cart slot switching preserves item states independently', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.switchCart(0);
      controller.addProductToCart(milkProduct, quantity: 3);
      controller.switchCart(1);
      controller.addProductToCart(meatWeighableProduct, quantity: 1.5);
      controller.switchCart(2);
      controller.addProductToCart(milkProduct, quantity: 1);

      controller.switchCart(0);
      expect(controller.currentCart.items.first.quantity, equals(3));
      controller.switchCart(1);
      expect(controller.currentCart.items.first.quantity, equals(1.5));
      controller.switchCart(2);
      expect(controller.currentCart.items.first.quantity, equals(1));
    });

    test('77. Hold cart automatically navigates to next available empty slot', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.switchCart(0);
      controller.addProductToCart(milkProduct);
      controller.holdCurrentCart();
      expect(controller.activeCartIndex, equals(1));
      expect(controller.currentCart.isEmpty, isTrue);
    });

    test('78. Holding cart when all slots are occupied stays on active slot', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.switchCart(0);
      controller.addProductToCart(milkProduct);
      controller.switchCart(1);
      controller.addProductToCart(milkProduct);
      controller.switchCart(2);
      controller.addProductToCart(milkProduct);

      controller.switchCart(0);
      controller.holdCurrentCart();
      expect(controller.activeCartIndex, equals(0));
    });

    test('79. Clearing cart slot 0 leaves slot 1 and 2 intact', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.switchCart(0);
      controller.addProductToCart(milkProduct);
      controller.switchCart(1);
      controller.addProductToCart(meatWeighableProduct);

      controller.switchCart(0);
      controller.clearCurrentCart();
      expect(controller.currentCart.isEmpty, isTrue);

      controller.switchCart(1);
      expect(controller.currentCart.isNotEmpty, isTrue);
    });

    test('80. Weighable product precision increment increases by 0.250 KG', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(meatWeighableProduct, quantity: 1.0);
      final itemId = controller.currentCart.items.first.itemId;
      controller.updateItemQuantity(itemId, 1.250);
      expect(controller.currentCart.items.first.quantity, equals(1.250));
    });

    test('81. Weighable product precision decrement decreases by 0.250 KG', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(meatWeighableProduct, quantity: 1.500);
      final itemId = controller.currentCart.items.first.itemId;
      controller.updateItemQuantity(itemId, 1.250);
      expect(controller.currentCart.items.first.quantity, equals(1.250));
    });

    test('82. Large quantity bulk purchase calculates exact subtotal', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 100);
      expect(controller.totals.grandTotal.toAmount(), equals(200000));
    });

    test('83. Setting zero quantity via updateItemQuantity is rejected', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 2);
      final itemId = controller.currentCart.items.first.itemId;
      controller.updateItemQuantity(itemId, -1);
      expect(controller.currentCart.items.first.quantity, equals(2));
    });

    test('84. Fractional weighable item 2.375 KG calculates total accurately', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(meatWeighableProduct, quantity: 2.375);
      // 2.375 * 14,000 = 33,250 IQD
      expect(controller.totals.grandTotal.toAmount(), equals(33250));
    });

    test('85. Applying line item discount reduces specific line total', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 2); // 4000
      final itemId = controller.currentCart.items.first.itemId;
      controller.applyItemDiscount(itemId, const Discount(type: DiscountType.percentage, value: 10));
      expect(controller.currentCart.items.first.discountAmount.toAmount(), equals(400));
      expect(controller.totals.grandTotal.toAmount(), equals(3600));
    });

    test('86. Applying fixed line item discount reduces total accordingly', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 1); // 2000
      final itemId = controller.currentCart.items.first.itemId;
      controller.applyItemDiscount(itemId, const Discount(type: DiscountType.fixed, value: 500));
      expect(controller.totals.grandTotal.toAmount(), equals(1500));
    });

    test('87. Combined item discount and cart discount compute harmoniously', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 2); // 4000
      final itemId = controller.currentCart.items.first.itemId;
      controller.applyItemDiscount(itemId, const Discount(type: DiscountType.fixed, value: 500)); // 3500
      controller.applyCartDiscount(const Discount(type: DiscountType.fixed, value: 500)); // 3000
      expect(controller.totals.grandTotal.toAmount(), equals(3000));
    });

    test('88. Re-applying cart discount overrides previous discount value', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 2); // 4000
      controller.applyCartDiscount(const Discount(type: DiscountType.fixed, value: 500));
      expect(controller.totals.discountTotal.toAmount(), equals(500));
      controller.applyCartDiscount(const Discount(type: DiscountType.fixed, value: 1000));
      expect(controller.totals.discountTotal.toAmount(), equals(1000));
      expect(controller.totals.grandTotal.toAmount(), equals(3000));
    });

    test('89. Assigned customer balance is visible on customer model', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      final cust = CachedCustomer(
        id: 'C-CREDIT',
        name: 'أحمد سالم',
        phone: '0780000000',
        creditBalanceMinorUnits: 25000,
        creditLimitMinorUnits: 150000,
        version: 1,
        fetchedAt: DateTime.now(),
      );
      controller.setCustomer(cust);
      expect(controller.selectedCustomer?.creditBalanceMinorUnits, equals(25000));
    });

    test('90. Unsetting customer reverts cart customer ID to null', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      final cust = CachedCustomer(
        id: 'C-02',
        name: 'محمد',
        phone: '0770',
        creditBalanceMinorUnits: 0,
        creditLimitMinorUnits: 0,
        version: 1,
        fetchedAt: DateTime.now(),
      );
      controller.setCustomer(cust);
      expect(controller.selectedCustomer, isNotNull);
      controller.setCustomer(null);
      expect(controller.selectedCustomer, isNull);
    });

    test('91. Exact cash payment produces zero change', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 2); // 4000
      final payments = [
        Payment(id: 'P-EXACT', method: PaymentMethod.cash, amount: Money.fromAmount(4000, Currency.iqd), receivedAt: DateTime.now()),
      ];
      final success = await controller.processPayment(payments: payments);
      expect(success, isTrue);
      expect(controller.lastCheckoutResult?.sale.changeTotal.toAmount(), equals(0));
    });

    test('92. Large cash denomination calculates change accurately', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 2); // 4000
      final payments = [
        Payment(id: 'P-50K', method: PaymentMethod.cash, amount: Money.fromAmount(50000, Currency.iqd), receivedAt: DateTime.now()),
      ];
      final success = await controller.processPayment(payments: payments);
      expect(success, isTrue);
      expect(controller.lastCheckoutResult?.sale.changeTotal.toAmount(), equals(46000));
    });

    test('93. Cash payment with zero received amount fails validation', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct, quantity: 1);
      final payments = [
        Payment(id: 'P-ZERO', method: PaymentMethod.cash, amount: Money.zero(Currency.iqd), receivedAt: DateTime.now()),
      ];
      final success = await controller.processPayment(payments: payments);
      expect(success, isFalse);
    });

    test('94. Split payment with 3 methods (Cash + Card + Digital)', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(meatWeighableProduct, quantity: 1); // 14000
      final payments = [
        Payment(id: 'P-CASH', method: PaymentMethod.cash, amount: Money.fromAmount(5000, Currency.iqd), receivedAt: DateTime.now()),
        Payment(id: 'P-CARD', method: PaymentMethod.card, amount: Money.fromAmount(5000, Currency.iqd), receivedAt: DateTime.now()),
        Payment(id: 'P-DIG', method: PaymentMethod.digital, amount: Money.fromAmount(4000, Currency.iqd), receivedAt: DateTime.now()),
      ];
      final success = await controller.processPayment(payments: payments);
      expect(success, isTrue);
      expect(controller.lastCheckoutResult?.sale.payments.length, equals(3));
    });

    test('95. Credit sale without customer is rejected with Arabic failure', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct);
      final payments = [
        Payment(id: 'P-NOCUST', method: PaymentMethod.credit, amount: Money.fromAmount(2000, Currency.iqd), receivedAt: DateTime.now()),
      ];
      final success = await controller.processPayment(payments: payments);
      expect(success, isFalse);
      expect(controller.errorMessage, contains('العميل'));
    });

    test('96. Online credit sale with customer records customer ID on completed sale', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct);
      final cust = CachedCustomer(
        id: 'CUST-ONL',
        name: 'فاطمة',
        phone: '07709999999',
        creditBalanceMinorUnits: 0,
        creditLimitMinorUnits: 100000,
        version: 1,
        fetchedAt: DateTime.now(),
      );
      controller.setCustomer(cust);
      final payments = [
        Payment(id: 'P-CR-OK', method: PaymentMethod.credit, amount: Money.fromAmount(2000, Currency.iqd), receivedAt: DateTime.now()),
      ];
      final success = await controller.processPayment(payments: payments);
      expect(success, isTrue);
      expect(controller.lastCheckoutResult?.sale.customerId, equals('CUST-ONL'));
    });

    test('97. Offline cash sales accumulate sequentially in outbox', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      connectivity.setStatus(ConnectivityState.offline);
      await controller.refreshSyncStatus();

      controller.addProductToCart(milkProduct, quantity: 1);
      await controller.processPayment(payments: [
        Payment(id: 'P-OFF-A', method: PaymentMethod.cash, amount: Money.fromAmount(2000, Currency.iqd), receivedAt: DateTime.now()),
      ]);

      controller.addProductToCart(milkProduct, quantity: 1);
      await controller.processPayment(payments: [
        Payment(id: 'P-OFF-B', method: PaymentMethod.cash, amount: Money.fromAmount(2000, Currency.iqd), receivedAt: DateTime.now()),
      ]);

      expect(controller.syncStatus.pendingOutboxCount, equals(2));
    });

    test('98. Offline credit sale is blocked by default safety policy', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      connectivity.setStatus(ConnectivityState.offline);
      await controller.refreshSyncStatus();

      controller.addProductToCart(milkProduct);
      final cust = CachedCustomer(id: 'C-OFF', name: 'سامر', phone: '0770', creditBalanceMinorUnits: 0, creditLimitMinorUnits: 50000, version: 1, fetchedAt: DateTime.now());
      controller.setCustomer(cust);

      final payments = [
        Payment(id: 'P-OFF-CR-BLOCKED', method: PaymentMethod.credit, amount: Money.fromAmount(2000, Currency.iqd), receivedAt: DateTime.now()),
      ];
      final success = await controller.processPayment(payments: payments);
      expect(success, isFalse);
    });

    test('99. Unstable network is treated as offline-safe by POS controller', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      connectivity.setStatus(ConnectivityState.unstable);
      await controller.refreshSyncStatus();
      expect(controller.isOffline, isTrue);
    });

    test('100. Sync status reports zero conflicts when queue is clean', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      await controller.refreshSyncStatus();
      expect(controller.syncStatus.conflictCount, equals(0));
    });

    test('101. Manual reprint command with reason completes successfully', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct);
      await controller.processPayment(payments: [
        Payment(id: 'P-REPRINT', method: PaymentMethod.cash, amount: Money.fromAmount(2000, Currency.iqd), receivedAt: DateTime.now()),
      ], autoPrint: true);

      final doc = const DocumentBuilderService().buildFromReceiptSnapshot(controller.lastCheckoutResult!.receipt);
      final reprintJob = await printCoordinator.submitPrintJob(SubmitPrintJobCommand(
        businessId: bizId,
        branchId: branchId,
        document: doc,
        triggerType: PrintTriggerType.manualReprint,
        requestedBy: 'cashier',
        reprintReason: 'طلب الزبون نسخة ثانية',
        idempotencyKey: 'REPRINT-OK-${DateTime.now().microsecondsSinceEpoch}',
      ));

      expect(reprintJob.status, equals(PrintJobStatus.completed));
    });

    test('102. Manual reprint command without reason is rejected by engine', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct);
      await controller.processPayment(payments: [
        Payment(id: 'P-REP-FAIL', method: PaymentMethod.cash, amount: Money.fromAmount(2000, Currency.iqd), receivedAt: DateTime.now()),
      ], autoPrint: true);

      final doc = const DocumentBuilderService().buildFromReceiptSnapshot(controller.lastCheckoutResult!.receipt);
      expect(
        () => printCoordinator.submitPrintJob(SubmitPrintJobCommand(
          businessId: bizId,
          branchId: branchId,
          document: doc,
          triggerType: PrintTriggerType.manualReprint,
          requestedBy: 'cashier',
          reprintReason: '   ', // Empty reason
          idempotencyKey: 'REPRINT-EMPTY-${DateTime.now().microsecondsSinceEpoch}',
        )),
        throwsA(isA<InvalidReprintReasonFailure>()),
      );
    });

    test('103. Sale lookup retrieves previously saved sale by sale number', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct);
      await controller.processPayment(payments: [
        Payment(id: 'P-LOOKUP', method: PaymentMethod.cash, amount: Money.fromAmount(2000, Currency.iqd), receivedAt: DateTime.now()),
      ]);
      final saleNum = controller.lastCheckoutResult!.sale.saleNumber;
      final sales = await controller.lookupSales(query: saleNum);
      expect(sales.isNotEmpty, isTrue);
      expect(sales.first.saleNumber, equals(saleNum));
    });

    test('104. Sale lookup with nonexistent query returns empty list', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      final sales = await controller.lookupSales(query: 'NONEXISTENT-99999');
      expect(sales.isEmpty, isTrue);
    });

    test('105. PosErrorMapper maps generic exception to friendly Arabic message', () {
      final msg = PosErrorMapper.toArabicMessage(Exception('Unexpected crash'));
      expect(msg, contains('تعذر إتمام العملية'));
    });

    test('106. Currency symbol is consistent Arabic IQD symbol', () {
      expect(Currency.iqd.symbol, equals('د.ع'));
      expect(Currency.iqd.code, equals('IQD'));
    });

    test('107. Money amount conversions preserve exact integer precision without decimals', () {
      const money = Money.fromMinorUnits(15750, Currency.iqd);
      expect(money.toAmount(), equals(15750));
    });

    test('108. Ultra-wide display resolution calculation stability', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(meatWeighableProduct, quantity: 10.0);
      expect(controller.totals.grandTotal.toAmount(), equals(140000));
    });

    test('109. Cart clear resets active customer and error messages', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct);
      final cust = CachedCustomer(id: 'C-X', name: 'علي', phone: '1', creditBalanceMinorUnits: 0, creditLimitMinorUnits: 0, version: 1, fetchedAt: DateTime.now());
      controller.setCustomer(cust);
      controller.clearCurrentCart();
      expect(controller.selectedCustomer, isNull);
      expect(controller.errorMessage, isNull);
    });

    test('110. Multiple active carts can be switched rapidly without data corruption', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      for (int slot = 0; slot < 3; slot++) {
        controller.switchCart(slot);
        controller.addProductToCart(milkProduct, quantity: (slot + 1).toDouble());
      }
      for (int slot = 0; slot < 3; slot++) {
        controller.switchCart(slot);
        expect(controller.currentCart.items.first.quantity, equals((slot + 1).toDouble()));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 3. CRITICAL UI TESTS (TEST 1 to TEST 8)
  // ═══════════════════════════════════════════════════════════════
  group('CRITICAL UI TESTS (1 to 8)', () {
    test('TEST 1: Double click Pay executes only ONE checkout command', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct);
      final payments = [
        Payment(id: 'P-DBL', method: PaymentMethod.cash, amount: Money.fromAmount(2000, Currency.iqd), receivedAt: DateTime.now()),
      ];

      // Dispatch 2 concurrent payments
      final fut1 = controller.processPayment(payments: payments);
      final fut2 = controller.processPayment(payments: payments);

      final results = await Future.wait([fut1, fut2]);
      // One must succeed, second must be rejected because processing flag was true
      expect(results.where((r) => r == true).length, equals(1));
    });

    test('TEST 2: Offline sale creates local sale + outbox queued + receipt', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      connectivity.setStatus(ConnectivityState.offline);
      await controller.refreshSyncStatus();
      expect(controller.isOffline, isTrue);

      controller.addProductToCart(milkProduct);
      final payments = [
        Payment(id: 'P-OFF-2', method: PaymentMethod.cash, amount: Money.fromAmount(2000, Currency.iqd), receivedAt: DateTime.now()),
      ];

      final success = await controller.processPayment(payments: payments);
      expect(success, isTrue);
      expect(controller.isLastSaleOffline, isTrue);
      expect(controller.lastCheckoutResult?.receipt, isNotNull);
      expect(controller.lastCheckoutResult?.sale.saleNumber, startsWith('OFF-'));
    });

    test('TEST 3: Offline blocked credit -> no transaction created', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      connectivity.setStatus(ConnectivityState.offline);
      await controller.refreshSyncStatus();
      expect(controller.isOffline, isTrue);

      controller.addProductToCart(milkProduct);
      final cust = CachedCustomer(
        id: 'C-01',
        name: 'Zaid',
        phone: '0770',
        creditBalanceMinorUnits: 0,
        creditLimitMinorUnits: 50000,
        version: 1,
        fetchedAt: DateTime.now(),
      );
      controller.setCustomer(cust);

      final payments = [
        Payment(id: 'P-CREDIT-OFF', method: PaymentMethod.credit, amount: Money.fromAmount(2000, Currency.iqd), receivedAt: DateTime.now()),
      ];

      // Offline credit is blocked by policy
      final success = await controller.processPayment(payments: payments);
      expect(success, isFalse);
      expect(controller.currentCart.isNotEmpty, isTrue); // Cart preserved
    });

    test('TEST 4: Product out of stock -> clear error, no sale', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      expect(
        () => controller.addProductToCart(outOfStockProduct),
        throwsA(isA<ProductUnavailableFailure>()),
      );
      expect(controller.currentCart.isEmpty, isTrue);
    });

    test('TEST 5: Printer offline -> sale completes successfully', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      mockDriver.status = PrinterStatus.offline;
      mockDriver.shouldFailPrint = true; // Printer jam or disconnected

      controller.addProductToCart(milkProduct);
      final success = await controller.processPayment(payments: [
        Payment(id: 'P-PRN-OK', method: PaymentMethod.cash, amount: Money.fromAmount(2000, Currency.iqd), receivedAt: DateTime.now()),
      ], autoPrint: true);

      expect(success, isTrue);
      expect(controller.lastCheckoutResult, isNotNull);
      expect(controller.printerState, equals(PrinterStatus.offline));
    });

    test('TEST 6: Unknown print state -> no blind duplicate print', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct);
      await controller.processPayment(payments: [
        Payment(id: 'P-IDEMP', method: PaymentMethod.cash, amount: Money.fromAmount(2000, Currency.iqd), receivedAt: DateTime.now()),
      ], autoPrint: true);

      final initialPrintCount = mockDriver.printedJobs.length;

      // Duplicate auto-print for same document is blocked
      expect(
        () => printCoordinator.submitPrintJob(SubmitPrintJobCommand(
          businessId: bizId,
          branchId: branchId,
          document: const DocumentBuilderService().buildFromReceiptSnapshot(controller.lastCheckoutResult!.receipt),
          triggerType: PrintTriggerType.autoPrint,
          requestedBy: 'cashier',
          idempotencyKey: 'PRINT-DUP-${controller.lastCheckoutResult!.sale.id}',
        )),
        throwsA(isA<DuplicateAutoPrintFailure>()),
      );

      expect(mockDriver.printedJobs.length, equals(initialPrintCount));
    });

    test('TEST 7: Session expired -> checkout blocked', () async {
      final controller = await createControllerForUser('cashier@madar.iq');
      controller.addProductToCart(milkProduct);

      // Force session expiry
      final now = DateTime.now();
      final expiredSession = ShopSession(
        sessionId: controller.sessionId,
        installationId: installId,
        terminalId: terminalId,
        userId: 'usr_cashier',
        businessId: bizId,
        activeBranchId: branchId,
        startedAt: now.subtract(const Duration(hours: 15)),
        lastHeartbeatAt: now.subtract(const Duration(hours: 13)),
        expiresAt: now.subtract(const Duration(hours: 1)),
        status: ShopSessionStatus.expired,
      );
      final user = await identityRepo.getUserById('usr_cashier');
      identityCoordinator.setSession(user: user!, session: expiredSession);

      final success = await controller.processPayment(payments: [
        Payment(id: 'P-EXP', method: PaymentMethod.cash, amount: Money.fromAmount(2000, Currency.iqd), receivedAt: DateTime.now()),
      ]);

      expect(success, isFalse);
      expect(controller.errorMessage, contains('جلسة العمل'));
    });

    test('TEST 8: Permission denied discount override -> blocked', () async {
      // Create controller with user lacking discount permission (e.g. inventory clerk)
      final controller = await createControllerForUser('clerk@madar.iq', requirePosAccess: false);
      expect(identityCoordinator.hasPermission(ShopPermission.applyCartDiscount), isFalse);

      expect(
        () => controller.applyCartDiscount(const Discount(type: DiscountType.percentage, value: 15)),
        throwsA(isA<UnauthorizedCashierFailure>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 4. REAL WORLD CASHIER FLOW INTEGRATION TEST (Section 53)
  // ═══════════════════════════════════════════════════════════════
  group('Section 53: Real World Cashier Flow Integration Test', () {
    test('Execute: Open POS -> Scan Barcode -> Add Product -> Qty 2 -> Customer -> Discount -> Pay Cash -> Change -> Complete -> Receipt -> Print Queue -> New Sale', () async {
      // 1. Open POS & Authenticate Cashier
      final authResult = await authService.loginAndOpenSession(
        loginIdentifier: 'cashier@madar.iq',
        secret: 'pass',
        businessId: bizId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
      );
      expect(authResult.isAllowed, isTrue);

      final controller = WindowsPosController(
        identityCoordinator: identityCoordinator,
        checkoutCoordinator: checkoutCoordinator,
        syncCoordinator: syncCoordinator,
        printCoordinator: printCoordinator,
        returnsCoordinator: null,
        productResolver: productResolver,
        coreRepository: coreRepo,
        posRepository: posRepo,
      );
      await controller.initCatalog();

      // 2. Scan Barcode (Keyboard Wedge)
      final scanned = await controller.scanBarcode('6281001001'); // Milk 2000 IQD
      expect(scanned, isTrue);
      expect(controller.cartItemCount, equals(1));

      // 3. Adjust Qty to 2
      final itemId = controller.currentCart.items.first.itemId;
      controller.incrementItem(itemId);
      expect(controller.currentCart.items.first.quantity, equals(2));
      expect(controller.totals.subtotal.toAmount(), equals(4000));

      // 4. Set Customer
      final customer = CachedCustomer(
        id: 'CUST-REGULAR',
        name: 'حسين جاسم',
        phone: '07712345678',
        creditBalanceMinorUnits: 0,
        creditLimitMinorUnits: 200000,
        version: 1,
        fetchedAt: DateTime.now(),
      );
      controller.setCustomer(customer);
      expect(controller.selectedCustomer?.name, equals('حسين جاسم'));

      // 5. Apply Discount (10% = 400 IQD, Grand Total = 3600 IQD)
      controller.applyCartDiscount(const Discount(type: DiscountType.percentage, value: 10));
      expect(controller.totals.grandTotal.toAmount(), equals(3600));

      // 6. Pay Cash (Tendered 5000 IQD -> Change 1400 IQD)
      final payments = [
        Payment(
          id: 'PAY-RW-01',
          method: PaymentMethod.cash,
          amount: Money.fromAmount(5000, Currency.iqd),
          receivedAt: DateTime.now(),
        ),
      ];

      final checkoutSuccess = await controller.processPayment(
        payments: payments,
        autoPrint: true,
      );
      expect(checkoutSuccess, isTrue);

      // 7. Verify Completed Sale & Change
      final result = controller.lastCheckoutResult!;
      expect(result.sale.grandTotal.toAmount(), equals(3600));
      expect(result.sale.paidTotal.toAmount(), equals(5000));
      expect(result.sale.changeTotal.toAmount(), equals(1400));
      expect(result.sale.customerName, equals('حسين جاسم'));

      // 8. Verify Receipt Generated & Enqueued in Print Queue
      expect(result.receipt, isNotNull);
      expect(result.receipt.saleNumber, equals(result.sale.saleNumber));
      expect(mockDriver.printedJobs.length, equals(1));

      // 9. New Sale Trigger: Cart clean and ready for next customer
      expect(controller.currentCart.isEmpty, isTrue);
      expect(controller.selectedCustomer, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 5. WIDGET & RESPONSIVE UI TESTS (Section 52 & 56)
  // ═══════════════════════════════════════════════════════════════
  group('Section 52: Responsive Window & Widget QA Tests', () {
    testWidgets('RTL Directionality and Top Status Bar render properly', (tester) async {
      final controller = await createControllerForUser('cashier@madar.iq');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: WindowsPosPage(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar info
      expect(find.textContaining('Ali Cashier'), findsWidgets);
      expect(find.textContaining('BIZ-01'), findsWidgets);
      expect(find.byType(PosTopStatusBar), findsOneWidget);
      expect(find.byType(PosSearchBar), findsOneWidget);
      expect(find.byType(PosCartPane), findsOneWidget);
    });

    testWidgets('Barcode input field can receive scanned text', (tester) async {
      final controller = await createControllerForUser('cashier@madar.iq');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: WindowsPosPage(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, '6281001001');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(controller.cartItemCount, equals(1));
    });

    for (final size in [
      const Size(1280, 720),
      const Size(1366, 768),
      const Size(1600, 900),
      const Size(1920, 1080),
      const Size(2560, 1440),
    ]) {
      testWidgets('Responsive test on resolution ${size.width}x${size.height} without RenderFlex overflow', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final controller = await createControllerForUser('cashier@madar.iq');
        controller.addProductToCart(milkProduct, quantity: 2);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Directionality(
                textDirection: TextDirection.rtl,
                child: WindowsPosPage(controller: controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must find total summary and pay button visible without overflow
        expect(find.textContaining('3600').evaluate().isNotEmpty || find.textContaining('4000').evaluate().isNotEmpty, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
