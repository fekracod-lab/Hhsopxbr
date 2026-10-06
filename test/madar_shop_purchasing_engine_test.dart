// MADAR SHOP — Phase S4 Test Suite
// Purchasing + Suppliers + Payables Comprehensive Test Matrix (70+ Tests)

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/madar_shop/madar_shop.dart';

class TestAuditRepository implements IShopAuditRepository {
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
    return entries.where((e) => e.businessId == businessId && e.branchId == branchId).toList();
  }
}

void main() {
  const testBusinessId = 'BIZ-MADAR-001';
  const testBranchId = 'BR-BAGHDAD-01';
  const testBranchId2 = 'BR-BASRA-02';
  const testActorId = 'USR-OPERATOR-1';

  late TestAuditRepository auditRepo;
  late ShopIdentityCoordinator identityCoord;
  late InMemoryInventoryRepository inventoryRepo;
  late InMemoryInventoryLedgerRepository inventoryLedgerRepo;
  late InMemoryInventoryIdempotencyStore inventoryIdemStore;
  late InventoryTransactionService inventoryService;

  late MemorySupplierRepository supplierRepo;
  late MemorySupplierLedgerRepository supplierLedgerRepo;
  late MemoryPurchaseOrderRepository poRepo;
  late MemoryPurchaseReceiptRepository receiptRepo;
  late MemorySupplierPaymentRepository paymentRepo;
  late MemoryPurchasingIdempotencyStore purchasingIdemStore;
  late PurchasingCoordinator purchasingCoord;
  late PurchasingReconciliationService reconciliationService;

  late List<PurchasingDomainEvent> emittedEvents;

  void setSessionForUser({
    required String userId,
    required String businessId,
    required String branchId,
    required ShopRole role,
    List<String>? accessibleBranchIds,
  }) {
    final now = DateTime.now();
    final user = ShopUser(
      userId: userId,
      businessId: businessId,
      fullName: 'Test User $userId',
      phone: '07700000000',
      email: '$userId@madar.iq',
      role: role,
      assignedBranchIds: accessibleBranchIds ?? [branchId],
      createdAt: now,
    );
    final session = ShopSession(
      sessionId: 'SESS-$userId',
      installationId: 'INST-01',
      terminalId: 'TERM-01',
      userId: userId,
      businessId: businessId,
      activeBranchId: branchId,
      startedAt: now,
      lastHeartbeatAt: now,
      expiresAt: now.add(const Duration(hours: 8)),
      status: ShopSessionStatus.active,
    );
    identityCoord.setSession(user: user, session: session);
  }

  setUp(() async {
    auditRepo = TestAuditRepository();
    identityCoord = ShopIdentityCoordinator();
    inventoryRepo = InMemoryInventoryRepository();
    inventoryLedgerRepo = InMemoryInventoryLedgerRepository();
    inventoryIdemStore = InMemoryInventoryIdempotencyStore();

    inventoryService = InventoryTransactionService(
      inventoryRepository: inventoryRepo,
      ledgerRepository: inventoryLedgerRepo,
      idempotencyStore: inventoryIdemStore,
      identityCoordinator: identityCoord,
      auditRepository: auditRepo,
    );

    supplierRepo = MemorySupplierRepository();
    supplierLedgerRepo = MemorySupplierLedgerRepository();
    poRepo = MemoryPurchaseOrderRepository();
    receiptRepo = MemoryPurchaseReceiptRepository();
    paymentRepo = MemorySupplierPaymentRepository();
    purchasingIdemStore = MemoryPurchasingIdempotencyStore();

    emittedEvents = [];

    purchasingCoord = PurchasingCoordinator(
      supplierRepository: supplierRepo,
      supplierLedgerRepository: supplierLedgerRepo,
      purchaseOrderRepository: poRepo,
      purchaseReceiptRepository: receiptRepo,
      supplierPaymentRepository: paymentRepo,
      idempotencyStore: purchasingIdemStore,
      inventoryService: inventoryService,
      identityCoordinator: identityCoord,
      auditRepository: auditRepo,
      eventSink: (event) => emittedEvents.add(event),
    );

    reconciliationService = PurchasingReconciliationService(
      purchaseOrderRepository: poRepo,
      receiptRepository: receiptRepo,
      inventoryLedgerRepository: inventoryLedgerRepo,
      supplierRepository: supplierRepo,
      supplierLedgerRepository: supplierLedgerRepo,
    );

    // تسجيل دخول المشرف صاحب الصلاحيات الكاملة
    setSessionForUser(
      userId: testActorId,
      businessId: testBusinessId,
      branchId: testBranchId,
      role: ShopRole.generalManager,
      accessibleBranchIds: [testBranchId, testBranchId2],
    );
  });

  group('Group A: Supplier Domain & Accounts', () {
    test('1. create supplier creates active supplier and zero balance account', () async {
      final cmd = CreateSupplierCommand(
        commandId: 'SUP-001',
        businessId: testBusinessId,
        name: 'شركة الرافدين للتجارة',
        phone: '07700000001',
        email: 'info@rafidain.iq',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUP-1',
      );

      final res = await purchasingCoord.createSupplier(cmd);

      expect(res.isSuccess, isTrue);
      expect(res.supplier?.id, equals('SUP-001'));
      expect(res.supplier?.name, equals('شركة الرافدين للتجارة'));
      expect(res.supplier?.status, equals(SupplierStatus.active));
      expect(res.account?.currentBalance, equals(Money.zero()));
      expect(res.account?.version, equals(1));
    });

    test('2. active supplier allows creating purchase orders', () async {
      await purchasingCoord.createSupplier(CreateSupplierCommand(
        commandId: 'SUP-ACT',
        businessId: testBusinessId,
        name: 'مورد نشط',
        phone: '07700000002',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUP-ACT',
      ));

      final poRes = await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-ACT-01',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: 'SUP-ACT',
        orderNumber: 'PO-1001',
        items: [
          PurchaseItemInput(
            productId: 'PROD-1',
            description: 'رز بسمتي 5 كغم',
            sku: 'RICE-5KG',
            quantity: StockQuantity.discrete(10),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(15000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-ACT',
      ));

      expect(poRes.isSuccess, isTrue);
      expect(poRes.order?.status, equals(PurchaseOrderStatus.draft));
    });

    test('3. inactive supplier rejects purchase order creation', () async {
      await purchasingCoord.createSupplier(CreateSupplierCommand(
        commandId: 'SUP-INACT',
        businessId: testBusinessId,
        name: 'مورد غير نشط',
        phone: '07700000003',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUP-INACT',
      ));

      await purchasingCoord.updateSupplier(UpdateSupplierCommand(
        commandId: 'UPD-INACT',
        businessId: testBusinessId,
        supplierId: 'SUP-INACT',
        status: SupplierStatus.inactive,
        actorId: testActorId,
        idempotencyKey: 'IDEM-UPD-INACT',
      ));

      expect(
        () => purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
          commandId: 'PO-FAIL-INACT',
          businessId: testBusinessId,
          branchId: testBranchId,
          supplierId: 'SUP-INACT',
          orderNumber: 'PO-1002',
          items: [
            PurchaseItemInput(
              productId: 'PROD-1',
              description: 'سلعة',
              sku: 'SKU-1',
              quantity: StockQuantity.discrete(5),
              unit: StockUnit.piece,
              unitCost: Money.fromAmount(1000),
            ),
          ],
          actorId: testActorId,
          idempotencyKey: 'IDEM-PO-FAIL-INACT',
        )),
        throwsA(isA<SupplierInactiveFailure>()),
      );
    });

    test('4. blocked supplier rejects purchase order creation', () async {
      await purchasingCoord.createSupplier(CreateSupplierCommand(
        commandId: 'SUP-BLK',
        businessId: testBusinessId,
        name: 'مورد محظور',
        phone: '07700000004',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUP-BLK',
      ));

      await purchasingCoord.blockSupplier(BlockSupplierCommand(
        commandId: 'BLK-01',
        businessId: testBusinessId,
        supplierId: 'SUP-BLK',
        reason: 'تأخير متكرر ومخالفة شروط الجودة',
        actorId: testActorId,
        idempotencyKey: 'IDEM-BLK-01',
      ));

      expect(
        () => purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
          commandId: 'PO-FAIL-BLK',
          businessId: testBusinessId,
          branchId: testBranchId,
          supplierId: 'SUP-BLK',
          orderNumber: 'PO-1003',
          items: [
            PurchaseItemInput(
              productId: 'PROD-1',
              description: 'سلعة',
              sku: 'SKU-1',
              quantity: StockQuantity.discrete(5),
              unit: StockUnit.piece,
              unitCost: Money.fromAmount(1000),
            ),
          ],
          actorId: testActorId,
          idempotencyKey: 'IDEM-PO-FAIL-BLK',
        )),
        throwsA(isA<SupplierBlockedFailure>()),
      );
    });

    test('5. supplier scope isolation: suppliers are isolated by businessId', () async {
      await purchasingCoord.createSupplier(CreateSupplierCommand(
        commandId: 'SUP-ISOL',
        businessId: testBusinessId,
        name: 'مورد مدار 1',
        phone: '07700000005',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUP-ISOL',
      ));

      final suppliersBiz1 = await supplierRepo.getSuppliers(businessId: testBusinessId);
      final suppliersBiz2 = await supplierRepo.getSuppliers(businessId: 'BIZ-OTHER');

      expect(suppliersBiz1.length, equals(1));
      expect(suppliersBiz2.length, equals(0));
    });
  });

  group('Group B: Purchase Order Lifecycle & Totals', () {
    late String testSupplierId;

    setUp(() async {
      testSupplierId = 'SUP-PO-GROUP';
      await purchasingCoord.createSupplier(CreateSupplierCommand(
        commandId: testSupplierId,
        businessId: testBusinessId,
        name: 'مورد مجموعة أوامر الشراء',
        phone: '07700000010',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUP-PO-GRP',
      ));
    });

    test('6. create purchase order with valid items starts in draft', () async {
      final res = await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-001',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-ORD-001',
        items: [
          PurchaseItemInput(
            productId: 'P-101',
            description: 'حليب 1 لتر',
            sku: 'MILK-1L',
            quantity: StockQuantity.discrete(20),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(2000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-001',
      ));

      expect(res.isSuccess, isTrue);
      expect(res.order?.status, equals(PurchaseOrderStatus.draft));
      expect(res.order?.grandTotal, equals(Money.fromAmount(40000)));
    });

    test('7. purchase item snapshots details accurately', () async {
      final res = await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-002',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-ORD-002',
        items: [
          PurchaseItemInput(
            productId: 'P-102',
            variantId: 'VAR-RED',
            description: 'عصير برتقال طبيعي',
            sku: 'JUICE-ORG',
            barcode: '6281000001',
            quantity: StockQuantity.discrete(15),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(3000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-002',
      ));

      final item = res.order!.items.first;
      expect(item.productId, equals('P-102'));
      expect(item.variantId, equals('VAR-RED'));
      expect(item.descriptionSnapshot, equals('عصير برتقال طبيعي'));
      expect(item.skuSnapshot, equals('JUICE-ORG'));
      expect(item.barcodeSnapshot, equals('6281000001'));
      expect(item.quantityOrdered, equals(StockQuantity.discrete(15)));
      expect(item.quantityReceived, equals(StockQuantity.zero()));
    });

    test('8. subtotal and grandTotal calculate correctly across multiple lines', () async {
      final res = await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-003',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-ORD-003',
        items: [
          PurchaseItemInput(
            productId: 'P-A',
            description: 'بند أ',
            sku: 'SKU-A',
            quantity: StockQuantity.discrete(10),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(5000), // 50,000
          ),
          PurchaseItemInput(
            productId: 'P-B',
            description: 'بند ب',
            sku: 'SKU-B',
            quantity: StockQuantity.discrete(5),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(10000), // 50,000
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-003',
      ));

      expect(res.order?.subtotal, equals(Money.fromAmount(100000)));
      expect(res.order?.grandTotal, equals(Money.fromAmount(100000)));
    });

    test('9. discounts deduct properly from lineTotal and grandTotal', () async {
      final res = await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-004',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-ORD-004',
        items: [
          PurchaseItemInput(
            productId: 'P-DISC',
            description: 'بند مع خصم خاص',
            sku: 'SKU-DISC',
            quantity: StockQuantity.discrete(10),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(10000), // 100,000
            discount: Money.fromAmount(15000), // خصم 15,000
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-004',
      ));

      expect(res.order?.subtotal, equals(Money.fromAmount(100000)));
      expect(res.order?.discountTotal, equals(Money.fromAmount(15000)));
      expect(res.order?.grandTotal, equals(Money.fromAmount(85000)));
    });

    test('10. tax adds properly to lineTotal and grandTotal', () async {
      final res = await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-005',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-ORD-005',
        items: [
          PurchaseItemInput(
            productId: 'P-TAX',
            description: 'بند خاضع للضريبة',
            sku: 'SKU-TAX',
            quantity: StockQuantity.discrete(10),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(10000), // 100,000
            tax: Money.fromAmount(5000), // ضريبة 5,000
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-005',
      ));

      expect(res.order?.subtotal, equals(Money.fromAmount(100000)));
      expect(res.order?.taxTotal, equals(Money.fromAmount(5000)));
      expect(res.order?.grandTotal, equals(Money.fromAmount(105000)));
    });

    test('11. submit purchase order transitions from draft to submitted', () async {
      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-SUB-01',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-ORD-SUB',
        items: [
          PurchaseItemInput(
            productId: 'P-1',
            description: 'سلعة',
            sku: 'SKU-1',
            quantity: StockQuantity.discrete(5),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(2000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-SUB-CREATE',
      ));

      final subRes = await purchasingCoord.submitPurchaseOrder(SubmitPurchaseOrderCommand(
        commandId: 'CMD-SUB-01',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-SUB-01',
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-SUB-EXEC',
      ));

      expect(subRes.isSuccess, isTrue);
      expect(subRes.order?.status, equals(PurchaseOrderStatus.submitted));
      expect(subRes.order?.version, equals(2));
    });

    test('12. approve purchase order transitions from submitted to approved', () async {
      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-APP-01',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-ORD-APP',
        items: [
          PurchaseItemInput(
            productId: 'P-1',
            description: 'سلعة',
            sku: 'SKU-1',
            quantity: StockQuantity.discrete(5),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(2000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-APP-CREATE',
      ));

      await purchasingCoord.submitPurchaseOrder(SubmitPurchaseOrderCommand(
        commandId: 'CMD-SUB-APP',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-APP-01',
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-SUB-APP',
      ));

      final appRes = await purchasingCoord.approvePurchaseOrder(ApprovePurchaseOrderCommand(
        commandId: 'CMD-APP-01',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-APP-01',
        actorId: 'USR-MANAGER-99',
        idempotencyKey: 'IDEM-PO-APP-EXEC',
      ));

      expect(appRes.isSuccess, isTrue);
      expect(appRes.order?.status, equals(PurchaseOrderStatus.approved));
      expect(appRes.order?.approvedBy, equals('USR-MANAGER-99'));
    });

    test('13. cancel draft purchase order transitions to cancelled', () async {
      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-CAN-DRAFT',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-ORD-CAN-DRAFT',
        items: [
          PurchaseItemInput(
            productId: 'P-1',
            description: 'سلعة',
            sku: 'SKU-1',
            quantity: StockQuantity.discrete(5),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(2000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-CAN-DRAFT-C',
      ));

      final canRes = await purchasingCoord.cancelPurchaseOrder(CancelPurchaseOrderCommand(
        commandId: 'CMD-CAN-DRAFT',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-CAN-DRAFT',
        reason: 'إلغاء من قبل المنشئ قبل الإرسال',
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-CAN-DRAFT-X',
      ));

      expect(canRes.isSuccess, isTrue);
      expect(canRes.order?.status, equals(PurchaseOrderStatus.cancelled));
    });

    test('14. cancel approved order without receiving transitions to cancelled', () async {
      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-CAN-APP',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-ORD-CAN-APP',
        items: [
          PurchaseItemInput(
            productId: 'P-1',
            description: 'سلعة',
            sku: 'SKU-1',
            quantity: StockQuantity.discrete(5),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(2000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-CAN-APP-C',
      ));

      await purchasingCoord.submitPurchaseOrder(SubmitPurchaseOrderCommand(
        commandId: 'CMD-CAN-APP-S',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-CAN-APP',
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-CAN-APP-S',
      ));

      await purchasingCoord.approvePurchaseOrder(ApprovePurchaseOrderCommand(
        commandId: 'CMD-CAN-APP-A',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-CAN-APP',
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-CAN-APP-A',
      ));

      final canRes = await purchasingCoord.cancelPurchaseOrder(CancelPurchaseOrderCommand(
        commandId: 'CMD-CAN-APP-X',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-CAN-APP',
        reason: 'تراجع الإدارة عن شراء البضاعة',
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-CAN-APP-X',
      ));

      expect(canRes.isSuccess, isTrue);
      expect(canRes.order?.status, equals(PurchaseOrderStatus.cancelled));
    });

    test('15. invalid transition draft directly to approved throws StateTransitionFailure', () async {
      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-INV-TRANS',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-ORD-INV',
        items: [
          PurchaseItemInput(
            productId: 'P-1',
            description: 'سلعة',
            sku: 'SKU-1',
            quantity: StockQuantity.discrete(5),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(2000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-INV-C',
      ));

      expect(
        () => purchasingCoord.approvePurchaseOrder(ApprovePurchaseOrderCommand(
          commandId: 'CMD-INV-APPROVE',
          businessId: testBusinessId,
          purchaseOrderId: 'PO-INV-TRANS',
          actorId: testActorId,
          idempotencyKey: 'IDEM-INV-APP',
        )),
        throwsA(isA<InvalidPurchaseStateTransitionFailure>()),
      );
    });
  });

  group('Group C: Receiving & Partial Receiving Engine', () {
    late String testSupplierId;
    late String approvedPoId;

    setUp(() async {
      testSupplierId = 'SUP-REC-TEST';
      approvedPoId = 'PO-TO-RECEIVE';

      await purchasingCoord.createSupplier(CreateSupplierCommand(
        commandId: testSupplierId,
        businessId: testBusinessId,
        name: 'مورد اختبار الاستلام',
        phone: '07700000020',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUP-REC',
      ));

      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: approvedPoId,
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-REC-100',
        items: [
          PurchaseItemInput(
            productId: 'PROD-SUGAR',
            description: 'سكر أبيض 50 كغم',
            sku: 'SUGAR-50KG',
            quantity: StockQuantity.discrete(100),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(50000), // 5,000,000 IQD
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-REC-CREATE',
      ));

      await purchasingCoord.submitPurchaseOrder(SubmitPurchaseOrderCommand(
        commandId: 'SUB-REC-100',
        businessId: testBusinessId,
        purchaseOrderId: approvedPoId,
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-REC-SUB',
      ));

      await purchasingCoord.approvePurchaseOrder(ApprovePurchaseOrderCommand(
        commandId: 'APP-REC-100',
        businessId: testBusinessId,
        purchaseOrderId: approvedPoId,
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-REC-APP',
      ));
    });

    test('16. full receive in single shipment sets status to received', () async {
      final res = await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-FULL',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: approvedPoId,
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-$approvedPoId-1',
            productId: 'PROD-SUGAR',
            quantityToReceive: StockQuantity.discrete(100),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-REC-FULL',
      ));

      expect(res.isSuccess, isTrue);
      expect(res.order.status, equals(PurchaseOrderStatus.received));
      expect(res.order.items.first.quantityReceived, equals(StockQuantity.discrete(100)));
      expect(res.order.items.first.isFullyReceived, isTrue);
    });

    test('17. partial receive sets status to partiallyReceived and preserves remaining', () async {
      final res = await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-PART-1',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: approvedPoId,
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-$approvedPoId-1',
            productId: 'PROD-SUGAR',
            quantityToReceive: StockQuantity.discrete(25),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-REC-PART-1',
      ));

      expect(res.isSuccess, isTrue);
      expect(res.order.status, equals(PurchaseOrderStatus.partiallyReceived));
      expect(res.order.items.first.quantityReceived, equals(StockQuantity.discrete(25)));
      expect(res.order.items.first.remainingQuantity, equals(StockQuantity.discrete(75)));
    });

    test('18. second partial receive increments total received and status remains partiallyReceived', () async {
      // الدفعة الأولى 25
      await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-BATCH-1',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: approvedPoId,
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-$approvedPoId-1',
            productId: 'PROD-SUGAR',
            quantityToReceive: StockQuantity.discrete(25),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-REC-B1',
      ));

      // الدفعة الثانية 50
      final res2 = await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-BATCH-2',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: approvedPoId,
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-$approvedPoId-1',
            productId: 'PROD-SUGAR',
            quantityToReceive: StockQuantity.discrete(50),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-REC-B2',
      ));

      expect(res2.order.status, equals(PurchaseOrderStatus.partiallyReceived));
      expect(res2.order.items.first.quantityReceived, equals(StockQuantity.discrete(75)));
      expect(res2.order.items.first.remainingQuantity, equals(StockQuantity.discrete(25)));
    });

    test('19. final receive completing 100% transitions order to received', () async {
      // استلام 75 أولاً
      await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-SEQ-1',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: approvedPoId,
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-$approvedPoId-1',
            productId: 'PROD-SUGAR',
            quantityToReceive: StockQuantity.discrete(75),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-REC-S1',
      ));

      // استلام المتبقي 25
      final finalRes = await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-SEQ-2',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: approvedPoId,
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-$approvedPoId-1',
            productId: 'PROD-SUGAR',
            quantityToReceive: StockQuantity.discrete(25),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-REC-S2',
      ));

      expect(finalRes.order.status, equals(PurchaseOrderStatus.received));
      expect(finalRes.order.items.first.quantityReceived, equals(StockQuantity.discrete(100)));
      expect(finalRes.order.items.first.remainingQuantity, equals(StockQuantity.zero()));
    });

    test('20. over receive is blocked under default policy', () async {
      expect(
        () => purchasingCoord.receiveGoods(ReceiveGoodsCommand(
          commandId: 'REC-OVER',
          businessId: testBusinessId,
          branchId: testBranchId,
          purchaseOrderId: approvedPoId,
          items: [
            ReceiveGoodsItemInput(
              purchaseItemId: 'PI-$approvedPoId-1',
              productId: 'PROD-SUGAR',
              quantityToReceive: StockQuantity.discrete(101), // طلب 100 فقط
            ),
          ],
          policy: OverReceivingPolicy.block,
          actorId: testActorId,
          idempotencyKey: 'IDEM-REC-OVER',
        )),
        throwsA(isA<OverReceivingBlockedFailure>()),
      );
    });

    test('21. duplicate receive with same idempotency key does not re-process', () async {
      final cmd = ReceiveGoodsCommand(
        commandId: 'REC-IDEM-TEST',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: approvedPoId,
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-$approvedPoId-1',
            productId: 'PROD-SUGAR',
            quantityToReceive: StockQuantity.discrete(40),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-KEY-REPLAY-40',
      );

      final firstRes = await purchasingCoord.receiveGoods(cmd);
      final secondRes = await purchasingCoord.receiveGoods(cmd);

      expect(firstRes.order.items.first.quantityReceived, equals(StockQuantity.discrete(40)));
      expect(secondRes.order.items.first.quantityReceived, equals(StockQuantity.discrete(40)));
      expect(firstRes.receipt.id, equals(secondRes.receipt.id));
    });

    test('22. invalid receipt with unlisted item throws InvalidPurchaseQuantityFailure', () async {
      expect(
        () => purchasingCoord.receiveGoods(ReceiveGoodsCommand(
          commandId: 'REC-UNLISTED',
          businessId: testBusinessId,
          branchId: testBranchId,
          purchaseOrderId: approvedPoId,
          items: [
            ReceiveGoodsItemInput(
              purchaseItemId: 'PI-NON-EXISTENT',
              productId: 'PROD-ALIEN',
              quantityToReceive: StockQuantity.discrete(5),
            ),
          ],
          actorId: testActorId,
          idempotencyKey: 'IDEM-REC-UNLISTED',
        )),
        throwsA(isA<InvalidPurchaseQuantityFailure>()),
      );
    });
  });

  group('Group D: Inventory S3 Integration Authority', () {
    late String testSupplierId;
    late String approvedPoId;

    setUp(() async {
      testSupplierId = 'SUP-S3-TEST';
      approvedPoId = 'PO-S3-LINK';

      await purchasingCoord.createSupplier(CreateSupplierCommand(
        commandId: testSupplierId,
        businessId: testBusinessId,
        name: 'مورد ربط المخزون',
        phone: '07700000030',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUP-S3',
      ));

      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: approvedPoId,
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-S3-100',
        items: [
          PurchaseItemInput(
            productId: 'INV-OIL-1L',
            description: 'زيت طبخ 1 لتر',
            sku: 'OIL-1L',
            quantity: StockQuantity.discrete(50),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(2500),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-S3-CREATE',
      ));

      await purchasingCoord.submitPurchaseOrder(SubmitPurchaseOrderCommand(
        commandId: 'SUB-S3-100',
        businessId: testBusinessId,
        purchaseOrderId: approvedPoId,
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-S3-SUB',
      ));

      await purchasingCoord.approvePurchaseOrder(ApprovePurchaseOrderCommand(
        commandId: 'APP-S3-100',
        businessId: testBusinessId,
        purchaseOrderId: approvedPoId,
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-S3-APP',
      ));
    });

    test('23. receiving increases S3 stock onHand', () async {
      final initialItem = await inventoryRepo.getInventoryItem(
        businessId: testBusinessId,
        branchId: testBranchId,
        productId: 'INV-OIL-1L',
      );
      expect(initialItem, isNull);

      await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-S3-1',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: approvedPoId,
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-$approvedPoId-1',
            productId: 'INV-OIL-1L',
            quantityToReceive: StockQuantity.discrete(30),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-S3-REC-1',
      ));

      final itemAfter = await inventoryRepo.getInventoryItem(
        businessId: testBusinessId,
        branchId: testBranchId,
        productId: 'INV-OIL-1L',
      );

      expect(itemAfter, isNotNull);
      expect(itemAfter!.onHand, equals(StockQuantity.discrete(30)));
    });

    test('24. correct quantity in onHand equals sum of all receipts', () async {
      await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-S3-A',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: approvedPoId,
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-$approvedPoId-1',
            productId: 'INV-OIL-1L',
            quantityToReceive: StockQuantity.discrete(20),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-S3-A',
      ));

      await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-S3-B',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: approvedPoId,
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-$approvedPoId-1',
            productId: 'INV-OIL-1L',
            quantityToReceive: StockQuantity.discrete(30),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-S3-B',
      ));

      final item = await inventoryRepo.getInventoryItem(
        businessId: testBusinessId,
        branchId: testBranchId,
        productId: 'INV-OIL-1L',
      );

      expect(item!.onHand, equals(StockQuantity.discrete(50)));
    });

    test('25. variant receiving increases variant-specific stock independently', () async {
      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-VAR-TEST',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-VAR-01',
        items: [
          PurchaseItemInput(
            productId: 'SHIRT',
            variantId: 'VAR-S',
            description: 'قميص قياس S',
            sku: 'SHIRT-S',
            quantity: StockQuantity.discrete(10),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(10000),
          ),
          PurchaseItemInput(
            productId: 'SHIRT',
            variantId: 'VAR-L',
            description: 'قميص قياس L',
            sku: 'SHIRT-L',
            quantity: StockQuantity.discrete(15),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(10000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-VAR-C',
      ));

      await purchasingCoord.submitPurchaseOrder(SubmitPurchaseOrderCommand(
        commandId: 'SUB-VAR',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-VAR-TEST',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUB-VAR',
      ));

      await purchasingCoord.approvePurchaseOrder(ApprovePurchaseOrderCommand(
        commandId: 'APP-VAR',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-VAR-TEST',
        actorId: testActorId,
        idempotencyKey: 'IDEM-APP-VAR',
      ));

      await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-VAR-S',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: 'PO-VAR-TEST',
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-PO-VAR-TEST-1',
            productId: 'SHIRT',
            variantId: 'VAR-S',
            quantityToReceive: StockQuantity.discrete(10),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-REC-VAR-S',
      ));

      final itemS = await inventoryRepo.getInventoryItem(
        businessId: testBusinessId,
        branchId: testBranchId,
        productId: 'SHIRT',
        variantId: 'VAR-S',
      );
      final itemL = await inventoryRepo.getInventoryItem(
        businessId: testBusinessId,
        branchId: testBranchId,
        productId: 'SHIRT',
        variantId: 'VAR-L',
      );

      expect(itemS?.onHand, equals(StockQuantity.discrete(10)));
      expect(itemL, isNull);
    });

    test('26. weighted item receiving works with decimal precision', () async {
      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-WEIGHT',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-WEIGHT-01',
        items: [
          PurchaseItemInput(
            productId: 'MEAT-KG',
            description: 'لحم بقري طازج',
            sku: 'MEAT-BEEF',
            quantity: StockQuantity.fromDouble(25.500, StockUnit.kg),
            unit: StockUnit.kg,
            unitCost: Money.fromAmount(12000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-W-C',
      ));

      await purchasingCoord.submitPurchaseOrder(SubmitPurchaseOrderCommand(
        commandId: 'SUB-W',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-WEIGHT',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUB-W',
      ));

      await purchasingCoord.approvePurchaseOrder(ApprovePurchaseOrderCommand(
        commandId: 'APP-W',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-WEIGHT',
        actorId: testActorId,
        idempotencyKey: 'IDEM-APP-W',
      ));

      await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-WEIGHT-1',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: 'PO-WEIGHT',
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-PO-WEIGHT-1',
            productId: 'MEAT-KG',
            quantityToReceive: StockQuantity.fromDouble(25.500, StockUnit.kg),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-REC-W-1',
      ));

      final item = await inventoryRepo.getInventoryItem(
        businessId: testBusinessId,
        branchId: testBranchId,
        productId: 'MEAT-KG',
      );

      expect(item?.onHand.toDouble(), equals(25.500));
    });

    test('27. duplicate receive replay does not double stock in S3', () async {
      final cmd = ReceiveGoodsCommand(
        commandId: 'REC-S3-DUP',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: approvedPoId,
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-$approvedPoId-1',
            productId: 'INV-OIL-1L',
            quantityToReceive: StockQuantity.discrete(15),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-S3-DOUBLE-CHECK',
      );

      await purchasingCoord.receiveGoods(cmd);
      await purchasingCoord.receiveGoods(cmd); // إعادة إرسال نفس الأمر

      final item = await inventoryRepo.getInventoryItem(
        businessId: testBusinessId,
        branchId: testBranchId,
        productId: 'INV-OIL-1L',
      );

      expect(item?.onHand, equals(StockQuantity.discrete(15))); // ليس 30!
    });

    test('28. branch isolation: receiving increases stock strictly in target branch', () async {
      await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-BRANCH-ISOL',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: approvedPoId,
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-$approvedPoId-1',
            productId: 'INV-OIL-1L',
            quantityToReceive: StockQuantity.discrete(10),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-BR-ISOL-1',
      ));

      final itemBranch1 = await inventoryRepo.getInventoryItem(
        businessId: testBusinessId,
        branchId: testBranchId,
        productId: 'INV-OIL-1L',
      );
      final itemBranch2 = await inventoryRepo.getInventoryItem(
        businessId: testBusinessId,
        branchId: testBranchId2,
        productId: 'INV-OIL-1L',
      );

      expect(itemBranch1?.onHand, equals(StockQuantity.discrete(10)));
      expect(itemBranch2, isNull);
    });
  });

  group('Group E: Supplier Ledger Semantics & Append-Only Rules', () {
    late String testSupplierId;

    setUp(() async {
      testSupplierId = 'SUP-LEDGER-GROUP';
      await purchasingCoord.createSupplier(CreateSupplierCommand(
        commandId: testSupplierId,
        businessId: testBusinessId,
        name: 'مورد دفتر الأستاذ',
        phone: '07700000040',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUP-LEDGER',
      ));
    });

    test('29. purchase goods creates credit entry in ledger increasing payable', () async {
      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-LED-1',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-LED-001',
        items: [
          PurchaseItemInput(
            productId: 'P-1',
            description: 'سلعة',
            sku: 'SKU-1',
            quantity: StockQuantity.discrete(10),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(10000), // 100,000 IQD
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-LED-C1',
      ));

      await purchasingCoord.submitPurchaseOrder(SubmitPurchaseOrderCommand(
        commandId: 'SUB-LED-1',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-LED-1',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUB-LED-1',
      ));

      await purchasingCoord.approvePurchaseOrder(ApprovePurchaseOrderCommand(
        commandId: 'APP-LED-1',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-LED-1',
        actorId: testActorId,
        idempotencyKey: 'IDEM-APP-LED-1',
      ));

      await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-LED-1',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: 'PO-LED-1',
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-PO-LED-1-1',
            productId: 'P-1',
            quantityToReceive: StockQuantity.discrete(10),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-REC-LED-1',
      ));

      final entries = await supplierLedgerRepo.getEntriesForSupplier(
        businessId: testBusinessId,
        supplierId: testSupplierId,
      );

      expect(entries.length, equals(1));
      final entry = entries.first;
      expect(entry.entryType, equals(SupplierLedgerEntryType.purchase));
      expect(entry.credit, equals(Money.fromAmount(100000)));
      expect(entry.balanceDelta, equals(Money.fromAmount(100000)));
      expect(entry.balanceAfter, equals(Money.fromAmount(100000)));

      final account = await supplierRepo.getSupplierAccount(
        businessId: testBusinessId,
        supplierId: testSupplierId,
      );
      expect(account?.currentBalance, equals(Money.fromAmount(100000)));
    });

    test('30. payment creates debit entry in ledger reducing payable', () async {
      // إيداع فاتورة أولاً بقيمة 100,000
      final account = await supplierRepo.getSupplierAccount(
        businessId: testBusinessId,
        supplierId: testSupplierId,
      );
      await supplierRepo.saveSupplierAccount(account!.copyWith(
        currentBalance: Money.fromAmount(100000),
      ));

      final payRes = await purchasingCoord.paySupplier(PaySupplierCommand(
        commandId: 'PAY-01',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        amount: Money.fromAmount(40000),
        method: SupplierPaymentMethod.cash,
        actorId: testActorId,
        idempotencyKey: 'IDEM-PAY-01',
      ));

      expect(payRes.isSuccess, isTrue);
      expect(payRes.ledgerEntry.entryType, equals(SupplierLedgerEntryType.payment));
      expect(payRes.ledgerEntry.debit, equals(Money.fromAmount(40000)));
      expect(payRes.ledgerEntry.balanceDelta, equals(-Money.fromAmount(40000)));
      expect(payRes.ledgerEntry.balanceAfter, equals(Money.fromAmount(60000)));
      expect(payRes.updatedAccount.currentBalance, equals(Money.fromAmount(60000)));
    });

    test('31. running balance correctly updates after each consecutive entry', () async {
      final account = await supplierRepo.getSupplierAccount(
        businessId: testBusinessId,
        supplierId: testSupplierId,
      );
      await supplierRepo.saveSupplierAccount(account!.copyWith(
        currentBalance: Money.fromAmount(100000),
      ));

      await purchasingCoord.paySupplier(PaySupplierCommand(
        commandId: 'PAY-STEP-1',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        amount: Money.fromAmount(30000),
        actorId: testActorId,
        idempotencyKey: 'IDEM-PAY-STEP-1',
      ));

      await purchasingCoord.paySupplier(PaySupplierCommand(
        commandId: 'PAY-STEP-2',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        amount: Money.fromAmount(20000),
        actorId: testActorId,
        idempotencyKey: 'IDEM-PAY-STEP-2',
      ));

      final entries = await supplierLedgerRepo.getEntriesForSupplier(
        businessId: testBusinessId,
        supplierId: testSupplierId,
      );

      expect(entries[0].balanceAfter, equals(Money.fromAmount(70000)));
      expect(entries[1].balanceAfter, equals(Money.fromAmount(50000)));
    });

    test('32. multiple purchases accumulate payable in ledger', () async {
      // قيدين مشتريات
      await supplierLedgerRepo.appendEntry(SupplierLedgerEntry(
        id: 'L-P1',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        referenceType: 'PURCHASE_RECEIPT',
        referenceId: 'R-1',
        entryType: SupplierLedgerEntryType.purchase,
        debit: Money.zero(),
        credit: Money.fromAmount(50000),
        balanceDelta: Money.fromAmount(50000),
        balanceAfter: Money.fromAmount(50000),
        currency: Currency.iqd,
        actorId: testActorId,
        createdAt: DateTime.now(),
        version: 1,
        idempotencyKey: 'K1',
      ));

      await supplierLedgerRepo.appendEntry(SupplierLedgerEntry(
        id: 'L-P2',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        referenceType: 'PURCHASE_RECEIPT',
        referenceId: 'R-2',
        entryType: SupplierLedgerEntryType.purchase,
        debit: Money.zero(),
        credit: Money.fromAmount(30000),
        balanceDelta: Money.fromAmount(30000),
        balanceAfter: Money.fromAmount(80000),
        currency: Currency.iqd,
        actorId: testActorId,
        createdAt: DateTime.now(),
        version: 2,
        idempotencyKey: 'K2',
      ));

      final entries = await supplierLedgerRepo.getEntriesForSupplier(
        businessId: testBusinessId,
        supplierId: testSupplierId,
      );

      expect(entries.length, equals(2));
      expect(entries.last.balanceAfter, equals(Money.fromAmount(80000)));
    });

    test('33. multiple payments deduct payable accurately to zero', () async {
      final account = await supplierRepo.getSupplierAccount(
        businessId: testBusinessId,
        supplierId: testSupplierId,
      );
      await supplierRepo.saveSupplierAccount(account!.copyWith(
        currentBalance: Money.fromAmount(50000),
      ));

      await purchasingCoord.paySupplier(PaySupplierCommand(
        commandId: 'P-CLEAR-1',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        amount: Money.fromAmount(30000),
        actorId: testActorId,
        idempotencyKey: 'IDEM-P-CLEAR-1',
      ));

      final clearRes = await purchasingCoord.paySupplier(PaySupplierCommand(
        commandId: 'P-CLEAR-2',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        amount: Money.fromAmount(20000),
        actorId: testActorId,
        idempotencyKey: 'IDEM-P-CLEAR-2',
      ));

      expect(clearRes.updatedAccount.currentBalance, equals(Money.zero()));
    });

    test('34. append-only enforcement: attempting to overwrite existing entry ID throws StateError', () async {
      final entry = SupplierLedgerEntry(
        id: 'IMMUTABLE-ENTRY-001',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        referenceType: 'PURCHASE',
        referenceId: 'PO-X',
        entryType: SupplierLedgerEntryType.purchase,
        debit: Money.zero(),
        credit: Money.fromAmount(10000),
        balanceDelta: Money.fromAmount(10000),
        balanceAfter: Money.fromAmount(10000),
        currency: Currency.iqd,
        actorId: testActorId,
        createdAt: DateTime.now(),
        version: 1,
        idempotencyKey: 'K-IMMUTABLE',
      );

      await supplierLedgerRepo.appendEntry(entry);

      expect(
        () => supplierLedgerRepo.appendEntry(entry),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Group F: Supplier Payments & Accounts Payable', () {
    late String testSupplierId;

    setUp(() async {
      testSupplierId = 'SUP-PAY-GROUP';
      await purchasingCoord.createSupplier(CreateSupplierCommand(
        commandId: testSupplierId,
        businessId: testBusinessId,
        name: 'مورد المدفوعات',
        phone: '07700000050',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUP-PAY-GRP',
      ));

      // تعيين رصيد مستحق بقيمة 100,000
      final account = await supplierRepo.getSupplierAccount(
        businessId: testBusinessId,
        supplierId: testSupplierId,
      );
      await supplierRepo.saveSupplierAccount(account!.copyWith(
        currentBalance: Money.fromAmount(100000),
      ));
    });

    test('35. exact payment clears full payable balance to zero', () async {
      final res = await purchasingCoord.paySupplier(PaySupplierCommand(
        commandId: 'PAY-EXACT',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        amount: Money.fromAmount(100000),
        method: SupplierPaymentMethod.bankTransfer,
        reference: 'TR-100234',
        actorId: testActorId,
        idempotencyKey: 'IDEM-PAY-EXACT',
      ));

      expect(res.isSuccess, isTrue);
      expect(res.updatedAccount.currentBalance, equals(Money.zero()));
      expect(res.payment.reference, equals('TR-100234'));
    });

    test('36. partial payment leaves remaining payable', () async {
      final res = await purchasingCoord.paySupplier(PaySupplierCommand(
        commandId: 'PAY-PARTIAL',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        amount: Money.fromAmount(35000),
        actorId: testActorId,
        idempotencyKey: 'IDEM-PAY-PARTIAL',
      ));

      expect(res.updatedAccount.currentBalance, equals(Money.fromAmount(65000)));
    });

    test('37. multiple partial payments succession 30k + 50k + 20k', () async {
      await purchasingCoord.paySupplier(PaySupplierCommand(
        commandId: 'P-1',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        amount: Money.fromAmount(30000),
        actorId: testActorId,
        idempotencyKey: 'IDEM-P1',
      ));

      await purchasingCoord.paySupplier(PaySupplierCommand(
        commandId: 'P-2',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        amount: Money.fromAmount(50000),
        actorId: testActorId,
        idempotencyKey: 'IDEM-P2',
      ));

      final res3 = await purchasingCoord.paySupplier(PaySupplierCommand(
        commandId: 'P-3',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        amount: Money.fromAmount(20000),
        actorId: testActorId,
        idempotencyKey: 'IDEM-P3',
      ));

      expect(res3.updatedAccount.currentBalance, equals(Money.zero()));
    });

    test('38. overpayment is blocked under default policy', () async {
      expect(
        () => purchasingCoord.paySupplier(PaySupplierCommand(
          commandId: 'PAY-OVER',
          businessId: testBusinessId,
          supplierId: testSupplierId,
          amount: Money.fromAmount(105000), // الرصيد 100,000 فقط
          policy: SupplierOverpaymentPolicy.block,
          actorId: testActorId,
          idempotencyKey: 'IDEM-PAY-OVER',
        )),
        throwsA(isA<SupplierOverpaymentBlockedFailure>()),
      );
    });

    test('39. invalid payment with zero or negative amount throws rejection', () async {
      expect(
        () => purchasingCoord.paySupplier(PaySupplierCommand(
          commandId: 'PAY-ZERO',
          businessId: testBusinessId,
          supplierId: testSupplierId,
          amount: Money.zero(),
          actorId: testActorId,
          idempotencyKey: 'IDEM-PAY-ZERO',
        )),
        throwsA(isA<SupplierOverpaymentBlockedFailure>()),
      );
    });

    test('40. duplicate payment command replay protection', () async {
      final cmd = PaySupplierCommand(
        commandId: 'PAY-DUP',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        amount: Money.fromAmount(25000),
        actorId: testActorId,
        idempotencyKey: 'IDEM-PAY-DUP-KEY',
      );

      final res1 = await purchasingCoord.paySupplier(cmd);
      final res2 = await purchasingCoord.paySupplier(cmd);

      expect(res1.payment.id, equals(res2.payment.id));
      expect(res2.updatedAccount.currentBalance, equals(Money.fromAmount(75000))); // لم يخصم 50,000!
    });
  });

  group('Group G: Idempotency Across All Commands', () {
    late String testSupplierId;

    setUp(() async {
      testSupplierId = 'SUP-IDEM-GROUP';
      await purchasingCoord.createSupplier(CreateSupplierCommand(
        commandId: testSupplierId,
        businessId: testBusinessId,
        name: 'مورد التكرار',
        phone: '07700000060',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUP-IDEM-GRP',
      ));
    });

    test('41. duplicate create purchase order returns cached order without duplicating', () async {
      final cmd = CreatePurchaseOrderCommand(
        commandId: 'PO-IDEM-1',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-IDEM-ORD',
        items: [
          PurchaseItemInput(
            productId: 'P-1',
            description: 'سلعة',
            sku: 'SKU-1',
            quantity: StockQuantity.discrete(5),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(1000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-CREATE-SAME',
      );

      final r1 = await purchasingCoord.createPurchaseOrder(cmd);
      final r2 = await purchasingCoord.createPurchaseOrder(cmd);

      expect(r1.order?.id, equals(r2.order?.id));
      final all = await poRepo.getPurchaseOrders(businessId: testBusinessId);
      expect(all.length, equals(1));
    });

    test('42. duplicate receive goods returns cached receipt', () async {
      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-IDEM-REC',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-IDEM-R',
        items: [
          PurchaseItemInput(
            productId: 'P-1',
            description: 'سلعة',
            sku: 'SKU-1',
            quantity: StockQuantity.discrete(10),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(1000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-C-R',
      ));

      await purchasingCoord.submitPurchaseOrder(SubmitPurchaseOrderCommand(
        commandId: 'SUB-IDEM-R',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-IDEM-REC',
        actorId: testActorId,
        idempotencyKey: 'IDEM-S-R',
      ));

      await purchasingCoord.approvePurchaseOrder(ApprovePurchaseOrderCommand(
        commandId: 'APP-IDEM-R',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-IDEM-REC',
        actorId: testActorId,
        idempotencyKey: 'IDEM-A-R',
      ));

      final rCmd = ReceiveGoodsCommand(
        commandId: 'REC-DUP-CHECK',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: 'PO-IDEM-REC',
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-PO-IDEM-REC-1',
            productId: 'P-1',
            quantityToReceive: StockQuantity.discrete(5),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-R-DUP-SAME',
      );

      final res1 = await purchasingCoord.receiveGoods(rCmd);
      final res2 = await purchasingCoord.receiveGoods(rCmd);

      expect(res1.receipt.id, equals(res2.receipt.id));
    });

    test('43. duplicate payment returns cached payment result', () async {
      final account = await supplierRepo.getSupplierAccount(
        businessId: testBusinessId,
        supplierId: testSupplierId,
      );
      await supplierRepo.saveSupplierAccount(account!.copyWith(
        currentBalance: Money.fromAmount(50000),
      ));

      final payCmd = PaySupplierCommand(
        commandId: 'PAY-DUP-IDEM',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        amount: Money.fromAmount(10000),
        actorId: testActorId,
        idempotencyKey: 'IDEM-PAY-SAME-KEY',
      );

      final p1 = await purchasingCoord.paySupplier(payCmd);
      final p2 = await purchasingCoord.paySupplier(payCmd);

      expect(p1.payment.id, equals(p2.payment.id));
    });

    test('44. replay of completed command produces single state change and emits duplicate event', () async {
      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-EVT-REC',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-EVT-R',
        items: [
          PurchaseItemInput(
            productId: 'P-1',
            description: 'سلعة',
            sku: 'SKU-1',
            quantity: StockQuantity.discrete(10),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(1000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-C-EVT',
      ));

      await purchasingCoord.submitPurchaseOrder(SubmitPurchaseOrderCommand(
        commandId: 'SUB-EVT-R',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-EVT-REC',
        actorId: testActorId,
        idempotencyKey: 'IDEM-S-EVT',
      ));

      await purchasingCoord.approvePurchaseOrder(ApprovePurchaseOrderCommand(
        commandId: 'APP-EVT-R',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-EVT-REC',
        actorId: testActorId,
        idempotencyKey: 'IDEM-A-EVT',
      ));

      final rCmd = ReceiveGoodsCommand(
        commandId: 'REC-EVT-DUP',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: 'PO-EVT-REC',
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-PO-EVT-REC-1',
            productId: 'P-1',
            quantityToReceive: StockQuantity.discrete(10),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-EVT-DUP-KEY',
      );

      await purchasingCoord.receiveGoods(rCmd);
      await purchasingCoord.receiveGoods(rCmd); // replay

      expect(
        emittedEvents.any((e) => e is DuplicateReceiveDetectedEvent),
        isTrue,
      );
    });
  });

  group('Group H: Authorization, RBAC & Multi-Tenant Isolation', () {
    test('45. cashier cannot create purchase order', () async {
      setSessionForUser(
        userId: 'USR-CASHIER',
        businessId: testBusinessId,
        branchId: testBranchId,
        role: ShopRole.cashier,
      );

      expect(
        () => purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
          commandId: 'PO-CASHIER',
          businessId: testBusinessId,
          branchId: testBranchId,
          supplierId: 'SUP-ANY',
          orderNumber: 'PO-100',
          items: [
            PurchaseItemInput(
              productId: 'P-1',
              description: 'سلعة',
              sku: 'SKU-1',
              quantity: StockQuantity.discrete(5),
              unit: StockUnit.piece,
              unitCost: Money.fromAmount(1000),
            ),
          ],
          actorId: 'USR-CASHIER',
          idempotencyKey: 'IDEM-CASHIER',
        )),
        throwsA(isA<UnauthorizedPurchasingOperationFailure>()),
      );
    });

    test('46. cashier cannot approve purchase order', () async {
      setSessionForUser(
        userId: 'USR-CASHIER',
        businessId: testBusinessId,
        branchId: testBranchId,
        role: ShopRole.cashier,
      );

      expect(
        () => purchasingCoord.approvePurchaseOrder(ApprovePurchaseOrderCommand(
          commandId: 'APP-CASHIER',
          businessId: testBusinessId,
          purchaseOrderId: 'PO-ANY',
          actorId: 'USR-CASHIER',
          idempotencyKey: 'IDEM-APP-CASHIER',
        )),
        throwsA(isA<UnauthorizedPurchasingOperationFailure>()),
      );
    });

    test('47. inventory clerk can receive goods', () async {
      // إعداد أمر شراء معتمد أولاً كمدير
      final s = Supplier(
        id: 'SUP-CLERK',
        businessId: testBusinessId,
        name: 'مورد الكاتب',
        phone: '07700000070',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await supplierRepo.saveSupplier(s);

      final po = PurchaseOrder(
        id: 'PO-CLERK',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: 'SUP-CLERK',
        orderNumber: 'PO-CLK',
        status: PurchaseOrderStatus.approved,
        items: [
          PurchaseItem(
            id: 'PI-CLK-1',
            productId: 'P-CLK',
            descriptionSnapshot: 'سلعة',
            skuSnapshot: 'SKU-CLK',
            quantityOrdered: StockQuantity.discrete(10),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(1000),
          ),
        ],
        createdBy: testActorId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        idempotencyKey: 'IDEM-CLK-PO',
      );
      await poRepo.savePurchaseOrder(po);

      // تبديل المستخدم إلى كاتب مخزن (Inventory Clerk)
      setSessionForUser(
        userId: 'USR-CLERK',
        businessId: testBusinessId,
        branchId: testBranchId,
        role: ShopRole.inventoryClerk,
      );

      final recRes = await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-CLK',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: 'PO-CLERK',
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-CLK-1',
            productId: 'P-CLK',
            quantityToReceive: StockQuantity.discrete(10),
          ),
        ],
        actorId: 'USR-CLERK',
        idempotencyKey: 'IDEM-CLK-REC',
      ));

      expect(recRes.isSuccess, isTrue);
    });

    test('48. inventory clerk cannot pay supplier', () async {
      setSessionForUser(
        userId: 'USR-CLERK',
        businessId: testBusinessId,
        branchId: testBranchId,
        role: ShopRole.inventoryClerk,
      );

      expect(
        () => purchasingCoord.paySupplier(PaySupplierCommand(
          commandId: 'PAY-CLERK',
          businessId: testBusinessId,
          supplierId: 'SUP-ANY',
          amount: Money.fromAmount(10000),
          actorId: 'USR-CLERK',
          idempotencyKey: 'IDEM-PAY-CLK',
        )),
        throwsA(isA<UnauthorizedPurchasingOperationFailure>()),
      );
    });

    test('49. branch mismatch rejects operation on inaccessible branch', () async {
      setSessionForUser(
        userId: 'USR-BRANCH-MGR',
        businessId: testBusinessId,
        branchId: testBranchId,
        role: ShopRole.branchManager,
        accessibleBranchIds: [testBranchId], // ليس لديه صلاحية البصرة
      );

      expect(
        () => purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
          commandId: 'PO-BASRA',
          businessId: testBusinessId,
          branchId: testBranchId2, // فرع البصرة
          supplierId: 'SUP-ANY',
          orderNumber: 'PO-BASRA-1',
          items: [
            PurchaseItemInput(
              productId: 'P-1',
              description: 'سلعة',
              sku: 'SKU-1',
              quantity: StockQuantity.discrete(5),
              unit: StockUnit.piece,
              unitCost: Money.fromAmount(1000),
            ),
          ],
          actorId: 'USR-BRANCH-MGR',
          idempotencyKey: 'IDEM-BASRA',
        )),
        throwsA(isA<PurchasingBranchMismatchFailure>()),
      );
    });

    test('50. business mismatch rejects operation on different business', () async {
      expect(
        () => purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
          commandId: 'PO-OTHER-BIZ',
          businessId: 'BIZ-COMPETITOR',
          branchId: testBranchId,
          supplierId: 'SUP-ANY',
          orderNumber: 'PO-COMP-1',
          items: [
            PurchaseItemInput(
              productId: 'P-1',
              description: 'سلعة',
              sku: 'SKU-1',
              quantity: StockQuantity.discrete(5),
              unit: StockUnit.piece,
              unitCost: Money.fromAmount(1000),
            ),
          ],
          actorId: testActorId,
          idempotencyKey: 'IDEM-OTHER-BIZ',
        )),
        throwsA(isA<PurchasingBusinessMismatchFailure>()),
      );
    });
  });

  group('Group I: Cancellation Rules', () {
    late String testSupplierId;

    setUp(() async {
      testSupplierId = 'SUP-CAN-GROUP';
      await purchasingCoord.createSupplier(CreateSupplierCommand(
        commandId: testSupplierId,
        businessId: testBusinessId,
        name: 'مورد الإلغاء',
        phone: '07700000080',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUP-CAN-GRP',
      ));
    });

    test('51. cancel before receive cancels full order', () async {
      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-CAN-BEFORE',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-CAN-B',
        items: [
          PurchaseItemInput(
            productId: 'P-1',
            description: 'سلعة',
            sku: 'SKU-1',
            quantity: StockQuantity.discrete(20),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(2000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-CAN-B-C',
      ));

      final res = await purchasingCoord.cancelPurchaseOrder(CancelPurchaseOrderCommand(
        commandId: 'CMD-CAN-B',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-CAN-BEFORE',
        reason: 'إلغاء قبل الشحن',
        actorId: testActorId,
        idempotencyKey: 'IDEM-CAN-B-X',
      ));

      expect(res.order?.status, equals(PurchaseOrderStatus.cancelled));
    });

    test('52. full cancel of partially received order is rejected', () async {
      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-CAN-PARTIAL',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-CAN-P',
        items: [
          PurchaseItemInput(
            productId: 'P-1',
            description: 'سلعة',
            sku: 'SKU-1',
            quantity: StockQuantity.discrete(100),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(1000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-CAN-P-C',
      ));

      await purchasingCoord.submitPurchaseOrder(SubmitPurchaseOrderCommand(
        commandId: 'SUB-CAN-P',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-CAN-PARTIAL',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUB-CAN-P',
      ));

      await purchasingCoord.approvePurchaseOrder(ApprovePurchaseOrderCommand(
        commandId: 'APP-CAN-P',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-CAN-PARTIAL',
        actorId: testActorId,
        idempotencyKey: 'IDEM-APP-CAN-P',
      ));

      await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-CAN-P-40',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: 'PO-CAN-PARTIAL',
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-PO-CAN-PARTIAL-1',
            productId: 'P-1',
            quantityToReceive: StockQuantity.discrete(40),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-REC-P-40',
      ));

      // محاولة إلغاء كلي
      expect(
        () => purchasingCoord.cancelPurchaseOrder(CancelPurchaseOrderCommand(
          commandId: 'CMD-CAN-FULL-REJECT',
          businessId: testBusinessId,
          purchaseOrderId: 'PO-CAN-PARTIAL',
          reason: 'إلغاء كلي غير مسموح',
          cancelRemainingOnly: false,
          actorId: testActorId,
          idempotencyKey: 'IDEM-CAN-FULL-REJECT',
        )),
        throwsA(isA<InvalidPurchaseStateTransitionFailure>()),
      );
    });

    test('53. cancel remaining quantity closes order and keeps already received intact', () async {
      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-CAN-REM',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-CAN-R',
        items: [
          PurchaseItemInput(
            productId: 'P-REM',
            description: 'سلعة متبقية',
            sku: 'SKU-REM',
            quantity: StockQuantity.discrete(100),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(1000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-CAN-R-C',
      ));

      await purchasingCoord.submitPurchaseOrder(SubmitPurchaseOrderCommand(
        commandId: 'SUB-CAN-R',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-CAN-REM',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUB-CAN-R',
      ));

      await purchasingCoord.approvePurchaseOrder(ApprovePurchaseOrderCommand(
        commandId: 'APP-CAN-R',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-CAN-REM',
        actorId: testActorId,
        idempotencyKey: 'IDEM-APP-CAN-R',
      ));

      await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-CAN-R-40',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: 'PO-CAN-REM',
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-PO-CAN-REM-1',
            productId: 'P-REM',
            quantityToReceive: StockQuantity.discrete(40),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-REC-R-40',
      ));

      // إلغاء المتبقي فقط
      final res = await purchasingCoord.cancelPurchaseOrder(CancelPurchaseOrderCommand(
        commandId: 'CMD-CAN-REM-OK',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-CAN-REM',
        reason: 'المورد نفذت لديه الكمية ولن يشحن المتبقي 60',
        cancelRemainingOnly: true,
        actorId: testActorId,
        idempotencyKey: 'IDEM-CAN-REM-OK',
      ));

      expect(res.order?.status, equals(PurchaseOrderStatus.closed));
      expect(res.order?.items.first.quantityReceived, equals(StockQuantity.discrete(40)));
      expect(res.order?.items.first.quantityOrdered, equals(StockQuantity.discrete(40)));

      // التحقق من أن المخزون لم يتأثر وظل +40
      final invItem = await inventoryRepo.getInventoryItem(
        businessId: testBusinessId,
        branchId: testBranchId,
        productId: 'P-REM',
      );
      expect(invItem?.onHand, equals(StockQuantity.discrete(40)));
    });

    test('54. cancelled or closed order cannot be cancelled again', () async {
      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-TERM-CAN',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-TERM',
        items: [
          PurchaseItemInput(
            productId: 'P-1',
            description: 'سلعة',
            sku: 'SKU-1',
            quantity: StockQuantity.discrete(10),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(1000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-TERM-C',
      ));

      await purchasingCoord.cancelPurchaseOrder(CancelPurchaseOrderCommand(
        commandId: 'CMD-TERM-1',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-TERM-CAN',
        reason: 'إلغاء أول',
        actorId: testActorId,
        idempotencyKey: 'IDEM-TERM-1',
      ));

      expect(
        () => purchasingCoord.cancelPurchaseOrder(CancelPurchaseOrderCommand(
          commandId: 'CMD-TERM-2',
          businessId: testBusinessId,
          purchaseOrderId: 'PO-TERM-CAN',
          reason: 'محاولة إلغاء ثانية',
          actorId: testActorId,
          idempotencyKey: 'IDEM-TERM-2',
        )),
        throwsA(isA<InvalidPurchaseStateTransitionFailure>()),
      );
    });
  });

  group('Group J: Reconciliation Service', () {
    late String testSupplierId;

    setUp(() async {
      testSupplierId = 'SUP-RECON-GRP';
      await purchasingCoord.createSupplier(CreateSupplierCommand(
        commandId: testSupplierId,
        businessId: testBusinessId,
        name: 'مورد المطابقة',
        phone: '07700000090',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUP-RECON',
      ));
    });

    test('55. matching inventory reconciliation: zero discrepancy when all receipts match inventory ledger', () async {
      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-RECON-MATCH',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-RECON-1',
        items: [
          PurchaseItemInput(
            productId: 'P-MATCH',
            description: 'سلعة مطابقة',
            sku: 'SKU-M',
            quantity: StockQuantity.discrete(50),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(2000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-RECON-M-C',
      ));

      await purchasingCoord.submitPurchaseOrder(SubmitPurchaseOrderCommand(
        commandId: 'SUB-M',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-RECON-MATCH',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUB-M',
      ));

      await purchasingCoord.approvePurchaseOrder(ApprovePurchaseOrderCommand(
        commandId: 'APP-M',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-RECON-MATCH',
        actorId: testActorId,
        idempotencyKey: 'IDEM-APP-M',
      ));

      await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-M',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: 'PO-RECON-MATCH',
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-PO-RECON-MATCH-1',
            productId: 'P-MATCH',
            quantityToReceive: StockQuantity.discrete(50),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-REC-M',
      ));

      final report = await reconciliationService.reconcilePurchasing(businessId: testBusinessId);

      expect(report.isInventoryBalanced, isTrue);
      expect(report.inventoryDiscrepancies, isEmpty);
    });

    test('56. inventory mismatch detected when inventory movements do not match purchase receipts', () async {
      // إيصال استلام 30 ولكن سجل المخزون به 20 فقط (محاكاة خلل)
      final receipt = PurchaseReceipt(
        id: 'REC-FAKE-MISMATCH',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: 'PO-FAKE-ORD',
        supplierId: testSupplierId,
        items: [
          PurchaseReceiptItem(
            purchaseItemId: 'PI-FAKE-1',
            productId: 'P-TAMPER',
            quantityReceived: StockQuantity.discrete(30),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(1000),
          ),
        ],
        receivedBy: testActorId,
        receivedAt: DateTime.now(),
        idempotencyKey: 'IDEM-FAKE-R',
      );
      await receiptRepo.saveReceipt(receipt);

      final fakePo = PurchaseOrder(
        id: 'PO-FAKE-ORD',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-FAKE',
        items: [],
        createdBy: testActorId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        idempotencyKey: 'IDEM-FAKE-PO',
      );
      await poRepo.savePurchaseOrder(fakePo);

      // إضافة حركة مخزنية 20 فقط
      await inventoryLedgerRepo.appendLedgerEntry(InventoryLedgerEntry(
        id: 'LED-TAMPER-1',
        businessId: testBusinessId,
        branchId: testBranchId,
        productId: 'P-TAMPER',
        movementType: InventoryMovementType.purchase,
        quantityDelta: StockQuantity.discrete(20),
        reservedDelta: StockQuantity.zero(StockUnit.piece),
        unit: StockUnit.piece,
        beforeOnHand: StockQuantity.zero(),
        afterOnHand: StockQuantity.discrete(20),
        beforeReserved: StockQuantity.zero(),
        afterReserved: StockQuantity.zero(),
        beforeAvailable: StockQuantity.zero(),
        afterAvailable: StockQuantity.discrete(20),
        referenceType: 'PURCHASE',
        referenceId: 'PO-FAKE-ORD',
        actorId: testActorId,
        reason: 'حركة اختبار مطابقة تالفة',
        createdAt: DateTime.now(),
        version: 1,
        idempotencyKey: 'IDEM-TAMPER',
      ));

      final report = await reconciliationService.reconcilePurchasing(businessId: testBusinessId);

      expect(report.isInventoryBalanced, isFalse);
      expect(report.inventoryDiscrepancies.length, equals(1));
      expect(report.inventoryDiscrepancies.first.difference, equals(StockQuantity.discrete(10)));
    });

    test('57. matching supplier ledger: account balance equals sum of ledger deltas', () async {
      await supplierLedgerRepo.appendEntry(SupplierLedgerEntry(
        id: 'LED-M1',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        referenceType: 'PURCHASE_RECEIPT',
        referenceId: 'R1',
        entryType: SupplierLedgerEntryType.purchase,
        debit: Money.zero(),
        credit: Money.fromAmount(70000),
        balanceDelta: Money.fromAmount(70000),
        balanceAfter: Money.fromAmount(70000),
        currency: Currency.iqd,
        actorId: testActorId,
        createdAt: DateTime.now(),
        version: 1,
        idempotencyKey: 'M1',
      ));

      await supplierLedgerRepo.appendEntry(SupplierLedgerEntry(
        id: 'LED-M2',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        referenceType: 'SUPPLIER_PAYMENT',
        referenceId: 'P1',
        entryType: SupplierLedgerEntryType.payment,
        debit: Money.fromAmount(20000),
        credit: Money.zero(),
        balanceDelta: -Money.fromAmount(20000),
        balanceAfter: Money.fromAmount(50000),
        currency: Currency.iqd,
        actorId: testActorId,
        createdAt: DateTime.now(),
        version: 2,
        idempotencyKey: 'M2',
      ));

      final account = await supplierRepo.getSupplierAccount(
        businessId: testBusinessId,
        supplierId: testSupplierId,
      );
      await supplierRepo.saveSupplierAccount(account!.copyWith(
        currentBalance: Money.fromAmount(50000),
      ));

      final report = await reconciliationService.reconcilePurchasing(businessId: testBusinessId);

      expect(report.isSupplierLedgerBalanced, isTrue);
      expect(report.supplierDiscrepancies, isEmpty);
    });

    test('58. supplier ledger mismatch detected when account balance is tampered', () async {
      // إدخال قيد 50,000 ولكن الرصيد في الحساب 40,000
      await supplierLedgerRepo.appendEntry(SupplierLedgerEntry(
        id: 'LED-TAMPER-S',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        referenceType: 'PURCHASE_RECEIPT',
        referenceId: 'R1',
        entryType: SupplierLedgerEntryType.purchase,
        debit: Money.zero(),
        credit: Money.fromAmount(50000),
        balanceDelta: Money.fromAmount(50000),
        balanceAfter: Money.fromAmount(50000),
        currency: Currency.iqd,
        actorId: testActorId,
        createdAt: DateTime.now(),
        version: 1,
        idempotencyKey: 'TS1',
      ));

      final account = await supplierRepo.getSupplierAccount(
        businessId: testBusinessId,
        supplierId: testSupplierId,
      );
      await supplierRepo.saveSupplierAccount(account!.copyWith(
        currentBalance: Money.fromAmount(40000), // فارق 10,000
      ));

      final report = await reconciliationService.reconcilePurchasing(businessId: testBusinessId);

      expect(report.isSupplierLedgerBalanced, isFalse);
      expect(report.supplierDiscrepancies.length, equals(1));
      expect(report.supplierDiscrepancies.first.discrepancy, equals(-Money.fromAmount(10000)));

      // اختبار إعادة بناء الرصيد Rebuild
      final rebuilt = await reconciliationService.rebuildSupplierAccountBalance(
        businessId: testBusinessId,
        supplierId: testSupplierId,
      );
      expect(rebuilt.currentBalance, equals(Money.fromAmount(50000)));
    });
  });

  group('Group K: Concurrency Control & OCC (CRITICAL PROOFS)', () {
    late String testSupplierId;
    late String poOrdered20Id;

    setUp(() async {
      testSupplierId = 'SUP-CONCUR-GRP';
      poOrdered20Id = 'PO-ORDERED-20';

      await purchasingCoord.createSupplier(CreateSupplierCommand(
        commandId: testSupplierId,
        businessId: testBusinessId,
        name: 'مورد التزامن الحرج',
        phone: '07700000099',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUP-CONCUR',
      ));

      // أمر شراء بكمية 20 مطلوبة
      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: poOrdered20Id,
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-CONCUR-20',
        items: [
          PurchaseItemInput(
            productId: 'PROD-COMPETE-20',
            description: 'صنف التنافس المتزامن 20 وحدة',
            sku: 'COMPETE-20',
            quantity: StockQuantity.discrete(20),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(5000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-C20',
      ));

      await purchasingCoord.submitPurchaseOrder(SubmitPurchaseOrderCommand(
        commandId: 'SUB-C20',
        businessId: testBusinessId,
        purchaseOrderId: poOrdered20Id,
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUB-C20',
      ));

      await purchasingCoord.approvePurchaseOrder(ApprovePurchaseOrderCommand(
        commandId: 'APP-C20',
        businessId: testBusinessId,
        purchaseOrderId: poOrdered20Id,
        actorId: testActorId,
        idempotencyKey: 'IDEM-APP-C20',
      ));
    });

    test('59. concurrent duplicate receive requests safely serialized without corrupting state', () async {
      final cmd = ReceiveGoodsCommand(
        commandId: 'REC-CONCUR-DUP',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: poOrdered20Id,
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-$poOrdered20Id-1',
            productId: 'PROD-COMPETE-20',
            quantityToReceive: StockQuantity.discrete(10),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-CONCUR-DUP-SAME',
      );

      final futures = [
        purchasingCoord.receiveGoods(cmd),
        purchasingCoord.receiveGoods(cmd),
      ];

      final results = await Future.wait(futures);
      expect(results[0].receipt.id, equals(results[1].receipt.id));

      final invItem = await inventoryRepo.getInventoryItem(
        businessId: testBusinessId,
        branchId: testBranchId,
        productId: 'PROD-COMPETE-20',
      );
      expect(invItem?.onHand, equals(StockQuantity.discrete(10)));
    });

    test('60. CRITICAL TEST 46: two terminals concurrently receive remaining 20 units -> exactly 1 succeeds, 1 fails with OverReceivingBlockedFailure, final received = 20, inventory +20, ONE movement in ledger', () async {
      // أمر الشراء: 20 مطلوب، 20 متبقي.
      // جهازان متزامنان يطلبان استلام 20 في نفس اللحظة:
      final term1Cmd = ReceiveGoodsCommand(
        commandId: 'REC-TERM-1',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: poOrdered20Id,
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-$poOrdered20Id-1',
            productId: 'PROD-COMPETE-20',
            quantityToReceive: StockQuantity.discrete(20),
          ),
        ],
        terminalId: 'TERM-A',
        actorId: 'ACTOR-A',
        idempotencyKey: 'IDEM-TERM-A-20',
      );

      final term2Cmd = ReceiveGoodsCommand(
        commandId: 'REC-TERM-2',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: poOrdered20Id,
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-$poOrdered20Id-1',
            productId: 'PROD-COMPETE-20',
            quantityToReceive: StockQuantity.discrete(20),
          ),
        ],
        terminalId: 'TERM-B',
        actorId: 'ACTOR-B',
        idempotencyKey: 'IDEM-TERM-B-20',
      );

      int successCount = 0;
      int failureCount = 0;
      Object? capturedError;

      // تنفيذ متزامن حقيقي
      final futures = [
        purchasingCoord.receiveGoods(term1Cmd).then((r) {
          successCount++;
        }).catchError((err) {
          failureCount++;
          capturedError = err;
        }),
        purchasingCoord.receiveGoods(term2Cmd).then((r) {
          successCount++;
        }).catchError((err) {
          failureCount++;
          capturedError = err;
        }),
      ];

      await Future.wait(futures);

      // 1. فحص النتائج التنافسية
      expect(successCount, equals(1), reason: 'عملية واحدة فقط يجب أن تنجح بالاستلام');
      expect(failureCount, equals(1), reason: 'العملية المنافسة الأخرى يجب أن تفشل لمنع التكرار');
      expect(
        capturedError,
        anyOf(
          isA<OverReceivingBlockedFailure>(),
          isA<InvalidPurchaseStateTransitionFailure>(),
        ),
      );

      // 2. فحص حالة أمر الشراء النهائية
      final finalPo = await poRepo.getPurchaseOrderById(
        businessId: testBusinessId,
        purchaseOrderId: poOrdered20Id,
      );
      expect(finalPo?.items.first.quantityReceived, equals(StockQuantity.discrete(20)));
      expect(finalPo?.status, equals(PurchaseOrderStatus.received));

      // 3. فحص رصيد المخزون في S3
      final invItem = await inventoryRepo.getInventoryItem(
        businessId: testBusinessId,
        branchId: testBranchId,
        productId: 'PROD-COMPETE-20',
      );
      expect(invItem?.onHand, equals(StockQuantity.discrete(20)), reason: 'المخزون يجب أن يكون +20 تماماً، ويستحيل أن يكون 40');

      // 4. فحص دفتر أستاذ المخزون S3
      final invMovements = await inventoryLedgerRepo.getLedgerEntriesForReference(
        referenceType: 'PURCHASE',
        referenceId: poOrdered20Id,
      );
      expect(invMovements.length, equals(1), reason: 'حركة شراء واحدة فقط في دفتر أستاذ المخزون');
      expect(invMovements.first.quantityDelta, equals(StockQuantity.discrete(20)));
    });

    test('61. concurrent payments against supplier balance serialized safely without negative breach', () async {
      final account = await supplierRepo.getSupplierAccount(
        businessId: testBusinessId,
        supplierId: testSupplierId,
      );
      await supplierRepo.saveSupplierAccount(account!.copyWith(
        currentBalance: Money.fromAmount(50000),
      ));

      final p1 = PaySupplierCommand(
        commandId: 'PAY-C-1',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        amount: Money.fromAmount(50000),
        actorId: 'ACTOR-1',
        idempotencyKey: 'IDEM-PAY-C1',
      );

      final p2 = PaySupplierCommand(
        commandId: 'PAY-C-2',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        amount: Money.fromAmount(50000),
        actorId: 'ACTOR-2',
        idempotencyKey: 'IDEM-PAY-C2',
      );

      int success = 0;
      int fail = 0;

      await Future.wait([
        purchasingCoord.paySupplier(p1).then((_) => success++).catchError((_) => fail++),
        purchasingCoord.paySupplier(p2).then((_) => success++).catchError((_) => fail++),
      ]);

      expect(success, equals(1));
      expect(fail, equals(1));

      final finalAccount = await supplierRepo.getSupplierAccount(
        businessId: testBusinessId,
        supplierId: testSupplierId,
      );
      expect(finalAccount?.currentBalance, equals(Money.zero()));
    });
  });

  group('Group L: Audit Logging System', () {
    late String testSupplierId;

    setUp(() async {
      testSupplierId = 'SUP-AUD-TEST';
      await purchasingCoord.createSupplier(CreateSupplierCommand(
        commandId: testSupplierId,
        businessId: testBusinessId,
        name: 'مورد التدقيق',
        phone: '07700000111',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUP-AUD',
      ));
    });

    test('62. purchase order lifecycle actions log immutable audit entries', () async {
      final poRes = await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-AUD-01',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-AUD-ORD',
        items: [
          PurchaseItemInput(
            productId: 'P-1',
            description: 'سلعة',
            sku: 'SKU-1',
            quantity: StockQuantity.discrete(10),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(2000),
          ),
        ],
        actorId: 'USR-CREATOR',
        idempotencyKey: 'IDEM-PO-AUD-C',
      ));

      await purchasingCoord.submitPurchaseOrder(SubmitPurchaseOrderCommand(
        commandId: 'SUB-AUD-01',
        businessId: testBusinessId,
        purchaseOrderId: poRes.order!.id,
        actorId: 'USR-SUBMITTER',
        idempotencyKey: 'IDEM-PO-AUD-S',
      ));

      await purchasingCoord.approvePurchaseOrder(ApprovePurchaseOrderCommand(
        commandId: 'APP-AUD-01',
        businessId: testBusinessId,
        purchaseOrderId: poRes.order!.id,
        actorId: 'USR-APPROVER',
        idempotencyKey: 'IDEM-PO-AUD-A',
      ));

      final createAudit = auditRepo.entries.firstWhere((e) => e.action == ShopAuditAction.purchaseCreated);
      final submitAudit = auditRepo.entries.firstWhere((e) => e.action == ShopAuditAction.purchaseSubmitted);
      final approveAudit = auditRepo.entries.firstWhere((e) => e.action == ShopAuditAction.purchaseApproved);

      expect(createAudit.userId, equals('USR-CREATOR'));
      expect(submitAudit.userId, equals('USR-SUBMITTER'));
      expect(approveAudit.userId, equals('USR-APPROVER'));
    });

    test('63. receive goods logs audit with exact quantities and receipt reference', () async {
      await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-AUD-REC',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-AUD-R',
        items: [
          PurchaseItemInput(
            productId: 'P-1',
            description: 'سلعة',
            sku: 'SKU-1',
            quantity: StockQuantity.discrete(10),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(2000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-AUD-R-C',
      ));

      await purchasingCoord.submitPurchaseOrder(SubmitPurchaseOrderCommand(
        commandId: 'SUB-AUD-R',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-AUD-REC',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUB-AUD-R',
      ));

      await purchasingCoord.approvePurchaseOrder(ApprovePurchaseOrderCommand(
        commandId: 'APP-AUD-R',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-AUD-REC',
        actorId: testActorId,
        idempotencyKey: 'IDEM-APP-AUD-R',
      ));

      await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-AUD-10',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: 'PO-AUD-REC',
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-PO-AUD-REC-1',
            productId: 'P-1',
            quantityToReceive: StockQuantity.discrete(10),
          ),
        ],
        actorId: 'USR-RECEIVER-1',
        idempotencyKey: 'IDEM-AUD-REC-10',
      ));

      final recAudit = auditRepo.entries.firstWhere((e) => e.action == ShopAuditAction.purchaseReceived);
      expect(recAudit.userId, equals('USR-RECEIVER-1'));
      expect(recAudit.referenceId, equals('REC-REC-AUD-10'));
    });

    test('64. payment logs audit with amount and balance snapshot', () async {
      final account = await supplierRepo.getSupplierAccount(
        businessId: testBusinessId,
        supplierId: testSupplierId,
      );
      await supplierRepo.saveSupplierAccount(account!.copyWith(
        currentBalance: Money.fromAmount(50000),
      ));

      await purchasingCoord.paySupplier(PaySupplierCommand(
        commandId: 'PAY-AUD-1',
        businessId: testBusinessId,
        supplierId: testSupplierId,
        amount: Money.fromAmount(20000),
        actorId: 'USR-ACCOUNTANT',
        idempotencyKey: 'IDEM-PAY-AUD-1',
      ));

      final payAudit = auditRepo.entries.firstWhere((e) => e.action == ShopAuditAction.supplierPaymentCompleted);
      expect(payAudit.userId, equals('USR-ACCOUNTANT'));
      expect(payAudit.metadata['amount'], contains('20000'));
    });
  });

  group('Group M: Cost Snapshots & Immutability', () {
    late String testSupplierId;

    setUp(() async {
      testSupplierId = 'SUP-COST-GRP';
      await purchasingCoord.createSupplier(CreateSupplierCommand(
        commandId: testSupplierId,
        businessId: testBusinessId,
        name: 'مورد التكلفة',
        phone: '07700000222',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUP-COST',
      ));
    });

    test('65. cost snapshot freezes unitCost and line total', () async {
      final snapshot = CostSnapshot(
        unitCost: Money.fromAmount(15000),
        discountPerUnit: Money.fromAmount(1000),
        taxPerUnit: Money.fromAmount(500),
      );

      expect(snapshot.unitCost, equals(Money.fromAmount(15000)));
      expect(snapshot.netUnitCost, equals(Money.fromAmount(14500)));
    });

    test('66. subsequent catalog price changes do not mutate historical purchase order item cost', () async {
      final poRes = await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-COST-HIST',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-COST-01',
        items: [
          PurchaseItemInput(
            productId: 'P-HIST',
            description: 'سلعة تاريخية',
            sku: 'SKU-H',
            quantity: StockQuantity.discrete(10),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(5000),
          ),
        ],
        actorId: testActorId,
        idempotencyKey: 'IDEM-PO-COST-H',
      ));

      // في حال تغير السعر في كتالوج المورد مستقبلاً إلى 7,500
      final storedPo = await poRepo.getPurchaseOrderById(
        businessId: testBusinessId,
        purchaseOrderId: poRes.order!.id,
      );

      expect(storedPo?.items.first.unitCost, equals(Money.fromAmount(5000)));
      expect(storedPo?.items.first.costSnapshot.unitCost, equals(Money.fromAmount(5000)));
    });

    test('67. multiple receipts preserve separate actual receiving unit costs', () async {
      final r1 = PurchaseReceiptItem(
        purchaseItemId: 'PI-1',
        productId: 'P-1',
        quantityReceived: StockQuantity.discrete(10),
        unit: StockUnit.piece,
        unitCost: Money.fromAmount(5000), // استلام في كانون الثاني
      );

      final r2 = PurchaseReceiptItem(
        purchaseItemId: 'PI-1',
        productId: 'P-1',
        quantityReceived: StockQuantity.discrete(10),
        unit: StockUnit.piece,
        unitCost: Money.fromAmount(5500), // استلام في شباط بسعر أعلى
      );

      expect(r1.unitCost, equals(Money.fromAmount(5000)));
      expect(r2.unitCost, equals(Money.fromAmount(5500)));
      expect(r1.lineTotal, equals(Money.fromAmount(50000)));
      expect(r2.lineTotal, equals(Money.fromAmount(55000)));
    });
  });

  group('Group N: Separation of Duties & Actor Tracking', () {
    late String testSupplierId;

    setUp(() async {
      testSupplierId = 'SUP-SEP-GRP';
      await purchasingCoord.createSupplier(CreateSupplierCommand(
        commandId: testSupplierId,
        businessId: testBusinessId,
        name: 'مورد الفصل والتدقيق',
        phone: '07700000333',
        actorId: testActorId,
        idempotencyKey: 'IDEM-SUP-SEP',
      ));
    });

    test('68. createdBy actor is strictly recorded in purchase order', () async {
      final res = await purchasingCoord.createPurchaseOrder(CreatePurchaseOrderCommand(
        commandId: 'PO-SEP-DUTIES',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-SEP-1',
        items: [
          PurchaseItemInput(
            productId: 'P-1',
            description: 'سلعة',
            sku: 'SKU-1',
            quantity: StockQuantity.discrete(5),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(1000),
          ),
        ],
        actorId: 'CLERK-AHMED',
        idempotencyKey: 'IDEM-SEP-C',
      ));

      expect(res.order?.createdBy, equals('CLERK-AHMED'));
    });

    test('69. approvedBy actor is recorded on approval', () async {
      final po = PurchaseOrder(
        id: 'PO-SEP-APP',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-SEP-2',
        status: PurchaseOrderStatus.submitted,
        items: [
          PurchaseItem(
            id: 'PI-1',
            productId: 'P-1',
            descriptionSnapshot: 'سلعة',
            skuSnapshot: 'SKU-1',
            quantityOrdered: StockQuantity.discrete(5),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(1000),
          ),
        ],
        createdBy: 'CLERK-AHMED',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        idempotencyKey: 'IDEM-SEP-A-C',
      );
      await poRepo.savePurchaseOrder(po);

      final appRes = await purchasingCoord.approvePurchaseOrder(ApprovePurchaseOrderCommand(
        commandId: 'CMD-SEP-APP',
        businessId: testBusinessId,
        purchaseOrderId: 'PO-SEP-APP',
        actorId: 'MANAGER-FATIMA',
        idempotencyKey: 'IDEM-SEP-A-X',
      ));

      expect(appRes.order?.approvedBy, equals('MANAGER-FATIMA'));
      expect(appRes.order?.createdBy, equals('CLERK-AHMED'));
    });

    test('70. receivedBy actor is recorded on receipt', () async {
      final po = PurchaseOrder(
        id: 'PO-SEP-REC',
        businessId: testBusinessId,
        branchId: testBranchId,
        supplierId: testSupplierId,
        orderNumber: 'PO-SEP-3',
        status: PurchaseOrderStatus.approved,
        items: [
          PurchaseItem(
            id: 'PI-1',
            productId: 'P-1',
            descriptionSnapshot: 'سلعة',
            skuSnapshot: 'SKU-1',
            quantityOrdered: StockQuantity.discrete(5),
            unit: StockUnit.piece,
            unitCost: Money.fromAmount(1000),
          ),
        ],
        createdBy: 'CLERK-AHMED',
        approvedBy: 'MANAGER-FATIMA',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        idempotencyKey: 'IDEM-SEP-R-C',
      );
      await poRepo.savePurchaseOrder(po);

      final recRes = await purchasingCoord.receiveGoods(ReceiveGoodsCommand(
        commandId: 'REC-SEP-1',
        businessId: testBusinessId,
        branchId: testBranchId,
        purchaseOrderId: 'PO-SEP-REC',
        items: [
          ReceiveGoodsItemInput(
            purchaseItemId: 'PI-1',
            productId: 'P-1',
            quantityToReceive: StockQuantity.discrete(5),
          ),
        ],
        actorId: 'WAREHOUSE-OMAR',
        idempotencyKey: 'IDEM-SEP-R-X',
      ));

      expect(recRes.receipt.receivedBy, equals('WAREHOUSE-OMAR'));
    });

    test('71. paidBy actor is recorded on payment', () async {
      final s = Supplier(
        id: 'SUP-SEP-PAY',
        businessId: testBusinessId,
        name: 'مورد الفصل',
        phone: '07700000123',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await supplierRepo.saveSupplier(s);

      final account = SupplierAccount.initial(
        supplierId: 'SUP-SEP-PAY',
        businessId: testBusinessId,
      ).copyWith(currentBalance: Money.fromAmount(100000));
      await supplierRepo.saveSupplierAccount(account);

      final payRes = await purchasingCoord.paySupplier(PaySupplierCommand(
        commandId: 'PAY-SEP-1',
        businessId: testBusinessId,
        supplierId: 'SUP-SEP-PAY',
        amount: Money.fromAmount(50000),
        actorId: 'ACCOUNTANT-ALI',
        idempotencyKey: 'IDEM-SEP-P-X',
      ));

      expect(payRes.payment.actorId, equals('ACCOUNTANT-ALI'));
      expect(payRes.ledgerEntry.actorId, equals('ACCOUNTANT-ALI'));
    });
  });
}
