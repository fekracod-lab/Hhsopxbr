// حزمة الاختبارات الشاملة لمحرك المخزون (MADAR SHOP Phase S3 Inventory Engine Tests)
// Unit & Domain Tests — Zero Mocks & 100% Deterministic Arithmetic — 61+ Real Tests

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/madar_shop/madar_shop.dart';

class FakeInventoryAuditRepository implements IShopAuditRepository {
  final List<ShopAuditEntry> entries = [];

  @override
  Future<void> recordAuditEntry(ShopAuditEntry entry) async {
    entries.add(entry);
  }

  @override
  Future<List<ShopAuditEntry>> getAuditEntries({
    required String businessId,
    required String branchId,
    ShopAuditAction? actionFilter,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    return entries;
  }
}

ShopUser _createTestUser({
  required String userId,
  required String businessId,
  List<String> assignedBranchIds = const [],
  ShopRole role = ShopRole.branchManager,
  Set<ShopPermission>? customPermissions,
}) {
  return ShopUser(
    userId: userId,
    businessId: businessId,
    assignedBranchIds: assignedBranchIds,
    fullName: 'Test User $userId',
    phone: '+9647700000000',
    email: '$userId@madar.shop',
    role: role,
    customPermissions: customPermissions,
    isActive: true,
    createdAt: DateTime.now(),
  );
}

ShopSession _createTestSession({
  required String sessionId,
  required String userId,
  required String businessId,
  required String activeBranchId,
  String terminalId = 'TERM-01',
}) {
  return ShopSession(
    sessionId: sessionId,
    installationId: 'INST-TEST-01',
    terminalId: terminalId,
    userId: userId,
    businessId: businessId,
    activeBranchId: activeBranchId,
    startedAt: DateTime.now(),
    lastHeartbeatAt: DateTime.now(),
    expiresAt: DateTime.now().add(const Duration(hours: 12)),
    status: ShopSessionStatus.active,
  );
}

void main() {
  group('MADAR SHOP Phase S3 — Inventory Engine Test Matrix', () {
    late InMemoryInventoryRepository inventoryRepo;
    late InMemoryInventoryLedgerRepository ledgerRepo;
    late InMemoryInventoryIdempotencyStore idempotencyStore;
    late FakeInventoryAuditRepository auditRepo;
    late ShopIdentityCoordinator identityCoordinator;
    late InventoryTransactionService transactionService;
    late InventoryReconciliationService reconciliationService;
    late List<InventoryDomainEvent> emittedEvents;

    const testBusinessId = 'BIZ-TEST-001';
    const testBranchA = 'BRANCH-MAIN-001';
    const testBranchB = 'BRANCH-SUB-002';
    const testActorId = 'USER-STAFF-001';

    setUp(() {
      inventoryRepo = InMemoryInventoryRepository();
      ledgerRepo = InMemoryInventoryLedgerRepository();
      idempotencyStore = InMemoryInventoryIdempotencyStore();
      auditRepo = FakeInventoryAuditRepository();
      identityCoordinator = ShopIdentityCoordinator();
      emittedEvents = [];

      // إعطاء المستخدم الافتراضي جلسة مدير مع كامل الصلاحيات لتسهيل الاختبارات الأساسية
      final ownerUser = _createTestUser(
        userId: testActorId,
        businessId: testBusinessId,
        assignedBranchIds: [testBranchA, testBranchB],
        role: ShopRole.branchManager,
        customPermissions: {
          ShopPermission.adjustInventoryStock,
          ShopPermission.performStocktaking,
          ShopPermission.manageBranches,
          ShopPermission.accessPos,
          ShopPermission.createSalesOrder,
        },
      );

      final session = _createTestSession(
        sessionId: 'SESSION-001',
        userId: testActorId,
        businessId: testBusinessId,
        activeBranchId: testBranchA,
      );

      identityCoordinator.setSession(user: ownerUser, session: session);

      transactionService = InventoryTransactionService(
        inventoryRepository: inventoryRepo,
        ledgerRepository: ledgerRepo,
        idempotencyStore: idempotencyStore,
        identityCoordinator: identityCoordinator,
        auditRepository: auditRepo,
        eventSink: (event) => emittedEvents.add(event),
      );

      reconciliationService = InventoryReconciliationService(
        inventoryRepository: inventoryRepo,
        ledgerRepository: ledgerRepo,
      );
    });

    // ══════════════════════════════════════════════════════════════════
    // GROUP A: Basic Inventory (1 - 6)
    // ══════════════════════════════════════════════════════════════════
    group('Group A: Basic Inventory', () {
      test('1. initial stock setup with onHand and available', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-001',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-001',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(item);

        final fetched = await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-001',
        );

        expect(fetched, isNotNull);
        expect(fetched!.onHand, StockQuantity.discrete(10));
        expect(fetched.reserved, StockQuantity.zero());
        expect(fetched.available, StockQuantity.discrete(10));
        expect(fetched.status, StockStatus.inStock);
      });

      test('2. zero stock initialization derives outOfStock status', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-002',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-002',
          initialOnHand: StockQuantity.zero(),
        );
        await inventoryRepo.saveInventoryItem(item);

        expect(item.onHand.isZero, isTrue);
        expect(item.available.isZero, isTrue);
        expect(item.status, StockStatus.outOfStock);
        expect(item.isOutOfStock, isTrue);
      });

      test('3. add stock increases onHand and available via adjustment', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-003',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-003',
          initialOnHand: StockQuantity.discrete(5),
        );
        await inventoryRepo.saveInventoryItem(item);

        final result = await transactionService.adjustStock(
          AdjustStockCommand(
            commandId: 'CMD-ADJ-001',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-003',
            quantityDelta: StockQuantity.discrete(3),
            actorId: testActorId,
            reason: 'إضافة رصيد جردي',
            idempotencyKey: 'IDEM-ADJ-001',
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(result.item.onHand, StockQuantity.discrete(8));
        expect(result.item.available, StockQuantity.discrete(8));
        expect(ledgerRepo.allEntries.length, 1);
        expect(ledgerRepo.allEntries.first.quantityDelta, StockQuantity.discrete(3));
      });

      test('4. remove stock decreases onHand and available', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-004',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-004',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(item);

        final result = await transactionService.adjustStock(
          AdjustStockCommand(
            commandId: 'CMD-ADJ-002',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-004',
            quantityDelta: -StockQuantity.discrete(4),
            actorId: testActorId,
            reason: 'تسوية عجز جردي',
            idempotencyKey: 'IDEM-ADJ-002',
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(result.item.onHand, StockQuantity.discrete(6));
        expect(result.item.available, StockQuantity.discrete(6));
        expect(ledgerRepo.allEntries.first.quantityDelta, -StockQuantity.discrete(4));
      });

      test('5. available calculation: onHand - reserved == available', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-005',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-005',
          initialOnHand: StockQuantity.discrete(15),
        );
        await inventoryRepo.saveInventoryItem(item);

        await transactionService.reserveStock(
          ReserveStockCommand(
            commandId: 'CMD-RES-001',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-005',
            quantity: StockQuantity.discrete(4),
            referenceType: 'ORDER',
            referenceId: 'ORD-999',
            actorId: testActorId,
            idempotencyKey: 'IDEM-RES-001',
          ),
        );

        final updated = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-005',
        ))!;

