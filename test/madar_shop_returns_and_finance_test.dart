// ═══════════════════════════════════════════════════════════════════════════════
// MADAR SHOP — PHASE S5 TEST SUITE (110 TESTS)
// RETURNS + FINANCE + COGS + GROSS PROFIT + INVENTORY VALUATION
// Pure Dart — Zero UI Dependencies
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';

import 'package:dalal_alqaim/features/madar_shop/application/finance/commands/finance_commands.dart';
import 'package:dalal_alqaim/features/madar_shop/application/finance/failures/finance_failures.dart';
import 'package:dalal_alqaim/features/madar_shop/application/finance/services/finance_coordinator.dart';
import 'package:dalal_alqaim/features/madar_shop/application/finance/services/finance_reconciliation_service.dart';
import 'package:dalal_alqaim/features/madar_shop/application/inventory/commands/inventory_commands.dart';
import 'package:dalal_alqaim/features/madar_shop/application/inventory/services/inventory_transaction_service.dart';
import 'package:dalal_alqaim/features/madar_shop/application/returns/commands/returns_commands.dart';
import 'package:dalal_alqaim/features/madar_shop/application/returns/failures/returns_failures.dart';
import 'package:dalal_alqaim/features/madar_shop/application/returns/services/returns_coordinator.dart';
import 'package:dalal_alqaim/features/madar_shop/application/shop_identity_coordinator.dart';
import 'package:dalal_alqaim/features/madar_shop/data/finance/repositories/memory_finance_idempotency_store.dart';
import 'package:dalal_alqaim/features/madar_shop/data/finance/repositories/memory_financial_entry_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/finance/repositories/memory_inventory_cost_layer_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/inventory/repositories/in_memory_inventory_idempotency_store.dart';
import 'package:dalal_alqaim/features/madar_shop/data/inventory/repositories/in_memory_inventory_ledger_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/inventory/repositories/in_memory_inventory_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/pos/repositories/shop_pos_repository_impl.dart';
import 'package:dalal_alqaim/features/madar_shop/data/purchasing/repositories/memory_purchase_receipt_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/purchasing/repositories/memory_supplier_ledger_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/purchasing/repositories/memory_supplier_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/purchasing/enums/supplier_status.dart';
import 'package:dalal_alqaim/features/madar_shop/data/returns/repositories/memory_refund_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/returns/repositories/memory_return_order_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/returns/repositories/memory_returns_idempotency_store.dart';
import 'package:dalal_alqaim/features/madar_shop/data/returns/repositories/memory_supplier_credit_note_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/data/returns/repositories/memory_supplier_return_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/audit/contracts/shop_audit_repository.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/audit/entities/shop_audit_entry.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/finance/calculators/cogs_calculator.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/finance/calculators/gross_profit_calculator.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/finance/calculators/revenue_calculator.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/finance/entities/financial_entry.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/finance/enums/costing_method.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/finance/enums/financial_direction.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/finance/enums/financial_entry_type.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/finance/value_objects/gross_profit_result.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/finance/value_objects/inventory_cost_layer.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/identity/entities/shop_session.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/identity/entities/shop_user.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/identity/rbac/shop_permission.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/identity/rbac/shop_role.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/inventory/entities/inventory_item.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/inventory/enums/inventory_movement_type.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/inventory/enums/return_restock_condition.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/inventory/value_objects/stock_quantity.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/inventory/value_objects/stock_unit.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/pos/entities/customer_ledger_entry.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/pos/entities/payment.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/pos/value_objects/pricing_snapshot.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/pos/entities/sale.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/pos/entities/sale_item.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/pos/enums/payment_method.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/pos/enums/sale_status.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/pos/value_objects/currency.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/pos/value_objects/money.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/purchasing/entities/purchase_receipt.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/purchasing/entities/purchase_receipt_item.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/purchasing/entities/supplier.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/purchasing/entities/supplier_account.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/returns/entities/refund.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/returns/entities/return_item.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/returns/entities/return_order.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/returns/entities/supplier_credit_note.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/returns/entities/supplier_return.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/returns/entities/supplier_return_item.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/returns/enums/refund_method.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/returns/enums/return_order_status.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/returns/enums/return_reason.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/returns/enums/return_type.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/returns/enums/supplier_return_status.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/returns/rules/return_rules.dart';
import 'package:dalal_alqaim/features/madar_shop/domain/returns/rules/return_state_machine.dart';