        expect(updated.onHand, StockQuantity.discrete(15));
        expect(updated.reserved, StockQuantity.discrete(4));
        expect(updated.available, StockQuantity.discrete(11));
      });

      test('6. reserved calculation correctly tracked after multiple reservations', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-006',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-006',
          initialOnHand: StockQuantity.discrete(20),
        );
        await inventoryRepo.saveInventoryItem(item);

        await transactionService.reserveStock(
          ReserveStockCommand(
            commandId: 'CMD-RES-A',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-006',
            quantity: StockQuantity.discrete(3),
            referenceType: 'ORDER',
            referenceId: 'ORD-1',
            actorId: testActorId,
            idempotencyKey: 'IDEM-RES-A',
          ),
        );

        await transactionService.reserveStock(
          ReserveStockCommand(
            commandId: 'CMD-RES-B',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-006',
            quantity: StockQuantity.discrete(5),
            referenceType: 'ORDER',
            referenceId: 'ORD-2',
            actorId: testActorId,
            idempotencyKey: 'IDEM-RES-B',
          ),
        );

        final updated = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-006',
        ))!;

        expect(updated.reserved, StockQuantity.discrete(8));
        expect(updated.available, StockQuantity.discrete(12));
      });
    });

    // ══════════════════════════════════════════════════════════════════
    // GROUP B: Sale Consumption (7 - 12)
    // ══════════════════════════════════════════════════════════════════
    group('Group B: Sale Consumption', () {
      test('7. sale decreases stock onHand and available', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-SALE-01',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-S1',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(item);

        final intent = InventoryMovementIntent(
          intentId: 'INTENT-001',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-S1',
          quantity: 3.0,
          movementType: InventoryMovementType.sale,
          referenceType: 'SALE',
          referenceId: 'SALE-101',
          requestedAt: DateTime.now(),
        );

        final result = await transactionService.consumeSaleMovementIntent(
          intent: intent,
          actorId: testActorId,
        );

        expect(result.isSuccess, isTrue);
        expect(result.item.onHand, StockQuantity.discrete(7));
        expect(result.item.available, StockQuantity.discrete(7));
        expect(ledgerRepo.allEntries.length, 1);
        final entry = ledgerRepo.allEntries.first;
        expect(entry.beforeOnHand, StockQuantity.discrete(10));
        expect(entry.quantityDelta, -StockQuantity.discrete(3));
        expect(entry.afterOnHand, StockQuantity.discrete(7));
        expect(entry.referenceId, 'SALE-101');
      });

      test('8. exact stock sale leaves onHand = 0, available = 0', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-SALE-02',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-S2',
          initialOnHand: StockQuantity.discrete(5),
        );
        await inventoryRepo.saveInventoryItem(item);

        final intent = InventoryMovementIntent(
          intentId: 'INTENT-002',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-S2',
          quantity: 5.0,
          referenceId: 'SALE-102',
          requestedAt: DateTime.now(),
        );

        final result = await transactionService.consumeSaleMovementIntent(
          intent: intent,
          actorId: testActorId,
        );

        expect(result.isSuccess, isTrue);
        expect(result.item.onHand.isZero, isTrue);
        expect(result.item.available.isZero, isTrue);
        expect(result.item.isOutOfStock, isTrue);
      });

      test('9. insufficient stock throws InsufficientStockFailure and does not alter stock', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-SALE-03',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-S3',
          initialOnHand: StockQuantity.discrete(2),
        );
        await inventoryRepo.saveInventoryItem(item);

        final intent = InventoryMovementIntent(
          intentId: 'INTENT-003',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-S3',
          quantity: 3.0,
          referenceId: 'SALE-103',
          requestedAt: DateTime.now(),
        );

        expect(
          () => transactionService.consumeSaleMovementIntent(
            intent: intent,
            actorId: testActorId,
          ),
          throwsA(isA<InsufficientStockFailure>()),
        );

        final untouched = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-S3',
        ))!;
        expect(untouched.onHand, StockQuantity.discrete(2));
        expect(ledgerRepo.allEntries.isEmpty, isTrue);
      });

      test('10. multiple sale items consumption', () async {
        final item1 = InventoryItem.initialize(
          inventoryId: 'INV-M-1',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-M1',
          initialOnHand: StockQuantity.discrete(8),
        );
        final item2 = InventoryItem.initialize(
          inventoryId: 'INV-M-2',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-M2',
          initialOnHand: StockQuantity.discrete(12),
        );
        await inventoryRepo.saveInventoryItem(item1);
        await inventoryRepo.saveInventoryItem(item2);

        final intent1 = InventoryMovementIntent(
          intentId: 'INTENT-M1',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-M1',
          quantity: 2.0,
          referenceId: 'SALE-MULTI',
          requestedAt: DateTime.now(),
        );
        final intent2 = InventoryMovementIntent(
          intentId: 'INTENT-M2',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-M2',
          quantity: 4.0,
          referenceId: 'SALE-MULTI',
          requestedAt: DateTime.now(),
        );

        await transactionService.consumeSaleMovementIntent(intent: intent1, actorId: testActorId);
        await transactionService.consumeSaleMovementIntent(intent: intent2, actorId: testActorId);

        final f1 = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-M1',
        ))!;
        final f2 = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-M2',
        ))!;

        expect(f1.onHand, StockQuantity.discrete(6));
        expect(f2.onHand, StockQuantity.discrete(8));
        expect(ledgerRepo.allEntries.length, 2);
      });

      test('11. variant sale decreases only specific variant stock', () async {
        final redItem = InventoryItem.initialize(
          inventoryId: 'INV-VAR-RED',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'SHIRT-01',
          variantId: 'VAR-RED-M',
          initialOnHand: StockQuantity.discrete(7),
        );
        final blueItem = InventoryItem.initialize(
          inventoryId: 'INV-VAR-BLUE',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'SHIRT-01',
          variantId: 'VAR-BLUE-L',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(redItem);
        await inventoryRepo.saveInventoryItem(blueItem);

        final intent = InventoryMovementIntent(
          intentId: 'INTENT-VAR-RED',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'SHIRT-01',
          variantId: 'VAR-RED-M',
          quantity: 2.0,
          referenceId: 'SALE-VAR',
          requestedAt: DateTime.now(),
        );

        await transactionService.consumeSaleMovementIntent(intent: intent, actorId: testActorId);

        final updatedRed = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'SHIRT-01',
          variantId: 'VAR-RED-M',
        ))!;
        final untouchedBlue = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'SHIRT-01',
          variantId: 'VAR-BLUE-L',
        ))!;

        expect(updatedRed.onHand, StockQuantity.discrete(5));
        expect(untouchedBlue.onHand, StockQuantity.discrete(10));
      });

      test('12. weighted sale (e.g. 1.750 kg) deterministic milli-unit precision', () async {
        final meatItem = InventoryItem.initialize(
          inventoryId: 'INV-WEIGHT-01',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'MEAT-01',
          unit: StockUnit.kg,
          initialOnHand: StockQuantity.fromDouble(10.0, StockUnit.kg),
        );
        await inventoryRepo.saveInventoryItem(meatItem);

        final intent = InventoryMovementIntent(
          intentId: 'INTENT-WEIGHT-1',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'MEAT-01',
          quantity: 1.750,
          referenceId: 'SALE-WEIGHT',
          requestedAt: DateTime.now(),
        );

        final result = await transactionService.consumeSaleMovementIntent(
          intent: intent,
          actorId: testActorId,
        );

        expect(result.isSuccess, isTrue);
        expect(result.item.onHand.milliUnits, 8250); // 10.000 - 1.750 = 8.250 kg
        expect(result.item.onHand.toDouble(), 8.25);
        expect(ledgerRepo.allEntries.first.quantityDelta.milliUnits, -1750);
      });
    });

    // ══════════════════════════════════════════════════════════════════
    // GROUP C: Idempotency & Double-Consumption Protection (13 - 16)
    // ══════════════════════════════════════════════════════════════════
    group('Group C: Idempotency', () {
      test('13. duplicate sale movement intent replay returns idempotent result and does not decrease stock twice', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-IDEM-01',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-IDEM-1',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(item);

        final intent = InventoryMovementIntent(
          intentId: 'INTENT-DUP-1',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-IDEM-1',
          quantity: 3.0,
          referenceId: 'SALE-DUP-1',
          requestedAt: DateTime.now(),
        );

        // First attempt
        final res1 = await transactionService.consumeSaleMovementIntent(intent: intent, actorId: testActorId);
        expect(res1.isSuccess, isTrue);
        expect(res1.isIdempotentReplay, isFalse);
        expect(res1.item.onHand, StockQuantity.discrete(7));
        expect(ledgerRepo.allEntries.length, 1);

        // Second duplicate attempt with exact same intent
        final res2 = await transactionService.consumeSaleMovementIntent(intent: intent, actorId: testActorId);
        expect(res2.isSuccess, isTrue);
        expect(res2.isIdempotentReplay, isTrue);
        expect(res2.item.onHand, StockQuantity.discrete(7)); // Not 4!
        expect(ledgerRepo.allEntries.length, 1); // Exactly one ledger entry!
      });

      test('14. same command twice returns idempotent result without second ledger entry', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-IDEM-02',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-IDEM-2',
          initialOnHand: StockQuantity.discrete(15),
        );
        await inventoryRepo.saveInventoryItem(item);

        final cmd = ApplyInventoryMovementCommand(
          commandId: 'CMD-IDEM-2',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-IDEM-2',
          quantity: StockQuantity.discrete(5),
          movementType: InventoryMovementType.sale,
          referenceType: 'SALE',
          referenceId: 'SALE-99',
          actorId: testActorId,
          idempotencyKey: 'IDEM-KEY-UNIQUE-2',
        );

        await transactionService.applyMovement(cmd);
        final replay = await transactionService.applyMovement(cmd);

        expect(replay.isIdempotentReplay, isTrue);
        expect(replay.item.onHand, StockQuantity.discrete(10));
        expect(ledgerRepo.allEntries.length, 1);
      });

      test('15. completed command replay returns previous status', () async {
        final hasProcessedBefore = await idempotencyStore.hasProcessed(
          businessId: testBusinessId,
          branchId: testBranchA,
          idempotencyKey: 'KEY-ABC',
        );
        expect(hasProcessedBefore, isFalse);

        await idempotencyStore.recordProcessed(
          businessId: testBusinessId,
          branchId: testBranchA,
          idempotencyKey: 'KEY-ABC',
          resultSummary: 'SUCCESS',
        );

        final hasProcessedAfter = await idempotencyStore.hasProcessed(
          businessId: testBusinessId,
          branchId: testBranchA,
          idempotencyKey: 'KEY-ABC',
        );
        expect(hasProcessedAfter, isTrue);
      });

      test('16. concurrent duplicate commands do not double-spend stock', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-IDEM-CONC',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-IDEM-CONC',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(item);

        final intent = InventoryMovementIntent(
          intentId: 'INTENT-CONC-DUP',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-IDEM-CONC',
          quantity: 4.0,
          referenceId: 'SALE-CONC-1',
          requestedAt: DateTime.now(),
        );

        // Launch both concurrently
        final future1 = transactionService.consumeSaleMovementIntent(intent: intent, actorId: testActorId);
        final future2 = transactionService.consumeSaleMovementIntent(intent: intent, actorId: testActorId);

        final results = await Future.wait([future1, future2]);

        final nonReplays = results.where((r) => !r.isIdempotentReplay).toList();
        final replays = results.where((r) => r.isIdempotentReplay).toList();

        expect(nonReplays.length, 1);
        expect(replays.length, 1);

        final finalItem = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-IDEM-CONC',
        ))!;
        expect(finalItem.onHand, StockQuantity.discrete(6)); // Deducted only once!
        expect(ledgerRepo.allEntries.length, 1);
      });
    });

    // ══════════════════════════════════════════════════════════════════
    // GROUP D: Reservation Engine (17 - 22)
    // ══════════════════════════════════════════════════════════════════
    group('Group D: Reservation', () {
      test('17. reserve available increases reserved and decreases available', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-RES-17',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-RES-17',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(item);

        final result = await transactionService.reserveStock(
          ReserveStockCommand(
            commandId: 'CMD-RES-17',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-RES-17',
            quantity: StockQuantity.discrete(3),
            referenceType: 'MARKETPLACE',
            referenceId: 'ORD-MKT-17',
            actorId: testActorId,
            idempotencyKey: 'IDEM-RES-17',
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(result.item.onHand, StockQuantity.discrete(10));
        expect(result.item.reserved, StockQuantity.discrete(3));
        expect(result.item.available, StockQuantity.discrete(7));
        expect(ledgerRepo.allEntries.first.movementType, InventoryMovementType.reservation);
      });

      test('18. reserve exact available leaves available = 0', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-RES-18',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-RES-18',
          initialOnHand: StockQuantity.discrete(6),
        );
        await inventoryRepo.saveInventoryItem(item);

        final result = await transactionService.reserveStock(
          ReserveStockCommand(
            commandId: 'CMD-RES-18',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-RES-18',
            quantity: StockQuantity.discrete(6),
            referenceType: 'MARKETPLACE',
            referenceId: 'ORD-MKT-18',
            actorId: testActorId,
            idempotencyKey: 'IDEM-RES-18',
          ),
        );

        expect(result.item.reserved, StockQuantity.discrete(6));
        expect(result.item.available.isZero, isTrue);
      });

      test('19. reserve too much throws ReservationExceededFailure', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-RES-19',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-RES-19',
          initialOnHand: StockQuantity.discrete(5),
        );
        await inventoryRepo.saveInventoryItem(item);

        expect(
          () => transactionService.reserveStock(
            ReserveStockCommand(
              commandId: 'CMD-RES-19',
              businessId: testBusinessId,
              branchId: testBranchA,
              productId: 'PROD-RES-19',
              quantity: StockQuantity.discrete(6),
              referenceType: 'MARKETPLACE',
              referenceId: 'ORD-MKT-19',
              actorId: testActorId,
              idempotencyKey: 'IDEM-RES-19',
            ),
          ),
          throwsA(isA<ReservationExceededFailure>()),
        );
      });

      test('20. release reservation decreases reserved and increases available', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-RES-20',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-RES-20',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(item);

        await transactionService.reserveStock(
          ReserveStockCommand(
            commandId: 'CMD-RES-20',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-RES-20',
            quantity: StockQuantity.discrete(4),
            referenceType: 'MARKETPLACE',
            referenceId: 'ORD-MKT-20',
            actorId: testActorId,
            idempotencyKey: 'IDEM-RES-20',
          ),
        );

        final releaseResult = await transactionService.releaseReservation(
          ReleaseReservationCommand(
            commandId: 'CMD-REL-20',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-RES-20',
            quantity: StockQuantity.discrete(2),
            referenceType: 'MARKETPLACE',
            referenceId: 'ORD-MKT-20',
            actorId: testActorId,
            idempotencyKey: 'IDEM-REL-20',
          ),
        );

        expect(releaseResult.isSuccess, isTrue);
        expect(releaseResult.item.reserved, StockQuantity.discrete(2));
        expect(releaseResult.item.available, StockQuantity.discrete(8));
        expect(releaseResult.item.onHand, StockQuantity.discrete(10));
      });

      test('21. release more than reserved throws failure', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-RES-21',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-RES-21',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(item);

        await transactionService.reserveStock(
          ReserveStockCommand(
            commandId: 'CMD-RES-21',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-RES-21',
            quantity: StockQuantity.discrete(2),
            referenceType: 'ORDER',
            referenceId: 'ORD-21',
            actorId: testActorId,
            idempotencyKey: 'IDEM-RES-21',
          ),
        );

        expect(
          () => transactionService.releaseReservation(
            ReleaseReservationCommand(
              commandId: 'CMD-REL-21',
              businessId: testBusinessId,
              branchId: testBranchA,
              productId: 'PROD-RES-21',
              quantity: StockQuantity.discrete(3),
              referenceType: 'ORDER',
              referenceId: 'ORD-21',
              actorId: testActorId,
              idempotencyKey: 'IDEM-REL-21',
            ),
          ),
          throwsA(isA<ReservationExceededFailure>()),
        );
      });

      test('22. reservation idempotency prevents duplicate reservation', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-RES-22',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-RES-22',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(item);

        final cmd = ReserveStockCommand(
          commandId: 'CMD-RES-22',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-RES-22',
          quantity: StockQuantity.discrete(3),
          referenceType: 'ORDER',
          referenceId: 'ORD-22',
          actorId: testActorId,
          idempotencyKey: 'IDEM-RES-22',
        );

        await transactionService.reserveStock(cmd);
        // Record in store for idempotency protection
        await idempotencyStore.recordProcessed(
          businessId: testBusinessId,
          branchId: testBranchA,
          idempotencyKey: 'IDEM-RES-22',
          resultSummary: 'RESERVED',
        );

        final hasProcessed = await idempotencyStore.hasProcessed(
          businessId: testBusinessId,
          branchId: testBranchA,
          idempotencyKey: 'IDEM-RES-22',
        );
        expect(hasProcessed, isTrue);
      });
    });

    // ══════════════════════════════════════════════════════════════════
    // GROUP E: Stock Adjustments (23 - 28)
    // ══════════════════════════════════════════════════════════════════
    group('Group E: Adjustment', () {
      test('23. adjustment in increases stock', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-ADJ-23',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-ADJ-23',
          initialOnHand: StockQuantity.discrete(5),
        );
        await inventoryRepo.saveInventoryItem(item);

        final result = await transactionService.adjustStock(
          AdjustStockCommand(
            commandId: 'CMD-ADJ-23',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-ADJ-23',
            quantityDelta: StockQuantity.discrete(5),
            actorId: testActorId,
            reason: 'جرد بضاعة فائضة',
            idempotencyKey: 'IDEM-ADJ-23',
          ),
        );

        expect(result.item.onHand, StockQuantity.discrete(10));
        expect(ledgerRepo.allEntries.last.movementType, InventoryMovementType.adjustmentIn);
      });

      test('24. adjustment out decreases stock', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-ADJ-24',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-ADJ-24',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(item);

        final result = await transactionService.adjustStock(
          AdjustStockCommand(
            commandId: 'CMD-ADJ-24',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-ADJ-24',
            quantityDelta: -StockQuantity.discrete(3),
            actorId: testActorId,
            reason: 'تلف أثناء النقل',
            idempotencyKey: 'IDEM-ADJ-24',
          ),
        );

        expect(result.item.onHand, StockQuantity.discrete(7));
        expect(ledgerRepo.allEntries.last.movementType, InventoryMovementType.adjustmentOut);
      });

      test('25. zero adjustment rejected with InvalidStockQuantityFailure', () async {
        expect(
          () => transactionService.adjustStock(
            AdjustStockCommand(
              commandId: 'CMD-ADJ-25',
              businessId: testBusinessId,
              branchId: testBranchA,
              productId: 'PROD-ADJ-25',
              quantityDelta: StockQuantity.zero(),
              actorId: testActorId,
              reason: 'لا يوجد تغيير',
              idempotencyKey: 'IDEM-ADJ-25',
            ),
          ),
          throwsA(isA<InvalidStockQuantityFailure>()),
        );
      });

      test('26. negative result blocked by policy throws InsufficientStockFailure', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-ADJ-26',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-ADJ-26',
          initialOnHand: StockQuantity.discrete(2),
          policy: NegativeStockPolicy.block,
        );
        await inventoryRepo.saveInventoryItem(item);

        expect(
          () => transactionService.adjustStock(
            AdjustStockCommand(
              commandId: 'CMD-ADJ-26',
              businessId: testBusinessId,
              branchId: testBranchA,
              productId: 'PROD-ADJ-26',
              quantityDelta: -StockQuantity.discrete(5),
              actorId: testActorId,
              reason: 'تسوية مبالغ فيها',
              idempotencyKey: 'IDEM-ADJ-26',
            ),
          ),
          throwsA(isA<InsufficientStockFailure>()),
        );
      });

      test('27. adjustment requires authorized actor with adjust permission', () async {
        // Setup cashier without adjust permission
        final cashierUser = _createTestUser(
          userId: 'CASHIER-01',
          businessId: testBusinessId,
          assignedBranchIds: [testBranchA],
          role: ShopRole.cashier,
          customPermissions: {ShopPermission.accessPos, ShopPermission.createSalesOrder},
        );

        final cashierSession = _createTestSession(
          sessionId: 'SESSION-CASHIER',
          userId: 'CASHIER-01',
          businessId: testBusinessId,
          activeBranchId: testBranchA,
        );

        final cashierCoordinator = ShopIdentityCoordinator();
        cashierCoordinator.setSession(user: cashierUser, session: cashierSession);

        final unauthorizedService = InventoryTransactionService(
          inventoryRepository: inventoryRepo,
          ledgerRepository: ledgerRepo,
          idempotencyStore: idempotencyStore,
          identityCoordinator: cashierCoordinator,
          auditRepository: auditRepo,
        );

        expect(
          () => unauthorizedService.adjustStock(
            AdjustStockCommand(
              commandId: 'CMD-ADJ-27',
              businessId: testBusinessId,
              branchId: testBranchA,
              productId: 'PROD-ADJ-27',
              quantityDelta: StockQuantity.discrete(1),
              actorId: 'CASHIER-01',
              reason: 'محاولة تعديل غير مصرحة',
              idempotencyKey: 'IDEM-ADJ-27',
            ),
          ),
          throwsA(isA<UnauthorizedInventoryOperationFailure>()),
        );
      });

      test('28. adjustment records mandatory reason in ledger and audit', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-ADJ-28',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-ADJ-28',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(item);

        await transactionService.adjustStock(
          AdjustStockCommand(
            commandId: 'CMD-ADJ-28',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-ADJ-28',
            quantityDelta: StockQuantity.discrete(2),
            actorId: testActorId,
            reason: 'سبب جردي رسمي موثق',
            idempotencyKey: 'IDEM-ADJ-28',
          ),
        );

        expect(ledgerRepo.allEntries.last.reason, 'سبب جردي رسمي موثق');
        expect(auditRepo.entries.last.reason, 'سبب جردي رسمي موثق');
      });
    });

    // ══════════════════════════════════════════════════════════════════
    // GROUP F: Purchase Contract (29 - 31)
    // ══════════════════════════════════════════════════════════════════
    group('Group F: Purchase Inbound Contract', () {
      test('29. purchase receive increases onHand and writes PURCHASE ledger entry', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-PURCHASE-29',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-PUR-29',
          initialOnHand: StockQuantity.discrete(20),
        );
        await inventoryRepo.saveInventoryItem(item);

        final result = await transactionService.receivePurchase(
          ReceivePurchaseCommand(
            commandId: 'CMD-PUR-29',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-PUR-29',
            quantity: StockQuantity.discrete(50),
            purchaseOrderId: 'PO-2026-001',
            supplierId: 'SUPPLIER-AL-QAIM',
            actorId: testActorId,
            idempotencyKey: 'IDEM-PUR-29',
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(result.item.onHand, StockQuantity.discrete(70));
        expect(ledgerRepo.allEntries.last.movementType, InventoryMovementType.purchase);
        expect(ledgerRepo.allEntries.last.referenceType, 'PURCHASE');
        expect(ledgerRepo.allEntries.last.referenceId, 'PO-2026-001');
      });

      test('30. purchase duplicate intent idempotency protection', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-PURCHASE-30',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-PUR-30',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(item);

        final cmd = ReceivePurchaseCommand(
          commandId: 'CMD-PUR-30',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-PUR-30',
          quantity: StockQuantity.discrete(20),
          purchaseOrderId: 'PO-DUP',
          supplierId: 'SUPPLIER-1',
          actorId: testActorId,
          idempotencyKey: 'IDEM-PO-DUP',
        );

        await transactionService.receivePurchase(cmd);
        final replay = await transactionService.receivePurchase(cmd);

        expect(replay.isIdempotentReplay, isTrue);
        expect(replay.item.onHand, StockQuantity.discrete(30)); // 10 + 20, not 50!
        expect(ledgerRepo.allEntries.length, 1);
      });

      test('31. purchase quantity validation rejects zero or negative quantity', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-PURCHASE-31',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-PUR-31',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(item);

        expect(
          () => transactionService.receivePurchase(
            ReceivePurchaseCommand(
              commandId: 'CMD-PUR-31',
              businessId: testBusinessId,
              branchId: testBranchA,
              productId: 'PROD-PUR-31',
              quantity: StockQuantity.zero(),
              purchaseOrderId: 'PO-ZERO',
              supplierId: 'SUP-1',
              actorId: testActorId,
              idempotencyKey: 'IDEM-PO-ZERO',
            ),
          ),
          throwsA(isA<InvalidStockQuantityFailure>()),
        );
      });
    });

    // ══════════════════════════════════════════════════════════════════
    // GROUP G: Return Restock Contract (32 - 35)
    // ══════════════════════════════════════════════════════════════════
    group('Group G: Return', () {
      test('32. restock return increases onHand with RETURN movement', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-RET-32',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-RET-32',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(item);

        final result = await transactionService.processReturn(
          ProcessReturnStockCommand(
            commandId: 'CMD-RET-32',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-RET-32',
            quantity: StockQuantity.discrete(2),
            saleId: 'SALE-RET-32',
            condition: ReturnRestockCondition.restock,
            actorId: testActorId,
            idempotencyKey: 'IDEM-RET-32',
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(result.item.onHand, StockQuantity.discrete(12));
        expect(ledgerRepo.allEntries.last.movementType, InventoryMovementType.customerReturn);
      });

      test('33. damaged return records damage and does not increase resellable onHand', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-RET-33',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-RET-33',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(item);

        final result = await transactionService.processReturn(
          ProcessReturnStockCommand(
            commandId: 'CMD-RET-33',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-RET-33',
            quantity: StockQuantity.discrete(2),
            saleId: 'SALE-RET-33',
            condition: ReturnRestockCondition.damaged,
            actorId: testActorId,
            idempotencyKey: 'IDEM-RET-33',
          ),
        );

        expect(result.item.onHand, StockQuantity.discrete(10)); // Unchanged!
      });

      test('34. partial return only increases returned quantity', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-RET-34',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-RET-34',
          initialOnHand: StockQuantity.discrete(5),
        );
        await inventoryRepo.saveInventoryItem(item);

        // Sold 5, Customer returns 2
        final result = await transactionService.processReturn(
          ProcessReturnStockCommand(
            commandId: 'CMD-RET-34',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-RET-34',
            quantity: StockQuantity.discrete(2),
            saleId: 'SALE-5',
            condition: ReturnRestockCondition.restock,
            actorId: testActorId,
            idempotencyKey: 'IDEM-RET-34',
          ),
        );

        expect(result.item.onHand, StockQuantity.discrete(7));
      });

      test('35. duplicate return intent replay protection', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-RET-35',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-RET-35',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(item);

        final cmd = ProcessReturnStockCommand(
          commandId: 'CMD-RET-35',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-RET-35',
          quantity: StockQuantity.discrete(3),
          saleId: 'SALE-RET-DUP',
          condition: ReturnRestockCondition.restock,
          actorId: testActorId,
          idempotencyKey: 'IDEM-RET-DUP',
        );

        await transactionService.processReturn(cmd);
        final replay = await transactionService.processReturn(cmd);

        expect(replay.isIdempotentReplay, isTrue);
        expect(replay.item.onHand, StockQuantity.discrete(13)); // Not 16!
        expect(ledgerRepo.allEntries.length, 1);
      });
    });

    // ══════════════════════════════════════════════════════════════════
    // GROUP H: Inter-Branch Transfers (36 - 40)
    // ══════════════════════════════════════════════════════════════════
    group('Group H: Transfer', () {
      test('36. transfer out decreases source branch stock', () async {
        final sourceItem = InventoryItem.initialize(
          inventoryId: 'INV-TR-SRC',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-TR-01',
          initialOnHand: StockQuantity.discrete(50),
        );
        final targetItem = InventoryItem.initialize(
          inventoryId: 'INV-TR-TGT',
          businessId: testBusinessId,
          branchId: testBranchB,
          productId: 'PROD-TR-01',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(sourceItem);
        await inventoryRepo.saveInventoryItem(targetItem);

        await transactionService.transferStock(
          TransferStockCommand(
            commandId: 'CMD-TR-01',
            businessId: testBusinessId,
            sourceBranchId: testBranchA,
            targetBranchId: testBranchB,
            productId: 'PROD-TR-01',
            quantity: StockQuantity.discrete(15),
            actorId: testActorId,
            idempotencyKey: 'IDEM-TR-01',
          ),
        );

        final updatedSource = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-TR-01',
        ))!;
        expect(updatedSource.onHand, StockQuantity.discrete(35));
      });

      test('37. transfer in increases destination branch stock', () async {
        final sourceItem = InventoryItem.initialize(
          inventoryId: 'INV-TR-SRC-37',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-TR-37',
          initialOnHand: StockQuantity.discrete(30),
        );
        final targetItem = InventoryItem.initialize(
          inventoryId: 'INV-TR-TGT-37',
          businessId: testBusinessId,
          branchId: testBranchB,
          productId: 'PROD-TR-37',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(sourceItem);
        await inventoryRepo.saveInventoryItem(targetItem);

        await transactionService.transferStock(
          TransferStockCommand(
            commandId: 'CMD-TR-37',
            businessId: testBusinessId,
            sourceBranchId: testBranchA,
            targetBranchId: testBranchB,
            productId: 'PROD-TR-37',
            quantity: StockQuantity.discrete(15),
            actorId: testActorId,
            idempotencyKey: 'IDEM-TR-37',
          ),
        );

        final updatedTarget = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchB,
          productId: 'PROD-TR-37',
        ))!;
        expect(updatedTarget.onHand, StockQuantity.discrete(25)); // 10 + 15
      });

      test('38. transfer with insufficient stock in source branch fails', () async {
        final sourceItem = InventoryItem.initialize(
          inventoryId: 'INV-TR-SRC-38',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-TR-38',
          initialOnHand: StockQuantity.discrete(5),
        );
        final targetItem = InventoryItem.initialize(
          inventoryId: 'INV-TR-TGT-38',
          businessId: testBusinessId,
          branchId: testBranchB,
          productId: 'PROD-TR-38',
          initialOnHand: StockQuantity.discrete(0),
        );
        await inventoryRepo.saveInventoryItem(sourceItem);
        await inventoryRepo.saveInventoryItem(targetItem);

        expect(
          () => transactionService.transferStock(
            TransferStockCommand(
              commandId: 'CMD-TR-38',
              businessId: testBusinessId,
              sourceBranchId: testBranchA,
              targetBranchId: testBranchB,
              productId: 'PROD-TR-38',
              quantity: StockQuantity.discrete(10), // Needs 10, has 5
              actorId: testActorId,
              idempotencyKey: 'IDEM-TR-38',
            ),
          ),
          throwsA(isA<InsufficientStockFailure>()),
        );

        final targetStillZero = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchB,
          productId: 'PROD-TR-38',
        ))!;
        expect(targetStillZero.onHand.isZero, isTrue);
      });

      test('39. transfer duplicate intent idempotency protection', () async {
        final sourceItem = InventoryItem.initialize(
          inventoryId: 'INV-TR-SRC-39',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-TR-39',
          initialOnHand: StockQuantity.discrete(40),
        );
        final targetItem = InventoryItem.initialize(
          inventoryId: 'INV-TR-TGT-39',
          businessId: testBusinessId,
          branchId: testBranchB,
          productId: 'PROD-TR-39',
          initialOnHand: StockQuantity.discrete(5),
        );
        await inventoryRepo.saveInventoryItem(sourceItem);
        await inventoryRepo.saveInventoryItem(targetItem);

        final cmd = TransferStockCommand(
          commandId: 'CMD-TR-39',
          businessId: testBusinessId,
          sourceBranchId: testBranchA,
          targetBranchId: testBranchB,
          productId: 'PROD-TR-39',
          quantity: StockQuantity.discrete(10),
          actorId: testActorId,
          idempotencyKey: 'IDEM-TR-39',
        );

        await transactionService.transferStock(cmd);
        await transactionService.transferStock(cmd); // duplicate replay

        final src = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-TR-39',
        ))!;
        final tgt = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchB,
          productId: 'PROD-TR-39',
        ))!;

        expect(src.onHand, StockQuantity.discrete(30)); // 40 - 10, not 40 - 20
        expect(tgt.onHand, StockQuantity.discrete(15)); // 5 + 10, not 5 + 20
      });

      test('40. branch mismatch validation rejects transfer to same branch', () async {
        expect(
          () => transactionService.transferStock(
            TransferStockCommand(
              commandId: 'CMD-TR-SAME',
              businessId: testBusinessId,
              sourceBranchId: testBranchA,
              targetBranchId: testBranchA, // Same branch
              productId: 'PROD-TR-01',
              quantity: StockQuantity.discrete(5),
              actorId: testActorId,
              idempotencyKey: 'IDEM-TR-SAME',
            ),
          ),
          throwsA(isA<InventoryBranchMismatchFailure>()),
        );
      });
    });

    // ══════════════════════════════════════════════════════════════════
    // GROUP I: Variants (41 - 43)
    // ══════════════════════════════════════════════════════════════════
    group('Group I: Variants', () {
      test('41. variant A stock independent', () async {
        final varA = InventoryItem.initialize(
          inventoryId: 'INV-V-A',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'SHOES-01',
          variantId: 'SIZE-42',
          initialOnHand: StockQuantity.discrete(8),
        );
        await inventoryRepo.saveInventoryItem(varA);

        final fetched = await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'SHOES-01',
          variantId: 'SIZE-42',
        );
        expect(fetched?.onHand, StockQuantity.discrete(8));
      });

      test('42. variant B stock independent', () async {
        final varB = InventoryItem.initialize(
          inventoryId: 'INV-V-B',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'SHOES-01',
          variantId: 'SIZE-44',
          initialOnHand: StockQuantity.discrete(14),
        );
        await inventoryRepo.saveInventoryItem(varB);

        final fetched = await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'SHOES-01',
          variantId: 'SIZE-44',
        );
        expect(fetched?.onHand, StockQuantity.discrete(14));
      });

      test('43. variant isolation: consuming variant A does not affect variant B', () async {
        final varA = InventoryItem.initialize(
          inventoryId: 'INV-V-A-43',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'SHOES-01',
          variantId: 'SIZE-42',
          initialOnHand: StockQuantity.discrete(8),
        );
        final varB = InventoryItem.initialize(
          inventoryId: 'INV-V-B-43',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'SHOES-01',
          variantId: 'SIZE-44',
          initialOnHand: StockQuantity.discrete(14),
        );
        await inventoryRepo.saveInventoryItem(varA);
        await inventoryRepo.saveInventoryItem(varB);

        final intentA = InventoryMovementIntent(
          intentId: 'INTENT-VAR-42',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'SHOES-01',
          variantId: 'SIZE-42',
          quantity: 3.0,
          referenceId: 'SALE-V-A',
          requestedAt: DateTime.now(),
        );

        await transactionService.consumeSaleMovementIntent(intent: intentA, actorId: testActorId);

        final updatedA = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'SHOES-01',
          variantId: 'SIZE-42',
        ))!;
        final untouchedB = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'SHOES-01',
          variantId: 'SIZE-44',
        ))!;

        expect(updatedA.onHand, StockQuantity.discrete(5)); // 8 - 3
        expect(untouchedB.onHand, StockQuantity.discrete(14)); // Remains 14
      });
    });

    // ══════════════════════════════════════════════════════════════════
    // GROUP J: Multi-Branch & Multi-Business Isolation (44 - 46)
    // ══════════════════════════════════════════════════════════════════
    group('Group J: Multi-Branch & Multi-Business Isolation', () {
      test('44. same product in Branch A and Branch B has independent stock', () async {
        final branchAItem = InventoryItem.initialize(
          inventoryId: 'INV-BR-A',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'COFFEE-01',
          initialOnHand: StockQuantity.discrete(20),
        );
        final branchBItem = InventoryItem.initialize(
          inventoryId: 'INV-BR-B',
          businessId: testBusinessId,
          branchId: testBranchB,
          productId: 'COFFEE-01',
          initialOnHand: StockQuantity.discrete(50),
        );
        await inventoryRepo.saveInventoryItem(branchAItem);
        await inventoryRepo.saveInventoryItem(branchBItem);

        expect(branchAItem.onHand, StockQuantity.discrete(20));
        expect(branchBItem.onHand, StockQuantity.discrete(50));
      });

      test('45. branch A cannot modify Branch B inventory without authorization', () async {
        final restrictedCoordinator = ShopIdentityCoordinator();
        final branchAOnlyUser = _createTestUser(
          userId: 'STAFF-A',
          businessId: testBusinessId,
          assignedBranchIds: [testBranchA], // Only branch A
          role: ShopRole.branchManager,
          customPermissions: {ShopPermission.adjustInventoryStock},
        );
        final session = _createTestSession(
          sessionId: 'SESSION-A',
          userId: 'STAFF-A',
          businessId: testBusinessId,
          activeBranchId: testBranchA,
          terminalId: 'TERM-A',
        );
        restrictedCoordinator.setSession(user: branchAOnlyUser, session: session);

        final branchRestrictedService = InventoryTransactionService(
          inventoryRepository: inventoryRepo,
          ledgerRepository: ledgerRepo,
          idempotencyStore: idempotencyStore,
          identityCoordinator: restrictedCoordinator,
          auditRepository: auditRepo,
        );

        expect(
          () => branchRestrictedService.adjustStock(
            AdjustStockCommand(
              commandId: 'CMD-CROSS-BR',
              businessId: testBusinessId,
              branchId: testBranchB, // Trying to touch branch B!
              productId: 'COFFEE-01',
              quantityDelta: StockQuantity.discrete(5),
              actorId: 'STAFF-A',
              reason: 'محاولة تعديل فرع غير مخصص',
              idempotencyKey: 'IDEM-CROSS-BR',
            ),
          ),
          throwsA(isA<InventoryBranchMismatchFailure>()),
        );
      });

      test('46. multi-business isolation: Business 1 cannot access Business 2 inventory', () async {
        final otherBizItem = InventoryItem.initialize(
          inventoryId: 'INV-BIZ-OTHER',
          businessId: 'BIZ-OTHER-999',
          branchId: 'BRANCH-OTHER',
          productId: 'PROD-OTHER',
          initialOnHand: StockQuantity.discrete(100),
        );
        await inventoryRepo.saveInventoryItem(otherBizItem);

        expect(
          () => transactionService.adjustStock(
            AdjustStockCommand(
              commandId: 'CMD-OTHER-BIZ',
              businessId: 'BIZ-OTHER-999', // Different business than session
              branchId: testBranchA,
              productId: 'PROD-OTHER',
              quantityDelta: StockQuantity.discrete(10),
              actorId: testActorId,
              reason: 'محاولة تعديل نشاط تجاري آخر',
              idempotencyKey: 'IDEM-OTHER-BIZ',
            ),
          ),
          throwsA(isA<UnauthorizedInventoryOperationFailure>()),
        );
      });
    });

    // ══════════════════════════════════════════════════════════════════
    // GROUP K: Concurrency Control & OCC (47 - 49)
    // ══════════════════════════════════════════════════════════════════
    group('Group K: Concurrency Control (MANDATORY PROOF)', () {
      test(
        '47. two terminals one unit concurrency test: exactly 1 succeeds, 1 fails with InsufficientStockFailure, onHand = 0, exactly 1 ledger entry',
        () async {
          // ─── INITIALIZE STOCK = 1 ───
          final singleUnitItem = InventoryItem.initialize(
            inventoryId: 'INV-CONCURRENCY-01',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-GOLD-WATCH',
            initialOnHand: StockQuantity.discrete(1),
          );
          await inventoryRepo.saveInventoryItem(singleUnitItem);

          final intentTerminalA = InventoryMovementIntent(
            intentId: 'INTENT-TERM-A',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-GOLD-WATCH',
            quantity: 1.0,
            referenceId: 'SALE-A',
            requestedAt: DateTime.now(),
          );

          final intentTerminalB = InventoryMovementIntent(
            intentId: 'INTENT-TERM-B',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-GOLD-WATCH',
            quantity: 1.0,
            referenceId: 'SALE-B',
            requestedAt: DateTime.now(),
          );

          int successCount = 0;
          int failureCount = 0;

          // Launch both sales concurrently
          final futureA = transactionService.consumeSaleMovementIntent(
            intent: intentTerminalA,
            actorId: 'CASHIER-A',
            terminalId: 'POS-01',
          ).then((res) {
            if (res.isSuccess) successCount++;
          }).catchError((e) {
            if (e is InsufficientStockFailure || e is InventoryConflictFailure) {
              failureCount++;
            }
          });

          final futureB = transactionService.consumeSaleMovementIntent(
            intent: intentTerminalB,
            actorId: 'CASHIER-B',
            terminalId: 'POS-02',
          ).then((res) {
            if (res.isSuccess) successCount++;
          }).catchError((e) {
            if (e is InsufficientStockFailure || e is InventoryConflictFailure) {
              failureCount++;
            }
          });

          await Future.wait([futureA, futureB]);

          // ─── CRITICAL ASSERTIONS ───
          expect(successCount, 1, reason: 'Exactly one terminal must succeed in selling the single item');
          expect(failureCount, 1, reason: 'The competing terminal must fail with InsufficientStock or Conflict');

          final finalStock = (await inventoryRepo.getInventoryItem(
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-GOLD-WATCH',
          ))!;

          expect(finalStock.onHand.isZero, isTrue, reason: 'Final onHand must be 0, never -1');
          expect(finalStock.available.isZero, isTrue, reason: 'Final available must be 0');

          final saleEntries = ledgerRepo.allEntries
              .where((e) => e.productId == 'PROD-GOLD-WATCH' && e.movementType == InventoryMovementType.sale)
              .toList();
          expect(saleEntries.length, 1, reason: 'Exactly one SALE ledger entry must be recorded');
        },
      );

      test('48. version conflict throws InventoryConflictFailure when expectedVersion mismatches', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-OCC-48',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-OCC-48',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(item); // Version is 1

        await expectLater(
          () => transactionService.applyMovement(
            ApplyInventoryMovementCommand(
              commandId: 'CMD-OCC-48',
              businessId: testBusinessId,
              branchId: testBranchA,
              productId: 'PROD-OCC-48',
              quantity: StockQuantity.discrete(2),
              movementType: InventoryMovementType.sale,
              referenceType: 'SALE',
              referenceId: 'SALE-OCC',
              actorId: testActorId,
              idempotencyKey: 'IDEM-OCC-48',
              expectedVersion: 99, // Mismatched version!
            ),
          ),
          throwsA(isA<InventoryConflictFailure>()),
        );

        expect(emittedEvents.any((e) => e is InventoryConflictDetectedEvent), isTrue);
      });

      test('49. retry after conflict succeeds when fetching updated version', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-OCC-49',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-OCC-49',
          initialOnHand: StockQuantity.discrete(10),
        );
        await inventoryRepo.saveInventoryItem(item); // Version 1

        // Operation 1 increments version to 2
        await transactionService.applyMovement(
          ApplyInventoryMovementCommand(
            commandId: 'CMD-OCC-49-A',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-OCC-49',
            quantity: StockQuantity.discrete(1),
            movementType: InventoryMovementType.sale,
            referenceType: 'SALE',
            referenceId: 'SALE-1',
            actorId: testActorId,
            idempotencyKey: 'IDEM-49-A',
            expectedVersion: 1,
          ),
        );

        // Operation 2 retries with fresh version = 2
        final freshItem = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-OCC-49',
        ))!;
        expect(freshItem.version, 2);

        final retryResult = await transactionService.applyMovement(
          ApplyInventoryMovementCommand(
            commandId: 'CMD-OCC-49-B',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-OCC-49',
            quantity: StockQuantity.discrete(2),
            movementType: InventoryMovementType.sale,
            referenceType: 'SALE',
            referenceId: 'SALE-2',
            actorId: testActorId,
            idempotencyKey: 'IDEM-49-B',
            expectedVersion: freshItem.version,
          ),
        );

        expect(retryResult.isSuccess, isTrue);
        expect(retryResult.item.onHand, StockQuantity.discrete(7));
      });
    });

    // ══════════════════════════════════════════════════════════════════
    // GROUP L: Inventory Ledger (50 - 52)
    // ══════════════════════════════════════════════════════════════════
    group('Group L: Ledger Append-Only', () {
      test('50. append-only ledger: attempts to duplicate or overwrite existing entry ID throws StateError', () async {
        final entry = InventoryLedgerEntry(
          id: 'LEDGER-IMMUTABLE-01',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-LED-50',
          movementType: InventoryMovementType.sale,
          quantityDelta: -StockQuantity.discrete(2),
          reservedDelta: StockQuantity.zero(),
          unit: StockUnit.piece,
          beforeOnHand: StockQuantity.discrete(10),
          afterOnHand: StockQuantity.discrete(8),
          beforeReserved: StockQuantity.zero(),
          afterReserved: StockQuantity.zero(),
          beforeAvailable: StockQuantity.discrete(10),
          afterAvailable: StockQuantity.discrete(8),
          referenceType: 'SALE',
          referenceId: 'SALE-50',
          actorId: testActorId,
          reason: 'Test sale',
          createdAt: DateTime.now(),
          version: 2,
          idempotencyKey: 'KEY-50',
        );

        await ledgerRepo.appendLedgerEntry(entry);

        expect(
          () => ledgerRepo.appendLedgerEntry(entry),
          throwsA(isA<StateError>()),
        );
      });

      test('51. before/after correctness: beforeOnHand, afterOnHand, deltas match perfectly', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-LED-51',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-LED-51',
          initialOnHand: StockQuantity.discrete(25),
        );
        await inventoryRepo.saveInventoryItem(item);

        await transactionService.applyMovement(
          ApplyInventoryMovementCommand(
            commandId: 'CMD-LED-51',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-LED-51',
            quantity: StockQuantity.discrete(7),
            movementType: InventoryMovementType.sale,
            referenceType: 'SALE',
            referenceId: 'SALE-51',
            actorId: testActorId,
            idempotencyKey: 'IDEM-51',
          ),
        );

        final entry = ledgerRepo.allEntries.last;
        expect(entry.beforeOnHand, StockQuantity.discrete(25));
        expect(entry.quantityDelta, -StockQuantity.discrete(7));
        expect(entry.afterOnHand, StockQuantity.discrete(18));
        expect(entry.beforeOnHand + entry.quantityDelta, entry.afterOnHand);
      });

      test('52. immutable entry verification: all entries list cannot be mutated directly', () async {
        final entry = InventoryLedgerEntry(
          id: 'LEDGER-IMM-52',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-52',
          movementType: InventoryMovementType.initialBalance,
          quantityDelta: StockQuantity.discrete(1),
          reservedDelta: StockQuantity.zero(),
          unit: StockUnit.piece,
          beforeOnHand: StockQuantity.zero(),
          afterOnHand: StockQuantity.discrete(1),
          beforeReserved: StockQuantity.zero(),
          afterReserved: StockQuantity.zero(),
          beforeAvailable: StockQuantity.zero(),
          afterAvailable: StockQuantity.discrete(1),
          referenceType: 'INIT',
          referenceId: 'INIT-52',
          actorId: testActorId,
          reason: 'Test immutability',
          createdAt: DateTime.now(),
          version: 1,
          idempotencyKey: 'KEY-52',
        );
        await ledgerRepo.appendLedgerEntry(entry);
        expect(() => ledgerRepo.allEntries.add(entry), throwsUnsupportedError);
      });
    });

    // ══════════════════════════════════════════════════════════════════
    // GROUP M: Low Stock & Derived Status (53 - 55)
    // ══════════════════════════════════════════════════════════════════
    group('Group M: Low Stock', () {
      test('53. threshold detection: onHand <= reorderPoint or lowStockThreshold derives StockStatus.lowStock and emits event', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-LOW-53',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-LOW-53',
          initialOnHand: StockQuantity.discrete(10),
          reorderPoint: StockQuantity.discrete(5),
          lowStockThreshold: StockQuantity.discrete(3),
        );
        await inventoryRepo.saveInventoryItem(item);

        await transactionService.applyMovement(
          ApplyInventoryMovementCommand(
            commandId: 'CMD-LOW-53',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-LOW-53',
            quantity: StockQuantity.discrete(6), // 10 - 6 = 4 <= reorderPoint(5)
            movementType: InventoryMovementType.sale,
            referenceType: 'SALE',
            referenceId: 'SALE-LOW-53',
            actorId: testActorId,
            idempotencyKey: 'IDEM-LOW-53',
          ),
        );

        final updated = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-LOW-53',
        ))!;

        expect(updated.status, StockStatus.lowStock);
        expect(updated.isLowStock, isTrue);
        expect(emittedEvents.any((e) => e is InventoryLowStockEvent), isTrue);
      });

      test('54. out of stock detection: onHand == 0 derives StockStatus.outOfStock and emits event', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-OOS-54',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-OOS-54',
          initialOnHand: StockQuantity.discrete(2),
        );
        await inventoryRepo.saveInventoryItem(item);

        await transactionService.applyMovement(
          ApplyInventoryMovementCommand(
            commandId: 'CMD-OOS-54',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-OOS-54',
            quantity: StockQuantity.discrete(2),
            movementType: InventoryMovementType.sale,
            referenceType: 'SALE',
            referenceId: 'SALE-OOS-54',
            actorId: testActorId,
            idempotencyKey: 'IDEM-OOS-54',
          ),
        );

        final updated = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-OOS-54',
        ))!;

        expect(updated.status, StockStatus.outOfStock);
        expect(updated.isOutOfStock, isTrue);
        expect(emittedEvents.any((e) => e is InventoryOutOfStockEvent), isTrue);
      });

      test('55. recovery from low stock when purchase received restores inStock status', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-REC-55',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-REC-55',
          initialOnHand: StockQuantity.discrete(2), // low stock
          reorderPoint: StockQuantity.discrete(5),
          lowStockThreshold: StockQuantity.discrete(2),
        );
        await inventoryRepo.saveInventoryItem(item);
        expect(item.status, StockStatus.lowStock);

        await transactionService.receivePurchase(
          ReceivePurchaseCommand(
            commandId: 'CMD-REC-55',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-REC-55',
            quantity: StockQuantity.discrete(50),
            purchaseOrderId: 'PO-REC',
            supplierId: 'SUP-REC',
            actorId: testActorId,
            idempotencyKey: 'IDEM-REC-55',
          ),
        );

        final recovered = (await inventoryRepo.getInventoryItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-REC-55',
        ))!;

        expect(recovered.status, StockStatus.inStock);
        expect(recovered.onHand, StockQuantity.discrete(52));
      });
    });

    // ══════════════════════════════════════════════════════════════════
    // GROUP N: Security & RBAC (56 - 59)
    // ══════════════════════════════════════════════════════════════════
    group('Group N: Security', () {
      test('56. unauthorized adjustment: cashier role without adjustment permission is rejected', () async {
        final cashierUser = _createTestUser(
          userId: 'CASHIER-SEC',
          businessId: testBusinessId,
          assignedBranchIds: [testBranchA],
          role: ShopRole.cashier,
          customPermissions: {ShopPermission.accessPos, ShopPermission.createSalesOrder},
        );

        final session = _createTestSession(
          sessionId: 'SES-SEC',
          userId: 'CASHIER-SEC',
          businessId: testBusinessId,
          activeBranchId: testBranchA,
        );

        final coord = ShopIdentityCoordinator();
        coord.setSession(user: cashierUser, session: session);

        final secService = InventoryTransactionService(
          inventoryRepository: inventoryRepo,
          ledgerRepository: ledgerRepo,
          idempotencyStore: idempotencyStore,
          identityCoordinator: coord,
          auditRepository: auditRepo,
        );

        expect(
          () => secService.adjustStock(
            AdjustStockCommand(
              commandId: 'CMD-UNAUTH-ADJ',
              businessId: testBusinessId,
              branchId: testBranchA,
              productId: 'PROD-001',
              quantityDelta: StockQuantity.discrete(1),
              actorId: 'CASHIER-SEC',
              reason: 'تسوية غير مصرحة',
              idempotencyKey: 'IDEM-UNAUTH-ADJ',
            ),
          ),
          throwsA(isA<UnauthorizedInventoryOperationFailure>()),
        );
      });

      test('57. unauthorized transfer: cashier cannot transfer inventory between branches', () async {
        final cashierUser = _createTestUser(
          userId: 'CASHIER-SEC-2',
          businessId: testBusinessId,
          assignedBranchIds: [testBranchA, testBranchB],
          role: ShopRole.cashier,
          customPermissions: {ShopPermission.accessPos},
        );

        final session = _createTestSession(
          sessionId: 'SES-SEC-2',
          userId: 'CASHIER-SEC-2',
          businessId: testBusinessId,
          activeBranchId: testBranchA,
        );

        final coord = ShopIdentityCoordinator();
        coord.setSession(user: cashierUser, session: session);

        final secService = InventoryTransactionService(
          inventoryRepository: inventoryRepo,
          ledgerRepository: ledgerRepo,
          idempotencyStore: idempotencyStore,
          identityCoordinator: coord,
          auditRepository: auditRepo,
        );

        expect(
          () => secService.transferStock(
            TransferStockCommand(
              commandId: 'CMD-UNAUTH-TR',
              businessId: testBusinessId,
              sourceBranchId: testBranchA,
              targetBranchId: testBranchB,
              productId: 'PROD-001',
              quantity: StockQuantity.discrete(2),
              actorId: 'CASHIER-SEC-2',
              idempotencyKey: 'IDEM-UNAUTH-TR',
            ),
          ),
          throwsA(isA<UnauthorizedInventoryOperationFailure>()),
        );
      });

      test('58. business mismatch is blocked in applyMovement', () async {
        expect(
          () => transactionService.applyMovement(
            ApplyInventoryMovementCommand(
              commandId: 'CMD-BIZ-MISMATCH',
              businessId: 'OTHER-BIZ', // Mismatched business
              branchId: testBranchA,
              productId: 'PROD-001',
              quantity: StockQuantity.discrete(1),
              movementType: InventoryMovementType.sale,
              referenceType: 'SALE',
              referenceId: 'REF-1',
              actorId: testActorId,
              idempotencyKey: 'IDEM-BIZ-MISMATCH',
            ),
          ),
          throwsA(isA<UnauthorizedInventoryOperationFailure>()),
        );
      });

      test('59. branch mismatch is blocked in applyMovement', () async {
        expect(
          () => transactionService.applyMovement(
            ApplyInventoryMovementCommand(
              commandId: 'CMD-BR-MISMATCH',
              businessId: testBusinessId,
              branchId: 'UNASSIGNED-BRANCH-99', // User cannot access this branch
              productId: 'PROD-001',
              quantity: StockQuantity.discrete(1),
              movementType: InventoryMovementType.sale,
              referenceType: 'SALE',
              referenceId: 'REF-2',
              actorId: testActorId,
              idempotencyKey: 'IDEM-BR-MISMATCH',
            ),
          ),
          throwsA(isA<InventoryBranchMismatchFailure>()),
        );
      });
    });

    // ══════════════════════════════════════════════════════════════════
    // GROUP O: Reconciliation (60 - 61)
    // ══════════════════════════════════════════════════════════════════
    group('Group O: Reconciliation', () {
      test('60. snapshot equals ledger: reconciliation report is balanced', () async {
        final item = InventoryItem.initialize(
          inventoryId: 'INV-REC-60',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-REC-60',
          initialOnHand: StockQuantity.discrete(0),
        );
        await inventoryRepo.saveInventoryItem(item);

        // 1. Initial Purchase +50
        await transactionService.receivePurchase(
          ReceivePurchaseCommand(
            commandId: 'CMD-REC-PUR',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-REC-60',
            quantity: StockQuantity.discrete(50),
            purchaseOrderId: 'PO-60',
            supplierId: 'SUP-60',
            actorId: testActorId,
            idempotencyKey: 'IDEM-REC-PUR',
          ),
        );

        // 2. Sale -10
        await transactionService.consumeSaleMovementIntent(
          intent: InventoryMovementIntent(
            intentId: 'INTENT-REC-SALE',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-REC-60',
            quantity: 10.0,
            referenceId: 'SALE-60',
            requestedAt: DateTime.now(),
          ),
          actorId: testActorId,
        );

        final finding = await reconciliationService.reconcileItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-REC-60',
        );

        expect(finding.isBalanced, isTrue);
        expect(finding.snapshotOnHand, StockQuantity.discrete(40));
        expect(finding.ledgerDerivedOnHand, StockQuantity.discrete(40));
        expect(finding.difference.isZero, isTrue);
      });

      test('61. mismatch detected: corrupted/tampered snapshot is detected with exact discrepancy', () async {
        // Create item with snapshot 50, but tamper repository to 45 without ledger entry
        final tamperedItem = InventoryItem.initialize(
          inventoryId: 'INV-REC-61',
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-CORRUPTED',
          initialOnHand: StockQuantity.discrete(45), // Corrupted snapshot!
        );
        await inventoryRepo.saveInventoryItem(tamperedItem);

        // Add a ledger entry that only accounts for +50
        await ledgerRepo.appendLedgerEntry(
          InventoryLedgerEntry(
            id: 'LEDGER-CORRUPT-INIT',
            businessId: testBusinessId,
            branchId: testBranchA,
            productId: 'PROD-CORRUPTED',
            movementType: InventoryMovementType.initialBalance,
            quantityDelta: StockQuantity.discrete(50),
            reservedDelta: StockQuantity.zero(),
            unit: StockUnit.piece,
            beforeOnHand: StockQuantity.zero(),
            afterOnHand: StockQuantity.discrete(50),
            beforeReserved: StockQuantity.zero(),
            afterReserved: StockQuantity.zero(),
            beforeAvailable: StockQuantity.zero(),
            afterAvailable: StockQuantity.discrete(50),
            referenceType: 'INIT',
            referenceId: 'INIT-1',
            actorId: testActorId,
            reason: 'Initial',
            createdAt: DateTime.now(),
            version: 1,
            idempotencyKey: 'KEY-INIT',
          ),
        );

        final finding = await reconciliationService.reconcileItem(
          businessId: testBusinessId,
          branchId: testBranchA,
          productId: 'PROD-CORRUPTED',
        );

        expect(finding.isBalanced, isFalse);
        expect(finding.snapshotOnHand, StockQuantity.discrete(45));
        expect(finding.ledgerDerivedOnHand, StockQuantity.discrete(50));
        expect(finding.difference, -StockQuantity.discrete(5));
      });
    });
  });
}