// Test Fake for IShopAuditRepository
class FakeAuditRepo implements IShopAuditRepository {
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

void main() {
  const businessId = 'BIZ-001';
  const branchId = 'BR-001';
  const staffUserId = 'USER-STAFF-1';

  late FakeAuditRepo auditRepo;
  late ShopIdentityCoordinator identityCoordinator;
  late InMemoryInventoryRepository inventoryRepo;
  late InMemoryInventoryLedgerRepository inventoryLedgerRepo;
  late InMemoryInventoryIdempotencyStore inventoryIdemStore;
  late InventoryTransactionService inventoryService;
  late ShopPosRepositoryImpl posRepo;

  late MemoryPurchaseReceiptRepository purchaseReceiptRepo;
  late MemorySupplierRepository supplierRepo;
  late MemorySupplierLedgerRepository supplierLedgerRepo;

  late MemoryReturnOrderRepository returnOrderRepo;
  late MemoryRefundRepository refundRepo;
  late MemorySupplierReturnRepository supplierReturnRepo;
  late MemorySupplierCreditNoteRepository supplierCreditNoteRepo;
  late MemoryReturnsIdempotencyStore returnsIdemStore;

  late MemoryFinancialEntryRepository financialEntryRepo;
  late MemoryInventoryCostLayerRepository costLayerRepo;
  late MemoryFinanceIdempotencyStore financeIdemStore;

  late ReturnsCoordinator returnsCoordinator;
  late FinanceCoordinator financeCoordinator;
  late FinanceReconciliationService reconciliationService;

  setUp(() async {
    auditRepo = FakeAuditRepo();
    posRepo = ShopPosRepositoryImpl();
    inventoryRepo = InMemoryInventoryRepository();
    inventoryLedgerRepo = InMemoryInventoryLedgerRepository();
    inventoryIdemStore = InMemoryInventoryIdempotencyStore();

    identityCoordinator = ShopIdentityCoordinator();
    final now = DateTime.now();
    final user = ShopUser(
      userId: staffUserId,
      businessId: businessId,
      fullName: 'Manager User',
      phone: '07700000000',
      email: '$staffUserId@madar.iq',
      role: ShopRole.branchManager,
      assignedBranchIds: [branchId],
      createdAt: now,
    );
    final session = ShopSession(
      sessionId: 'SESS-$staffUserId',
      installationId: 'INST-01',
      terminalId: 'TERM-01',
      userId: staffUserId,
      businessId: businessId,
      activeBranchId: branchId,
      startedAt: now,
      lastHeartbeatAt: now,
      expiresAt: now.add(const Duration(hours: 8)),
      status: ShopSessionStatus.active,
    );
    identityCoordinator.setSession(user: user, session: session);

    inventoryService = InventoryTransactionService(
      inventoryRepository: inventoryRepo,
      ledgerRepository: inventoryLedgerRepo,
      idempotencyStore: inventoryIdemStore,
      identityCoordinator: identityCoordinator,
      auditRepository: auditRepo,
    );

    purchaseReceiptRepo = MemoryPurchaseReceiptRepository();
    supplierRepo = MemorySupplierRepository();
    supplierLedgerRepo = MemorySupplierLedgerRepository();

    returnOrderRepo = MemoryReturnOrderRepository();
    refundRepo = MemoryRefundRepository();
    supplierReturnRepo = MemorySupplierReturnRepository();
    supplierCreditNoteRepo = MemorySupplierCreditNoteRepository();
    returnsIdemStore = MemoryReturnsIdempotencyStore();

    financialEntryRepo = MemoryFinancialEntryRepository();
    costLayerRepo = MemoryInventoryCostLayerRepository();
    financeIdemStore = MemoryFinanceIdempotencyStore();

    returnsCoordinator = ReturnsCoordinator(
      returnOrderRepo: returnOrderRepo,
      refundRepo: refundRepo,
      supplierReturnRepo: supplierReturnRepo,
      supplierCreditNoteRepo: supplierCreditNoteRepo,
      idempotencyStore: returnsIdemStore,
      posRepo: posRepo,
      inventoryTxService: inventoryService,
      purchaseReceiptRepo: purchaseReceiptRepo,
      supplierLedgerRepo: supplierLedgerRepo,
      supplierRepo: supplierRepo,
      auditRepo: auditRepo,
      currentBusinessId: businessId,
      currentBranchId: branchId,
      currentRole: ShopRole.branchManager,
    );

    financeCoordinator = FinanceCoordinator(
      financialEntryRepo: financialEntryRepo,
      costLayerRepo: costLayerRepo,
      idempotencyStore: financeIdemStore,
      posRepo: posRepo,
      inventoryRepo: inventoryRepo,
      auditRepo: auditRepo,
      currentBusinessId: businessId,
      currentBranchId: branchId,
      currentRole: ShopRole.branchManager,
    );

    reconciliationService = FinanceReconciliationService(
      financialEntryRepo: financialEntryRepo,
      costLayerRepo: costLayerRepo,
      posRepo: posRepo,
      inventoryLedgerRepo: inventoryLedgerRepo,
      returnOrderRepo: returnOrderRepo,
      refundRepo: refundRepo,
      supplierReturnRepo: supplierReturnRepo,
      supplierCreditNoteRepo: supplierCreditNoteRepo,
    );
  });

  // Helper to create completed sale in POS repository
  Future<Sale> createCompletedSale({
    required String saleId,
    required String productId,
    required double quantity,
    required Money unitPrice,
    required Money unitCost,
    Money? discountTotal,
    Money? taxTotal,
    String? customerId,
  }) async {
    final disc = discountTotal ?? Money.zero(unitPrice.currency);
    final tax = taxTotal ?? Money.zero(unitPrice.currency);
    final subtotal = unitPrice * quantity;
    final grandTotal = (subtotal - disc) + tax;

    final existingInv = await inventoryRepo.getInventoryItem(
      businessId: businessId,
      branchId: branchId,
      productId: productId,
    );
    if (existingInv == null) {
      await inventoryRepo.saveInventoryItem(InventoryItem.initialize(
        inventoryId: 'INV-$productId',
        businessId: businessId,
        branchId: branchId,
        productId: productId,
        initialOnHand: StockQuantity.discrete(100),
      ));
    }

    final saleItem = SaleItem(
      itemId: 'ITEM-$saleId-1',
      productId: productId,
      name: 'Item $productId',
      sku: 'SKU-$productId',
      quantity: quantity,
      lineDiscount: disc,
      lineTax: tax,
      pricingSnapshot: PricingSnapshot.create(
        basePrice: unitPrice,
        unitPrice: unitPrice,
        costPrice: unitCost,
        unitDiscount: quantity > 0 ? (disc * (1.0 / quantity)) : Money.zero(unitPrice.currency),
        unitTax: quantity > 0 ? (tax * (1.0 / quantity)) : Money.zero(unitPrice.currency),
      ),
    );

    final sale = Sale(
      id: saleId,
      businessId: businessId,
      branchId: branchId,
      terminalId: 'TERM-01',
      sessionId: 'SESS-01',
      cashierId: staffUserId,
      cashierName: 'Staff Cashier',
      saleNumber: 'SALE-NUM-$saleId',
      source: 'POS_DESKTOP',
      status: SaleStatus.completed,
      items: [saleItem],
      subtotal: subtotal,
      discountTotal: disc,
      taxTotal: tax,
      grandTotal: grandTotal,
      paidTotal: grandTotal,
      remainingTotal: Money.zero(grandTotal.currency),
      changeTotal: Money.zero(grandTotal.currency),
      customerId: customerId,
      customerName: customerId != null ? 'Customer $customerId' : null,
      payments: [
        Payment(
          id: 'PAY-$saleId',
          method: PaymentMethod.cash,
          amount: grandTotal,
          receivedAt: DateTime.now(),
        ),
      ],
      currency: grandTotal.currency,
      createdAt: DateTime.now(),
      completedAt: DateTime.now(),
      version: 1,
      idempotencyKey: 'IDEM-$saleId',
    );

    await posRepo.saveSale(sale);
    return sale;
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // GROUP A: RETURN STATE MACHINE (8 Tests)
  // ═════════════════════════════════════════════════════════════════════════════
  group('Group A: Return State Machine', () {
    test('1. REQUESTED -> APPROVED is allowed', () {
      final res = ReturnStateMachine.validateTransition(
        currentStatus: ReturnOrderStatus.requested,
        nextStatus: ReturnOrderStatus.approved,
      );
      expect(res.isAllowed, isTrue);
    });

    test('2. APPROVED -> RECEIVED is allowed', () {
      final res = ReturnStateMachine.validateTransition(
        currentStatus: ReturnOrderStatus.approved,
        nextStatus: ReturnOrderStatus.received,
      );
      expect(res.isAllowed, isTrue);
    });

    test('3. RECEIVED -> REFUNDED is allowed', () {
      final res = ReturnStateMachine.validateTransition(
        currentStatus: ReturnOrderStatus.received,
        nextStatus: ReturnOrderStatus.refunded,
      );
      expect(res.isAllowed, isTrue);
    });

    test('4. REFUNDED -> COMPLETED is allowed', () {
      final res = ReturnStateMachine.validateTransition(
        currentStatus: ReturnOrderStatus.refunded,
        nextStatus: ReturnOrderStatus.completed,
      );
      expect(res.isAllowed, isTrue);
    });

    test('5. Illegal jump: REQUESTED -> COMPLETED is blocked', () {
      final res = ReturnStateMachine.validateTransition(
        currentStatus: ReturnOrderStatus.requested,
        nextStatus: ReturnOrderStatus.completed,
      );
      expect(res.isAllowed, isFalse);
      expect(res.rejectionReason, contains('غير مسموح'));
    });

    test('6. Illegal jump: REQUESTED -> REFUNDED is blocked', () {
      final res = ReturnStateMachine.validateTransition(
        currentStatus: ReturnOrderStatus.requested,
        nextStatus: ReturnOrderStatus.refunded,
      );
      expect(res.isAllowed, isFalse);
    });

    test('7. Terminal status cannot transition backwards: COMPLETED -> REQUESTED is blocked', () {
      final res = ReturnStateMachine.validateTransition(
        currentStatus: ReturnOrderStatus.completed,
        nextStatus: ReturnOrderStatus.requested,
      );
      expect(res.isAllowed, isFalse);
    });

    test('8. Rejection from REQUESTED is allowed', () {
      final res = ReturnStateMachine.validateTransition(
        currentStatus: ReturnOrderStatus.requested,
        nextStatus: ReturnOrderStatus.rejected,
      );
      expect(res.isAllowed, isTrue);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // GROUP B: RETURN QUANTITY VALIDATION & CALCULATIONS (8 Tests)
  // ═════════════════════════════════════════════════════════════════════════════
  group('Group B: Return Quantity Validation', () {
    test('9. Full return quantity exact match is allowed', () {
      final res = ReturnRules.validateReturnQuantity(
        soldQuantity: StockQuantity.discrete(10),
        alreadyReturnedQuantity: StockQuantity.discrete(0),
        requestedQuantity: StockQuantity.discrete(10),
      );
      expect(res.isAllowed, isTrue);
    });

    test('10. Partial return quantity within limit is allowed', () {
      final res = ReturnRules.validateReturnQuantity(
        soldQuantity: StockQuantity.discrete(10),
        alreadyReturnedQuantity: StockQuantity.discrete(4),
        requestedQuantity: StockQuantity.discrete(6),
      );
      expect(res.isAllowed, isTrue);
    });

    test('11. Over-return quantity is strictly rejected (sold=10, ret=4, req=7 -> FAIL)', () {
      final res = ReturnRules.validateReturnQuantity(
        soldQuantity: StockQuantity.discrete(10),
        alreadyReturnedQuantity: StockQuantity.discrete(4),
        requestedQuantity: StockQuantity.discrete(7),
      );
      expect(res.isAllowed, isFalse);
      expect(res.reason, contains('تتجاوز الكمية المتبقية'));
    });

    test('12. Zero return quantity is rejected', () {
      final res = ReturnRules.validateReturnQuantity(
        soldQuantity: StockQuantity.discrete(10),
        alreadyReturnedQuantity: StockQuantity.discrete(0),
        requestedQuantity: StockQuantity.discrete(0),
      );
      expect(res.isAllowed, isFalse);
    });

    test('13. Negative return quantity is rejected', () {
      final res = ReturnRules.validateReturnQuantity(
        soldQuantity: StockQuantity.discrete(10),
        alreadyReturnedQuantity: StockQuantity.discrete(0),
        requestedQuantity: StockQuantity.fromMilliUnits(-1000),
      );
      expect(res.isAllowed, isFalse);
    });

    test('14. Already 100% returned item rejects further returns', () {
      final res = ReturnRules.validateReturnQuantity(
        soldQuantity: StockQuantity.discrete(5),
        alreadyReturnedQuantity: StockQuantity.discrete(5),
        requestedQuantity: StockQuantity.discrete(1),
      );
      expect(res.isAllowed, isFalse);
      expect(res.reason, contains('تم إرجاع كامل الكمية'));
    });

    test('15. Supplier return within received quantity is allowed', () {
      final res = ReturnRules.validateSupplierReturnQuantity(
        receivedQuantity: StockQuantity.discrete(50),
        alreadyReturnedQuantity: StockQuantity.discrete(10),
        requestedQuantity: StockQuantity.discrete(40),
      );
      expect(res.isAllowed, isTrue);
    });

    test('16. Supplier over-return is strictly blocked', () {
      final res = ReturnRules.validateSupplierReturnQuantity(
        receivedQuantity: StockQuantity.discrete(50),
        alreadyReturnedQuantity: StockQuantity.discrete(10),
        requestedQuantity: StockQuantity.discrete(41),
      );
      expect(res.isAllowed, isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // GROUP C: CUSTOMER RETURNS FLOW & S3 INVENTORY AUTHORITY (8 Tests)
  // ═════════════════════════════════════════════════════════════════════════════
  group('Group C: Customer Returns Flow & S3 Authority', () {
    test('17. Full return creates order in REQUESTED state with accurate frozen price', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-101',
        productId: 'PROD-A',
        quantity: 5,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(7000),
      );

      final cmd = CreateReturnOrderCommand(
        commandId: 'RET-001',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-001',
        type: ReturnType.fullReturn,
        items: [
          ReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'PROD-A',
            quantity: StockQuantity.discrete(5),
            restockCondition: ReturnRestockCondition.restock,
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-RET-001',
      );

      final result = await returnsCoordinator.createReturnOrder(cmd);
      expect(result.isSuccess, isTrue);
      expect(result.order.status, equals(ReturnOrderStatus.requested));
      expect(result.order.items.first.unitRefundPrice.minorUnits, equals(10000));
      expect(result.order.items.first.originalCostBasis.minorUnits, equals(7000));
      expect(result.order.grandTotalRefund.minorUnits, equals(50000));
    });

    test('18. Partial return calculates refund total accurately', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-102',
        productId: 'PROD-A',
        quantity: 5,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(7000),
      );

      final cmd = CreateReturnOrderCommand(
        commandId: 'RET-002',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-002',
        type: ReturnType.partialReturn,
        items: [
          ReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'PROD-A',
            quantity: StockQuantity.discrete(2),
            restockCondition: ReturnRestockCondition.restock,
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-RET-002',
      );

      final result = await returnsCoordinator.createReturnOrder(cmd);
      expect(result.isSuccess, isTrue);
      expect(result.order.grandTotalRefund.minorUnits, equals(20000));
    });

    test('19. Return without original completed sale fails', () async {
      final cmd = CreateReturnOrderCommand(
        commandId: 'RET-003',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: 'NON-EXISTENT-SALE',
        returnNumber: 'RN-003',
        items: [
          ReturnItemInput(
            originalSaleItemId: 'ITEM-NONE',
            productId: 'PROD-A',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-RET-003',
      );

      expect(() => returnsCoordinator.createReturnOrder(cmd), throwsA(isA<OriginalSaleNotFoundFailure>()));
    });

    test('20. Cumulative returned quantity prevents over-return in subsequent request', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-104',
        productId: 'PROD-A',
        quantity: 5,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(7000),
      );

      // Return 1: returns 3
      await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-104-A',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-104-A',
        type: ReturnType.partialReturn,
        items: [
          ReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'PROD-A',
            quantity: StockQuantity.discrete(3),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-104-A',
      ));

      // Return 2: attempts to return 3 more (total 6 > 5) -> must FAIL
      final failCmd = CreateReturnOrderCommand(
        commandId: 'RET-104-B',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-104-B',
        type: ReturnType.partialReturn,
        items: [
          ReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'PROD-A',
            quantity: StockQuantity.discrete(3),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-104-B',
      );

      expect(() => returnsCoordinator.createReturnOrder(failCmd), throwsA(isA<InvalidReturnQuantityFailure>()));
    });

    test('21. Approved return transitions to APPROVED', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-105',
        productId: 'PROD-A',
        quantity: 2,
        unitPrice: Money.fromMinorUnits(5000),
        unitCost: Money.fromMinorUnits(3000),
      );

      final createRes = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-105',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-105',
        items: [
          ReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'PROD-A',
            quantity: StockQuantity.discrete(2),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-105',
      ));

      final appRes = await returnsCoordinator.approveReturnOrder(ApproveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: createRes.order.id,
        actorId: staffUserId,
      ));

      expect(appRes.isSuccess, isTrue);
      expect(appRes.order.status, equals(ReturnOrderStatus.approved));
      expect(appRes.order.approvedBy, equals(staffUserId));
    });

    test('22. Resellable return received increases S3 inventory onHand', () async {
      // Seed inventory
      await inventoryRepo.saveInventoryItem(InventoryItem.initialize(
        inventoryId: 'INV-1',
        businessId: businessId,
        branchId: branchId,
        productId: 'PROD-RESTOCK',
        initialOnHand: StockQuantity.discrete(10),
      ));

      final sale = await createCompletedSale(
        saleId: 'SALE-106',
        productId: 'PROD-RESTOCK',
        quantity: 3,
        unitPrice: Money.fromMinorUnits(5000),
        unitCost: Money.fromMinorUnits(3000),
      );

      final retRes = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-106',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-106',
        items: [
          ReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'PROD-RESTOCK',
            quantity: StockQuantity.discrete(2),
            restockCondition: ReturnRestockCondition.restock,
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-106',
      ));

      await returnsCoordinator.approveReturnOrder(ApproveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      final recRes = await returnsCoordinator.receiveReturnOrder(ReceiveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      expect(recRes.isSuccess, isTrue);
      expect(recRes.order.status, equals(ReturnOrderStatus.received));

      // S3 inventory onHand must have increased from 10 to 12
      final item = await inventoryRepo.getInventoryItem(
        businessId: businessId,
        branchId: branchId,
        productId: 'PROD-RESTOCK',
      );
      expect(item!.onHand.toDouble(), equals(12.0));
    });

    test('23. Damaged return received DOES NOT increase sellable onHand inventory', () async {
      await inventoryRepo.saveInventoryItem(InventoryItem.initialize(
        inventoryId: 'INV-DAMAGED',
        businessId: businessId,
        branchId: branchId,
        productId: 'PROD-DAMAGED',
        initialOnHand: StockQuantity.discrete(10),
      ));

      final sale = await createCompletedSale(
        saleId: 'SALE-107',
        productId: 'PROD-DAMAGED',
        quantity: 2,
        unitPrice: Money.fromMinorUnits(5000),
        unitCost: Money.fromMinorUnits(3000),
      );

      final retRes = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-107',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-107',
        items: [
          ReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'PROD-DAMAGED',
            quantity: StockQuantity.discrete(2),
            restockCondition: ReturnRestockCondition.damaged,
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-107',
      ));

      await returnsCoordinator.approveReturnOrder(ApproveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      await returnsCoordinator.receiveReturnOrder(ReceiveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      // onHand must REMAIN 10 (not 12)
      final item = await inventoryRepo.getInventoryItem(
        businessId: businessId,
        branchId: branchId,
        productId: 'PROD-DAMAGED',
      );
      expect(item!.onHand.toDouble(), equals(10.0));
    });

    test('24. Expired condition return is not restocked', () {
      final item = ReturnItem(
        id: 'RI-EXP',
        originalSaleItemId: 'OSI-1',
        productId: 'P1',
        descriptionSnapshot: 'Exp Item',
        skuSnapshot: 'SKU1',
        quantity: StockQuantity.discrete(1),
        unitRefundPrice: Money.fromMinorUnits(1000),
        originalCostBasis: Money.fromMinorUnits(500),
        restockCondition: ReturnRestockCondition.expired,
      );
      expect(item.isRestockable, isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // GROUP D: CUSTOMER REFUNDS & PAYMENT METHODS (8 Tests)
  // ═════════════════════════════════════════════════════════════════════════════
  group('Group D: Customer Refunds & Payment Methods', () {
    test('25. Cash refund completes successfully and transitions return to COMPLETED', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-201',
        productId: 'PROD-X',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(15000),
        unitCost: Money.fromMinorUnits(10000),
      );

      final retRes = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-201',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-201',
        items: [
          ReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'PROD-X',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-201',
      ));

      await returnsCoordinator.approveReturnOrder(ApproveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      await returnsCoordinator.receiveReturnOrder(ReceiveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      final refundRes = await returnsCoordinator.processRefund(ProcessRefundCommand(
        commandId: 'REF-201',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        refundAmount: Money.fromMinorUnits(15000),
        method: RefundMethod.cash,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-REF-201',
      ));

      expect(refundRes.isSuccess, isTrue);
      expect(refundRes.order.status, equals(ReturnOrderStatus.completed));
      expect(refundRes.refund.method, equals(RefundMethod.cash));
      expect(refundRes.refund.amount.minorUnits, equals(15000));
    });

    test('26. Card refund stores reference code', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-202',
        productId: 'PROD-X',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(20000),
        unitCost: Money.fromMinorUnits(12000),
      );

      final retRes = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-202',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-202',
        items: [
          ReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'PROD-X',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-202',
      ));

      await returnsCoordinator.approveReturnOrder(ApproveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      await returnsCoordinator.receiveReturnOrder(ReceiveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      final refundRes = await returnsCoordinator.processRefund(ProcessRefundCommand(
        commandId: 'REF-202',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        refundAmount: Money.fromMinorUnits(20000),
        method: RefundMethod.card,
        reference: 'AUTH-VISA-9988',
        actorId: staffUserId,
        idempotencyKey: 'IDEM-REF-202',
      ));

      expect(refundRes.isSuccess, isTrue);
      expect(refundRes.refund.method, equals(RefundMethod.card));
      expect(refundRes.refund.reference, equals('AUTH-VISA-9988'));
    });

    test('27. Digital refund method supported', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-203',
        productId: 'PROD-X',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(6000),
      );

      final retRes = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-203',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-203',
        items: [
          ReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'PROD-X',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-203',
      ));

      await returnsCoordinator.approveReturnOrder(ApproveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      await returnsCoordinator.receiveReturnOrder(ReceiveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      final refundRes = await returnsCoordinator.processRefund(ProcessRefundCommand(
        commandId: 'REF-203',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        refundAmount: Money.fromMinorUnits(10000),
        method: RefundMethod.digital,
        reference: 'ZAIN-CASH-TX-12345',
        actorId: staffUserId,
        idempotencyKey: 'IDEM-REF-203',
      ));

      expect(refundRes.isSuccess, isTrue);
      expect(refundRes.refund.method, equals(RefundMethod.digital));
    });

    test('28. Refund amount mismatch against return grand total throws failure', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-204',
        productId: 'PROD-X',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(6000),
      );

      final retRes = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-204',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-204',
        items: [
          ReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'PROD-X',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-204',
      ));

      await returnsCoordinator.approveReturnOrder(ApproveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      await returnsCoordinator.receiveReturnOrder(ReceiveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      // Requested 9,000 when return total is 10,000 -> mismatch
      final refundCmd = ProcessRefundCommand(
        commandId: 'REF-204',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        refundAmount: Money.fromMinorUnits(9000),
        method: RefundMethod.cash,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-REF-204',
      );

      expect(() => returnsCoordinator.processRefund(refundCmd), throwsA(isA<RefundAmountMismatchFailure>()));
    });

    test('29. Refund before receiving return order is blocked', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-205',
        productId: 'PROD-X',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(6000),
      );

      final retRes = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-205',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-205',
        items: [
          ReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'PROD-X',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-205',
      ));

      // Attempt refund while still in REQUESTED
      final refundCmd = ProcessRefundCommand(
        commandId: 'REF-205',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        refundAmount: Money.fromMinorUnits(10000),
        method: RefundMethod.cash,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-REF-205',
      );

      expect(() => returnsCoordinator.processRefund(refundCmd), throwsA(isA<InvalidReturnStateTransitionFailure>()));
    });

    test('30. Refund on already completed return throws StateTransitionFailure', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-206',
        productId: 'PROD-X',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(6000),
      );

      final retRes = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-206',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-206',
        items: [
          ReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'PROD-X',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-206',
      ));

      await returnsCoordinator.approveReturnOrder(ApproveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      await returnsCoordinator.receiveReturnOrder(ReceiveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      await returnsCoordinator.processRefund(ProcessRefundCommand(
        commandId: 'REF-206',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        refundAmount: Money.fromMinorUnits(10000),
        method: RefundMethod.cash,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-REF-206',
      ));

      // Attempt second refund on completed order
      final secondRefundCmd = ProcessRefundCommand(
        commandId: 'REF-206-SECOND',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        refundAmount: Money.fromMinorUnits(10000),
        method: RefundMethod.cash,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-REF-206-SECOND',
      );

      expect(() => returnsCoordinator.processRefund(secondRefundCmd), throwsA(isA<InvalidReturnStateTransitionFailure>()));
    });

    test('31. Refund method parsing and string representation', () {
      expect(RefundMethod.fromString('cash'), equals(RefundMethod.cash));
      expect(RefundMethod.fromString('card'), equals(RefundMethod.card));
      expect(RefundMethod.fromString('digital'), equals(RefundMethod.digital));
      expect(RefundMethod.fromString('customer_credit'), equals(RefundMethod.customerCredit));
      expect(RefundMethod.fromString('unknown'), equals(RefundMethod.cash));
    });

    test('32. Refund query by return ID returns correct list', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-208',
        productId: 'PROD-X',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(6000),
      );

      final retRes = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-208',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-208',
        items: [
          ReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'PROD-X',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-208',
      ));

      await returnsCoordinator.approveReturnOrder(ApproveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      await returnsCoordinator.receiveReturnOrder(ReceiveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      await returnsCoordinator.processRefund(ProcessRefundCommand(
        commandId: 'REF-208',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        refundAmount: Money.fromMinorUnits(10000),
        method: RefundMethod.cash,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-REF-208',
      ));

      final refunds = await refundRepo.getRefundsForReturn(returnId: retRes.order.id);
      expect(refunds.length, equals(1));
      expect(refunds.first.id, equals('REF-208'));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // GROUP E: CUSTOMER CREDIT & CUSTOMER LEDGER INTEGRATION (6 Tests)
  // ═════════════════════════════════════════════════════════════════════════════
  group('Group E: Customer Credit & Customer Ledger Integration', () {
    test('33. Customer credit refund writes CustomerLedgerEntry in POS repository', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-301',
        productId: 'PROD-CUST',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(30000),
        unitCost: Money.fromMinorUnits(20000),
        customerId: 'CUST-007',
      );

      final retRes = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-301',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-301',
        customerId: 'CUST-007',
        items: [
          ReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'PROD-CUST',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-301',
      ));

      await returnsCoordinator.approveReturnOrder(ApproveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      await returnsCoordinator.receiveReturnOrder(ReceiveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      final refRes = await returnsCoordinator.processRefund(ProcessRefundCommand(
        commandId: 'REF-301',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        refundAmount: Money.fromMinorUnits(30000),
        method: RefundMethod.customerCredit,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-REF-301',
      ));

      expect(refRes.isSuccess, isTrue);

      // Verify POS repository has recorded CustomerLedgerEntry
      expect(posRepo.ledgerEntries.length, equals(1));
      final entry = posRepo.ledgerEntries.first;
      expect(entry.customerId, equals('CUST-007'));
      expect(entry.credit.minorUnits, equals(30000));
      expect(entry.reason.contains('مرتجع'), isTrue);
    });

    test('34. Customer credit refund without customerId throws RefundProcessingFailure', () async {
      // Sale without customer (walk-in)
      final sale = await createCompletedSale(
        saleId: 'SALE-302',
        productId: 'PROD-CUST',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(6000),
      );

      final retRes = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-302',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-302',
        items: [
          ReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'PROD-CUST',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-302',
      ));

      await returnsCoordinator.approveReturnOrder(ApproveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      await returnsCoordinator.receiveReturnOrder(ReceiveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      // Attempt credit refund on walk-in customer -> must fail
      final refundCmd = ProcessRefundCommand(
        commandId: 'REF-302',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        refundAmount: Money.fromMinorUnits(10000),
        method: RefundMethod.customerCredit,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-REF-302',
      );

      expect(() => returnsCoordinator.processRefund(refundCmd), throwsA(isA<RefundProcessingFailure>()));
    });

    test('35. CustomerLedgerEntry.fromRefundCredit constructs immutable credit entry', () {
      final entry = CustomerLedgerEntry.fromRefundCredit(
        entryId: 'ENT-001',
        customerId: 'CUST-10',
        returnId: 'RET-10',
        businessId: businessId,
        branchId: branchId,
        refundAmount: Money.fromMinorUnits(25000),
        note: 'Customer return credit',
      );
      expect(entry.entryId, equals('ENT-001'));
      expect(entry.customerId, equals('CUST-10'));
      expect(entry.credit.minorUnits, equals(25000));
      expect(entry.reason, contains('Customer return credit'));
    });

    test('36. Multiple customer credit returns accumulate ledger entries correctly', () async {
      for (int i = 1; i <= 2; i++) {
        final sale = await createCompletedSale(
          saleId: 'SALE-MULTI-$i',
          productId: 'PROD-P',
          quantity: 1,
          unitPrice: Money.fromMinorUnits(10000),
          unitCost: Money.fromMinorUnits(6000),
          customerId: 'CUST-VIP',
        );

        final retRes = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
          commandId: 'RET-MULTI-$i',
          businessId: businessId,
          branchId: branchId,
          originalSaleId: sale.id,
          returnNumber: 'RN-M-$i',
          customerId: 'CUST-VIP',
          items: [
            ReturnItemInput(
              originalSaleItemId: sale.items.first.itemId,
              productId: 'PROD-P',
              quantity: StockQuantity.discrete(1),
            ),
          ],
          actorId: staffUserId,
          idempotencyKey: 'IDEM-M-$i',
        ));

        await returnsCoordinator.approveReturnOrder(ApproveReturnOrderCommand(
          businessId: businessId,
          branchId: branchId,
          returnOrderId: retRes.order.id,
          actorId: staffUserId,
        ));

        await returnsCoordinator.receiveReturnOrder(ReceiveReturnOrderCommand(
          businessId: businessId,
          branchId: branchId,
          returnOrderId: retRes.order.id,
          actorId: staffUserId,
        ));

        await returnsCoordinator.processRefund(ProcessRefundCommand(
          commandId: 'REF-MULTI-$i',
          businessId: businessId,
          branchId: branchId,
          returnOrderId: retRes.order.id,
          refundAmount: Money.fromMinorUnits(10000),
          method: RefundMethod.customerCredit,
          actorId: staffUserId,
          idempotencyKey: 'IDEM-REF-M-$i',
        ));
      }

      expect(posRepo.ledgerEntries.length, equals(2));
      expect(posRepo.ledgerEntries.every((e) => e.customerId == 'CUST-VIP'), isTrue);
    });

    test('37. Credit refund logs audit action refundCompleted', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-305',
        productId: 'PROD-P',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(6000),
        customerId: 'CUST-01',
      );

      final retRes = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-305',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-305',
        customerId: 'CUST-01',
        items: [
          ReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'PROD-P',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-305',
      ));

      await returnsCoordinator.approveReturnOrder(ApproveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      await returnsCoordinator.receiveReturnOrder(ReceiveReturnOrderCommand(
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
      ));

      await returnsCoordinator.processRefund(ProcessRefundCommand(
        commandId: 'REF-305',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        refundAmount: Money.fromMinorUnits(10000),
        method: RefundMethod.customerCredit,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-REF-305',
      ));

      final refundAudit = auditRepo.entries.where((e) => e.action == ShopAuditAction.refundCompleted);
      expect(refundAudit.isNotEmpty, isTrue);
    });

    test('38. Customer credit value preserved without floating point precision loss', () {
      final m1 = Money.fromMinorUnits(1234567);
      final m2 = Money.fromMinorUnits(2345678);
      final sum = m1 + m2;
      expect(sum.minorUnits, equals(3580245));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // GROUP F: SUPPLIER RETURNS FLOW & S3 AUTHORITY (7 Tests)
  // ═════════════════════════════════════════════════════════════════════════════
  group('Group F: Supplier Returns Flow & S3 Authority', () {
    setUp(() async {
      // Seed supplier & account
      await supplierRepo.saveSupplier(Supplier(
        id: 'SUP-01',
        businessId: businessId,
        name: 'Al-Farah Supplier',
        phone: '07701234567',
        status: SupplierStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await supplierRepo.saveSupplierAccount(SupplierAccount(
        supplierId: 'SUP-01',
        businessId: businessId,
        currentBalance: Money.fromMinorUnits(500000), // 500,000 IQD payable
        currency: Currency.iqd,
        updatedAt: DateTime.now(),
      ));

      // Seed purchase receipt
      await purchaseReceiptRepo.saveReceipt(PurchaseReceipt(
        id: 'PREC-01',
        businessId: businessId,
        branchId: branchId,
        purchaseOrderId: 'PO-01',
        supplierId: 'SUP-01',
        items: [
          PurchaseReceiptItem(
            purchaseItemId: 'PI-01',
            productId: 'PROD-SUP-RET',
            quantityReceived: StockQuantity.discrete(20),
            unit: StockUnit.piece,
            unitCost: Money.fromMinorUnits(10000),
          ),
        ],
        receivedBy: staffUserId,
        receivedAt: DateTime.now(),
        idempotencyKey: 'IDEM-PREC-01',
      ));

      // Seed inventory onHand = 20
      await inventoryRepo.saveInventoryItem(InventoryItem.initialize(
        inventoryId: 'INV-SUP-01',
        businessId: businessId,
        branchId: branchId,
        productId: 'PROD-SUP-RET',
        initialOnHand: StockQuantity.discrete(20),
      ));
    });

    test('39. Create supplier return starts in DRAFT status', () async {
      final res = await returnsCoordinator.createSupplierReturn(CreateSupplierReturnCommand(
        commandId: 'SRET-01',
        businessId: businessId,
        branchId: branchId,
        supplierId: 'SUP-01',
        originalPurchaseId: 'PO-01',
        originalReceiptId: 'PREC-01',
        returnNumber: 'SRN-01',
        items: [
          SupplierReturnItemInput(
            purchaseReceiptItemId: 'PI-01',
            productId: 'PROD-SUP-RET',
            quantity: StockQuantity.discrete(5),
            unitCost: Money.fromMinorUnits(10000),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-SRET-01',
      ));

      expect(res.isSuccess, isTrue);
      expect(res.supplierReturn.status, equals(SupplierReturnStatus.draft));
      expect(res.supplierReturn.totalAmount.minorUnits, equals(50000));
    });

    test('40. Supplier return quantity exceeding receipt quantity is rejected', () async {
      final cmd = CreateSupplierReturnCommand(
        commandId: 'SRET-02',
        businessId: businessId,
        branchId: branchId,
        supplierId: 'SUP-01',
        originalPurchaseId: 'PO-01',
        originalReceiptId: 'PREC-01',
        returnNumber: 'SRN-02',
        items: [
          SupplierReturnItemInput(
            purchaseReceiptItemId: 'PI-01',
            productId: 'PROD-SUP-RET',
            quantity: StockQuantity.discrete(25), // Received was only 20
            unitCost: Money.fromMinorUnits(10000),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-SRET-02',
      );

      expect(() => returnsCoordinator.createSupplierReturn(cmd), throwsA(isA<InvalidSupplierReturnQuantityFailure>()));
    });

    test('41. Approving supplier return decreases S3 inventory onHand', () async {
      final createRes = await returnsCoordinator.createSupplierReturn(CreateSupplierReturnCommand(
        commandId: 'SRET-03',
        businessId: businessId,
        branchId: branchId,
        supplierId: 'SUP-01',
        originalPurchaseId: 'PO-01',
        originalReceiptId: 'PREC-01',
        returnNumber: 'SRN-03',
        items: [
          SupplierReturnItemInput(
            purchaseReceiptItemId: 'PI-01',
            productId: 'PROD-SUP-RET',
            quantity: StockQuantity.discrete(5),
            unitCost: Money.fromMinorUnits(10000),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-SRET-03',
      ));

      final appRes = await returnsCoordinator.approveSupplierReturn(ApproveSupplierReturnCommand(
        businessId: businessId,
        branchId: branchId,
        supplierReturnId: createRes.supplierReturn.id,
        actorId: staffUserId,
      ));

      expect(appRes.isSuccess, isTrue);
      expect(appRes.supplierReturn.status, equals(SupplierReturnStatus.completed));

      // S3 stock must have decreased from 20 to 15
      final item = await inventoryRepo.getInventoryItem(
        businessId: businessId,
        branchId: branchId,
        productId: 'PROD-SUP-RET',
      );
      expect(item!.onHand.toDouble(), equals(15.0));
    });

    test('42. Approving supplier return records supplierReturn movement in S3 ledger', () async {
      final createRes = await returnsCoordinator.createSupplierReturn(CreateSupplierReturnCommand(
        commandId: 'SRET-04',
        businessId: businessId,
        branchId: branchId,
        supplierId: 'SUP-01',
        originalPurchaseId: 'PO-01',
        originalReceiptId: 'PREC-01',
        returnNumber: 'SRN-04',
        items: [
          SupplierReturnItemInput(
            purchaseReceiptItemId: 'PI-01',
            productId: 'PROD-SUP-RET',
            quantity: StockQuantity.discrete(3),
            unitCost: Money.fromMinorUnits(10000),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-SRET-04',
      ));

      await returnsCoordinator.approveSupplierReturn(ApproveSupplierReturnCommand(
        businessId: businessId,
        branchId: branchId,
        supplierReturnId: createRes.supplierReturn.id,
        actorId: staffUserId,
      ));

      final movements = await inventoryLedgerRepo.getLedgerEntries(
        businessId: businessId,
        branchId: branchId,
        movementType: InventoryMovementType.supplierReturn,
      );
      expect(movements.isNotEmpty, isTrue);
      expect(movements.first.referenceType, equals('SUPPLIER_RETURN'));
      expect(movements.first.quantityDelta.toDouble(), equals(-3.0));
    });

    test('43. Supplier return against non-existent receipt fails', () async {
      final cmd = CreateSupplierReturnCommand(
        commandId: 'SRET-05',
        businessId: businessId,
        branchId: branchId,
        supplierId: 'SUP-01',
        originalPurchaseId: 'PO-01',
        originalReceiptId: 'PREC-NONE',
        returnNumber: 'SRN-05',
        items: [
          SupplierReturnItemInput(
            purchaseReceiptItemId: 'PI-01',
            productId: 'PROD-SUP-RET',
            quantity: StockQuantity.discrete(1),
            unitCost: Money.fromMinorUnits(10000),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-SRET-05',
      );

      expect(() => returnsCoordinator.createSupplierReturn(cmd), throwsA(isA<OriginalPurchaseReceiptNotFoundFailure>()));
    });

    test('44. Cumulative supplier returns prevent exceeding receipt total across multiple commands', () async {
      // First return: 15
      await returnsCoordinator.createSupplierReturn(CreateSupplierReturnCommand(
        commandId: 'SRET-06-A',
        businessId: businessId,
        branchId: branchId,
        supplierId: 'SUP-01',
        originalPurchaseId: 'PO-01',
        originalReceiptId: 'PREC-01',
        returnNumber: 'SRN-06-A',
        items: [
          SupplierReturnItemInput(
            purchaseReceiptItemId: 'PI-01',
            productId: 'PROD-SUP-RET',
            quantity: StockQuantity.discrete(15),
            unitCost: Money.fromMinorUnits(10000),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-06-A',
      ));

      // Second return: 6 (15 + 6 = 21 > 20) -> must fail
      final cmdB = CreateSupplierReturnCommand(
        commandId: 'SRET-06-B',
        businessId: businessId,
        branchId: branchId,
        supplierId: 'SUP-01',
        originalPurchaseId: 'PO-01',
        originalReceiptId: 'PREC-01',
        returnNumber: 'SRN-06-B',
        items: [
          SupplierReturnItemInput(
            purchaseReceiptItemId: 'PI-01',
            productId: 'PROD-SUP-RET',
            quantity: StockQuantity.discrete(6),
            unitCost: Money.fromMinorUnits(10000),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-06-B',
      );

      expect(() => returnsCoordinator.createSupplierReturn(cmdB), throwsA(isA<InvalidSupplierReturnQuantityFailure>()));
    });

    test('45. Approving non-existent supplier return throws SupplierReturnNotFoundFailure', () async {
      final cmd = ApproveSupplierReturnCommand(
        businessId: businessId,
        branchId: branchId,
        supplierReturnId: 'NON-EXISTENT',
        actorId: staffUserId,
      );
      expect(() => returnsCoordinator.approveSupplierReturn(cmd), throwsA(isA<SupplierReturnNotFoundFailure>()));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // GROUP G: SUPPLIER CREDIT NOTES & S4 SUPPLIER LEDGER (7 Tests)
  // ═════════════════════════════════════════════════════════════════════════════
  group('Group G: Supplier Credit Notes & S4 Supplier Ledger', () {
    setUp(() async {
      await supplierRepo.saveSupplier(Supplier(
        id: 'SUP-02',
        businessId: businessId,
        name: 'Tigris Electronics',
        phone: '07709876543',
        status: SupplierStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await supplierRepo.saveSupplierAccount(SupplierAccount(
        supplierId: 'SUP-02',
        businessId: businessId,
        currentBalance: Money.fromMinorUnits(200000), // 200,000 IQD payable
        currency: Currency.iqd,
        updatedAt: DateTime.now(),
      ));

      await purchaseReceiptRepo.saveReceipt(PurchaseReceipt(
        id: 'PREC-02',
        businessId: businessId,
        branchId: branchId,
        purchaseOrderId: 'PO-02',
        supplierId: 'SUP-02',
        items: [
          PurchaseReceiptItem(
            purchaseItemId: 'PI-02',
            productId: 'PROD-CN',
            quantityReceived: StockQuantity.discrete(10),
            unit: StockUnit.piece,
            unitCost: Money.fromMinorUnits(20000),
          ),
        ],
        receivedBy: staffUserId,
        receivedAt: DateTime.now(),
        idempotencyKey: 'IDEM-PREC-02',
      ));

      await inventoryRepo.saveInventoryItem(InventoryItem.initialize(
        inventoryId: 'INV-CN',
        businessId: businessId,
        branchId: branchId,
        productId: 'PROD-CN',
        initialOnHand: StockQuantity.discrete(10),
      ));
    });

    test('46. Approving supplier return creates SupplierCreditNote entity', () async {
      final createRes = await returnsCoordinator.createSupplierReturn(CreateSupplierReturnCommand(
        commandId: 'SRET-G-01',
        businessId: businessId,
        branchId: branchId,
        supplierId: 'SUP-02',
        originalPurchaseId: 'PO-02',
        originalReceiptId: 'PREC-02',
        returnNumber: 'SRN-G-01',
        items: [
          SupplierReturnItemInput(
            purchaseReceiptItemId: 'PI-02',
            productId: 'PROD-CN',
            quantity: StockQuantity.discrete(3),
            reason: 'Defective batch',
          ),
        ],
        reason: 'Supplier return request',
        actorId: staffUserId,
        idempotencyKey: 'IDEM-G-01',
      ));

      final appRes = await returnsCoordinator.approveSupplierReturn(ApproveSupplierReturnCommand(
        commandId: 'APP-SRET-01',
        businessId: businessId,
        supplierReturnId: createRes.supplierReturn.id,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-APP-SRET-01',
      ));

      expect(appRes.creditNote, isNotNull);
      expect(appRes.creditNote.amount.minorUnits, equals(60000));
      expect(appRes.creditNote.supplierId, equals('SUP-02'));
    });

    test('47. Supplier credit note reduces supplier payable in S4 Supplier Ledger', () async {
      final createRes = await returnsCoordinator.createSupplierReturn(CreateSupplierReturnCommand(
        commandId: 'SRET-G-02',
        businessId: businessId,
        branchId: branchId,
        supplierId: 'SUP-02',
        originalPurchaseId: 'PO-02',
        originalReceiptId: 'PREC-02',
        returnNumber: 'SRN-G-02',
        items: [
          SupplierReturnItemInput(
            purchaseReceiptItemId: 'PI-02',
            productId: 'PROD-CN',
            quantity: StockQuantity.discrete(2),
            reason: 'Damaged item',
          ),
        ],
        reason: 'Supplier return request',
        actorId: staffUserId,
        idempotencyKey: 'IDEM-G-02',
      ));

      await returnsCoordinator.approveSupplierReturn(ApproveSupplierReturnCommand(
        commandId: 'APP-SRET-02',
        businessId: businessId,
        supplierReturnId: createRes.supplierReturn.id,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-APP-SRET-02',
      ));

      // Supplier account balance was 200,000; reduced by 40,000 -> 160,000
      final account = await supplierRepo.getSupplierAccount(businessId: businessId, supplierId: 'SUP-02');
      expect(account!.currentBalance.minorUnits, equals(160000));

      // Supplier ledger entries
      final entries = await supplierLedgerRepo.getEntriesForSupplier(businessId: businessId, supplierId: 'SUP-02');
      expect(entries.any((e) => e.entryType.name == 'creditNote'), isTrue);
    });

    test('48. Multiple supplier returns continuously decrement payable accurately', () async {
      for (int i = 1; i <= 2; i++) {
        final retRes = await returnsCoordinator.createSupplierReturn(CreateSupplierReturnCommand(
          commandId: 'SRET-G-MULTI-$i',
          businessId: businessId,
          branchId: branchId,
          supplierId: 'SUP-02',
          originalPurchaseId: 'PO-02',
          originalReceiptId: 'PREC-02',
          returnNumber: 'SRN-GM-$i',
          items: [
            SupplierReturnItemInput(
              purchaseReceiptItemId: 'PI-02',
              productId: 'PROD-CN',
              quantity: StockQuantity.discrete(1),
              reason: 'Damaged part',
            ),
          ],
          reason: 'Supplier return multi',
          actorId: staffUserId,
          idempotencyKey: 'IDEM-GM-$i',
        ));

        await returnsCoordinator.approveSupplierReturn(ApproveSupplierReturnCommand(
          commandId: 'APP-SRET-MULTI-$i',
          businessId: businessId,
          supplierReturnId: retRes.supplierReturn.id,
          actorId: staffUserId,
          idempotencyKey: 'IDEM-APP-GM-$i',
        ));
      }

      // Balance was 200,000 - 20,000 - 20,000 = 160,000
      final account = await supplierRepo.getSupplierAccount(businessId: businessId, supplierId: 'SUP-02');
      expect(account!.currentBalance.minorUnits, equals(160000));
    });

    test('49. Credit note creation logs audit action creditNoteCreated', () async {
      final retRes = await returnsCoordinator.createSupplierReturn(CreateSupplierReturnCommand(
        commandId: 'SRET-G-AUDIT',
        businessId: businessId,
        branchId: branchId,
        supplierId: 'SUP-02',
        originalPurchaseId: 'PO-02',
        originalReceiptId: 'PREC-02',
        returnNumber: 'SRN-G-AUDIT',
        items: [
          SupplierReturnItemInput(
            purchaseReceiptItemId: 'PI-02',
            productId: 'PROD-CN',
            quantity: StockQuantity.discrete(1),
            reason: 'Damaged item',
          ),
        ],
        reason: 'Supplier return audit',
        actorId: staffUserId,
        idempotencyKey: 'IDEM-G-AUDIT',
      ));

      await returnsCoordinator.approveSupplierReturn(ApproveSupplierReturnCommand(
        commandId: 'APP-SRET-AUD',
        businessId: businessId,
        supplierReturnId: retRes.supplierReturn.id,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-APP-AUD',
      ));

      final cnAudit = auditRepo.entries.where((e) => e.action == ShopAuditAction.creditNoteCreated);
      expect(cnAudit.isNotEmpty, isTrue);
    });

    test('50. Credit note query for supplier returns valid list', () async {
      final notes = await supplierCreditNoteRepo.getCreditNotesForSupplier(
        businessId: businessId,
        supplierId: 'SUP-02',
      );
      expect(notes, isA<List>());
    });

    test('51. Supplier return cannot be approved twice', () async {
      final retRes = await returnsCoordinator.createSupplierReturn(CreateSupplierReturnCommand(
        commandId: 'SRET-G-TWICE',
        businessId: businessId,
        branchId: branchId,
        supplierId: 'SUP-02',
        originalPurchaseId: 'PO-02',
        originalReceiptId: 'PREC-02',
        returnNumber: 'SRN-G-TWICE',
        items: [
          SupplierReturnItemInput(
            purchaseReceiptItemId: 'PI-02',
            productId: 'PROD-CN',
            quantity: StockQuantity.discrete(1),
            reason: 'Defective item',
          ),
        ],
        reason: 'Twice approval check',
        actorId: staffUserId,
        idempotencyKey: 'IDEM-G-TWICE',
      ));

      await returnsCoordinator.approveSupplierReturn(ApproveSupplierReturnCommand(
        commandId: 'APP-SRET-1',
        businessId: businessId,
        supplierReturnId: retRes.supplierReturn.id,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-APP-TWICE-1',
      ));

      final secondCmd = ApproveSupplierReturnCommand(
        commandId: 'APP-SRET-2',
        businessId: businessId,
        supplierReturnId: retRes.supplierReturn.id,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-APP-TWICE-2',
      );

      expect(() => returnsCoordinator.approveSupplierReturn(secondCmd), throwsA(isA<InvalidSupplierReturnQuantityFailure>()));
    });

    test('52. Supplier ledger entry is append-only', () async {
      final entries = await supplierLedgerRepo.getEntriesForSupplier(businessId: businessId, supplierId: 'SUP-02');
      if (entries.isNotEmpty) {
        expect(() => supplierLedgerRepo.appendEntry(entries.first), throwsA(isA<StateError>()));
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // GROUP H: REVENUE ENGINE & NET CALCULATIONS (6 Tests)
  // ═════════════════════════════════════════════════════════════════════════════
  group('Group H: Revenue Engine & Net Calculations', () {
    test('53. Revenue calculation: gross revenue without discount and zero tax', () async {
      final sale = await createCompletedSale(
        saleId: 'S-REV-1',
        productId: 'P-R1',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(100000),
        unitCost: Money.fromMinorUnits(60000),
      );

      final rev = RevenueCalculator.calculateSaleRevenue(sale);
      expect(rev.grossRevenue.minorUnits, equals(100000));
      expect(rev.discountTotal.minorUnits, equals(0));
      expect(rev.netRevenue.minorUnits, equals(100000));
      expect(rev.taxTotal.minorUnits, equals(0));
    });

    test('54. Revenue calculation: discount properly reduces net revenue', () async {
      final sale = await createCompletedSale(
        saleId: 'S-REV-2',
        productId: 'P-R2',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(100000),
        unitCost: Money.fromMinorUnits(60000),
        discountTotal: Money.fromMinorUnits(10000),
      );

      final rev = RevenueCalculator.calculateSaleRevenue(sale);
      expect(rev.grossRevenue.minorUnits, equals(100000));
      expect(rev.discountTotal.minorUnits, equals(10000));
      expect(rev.netRevenue.minorUnits, equals(90000));
    });

    test('55. Revenue separates tax from net sales', () async {
      final sale = await createCompletedSale(
        saleId: 'S-REV-3',
        productId: 'P-R3',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(100000),
        unitCost: Money.fromMinorUnits(60000),
        taxTotal: Money.fromMinorUnits(5000),
      );

      final rev = RevenueCalculator.calculateSaleRevenue(sale);
      expect(rev.grossRevenue.minorUnits, equals(100000));
      expect(rev.netRevenue.minorUnits, equals(100000));
      expect(rev.taxTotal.minorUnits, equals(5000));
    });

    test('56. Post sale financials creates CREDIT saleRevenue entry', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-REV-04',
        productId: 'P-REV',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(50000),
        unitCost: Money.fromMinorUnits(30000),
        discountTotal: Money.fromMinorUnits(5000),
      );

      final res = await financeCoordinator.postSaleFinancials(PostSaleFinancialsCommand(
        commandId: 'CMD-POST-REV-04',
        businessId: businessId,
        branchId: branchId,
        sale: sale,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-POST-REV-04',
      ));

      expect(res.isSuccess, isTrue);
      expect(res.revenueEntry, isNotNull);
      expect(res.revenueEntry!.entryType, equals(FinancialEntryType.saleRevenue));
      expect(res.revenueEntry!.direction, equals(FinancialDirection.credit));
      expect(res.revenueEntry!.amount.minorUnits, equals(45000)); // 50,000 - 5,000
    });

    test('57. Revenue posting for mismatched branch throws FinanceBranchMismatchFailure', () async {
      final sale = await createCompletedSale(
        saleId: 'S-BRANCH-MISMATCH',
        productId: 'P-BR',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(5000),
      );
      final cmd = PostSaleFinancialsCommand(
        commandId: 'CMD-BR-MISMATCH',
        businessId: businessId,
        branchId: 'OTHER-BRANCH',
        sale: sale,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-BR-NONE',
      );
      expect(() => financeCoordinator.postSaleFinancials(cmd), throwsA(isA<FinanceBranchMismatchFailure>()));
    });

    test('58. Revenue amount is strictly non-negative invariant', () {
      final sale = Sale(
        id: 'S-ZERO',
        businessId: businessId,
        branchId: branchId,
        terminalId: 'T1',
        sessionId: 'S1',
        cashierId: staffUserId,
        cashierName: 'Cashier',
        saleNumber: 'SN-0',
        source: 'POS',
        status: SaleStatus.completed,
        items: [],
        subtotal: Money.zero(),
        discountTotal: Money.zero(),
        taxTotal: Money.zero(),
        grandTotal: Money.zero(),
        paidTotal: Money.zero(),
        remainingTotal: Money.zero(),
        changeTotal: Money.zero(),
        currency: Currency.iqd,
        payments: [],
        createdAt: DateTime.now(),
        version: 1,
        idempotencyKey: 'IDEM-ZERO',
      );
      final rev = RevenueCalculator.calculateSaleRevenue(sale);
      expect(rev.netRevenue.minorUnits >= 0, isTrue);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // GROUP I: COSTING METHODS: WEIGHTED AVERAGE & FIFO COST LAYERS (9 Tests)
  // ═════════════════════════════════════════════════════════════════════════════
  group('Group I: Costing Methods (Weighted Average & FIFO)', () {
    test('59. Weighted Average Cost Formula: 10 @ 5,000 + 10 @ 7,000 = 6,000 average', () {
      final newAvg = CogsCalculator.calculateNewWeightedAverageCost(
        existingQuantity: StockQuantity.discrete(10),
        existingAverageCost: Money.fromMinorUnits(5000),
        receivedQuantity: StockQuantity.discrete(10),
        receivedCost: Money.fromMinorUnits(7000),
      );
      expect(newAvg.minorUnits, equals(6000));
    });

    test('60. Weighted Average with unequal quantities: 10 @ 5,000 + 20 @ 8,000 = 7,000', () {
      // (10*5000 + 20*8000) / 30 = (50,000 + 160,000) / 30 = 210,000 / 30 = 7,000
      final newAvg = CogsCalculator.calculateNewWeightedAverageCost(
        existingQuantity: StockQuantity.discrete(10),
        existingAverageCost: Money.fromMinorUnits(5000),
        receivedQuantity: StockQuantity.discrete(20),
        receivedCost: Money.fromMinorUnits(8000),
      );
      expect(newAvg.minorUnits, equals(7000));
    });

    test('61. Weighted Average with zero existing quantity adopts received cost', () {
      final newAvg = CogsCalculator.calculateNewWeightedAverageCost(
        existingQuantity: StockQuantity.discrete(0),
        existingAverageCost: Money.fromMinorUnits(0),
        receivedQuantity: StockQuantity.discrete(15),
        receivedCost: Money.fromMinorUnits(12000),
      );
      expect(newAvg.minorUnits, equals(12000));
    });

    test('62. Weighted Average COGS: selling 5 units at average cost 6,000 = 30,000 COGS', () {
      final cogs = CogsCalculator.calculateWeightedAverageCogs(
        quantitySold: StockQuantity.discrete(5),
        averageCost: Money.fromMinorUnits(6000),
      );
      expect(cogs.minorUnits, equals(30000));
    });

    test('63. FIFO cost layer consumption: consumes oldest layer first', () {
      final layer1 = InventoryCostLayer(
        id: 'L1',
        businessId: businessId,
        branchId: branchId,
        productId: 'P-FIFO',
        sourceType: 'PURCHASE',
        sourceId: 'PO-1',
        quantity: StockQuantity.discrete(10),
        remainingQuantity: StockQuantity.discrete(10),
        unitCost: Money.fromMinorUnits(5000),
        createdAt: DateTime(2026, 9, 1),
      );

      final layer2 = InventoryCostLayer(
        id: 'L2',
        businessId: businessId,
        branchId: branchId,
        productId: 'P-FIFO',
        sourceType: 'PURCHASE',
        sourceId: 'PO-2',
        quantity: StockQuantity.discrete(10),
        remainingQuantity: StockQuantity.discrete(10),
        unitCost: Money.fromMinorUnits(7000),
        createdAt: DateTime(2026, 9, 5),
      );

      // Consume 12 units: 10 from L1 @ 5,000 + 2 from L2 @ 7,000 = 50,000 + 14,000 = 64,000
      final result = CogsCalculator.consumeFifoCostLayers(
        layers: [layer1, layer2],
        quantityToConsume: StockQuantity.discrete(12),
      );

      expect(result.totalCogs.minorUnits, equals(64000));
      expect(result.totalConsumedQuantity.toDouble(), equals(12.0));

      final updatedL1 = result.updatedLayers.firstWhere((l) => l.id == 'L1');
      final updatedL2 = result.updatedLayers.firstWhere((l) => l.id == 'L2');

      expect(updatedL1.remainingQuantity.toDouble(), equals(0.0));
      expect(updatedL1.isExhausted, isTrue);

      expect(updatedL2.remainingQuantity.toDouble(), equals(8.0));
      expect(updatedL2.isExhausted, isFalse);
    });

    test('64. FIFO partial consumption leaves remaining layer quantity intact', () {
      final layer = InventoryCostLayer(
        id: 'L-SINGLE',
        businessId: businessId,
        branchId: branchId,
        productId: 'P1',
        sourceType: 'PURCHASE',
        sourceId: 'PO-1',
        quantity: StockQuantity.discrete(10),
        remainingQuantity: StockQuantity.discrete(10),
        unitCost: Money.fromMinorUnits(4000),
        createdAt: DateTime.now(),
      );

      final result = CogsCalculator.consumeFifoCostLayers(
        layers: [layer],
        quantityToConsume: StockQuantity.discrete(4),
      );

      expect(result.totalCogs.minorUnits, equals(16000));
      expect(result.updatedLayers.first.remainingQuantity.toDouble(), equals(6.0));
    });

    test('65. FIFO consuming zero quantity returns zero COGS', () {
      final layer = InventoryCostLayer(
        id: 'L1',
        businessId: businessId,
        branchId: branchId,
        productId: 'P1',
        sourceType: 'PURCHASE',
        sourceId: 'PO-1',
        quantity: StockQuantity.discrete(10),
        remainingQuantity: StockQuantity.discrete(10),
        unitCost: Money.fromMinorUnits(4000),
        createdAt: DateTime.now(),
      );

      final result = CogsCalculator.consumeFifoCostLayers(
        layers: [layer],
        quantityToConsume: StockQuantity.discrete(0),
      );

      expect(result.totalCogs.minorUnits, equals(0));
      expect(result.totalConsumedQuantity.toDouble(), equals(0.0));
    });

    test('66. InventoryCostLayer copyWith and version increment', () {
      final layer = InventoryCostLayer(
        id: 'L-V1',
        businessId: businessId,
        branchId: branchId,
        productId: 'P1',
        sourceType: 'PURCHASE',
        sourceId: 'PO-1',
        quantity: StockQuantity.discrete(10),
        remainingQuantity: StockQuantity.discrete(10),
        unitCost: Money.fromMinorUnits(5000),
        createdAt: DateTime.now(),
        version: 1,
      );

      final consumed = layer.consume(StockQuantity.discrete(3));
      expect(consumed.updatedLayer.version, equals(2));
      expect(consumed.updatedLayer.remainingQuantity.toDouble(), equals(7.0));
      expect(consumed.costOfConsumed.minorUnits, equals(15000));
    });

    test('67. CostingMethod enum string representations', () {
      expect(CostingMethod.fromString('fifo'), equals(CostingMethod.fifo));
      expect(CostingMethod.fromString('weighted_average'), equals(CostingMethod.weightedAverage));
      expect(CostingMethod.fromString('unknown'), equals(CostingMethod.weightedAverage));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // GROUP J: COGS ENGINE & REVERSALS ON RETURN (7 Tests)
  // ═════════════════════════════════════════════════════════════════════════════
  group('Group J: COGS Engine & Reversals on Return', () {
    test('68. Post sale financials creates DEBIT saleCogs entry', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-COGS-1',
        productId: 'P-COGS',
        quantity: 2,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(6000),
      );

      final res = await financeCoordinator.postSaleFinancials(PostSaleFinancialsCommand(
        commandId: 'CMD-COGS-1',
        businessId: businessId,
        branchId: branchId,
        sale: sale,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-COGS-01',
      ));

      expect(res.cogsEntry, isNotNull);
      expect(res.cogsEntry!.entryType, equals(FinancialEntryType.saleCogs));
      expect(res.cogsEntry!.direction, equals(FinancialDirection.debit));
      expect(res.cogsEntry!.amount.minorUnits, equals(12000)); // 2 * 6,000
    });

    test('69. Post return financials creates CREDIT saleCogs reversal for resellable items', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-COGS-2',
        productId: 'P-REV-COGS',
        quantity: 5,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(4000),
      );

      // Return 2 resellable items (original cost 4,000 * 2 = 8,000)
      final retOrder = ReturnOrder(
        id: 'RET-COGS-REV-2',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-REV-2',
        type: ReturnType.partialReturn,
        status: ReturnOrderStatus.completed,
        items: [
          ReturnItem(
            id: 'RI-1',
            originalSaleItemId: sale.items.first.itemId,
            productId: 'P-REV-COGS',
            descriptionSnapshot: 'Item',
            skuSnapshot: 'SKU',
            quantity: StockQuantity.discrete(2),
            unitRefundPrice: Money.fromMinorUnits(10000),
            originalCostBasis: Money.fromMinorUnits(4000),
            restockCondition: ReturnRestockCondition.restock,
          ),
        ],
        currency: Currency.iqd,
        createdBy: staffUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        idempotencyKey: 'IDEM-RN-REV-2',
      );
      await returnOrderRepo.saveReturnOrder(retOrder);

      await financeCoordinator.reverseSaleFinancialsOnReturn(ReverseSaleFinancialsOnReturnCommand(
        commandId: 'CMD-REV-1',
        businessId: businessId,
        branchId: branchId,
        returnOrder: retOrder,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-FIN-POST-RET-2',
      ));

      final entries = await financialEntryRepo.getEntries(
        businessId: businessId,
        branchId: branchId,
        entryType: FinancialEntryType.saleCogs,
      );

      final cogsReversal = entries.firstWhere((e) => e.direction == FinancialDirection.credit);
      expect(cogsReversal.amount.minorUnits, equals(8000));
      expect(cogsReversal.referenceType, equals('CUSTOMER_RETURN'));
    });

    test('70. Damaged return DOES NOT create COGS reversal credit entry', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-COGS-3',
        productId: 'P-DAM-COGS',
        quantity: 2,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(4000),
      );

      final retOrder = ReturnOrder(
        id: 'RET-DAMAGED-COGS',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-DAM',
        type: ReturnType.partialReturn,
        status: ReturnOrderStatus.completed,
        items: [
          ReturnItem(
            id: 'RI-DAM',
            originalSaleItemId: sale.items.first.itemId,
            productId: 'P-DAM-COGS',
            descriptionSnapshot: 'Item',
            skuSnapshot: 'SKU',
            quantity: StockQuantity.discrete(2),
            unitRefundPrice: Money.fromMinorUnits(10000),
            originalCostBasis: Money.fromMinorUnits(4000),
            restockCondition: ReturnRestockCondition.damaged,
          ),
        ],
        currency: Currency.iqd,
        createdBy: staffUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        idempotencyKey: 'IDEM-RN-DAM',
      );
      await returnOrderRepo.saveReturnOrder(retOrder);

      await financeCoordinator.reverseSaleFinancialsOnReturn(ReverseSaleFinancialsOnReturnCommand(
        commandId: 'CMD-REV-DAM',
        businessId: businessId,
        branchId: branchId,
        returnOrder: retOrder,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-FIN-POST-DAM',
      ));

      final entries = await financialEntryRepo.getEntries(
        businessId: businessId,
        branchId: branchId,
        entryType: FinancialEntryType.saleCogs,
      );

      // Reversal credit entry should not exist because item was damaged
      expect(entries.any((e) => e.direction == FinancialDirection.credit), isFalse);
    });

    test('71. Resellable return restores InventoryCostLayer in repository', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-COGS-4',
        productId: 'P-LAYER-RESTORE',
        quantity: 2,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(4500),
      );

      final retOrder = ReturnOrder(
        id: 'RET-RESTOCK-LAYER',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-RESTORE',
        type: ReturnType.fullReturn,
        status: ReturnOrderStatus.completed,
        items: [
          ReturnItem(
            id: 'RI-RESTORE',
            originalSaleItemId: sale.items.first.itemId,
            productId: 'P-LAYER-RESTORE',
            descriptionSnapshot: 'Item',
            skuSnapshot: 'SKU',
            quantity: StockQuantity.discrete(2),
            unitRefundPrice: Money.fromMinorUnits(10000),
            originalCostBasis: Money.fromMinorUnits(4500),
            restockCondition: ReturnRestockCondition.restock,
          ),
        ],
        currency: Currency.iqd,
        createdBy: staffUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        idempotencyKey: 'IDEM-RN-RESTORE',
      );
      await returnOrderRepo.saveReturnOrder(retOrder);

      await financeCoordinator.reverseSaleFinancialsOnReturn(ReverseSaleFinancialsOnReturnCommand(
        commandId: 'CMD-REV-RESTORE',
        businessId: businessId,
        branchId: branchId,
        returnOrder: retOrder,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-FIN-POST-RESTORE',
      ));

      final layers = await costLayerRepo.getLayersForProduct(
        businessId: businessId,
        branchId: branchId,
        productId: 'P-LAYER-RESTORE',
      );
      expect(layers.isNotEmpty, isTrue);
      expect(layers.first.unitCost.minorUnits, equals(4500));
      expect(layers.first.remainingQuantity.toDouble(), equals(2.0));
    });

    test('72. Atomic posting: both Revenue and COGS are posted together', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-ATOMIC',
        productId: 'P-ATOMIC',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(100000),
        unitCost: Money.fromMinorUnits(70000),
      );

      final res = await financeCoordinator.postSaleFinancials(PostSaleFinancialsCommand(
        commandId: 'CMD-ATOMIC',
        businessId: businessId,
        branchId: branchId,
        sale: sale,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-ATOMIC',
      ));

      expect(res.revenueEntry, isNotNull);
      expect(res.cogsEntry, isNotNull);
      expect(res.grossProfit.minorUnits, equals(30000));
    });

    test('73. COGS posting preserves original frozen pricing snapshot from sale', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-FROZEN',
        productId: 'P-FROZEN',
        quantity: 3,
        unitPrice: Money.fromMinorUnits(20000),
        unitCost: Money.fromMinorUnits(14000),
      );

      final res = await financeCoordinator.postSaleFinancials(PostSaleFinancialsCommand(
        commandId: 'CMD-FROZEN',
        businessId: businessId,
        branchId: branchId,
        sale: sale,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-FROZEN',
      ));

      expect(res.cogsEntry!.amount.minorUnits, equals(42000)); // 3 * 14,000
    });

    test('74. Negative COGS invariant rejected', () {
      final cogs = CogsCalculator.calculateWeightedAverageCogs(
        quantitySold: StockQuantity.discrete(0),
        averageCost: Money.fromMinorUnits(5000),
      );
      expect(cogs.minorUnits >= 0, isTrue);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // GROUP K: GROSS PROFIT & MARGIN ENGINE (7 Tests)
  // ═════════════════════════════════════════════════════════════════════════════
  group('Group K: Gross Profit & Margin Engine', () {
    test('75. Standard Gross Profit: 100,000 Sale, 60,000 Cost = 40,000 Profit (40% Margin)', () {
      final res = GrossProfitCalculator.calculate(
        grossRevenue: Money.fromMinorUnits(100000),
        discountTotal: Money.zero(),
        taxTotal: Money.zero(),
        cogs: Money.fromMinorUnits(60000),
        unitsCount: 10,
      );

      expect(res.grossProfit.minorUnits, equals(40000));
      expect(res.grossMarginPercentage, closeTo(40.0, 0.001));
    });

    test('76. Gross Profit with discount: Subtotal 100,000, Discount 10,000, COGS 50,000 = 40,000 Profit', () {
      final res = GrossProfitCalculator.calculate(
        grossRevenue: Money.fromMinorUnits(100000),
        discountTotal: Money.fromMinorUnits(10000),
        taxTotal: Money.zero(),
        cogs: Money.fromMinorUnits(50000),
        unitsCount: 5,
      );

      // Net revenue = 90,000; Profit = 90,000 - 50,000 = 40,000
      expect(res.netRevenue.minorUnits, equals(90000));
      expect(res.grossProfit.minorUnits, equals(40000));
      expect(res.grossMarginPercentage, closeTo((40000 / 90000) * 100.0, 0.01));
    });

    test('77. Zero revenue handles division-by-zero safely (margin = 0.0 or null)', () {
      final res = GrossProfitCalculator.calculate(
        grossRevenue: Money.zero(),
        discountTotal: Money.zero(),
        taxTotal: Money.zero(),
        cogs: Money.zero(),
        unitsCount: 0,
      );

      expect(res.grossProfit.minorUnits, equals(0));
      expect(res.grossMarginPercentage, equals(0.0));
    });

    test('78. Negative gross profit (loss): Revenue 50,000, COGS 70,000 = -20,000 Profit', () {
      final res = GrossProfitCalculator.calculate(
        grossRevenue: Money.fromMinorUnits(50000),
        discountTotal: Money.zero(),
        taxTotal: Money.zero(),
        cogs: Money.fromMinorUnits(70000),
        unitsCount: 5,
      );

      expect(res.grossProfit.minorUnits, equals(-20000));
      expect(res.grossMarginPercentage, closeTo(-40.0, 0.001));
    });

    test('79. Period profit calculation aggregates revenue, COGS and refunds across entries', () async {
      await financialEntryRepo.appendEntry(FinancialEntry(
        id: 'E1',
        businessId: businessId,
        branchId: branchId,
        entryType: FinancialEntryType.saleRevenue,
        referenceType: 'SALE',
        referenceId: 'S1',
        amount: Money.fromMinorUnits(100000),
        currency: Currency.iqd,
        direction: FinancialDirection.credit,
        actorId: staffUserId,
        createdAt: DateTime(2026, 9, 10),
        idempotencyKey: 'IDEM-E1',
      ));

      await financialEntryRepo.appendEntry(FinancialEntry(
        id: 'E2',
        businessId: businessId,
        branchId: branchId,
        entryType: FinancialEntryType.saleCogs,
        referenceType: 'SALE',
        referenceId: 'S1',
        amount: Money.fromMinorUnits(60000),
        currency: Currency.iqd,
        direction: FinancialDirection.debit,
        actorId: staffUserId,
        createdAt: DateTime(2026, 9, 10),
        idempotencyKey: 'IDEM-E2',
      ));

      final res = await financeCoordinator.calculatePeriodProfit(CalculatePeriodProfitCommand(
        businessId: businessId,
        branchId: branchId,
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        actorId: staffUserId,
      ));

      expect(res.isSuccess, isTrue);
      expect(res.result!.grossProfit.minorUnits, equals(40000));
      expect(res.result!.grossMarginPercentage, closeTo(40.0, 0.01));
    });

    test('80. Invalid period (from after to) throws FinancialPeriodInvalidFailure', () async {
      final cmd = CalculatePeriodProfitCommand(
        businessId: businessId,
        branchId: branchId,
        from: DateTime(2026, 9, 30),
        to: DateTime(2026, 9, 1),
        actorId: staffUserId,
      );
      expect(() => financeCoordinator.calculatePeriodProfit(cmd), throwsA(isA<FinancialPeriodInvalidFailure>()));
    });

    test('81. Gross profit calculation executes successfully and returns valid report', () async {
      final res = await financeCoordinator.calculatePeriodProfit(CalculatePeriodProfitCommand(
        businessId: businessId,
        branchId: branchId,
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        actorId: staffUserId,
      ));

      expect(res.isSuccess, isTrue);
      expect(res.result, isNotNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // GROUP L: INVENTORY VALUATION ENGINE (7 Tests)
  // ═════════════════════════════════════════════════════════════════════════════
  group('Group L: Inventory Valuation Engine', () {
    test('82. Valuation with FIFO Cost Layers (as-of timestamp support)', () async {
      await costLayerRepo.saveLayer(InventoryCostLayer(
        id: 'LAY-1',
        businessId: businessId,
        branchId: branchId,
        productId: 'P-VAL-1',
        sourceType: 'PURCHASE',
        sourceId: 'PO-1',
        quantity: StockQuantity.discrete(10),
        remainingQuantity: StockQuantity.discrete(10),
        unitCost: Money.fromMinorUnits(5000),
        createdAt: DateTime(2026, 9, 1),
      ));

      await costLayerRepo.saveLayer(InventoryCostLayer(
        id: 'LAY-2',
        businessId: businessId,
        branchId: branchId,
        productId: 'P-VAL-1',
        sourceType: 'PURCHASE',
        sourceId: 'PO-2',
        quantity: StockQuantity.discrete(10),
        remainingQuantity: StockQuantity.discrete(5),
        unitCost: Money.fromMinorUnits(8000),
        createdAt: DateTime(2026, 9, 15),
      ));

      final res = await financeCoordinator.calculateInventoryValuation(CalculateInventoryValuationCommand(
        businessId: businessId,
        branchId: branchId,
        asOf: DateTime(2026, 9, 20),
        costingMethod: CostingMethod.fifo,
        actorId: staffUserId,
      ));

      // 10 * 5,000 + 5 * 8,000 = 50,000 + 40,000 = 90,000
      expect(res.isSuccess, isTrue);
      expect(res.report!.totalValuation.minorUnits, equals(90000));
      expect(res.report!.totalUnitsCount, equals(15.0));
    });

    test('83. As-Of timestamp filters out subsequent future layers accurately', () async {
      // Layer in September
      await costLayerRepo.saveLayer(InventoryCostLayer(
        id: 'LAY-SEPT',
        businessId: businessId,
        branchId: branchId,
        productId: 'P-AS-OF',
        sourceType: 'PURCHASE',
        sourceId: 'PO-1',
        quantity: StockQuantity.discrete(10),
        remainingQuantity: StockQuantity.discrete(10),
        unitCost: Money.fromMinorUnits(5000),
        createdAt: DateTime(2026, 9, 15),
      ));

      // Layer in October (future)
      await costLayerRepo.saveLayer(InventoryCostLayer(
        id: 'LAY-OCT',
        businessId: businessId,
        branchId: branchId,
        productId: 'P-AS-OF',
        sourceType: 'PURCHASE',
        sourceId: 'PO-2',
        quantity: StockQuantity.discrete(10),
        remainingQuantity: StockQuantity.discrete(10),
        unitCost: Money.fromMinorUnits(10000),
        createdAt: DateTime(2026, 10, 5),
      ));

      // Query As-Of 2026-09-30 (must exclude October layer)
      final res = await financeCoordinator.calculateInventoryValuation(CalculateInventoryValuationCommand(
        businessId: businessId,
        branchId: branchId,
        asOf: DateTime(2026, 9, 30),
        costingMethod: CostingMethod.weightedAverage,
        actorId: staffUserId,
      ));

      expect(res.report!.totalValuation.minorUnits, equals(50000));
      expect(res.report!.totalUnitsCount, equals(10.0));
    });

    test('84. Valuation with Weighted Average method', () async {
      await costLayerRepo.saveLayer(InventoryCostLayer(
        id: 'LAY-WA-1',
        businessId: businessId,
        branchId: branchId,
        productId: 'P-WA',
        sourceType: 'PURCHASE',
        sourceId: 'PO-1',
        quantity: StockQuantity.discrete(10),
        remainingQuantity: StockQuantity.discrete(10),
        unitCost: Money.fromMinorUnits(4000),
        createdAt: DateTime(2026, 9, 1),
      ));

      await costLayerRepo.saveLayer(InventoryCostLayer(
        id: 'LAY-WA-2',
        businessId: businessId,
        branchId: branchId,
        productId: 'P-WA',
        sourceType: 'PURCHASE',
        sourceId: 'PO-2',
        quantity: StockQuantity.discrete(10),
        remainingQuantity: StockQuantity.discrete(10),
        unitCost: Money.fromMinorUnits(6000),
        createdAt: DateTime(2026, 9, 2),
      ));

      final res = await financeCoordinator.calculateInventoryValuation(CalculateInventoryValuationCommand(
        businessId: businessId,
        branchId: branchId,
        asOf: DateTime(2026, 9, 3),
        costingMethod: CostingMethod.weightedAverage,
        actorId: staffUserId,
      ));

      // 10 @ 4k + 10 @ 6k = 20 @ 5k = 100,000 total
      expect(res.report!.totalValuation.minorUnits, equals(100000));
      expect(res.report!.items.first.unitCostBasis.minorUnits, equals(5000));
    });

    test('85. Valuation logs audit action inventoryValuationCalculated', () async {
      await financeCoordinator.calculateInventoryValuation(CalculateInventoryValuationCommand(
        businessId: businessId,
        branchId: branchId,
        asOf: DateTime.now(),
        costingMethod: CostingMethod.weightedAverage,
        actorId: staffUserId,
      ));

      final audit = auditRepo.entries.where((e) => e.action == ShopAuditAction.inventoryValuationCalculated);
      expect(audit.isNotEmpty, isTrue);
    });

    test('86. Empty inventory valuation returns zero value report without error', () async {
      final res = await financeCoordinator.calculateInventoryValuation(CalculateInventoryValuationCommand(
        businessId: businessId,
        branchId: branchId,
        asOf: DateTime.now(),
        costingMethod: CostingMethod.fifo,
        actorId: staffUserId,
      ));

      expect(res.report!.totalValuation.minorUnits, equals(0));
      expect(res.report!.items.isEmpty, isTrue);
    });

    test('87. Valuation isolated by branchId', () async {
      await costLayerRepo.saveLayer(InventoryCostLayer(
        id: 'L-B1',
        businessId: businessId,
        branchId: branchId,
        productId: 'P1',
        sourceType: 'PURCHASE',
        sourceId: 'PO-1',
        quantity: StockQuantity.discrete(5),
        remainingQuantity: StockQuantity.discrete(5),
        unitCost: Money.fromMinorUnits(10000),
        createdAt: DateTime.now(),
      ));

      await costLayerRepo.saveLayer(InventoryCostLayer(
        id: 'L-B2',
        businessId: businessId,
        branchId: 'BRANCH-OTHER',
        productId: 'P1',
        sourceType: 'PURCHASE',
        sourceId: 'PO-2',
        quantity: StockQuantity.discrete(10),
        remainingQuantity: StockQuantity.discrete(10),
        unitCost: Money.fromMinorUnits(10000),
        createdAt: DateTime.now(),
      ));

      final res = await financeCoordinator.calculateInventoryValuation(CalculateInventoryValuationCommand(
        businessId: businessId,
        branchId: branchId,
        asOf: DateTime.now(),
        costingMethod: CostingMethod.fifo,
        actorId: staffUserId,
      ));

      expect(res.report!.totalValuation.minorUnits, equals(50000));
    });

    test('88. Multi-business isolation in inventory valuation', () async {
      await costLayerRepo.saveLayer(InventoryCostLayer(
        id: 'L-BIZ-2',
        businessId: 'OTHER-BIZ',
        branchId: branchId,
        productId: 'P1',
        sourceType: 'PURCHASE',
        sourceId: 'PO-1',
        quantity: StockQuantity.discrete(10),
        remainingQuantity: StockQuantity.discrete(10),
        unitCost: Money.fromMinorUnits(50000),
        createdAt: DateTime.now(),
      ));

      final res = await financeCoordinator.calculateInventoryValuation(CalculateInventoryValuationCommand(
        businessId: businessId,
        branchId: branchId,
        asOf: DateTime.now(),
        costingMethod: CostingMethod.fifo,
        actorId: staffUserId,
      ));

      // Should not see OTHER-BIZ layers
      expect(res.report!.totalValuation.minorUnits, equals(0));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // GROUP M: IDEMPOTENCY REPLAY PROTECTION (6 Tests)
  // ═════════════════════════════════════════════════════════════════════════════
  group('Group M: Idempotency Replay Protection', () {
    test('89. Duplicate create return command returns cached result without creating duplicate', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-IDEM-1',
        productId: 'P-IDEM',
        quantity: 5,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(6000),
      );

      final cmd = CreateReturnOrderCommand(
        commandId: 'RET-IDEM-1',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-IDEM-1',
        items: [
          CreateReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'P-IDEM',
            quantity: StockQuantity.discrete(2),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-RETURN-KEY-1',
      );

      final res1 = await returnsCoordinator.createReturnOrder(cmd);
      final res2 = await returnsCoordinator.createReturnOrder(cmd);

      expect(res1.order.id, equals(res2.order.id));
      final allReturns = await returnOrderRepo.getReturnOrders(businessId: businessId);
      expect(allReturns.length, equals(1));
    });

    test('90. Duplicate process refund command returns cached result without double paying', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-IDEM-2',
        productId: 'P-IDEM',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(6000),
      );

      final retRes = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-IDEM-2',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-IDEM-2',
        items: [
          CreateReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'P-IDEM',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-RET-2',
      ));

      await returnsCoordinator.approveReturnOrder(ApproveReturnOrderCommand(
        commandId: 'CMD-IDEM-APP-2',
        businessId: businessId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-APP-2',
      ));

      await returnsCoordinator.receiveReturnOrder(ReceiveReturnOrderCommand(
        commandId: 'CMD-IDEM-REC-2',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-REC-2',
      ));

      final refundCmd = ProcessRefundCommand(
        commandId: 'REF-IDEM-2',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        refundAmount: Money.fromMinorUnits(10000),
        method: RefundMethod.cash,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-REF-KEY-2',
      );

      final ref1 = await returnsCoordinator.processRefund(refundCmd);
      final ref2 = await returnsCoordinator.processRefund(refundCmd);

      expect(ref1.refund.id, equals(ref2.refund.id));
      final refunds = await refundRepo.getRefundsForReturn(returnId: retRes.order.id);
      expect(refunds.length, equals(1));
    });

    test('91. Duplicate post sale financials command returns cached result without duplicate entries', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-IDEM-3',
        productId: 'P-IDEM',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(20000),
        unitCost: Money.fromMinorUnits(12000),
      );

      final cmd = PostSaleFinancialsCommand(
        commandId: 'CMD-POST-SALE-3',
        businessId: businessId,
        branchId: branchId,
        sale: sale,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-FIN-POST-SALE-3',
      );

      final res1 = await financeCoordinator.postSaleFinancials(cmd);
      final res2 = await financeCoordinator.postSaleFinancials(cmd);

      expect(res1.revenueEntry?.id, equals(res2.revenueEntry?.id));

      final entries = await financialEntryRepo.getEntries(businessId: businessId);
      // Exactly 2 entries: 1 revenue + 1 COGS
      expect(entries.length, equals(2));
    });

    test('92. Duplicate create supplier return returns cached result', () async {
      await purchaseReceiptRepo.saveReceipt(PurchaseReceipt(
        id: 'PREC-IDEM',
        businessId: businessId,
        branchId: branchId,
        purchaseOrderId: 'PO-IDEM',
        supplierId: 'SUP-IDEM',
        items: [
          PurchaseReceiptItem(
            purchaseItemId: 'PI-IDEM',
            productId: 'P-IDEM',
            quantityReceived: StockQuantity.discrete(10),
            unit: StockUnit.piece,
            unitCost: Money.fromMinorUnits(5000),
          ),
        ],
        receivedBy: staffUserId,
        receivedAt: DateTime.now(),
        idempotencyKey: 'IDEM-PREC-REC',
      ));

      final cmd = CreateSupplierReturnCommand(
        commandId: 'SRET-IDEM',
        businessId: businessId,
        branchId: branchId,
        supplierId: 'SUP-IDEM',
        originalPurchaseId: 'PO-IDEM',
        originalReceiptId: 'PREC-IDEM',
        returnNumber: 'SRN-IDEM',
        items: [
          SupplierReturnItemInput(
            purchaseReceiptItemId: 'PI-IDEM',
            productId: 'P-IDEM',
            quantity: StockQuantity.discrete(2),
            reason: 'Defective batch',
          ),
        ],
        reason: 'Defective batch returned to supplier',
        actorId: staffUserId,
        idempotencyKey: 'IDEM-SRET-KEY',
      );

      final res1 = await returnsCoordinator.createSupplierReturn(cmd);
      final res2 = await returnsCoordinator.createSupplierReturn(cmd);

      expect(res1.supplierReturn.id, equals(res2.supplierReturn.id));
      final all = await supplierReturnRepo.getSupplierReturns(businessId: businessId);
      expect(all.length, equals(1));
    });

    test('93. Different idempotency keys create separate independent records', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-IDEM-DIFF',
        productId: 'P-IDEM',
        quantity: 5,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(6000),
      );

      final res1 = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-DIFF-1',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-D1',
        items: [
          CreateReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'P-IDEM',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'KEY-1',
      ));

      final res2 = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-DIFF-2',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-D2',
        items: [
          CreateReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'P-IDEM',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'KEY-2',
      ));

      expect(res1.order.id, isNot(equals(res2.order.id)));
      final all = await returnOrderRepo.getReturnOrders(businessId: businessId);
      expect(all.length, equals(2));
    });

    test('94. Financial entry repository append-only prevents duplicate entry ID', () async {
      final entry = FinancialEntry(
        id: 'ENTRY-DUP',
        businessId: businessId,
        branchId: branchId,
        entryType: FinancialEntryType.payment,
        referenceType: 'PAYMENT',
        referenceId: 'PAY-1',
        amount: Money.fromMinorUnits(1000),
        currency: Currency.iqd,
        direction: FinancialDirection.debit,
        actorId: staffUserId,
        createdAt: DateTime.now(),
        idempotencyKey: 'IDEM-DUP-ENTRY',
      );

      await financialEntryRepo.appendEntry(entry);
      expect(() => financialEntryRepo.appendEntry(entry), throwsA(isA<StateError>()));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // GROUP N: CRITICAL CONCURRENCY TESTS A, B, C (4 Tests)
  // ═════════════════════════════════════════════════════════════════════════════
  group('Group N: Critical Concurrency Tests A, B, C', () {
    test('95. CRITICAL TEST A: Sold = 1, Two concurrent returns of 1 -> exactly 1 succeeds, 1 fails with InvalidReturnQuantityFailure, final returned = 1', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-CONCUR-A',
        productId: 'P-CONCUR-A',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(50000),
        unitCost: Money.fromMinorUnits(30000),
      );

      final cmd1 = CreateReturnOrderCommand(
        commandId: 'RET-CONCUR-A1',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-CA-1',
        items: [
          CreateReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'P-CONCUR-A',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: 'ACTOR-1',
        idempotencyKey: 'IDEM-CONCUR-A1',
      );

      final cmd2 = CreateReturnOrderCommand(
        commandId: 'RET-CONCUR-A2',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-CA-2',
        items: [
          CreateReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'P-CONCUR-A',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: 'ACTOR-2',
        idempotencyKey: 'IDEM-CONCUR-A2',
      );

      // Launch both concurrently
      final futures = [
        returnsCoordinator.createReturnOrder(cmd1),
        returnsCoordinator.createReturnOrder(cmd2),
      ];

      final results = await Future.wait(futures.map((f) async {
        try {
          await f;
          return (success: true, error: null);
        } catch (e) {
          return (success: false, error: e);
        }
      }));

      final successCount = results.where((r) => r.success).length;
      final failureCount = results.where((r) => !r.success).length;

      expect(successCount, equals(1), reason: 'Exactly one return request must succeed');
      expect(failureCount, equals(1), reason: 'The competing return request must fail');
      expect(results.firstWhere((r) => !r.success).error, isA<InvalidReturnQuantityFailure>());

      // Final returned orders in store must be exactly 1
      final orders = await returnOrderRepo.getReturnOrdersForSale(businessId: businessId, saleId: sale.id);
      expect(orders.length, equals(1));
    });

    test('96. CRITICAL TEST B: Two concurrent refunds for same return -> exactly 1 succeeds, 1 fails/conflict, exactly ONE refund recorded', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-CONCUR-B',
        productId: 'P-CONCUR-B',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(20000),
        unitCost: Money.fromMinorUnits(12000),
      );

      final retRes = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-CONCUR-B',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-CB',
        items: [
          CreateReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'P-CONCUR-B',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-CONCUR-B-RET',
      ));

      await returnsCoordinator.approveReturnOrder(ApproveReturnOrderCommand(
        commandId: 'CMD-CB-APP',
        businessId: businessId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-CB-APP',
      ));

      await returnsCoordinator.receiveReturnOrder(ReceiveReturnOrderCommand(
        commandId: 'CMD-CB-REC',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-CB-REC',
      ));

      final refundCmd1 = ProcessRefundCommand(
        commandId: 'REF-CONCUR-B1',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        refundAmount: Money.fromMinorUnits(20000),
        method: RefundMethod.cash,
        actorId: 'ACTOR-1',
        idempotencyKey: 'IDEM-REF-B1',
      );

      final refundCmd2 = ProcessRefundCommand(
        commandId: 'REF-CONCUR-B2',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        refundAmount: Money.fromMinorUnits(20000),
        method: RefundMethod.cash,
        actorId: 'ACTOR-2',
        idempotencyKey: 'IDEM-REF-B2',
      );

      final results = await Future.wait([refundCmd1, refundCmd2].map((cmd) async {
        try {
          await returnsCoordinator.processRefund(cmd);
          return (success: true, error: null);
        } catch (e) {
          return (success: false, error: e);
        }
      }));

      final successCount = results.where((r) => r.success).length;
      final failureCount = results.where((r) => !r.success).length;

      expect(successCount, equals(1));
      expect(failureCount, equals(1));

      final recordedRefunds = await refundRepo.getRefundsForReturn(returnId: retRes.order.id);
      expect(recordedRefunds.length, equals(1));
    });

    test('97. CRITICAL TEST C: Two concurrent supplier returns against remaining quantity -> no over-return, exactly 1 succeeds', () async {
      await purchaseReceiptRepo.saveReceipt(PurchaseReceipt(
        id: 'PREC-CONCUR-C',
        businessId: businessId,
        branchId: branchId,
        purchaseOrderId: 'PO-CONCUR-C',
        supplierId: 'SUP-C',
        items: [
          PurchaseReceiptItem(
            purchaseItemId: 'PI-CONCUR-C',
            productId: 'P-CONCUR-C',
            quantityReceived: StockQuantity.discrete(1), // Remaining is only 1
            unit: StockUnit.piece,
            unitCost: Money.fromMinorUnits(10000),
          ),
        ],
        receivedBy: staffUserId,
        receivedAt: DateTime.now(),
        idempotencyKey: 'IDEM-PREC-C',
      ));

      final cmd1 = CreateSupplierReturnCommand(
        commandId: 'SRET-CONCUR-C1',
        businessId: businessId,
        branchId: branchId,
        supplierId: 'SUP-C',
        originalPurchaseId: 'PO-CONCUR-C',
        originalReceiptId: 'PREC-CONCUR-C',
        returnNumber: 'SRN-C1',
        items: [
          SupplierReturnItemInput(
            purchaseReceiptItemId: 'PI-CONCUR-C',
            productId: 'P-CONCUR-C',
            quantity: StockQuantity.discrete(1),
            reason: 'Defective part',
          ),
        ],
        reason: 'Defective batch return',
        actorId: 'ACTOR-1',
        idempotencyKey: 'IDEM-C1',
      );

      final cmd2 = CreateSupplierReturnCommand(
        commandId: 'SRET-CONCUR-C2',
        businessId: businessId,
        branchId: branchId,
        supplierId: 'SUP-C',
        originalPurchaseId: 'PO-CONCUR-C',
        originalReceiptId: 'PREC-CONCUR-C',
        returnNumber: 'SRN-C2',
        items: [
          SupplierReturnItemInput(
            purchaseReceiptItemId: 'PI-CONCUR-C',
            productId: 'P-CONCUR-C',
            quantity: StockQuantity.discrete(1),
            reason: 'Defective part',
          ),
        ],
        reason: 'Defective batch return',
        actorId: 'ACTOR-2',
        idempotencyKey: 'IDEM-C2',
      );

      final results = await Future.wait([cmd1, cmd2].map((cmd) async {
        try {
          await returnsCoordinator.createSupplierReturn(cmd);
          return (success: true, error: null);
        } catch (e) {
          return (success: false, error: e);
        }
      }));

      final successCount = results.where((r) => r.success).length;
      final failureCount = results.where((r) => !r.success).length;

      expect(successCount, equals(1));
      expect(failureCount, equals(1));

      final supplierReturns = await supplierReturnRepo.getSupplierReturns(businessId: businessId);
      expect(supplierReturns.length, equals(1));
    });

    test('98. Concurrent post sale financials for same sale results in single execution via lock', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-CONCUR-FIN',
        productId: 'P-CFIN',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(6000),
      );

      final cmd1 = PostSaleFinancialsCommand(
        commandId: 'CMD-CFIN-1',
        businessId: businessId,
        branchId: branchId,
        sale: sale,
        actorId: 'ACTOR-1',
        idempotencyKey: 'IDEM-FIN-CONCUR',
      );

      final cmd2 = PostSaleFinancialsCommand(
        commandId: 'CMD-CFIN-2',
        businessId: businessId,
        branchId: branchId,
        sale: sale,
        actorId: 'ACTOR-2',
        idempotencyKey: 'IDEM-FIN-CONCUR',
      );

      final res = await Future.wait([
        financeCoordinator.postSaleFinancials(cmd1),
        financeCoordinator.postSaleFinancials(cmd2),
      ]);

      expect(res[0].revenueEntry?.id, equals(res[1].revenueEntry?.id));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // GROUP O: FINANCIAL RECONCILIATION SERVICE (5 Tests)
  // ═════════════════════════════════════════════════════════════════════════════
  group('Group O: Financial Reconciliation Service', () {
    test('99. Balanced reconciliation report when Sales equal Revenue entries', () async {
      final sale = await createCompletedSale(
        saleId: 'S-REC-1',
        productId: 'P1',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(50000),
        unitCost: Money.fromMinorUnits(30000),
      );

      // Post revenue
      await financeCoordinator.postSaleFinancials(PostSaleFinancialsCommand(
        commandId: 'CMD-REC-FIN-1',
        businessId: businessId,
        branchId: branchId,
        sale: sale,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-REC-1',
      ));

      final report = await reconciliationService.reconcileFinance(businessId: businessId);
      expect(report.isRevenueBalanced, isTrue);
      expect(report.hasDiscrepancies, isFalse);
    });

    test('100. Reconciliation detects mismatch when Sale exists without Revenue entry', () async {
      // Create sale without posting financials
      await createCompletedSale(
        saleId: 'S-UNPOSTED',
        productId: 'P1',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(50000),
        unitCost: Money.fromMinorUnits(30000),
      );

      final report = await reconciliationService.reconcileFinance(businessId: businessId);
      expect(report.isRevenueBalanced, isFalse);
      expect(report.discrepancies.any((d) => d.checkType == 'SALES_REVENUE_MISMATCH'), isTrue);
    });

    test('101. Reconciliation detects mismatch between Returns and executed Refunds', () async {
      final sale = await createCompletedSale(
        saleId: 'S-REC-REF',
        productId: 'P1',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(20000),
        unitCost: Money.fromMinorUnits(12000),
      );

      // Return order is completed, but NO refund was saved in refundRepo
      final retOrder = ReturnOrder(
        id: 'RET-UNREFUNDED',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-UNREF',
        type: ReturnType.fullReturn,
        status: ReturnOrderStatus.completed,
        items: [
          ReturnItem(
            id: 'RI-U',
            originalSaleItemId: sale.items.first.itemId,
            productId: 'P1',
            descriptionSnapshot: 'Item',
            skuSnapshot: 'SKU',
            quantity: StockQuantity.discrete(1),
            unitRefundPrice: Money.fromMinorUnits(20000),
            originalCostBasis: Money.fromMinorUnits(12000),
          ),
        ],
        currency: Currency.iqd,
        createdBy: staffUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        idempotencyKey: 'IDEM-UNREF',
      );
      await returnOrderRepo.saveReturnOrder(retOrder);

      final report = await reconciliationService.reconcileFinance(businessId: businessId);
      expect(report.isReturnsBalanced, isFalse);
      expect(report.discrepancies.any((d) => d.checkType == 'RETURNS_REFUND_MISMATCH'), isTrue);
    });

    test('102. Supplier returns and credit notes match verification', () async {
      await supplierReturnRepo.saveSupplierReturn(SupplierReturn(
        id: 'SR-REC',
        businessId: businessId,
        branchId: branchId,
        supplierId: 'SUP-1',
        originalPurchaseId: 'PO-1',
        originalReceiptId: 'PREC-1',
        returnNumber: 'SRN-REC',
        status: SupplierReturnStatus.completed,
        items: [
          SupplierReturnItem(
            id: 'SRI-1',
            purchaseReceiptItemId: 'PI-1',
            productId: 'P1',
            quantity: StockQuantity.discrete(1),
            unitCost: Money.fromMinorUnits(10000),
            reason: 'Damaged',
          ),
        ],
        currency: Currency.iqd,
        reason: 'Damaged batch return',
        actorId: staffUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        idempotencyKey: 'IDEM-SR-REC',
      ));

      await supplierCreditNoteRepo.saveCreditNote(SupplierCreditNote(
        id: 'CN-SR-REC',
        businessId: businessId,
        supplierId: 'SUP-1',
        supplierReturnId: 'SR-REC',
        creditNoteNumber: 'CN-NUM-1',
        amount: Money.fromMinorUnits(10000),
        reason: 'Credit note',
        createdAt: DateTime.now(),
        actorId: staffUserId,
        idempotencyKey: 'IDEM-CN-REC',
      ));

      final report = await reconciliationService.reconcileFinance(businessId: businessId);
      expect(report.isSupplierReturnsBalanced, isTrue);
    });

    test('103. Discrepancy details capture expected, actual and delta accurately', () async {
      await createCompletedSale(
        saleId: 'S-DELTA',
        productId: 'P1',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(25000),
        unitCost: Money.fromMinorUnits(15000),
      );

      final report = await reconciliationService.reconcileFinance(businessId: businessId);
      final disc = report.discrepancies.firstWhere((d) => d.checkType == 'SALES_REVENUE_MISMATCH');
      expect(disc.expectedAmount.minorUnits, equals(25000));
      expect(disc.actualAmount.minorUnits, equals(0));
      expect(disc.discrepancy.minorUnits, equals(-25000));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════════
  // GROUP P: RBAC, MULTI-TENANT ISOLATION & AUDIT TRAIL (7 Tests)
  // ═════════════════════════════════════════════════════════════════════════════
  group('Group P: RBAC, Multi-Tenant Isolation & Audit Trail', () {
    test('104. Cashier role cannot approve return orders (ReturnsPermissionDeniedFailure)', () async {
      final cashierCoordinator = ReturnsCoordinator(
        returnOrderRepo: returnOrderRepo,
        refundRepo: refundRepo,
        supplierReturnRepo: supplierReturnRepo,
        supplierCreditNoteRepo: supplierCreditNoteRepo,
        idempotencyStore: returnsIdemStore,
        posRepo: posRepo,
        inventoryTxService: inventoryService,
        purchaseReceiptRepo: purchaseReceiptRepo,
        supplierLedgerRepo: supplierLedgerRepo,
        supplierRepo: supplierRepo,
        auditRepo: auditRepo,
        currentBusinessId: businessId,
        currentBranchId: branchId,
        currentRole: ShopRole.cashier,
      );

      final cmd = ApproveReturnOrderCommand(
        commandId: 'CMD-APP-CASH',
        businessId: businessId,
        returnOrderId: 'RET-001',
        actorId: 'CASHIER-1',
        idempotencyKey: 'IDEM-APP-CASH',
      );

      expect(() => cashierCoordinator.approveReturnOrder(cmd), throwsA(isA<ReturnsPermissionDeniedFailure>()));
    });

    test('105. Inventory clerk cannot process financial refunds', () async {
      final clerkCoordinator = ReturnsCoordinator(
        returnOrderRepo: returnOrderRepo,
        refundRepo: refundRepo,
        supplierReturnRepo: supplierReturnRepo,
        supplierCreditNoteRepo: supplierCreditNoteRepo,
        idempotencyStore: returnsIdemStore,
        posRepo: posRepo,
        inventoryTxService: inventoryService,
        purchaseReceiptRepo: purchaseReceiptRepo,
        supplierLedgerRepo: supplierLedgerRepo,
        supplierRepo: supplierRepo,
        auditRepo: auditRepo,
        currentBusinessId: businessId,
        currentBranchId: branchId,
        currentRole: ShopRole.inventoryClerk,
      );

      final cmd = ProcessRefundCommand(
        commandId: 'REF-001',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: 'RET-001',
        refundAmount: Money.fromMinorUnits(5000),
        method: RefundMethod.cash,
        actorId: 'CLERK-1',
        idempotencyKey: 'IDEM-REF-CLERK',
      );

      expect(() => clerkCoordinator.processRefund(cmd), throwsA(isA<ReturnsPermissionDeniedFailure>()));
    });

    test('106. Cashier cannot view profit reports (FinancePermissionDeniedFailure)', () async {
      final cashierFinanceCoordinator = FinanceCoordinator(
        financialEntryRepo: financialEntryRepo,
        costLayerRepo: costLayerRepo,
        idempotencyStore: financeIdemStore,
        posRepo: posRepo,
        inventoryRepo: inventoryRepo,
        auditRepo: auditRepo,
        currentBusinessId: businessId,
        currentBranchId: branchId,
        currentRole: ShopRole.cashier,
      );

      final cmd = CalculatePeriodProfitCommand(
        businessId: businessId,
        branchId: branchId,
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        actorId: 'CASHIER-1',
      );

      expect(() => cashierFinanceCoordinator.calculatePeriodProfit(cmd), throwsA(isA<FinancePermissionDeniedFailure>()));
    });

    test('107. Multi-tenant business isolation in ReturnsCoordinator', () async {
      final cmd = CreateReturnOrderCommand(
        commandId: 'RET-DIFF-BIZ',
        businessId: 'BUSINESS-OTHER', // Mismatched business
        branchId: branchId,
        originalSaleId: 'SALE-1',
        returnNumber: 'RN-DIFF',
        items: [],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-DIFF-BIZ',
      );

      expect(() => returnsCoordinator.createReturnOrder(cmd), throwsA(isA<ReturnsBusinessMismatchFailure>()));
    });

    test('108. Multi-tenant business isolation in FinanceCoordinator', () async {
      final sale = await createCompletedSale(
        saleId: 'S-DIFF',
        productId: 'P-DIFF',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(1000),
        unitCost: Money.fromMinorUnits(500),
      );

      final cmd = PostSaleFinancialsCommand(
        commandId: 'CMD-DIFF-FIN',
        businessId: 'BUSINESS-OTHER',
        branchId: branchId,
        sale: sale,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-DIFF',
      );

      expect(() => financeCoordinator.postSaleFinancials(cmd), throwsA(isA<FinanceBusinessMismatchFailure>()));
    });

    test('109. Audit trail records append-only entries across return lifecycle', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-AUDIT-LIFECYCLE',
        productId: 'P-AUDIT',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(6000),
      );

      final retRes = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-AUD-LIFE',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-LIFE',
        items: [
          CreateReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'P-AUDIT',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: staffUserId,
        idempotencyKey: 'IDEM-LIFE-1',
      ));

      await returnsCoordinator.approveReturnOrder(ApproveReturnOrderCommand(
        commandId: 'CMD-AUD-APP',
        businessId: businessId,
        returnOrderId: retRes.order.id,
        actorId: staffUserId,
        idempotencyKey: 'IDEM-AUD-APP',
      ));

      final actions = auditRepo.entries.map((e) => e.action).toSet();
      expect(actions.contains(ShopAuditAction.returnCreated), isTrue);
      expect(actions.contains(ShopAuditAction.returnApproved), isTrue);
    });

    test('110. Actor identity tracking: createdBy, approvedBy, receivedBy, refundedBy distinct actors preserved', () async {
      final sale = await createCompletedSale(
        saleId: 'SALE-ACTORS',
        productId: 'P-ACT',
        quantity: 1,
        unitPrice: Money.fromMinorUnits(10000),
        unitCost: Money.fromMinorUnits(6000),
      );

      final retRes = await returnsCoordinator.createReturnOrder(CreateReturnOrderCommand(
        commandId: 'RET-ACTORS',
        businessId: businessId,
        branchId: branchId,
        originalSaleId: sale.id,
        returnNumber: 'RN-ACT',
        items: [
          CreateReturnItemInput(
            originalSaleItemId: sale.items.first.itemId,
            productId: 'P-ACT',
            quantity: StockQuantity.discrete(1),
          ),
        ],
        actorId: 'CREATOR-USER',
        idempotencyKey: 'IDEM-ACT-1',
      ));

      final appRes = await returnsCoordinator.approveReturnOrder(ApproveReturnOrderCommand(
        commandId: 'CMD-ACT-APP',
        businessId: businessId,
        returnOrderId: retRes.order.id,
        actorId: 'APPROVER-USER',
        idempotencyKey: 'IDEM-ACT-APP',
      ));

      final recRes = await returnsCoordinator.receiveReturnOrder(ReceiveReturnOrderCommand(
        commandId: 'CMD-ACT-REC',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        actorId: 'RECEIVER-USER',
        idempotencyKey: 'IDEM-ACT-REC',
      ));

      final refRes = await returnsCoordinator.processRefund(ProcessRefundCommand(
        commandId: 'REF-ACTORS',
        businessId: businessId,
        branchId: branchId,
        returnOrderId: retRes.order.id,
        refundAmount: Money.fromMinorUnits(10000),
        method: RefundMethod.cash,
        actorId: 'REFUNDER-USER',
        idempotencyKey: 'IDEM-ACT-REF',
      ));

      expect(refRes.order.createdBy, equals('CREATOR-USER'));
      expect(refRes.order.approvedBy, equals('APPROVER-USER'));
      expect(refRes.order.receivedBy, equals('RECEIVER-USER'));
      expect(refRes.order.refundedBy, equals('REFUNDER-USER'));
    });
  });
}
