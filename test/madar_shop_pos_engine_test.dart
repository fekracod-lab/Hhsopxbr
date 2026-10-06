// حزمة الاختبارات الشاملة لمحرك معاملات نقطة البيع (MADAR SHOP Phase S2 POS Transaction Engine Tests)
// Unit & Domain Tests — Zero Mocks & 100% Deterministic Arithmetic

import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/madar_shop/madar_shop.dart';

// Fake implementations for Test isolation
class FakePosAuditRepository implements IShopAuditRepository {
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

class FakePosCoreRepository implements IShopCoreRepository {
  final List<ShopProduct> products;

  FakePosCoreRepository(this.products);

  @override
  Future<List<ShopProduct>> getProducts({
    required String businessId,
    required String branchId,
    bool includeArchived = false,
  }) async {
    return products;
  }

  @override
  Future<ShopProduct?> getProductById({
    required String businessId,
    required String branchId,
    required String productId,
  }) async {
    return products.firstWhere((p) => p.productId == productId);
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
  Future<void> updateOrderStatus({required String businessId, required String orderId, required ShopOrderStatus newStatus, String? reason}) async {}
}

void main() {
  group('MADAR SHOP Phase S2 — POS Transaction Engine Test Matrix', () {
    // ─── Fixtures ───
    final colaProduct = ShopProduct(
      productId: 'PROD-COLA',
      businessId: 'BIZ-01',
      branchId: 'BR-01',
      categoryId: 'CAT-BEV',
      name: 'كوكاكولا علبة',
      sku: 'SKU-COLA-CAN',
      barcode: '1234567890123',
      barcodeType: ShopBarcodeType.ean13,
      costPrice: 750.0,
      sellingPrice: 1000.0,
      stockQuantity: 50.0,
      unitOfMeasure: 'piece',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final tshirtProduct = ShopProduct(
      productId: 'PROD-TSHIRT',
      businessId: 'BIZ-01',
      branchId: 'BR-01',
      categoryId: 'CAT-CLOTH',
      name: 'تيشيرت قطني فاخر',
      sku: 'SKU-TSHIRT-BASE',
      costPrice: 10000.0,
      sellingPrice: 18000.0,
      stockQuantity: 20.0,
      unitOfMeasure: 'piece',
      variants: const [
        ShopProductVariant(
          variantId: 'VAR-BLK-L',
          sku: 'SKU-TSHIRT-BLK-L',
          barcode: '998877665544',
          title: 'أسود / L',
          costPrice: 11000.0,
          sellingPrice: 20000.0,
          stockQuantity: 8.0,
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final riceWeighable = ShopProduct(
      productId: 'PROD-RICE',
      businessId: 'BIZ-01',
      branchId: 'BR-01',
      categoryId: 'CAT-FOOD',
      name: 'رز عنبر عراقي ممتاز',
      sku: 'SKU-RICE-KG',
      barcode: '554433221100',
      costPrice: 2000.0,
      sellingPrice: 3000.0,
      stockQuantity: 100.0,
      unitOfMeasure: 'kg',
      isWeighable: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    late ShopIdentityCoordinator identityCoordinator;
    late ShopUser cashierUser;
    late ShopSession activeSession;

    setUp(() {
      identityCoordinator = ShopIdentityCoordinator();
      cashierUser = ShopUser(
        userId: 'U-CASHIER-101',
        businessId: 'BIZ-01',
        fullName: 'عمر الكاشير',
        phone: '07701234567',
        email: 'cashier@madar.iq',
        role: ShopRole.cashier,
        createdAt: DateTime.now(),
      );

      activeSession = ShopSession(
        sessionId: 'SESS-101',
        installationId: 'INST-WIN-01',
        terminalId: 'TERM-01',
        userId: 'U-CASHIER-101',
        businessId: 'BIZ-01',
        activeBranchId: 'BR-01',
        startedAt: DateTime.now(),
        lastHeartbeatAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 8)),
      );

      identityCoordinator.setSession(user: cashierUser, session: activeSession);
    });

    // ────────────────────────────────────────────
    // GROUP A: Cart Engine (1 to 7)
    // ────────────────────────────────────────────
    group('Group A: Cart Engine', () {
      test('1. add product item to cart', () {
        var cart = const Cart();
        final item = CartItem(
          itemId: 'ITM-1',
          productId: colaProduct.productId,
          sku: colaProduct.sku,
          name: colaProduct.name,
          unitPrice: Money.fromAmount(colaProduct.sellingPrice),
          costPrice: Money.fromAmount(colaProduct.costPrice),
          quantity: 2.0,
        );

        cart = cart.addItem(item);
        expect(cart.itemCount, 1);
        expect(cart.totalUnitsCount, 2.0);
        expect(cart.itemsSubtotal.minorUnits, 2000);
      });

      test('2. remove item from cart', () {
        var cart = const Cart();
        final item = CartItem(
          itemId: 'ITM-1',
          productId: colaProduct.productId,
          sku: colaProduct.sku,
          name: colaProduct.name,
          unitPrice: Money.fromAmount(colaProduct.sellingPrice),
          costPrice: Money.fromAmount(colaProduct.costPrice),
          quantity: 2.0,
        );

        cart = cart.addItem(item);
        expect(cart.isNotEmpty, isTrue);
        cart = cart.removeItem('ITM-1');
        expect(cart.isEmpty, isTrue);
      });

      test('3. increase, decrease and set quantity in cart', () {
        var cart = const Cart();
        final item = CartItem(
          itemId: 'ITM-1',
          productId: colaProduct.productId,
          sku: colaProduct.sku,
          name: colaProduct.name,
          unitPrice: Money.fromAmount(colaProduct.sellingPrice),
          costPrice: Money.fromAmount(colaProduct.costPrice),
          quantity: 2.0,
        );

        cart = cart.addItem(item);
        cart = cart.updateQuantity('ITM-1', 5.0);
        expect(cart.items.first.quantity, 5.0);
        expect(cart.itemsSubtotal.minorUnits, 5000);

        // Setting quantity to 0 removes the item
        cart = cart.updateQuantity('ITM-1', 0.0);
        expect(cart.isEmpty, isTrue);
      });

      test('4. clear cart resets everything to empty', () {
        var cart = const Cart();
        cart = cart.addItem(CartItem(
          itemId: 'ITM-1',
          productId: colaProduct.productId,
          sku: colaProduct.sku,
          name: colaProduct.name,
          unitPrice: Money.fromAmount(colaProduct.sellingPrice),
          costPrice: Money.fromAmount(colaProduct.costPrice),
          quantity: 1.0,
        ));
        expect(cart.isNotEmpty, isTrue);
        cart = cart.clear();
        expect(cart.isEmpty, isTrue);
        expect(cart.itemsSubtotal.isZero, isTrue);
      });

      test('5. variant support in cart', () {
        var cart = const Cart();
        final variant = tshirtProduct.variants.first;
        final item = CartItem(
          itemId: 'ITM-VAR-1',
          productId: tshirtProduct.productId,
          variantId: variant.variantId,
          variantTitle: variant.title,
          sku: variant.sku,
          name: '${tshirtProduct.name} - ${variant.title}',
          unitPrice: Money.fromAmount(variant.sellingPrice),
          costPrice: Money.fromAmount(variant.costPrice),
          quantity: 1.0,
        );

        cart = cart.addItem(item);
        expect(cart.items.first.variantTitle, 'أسود / L');
        expect(cart.items.first.unitPrice.minorUnits, 20000);
      });

      test('6. barcode resolution in cart', () async {
        final repo = FakePosCoreRepository([colaProduct, tshirtProduct, riceWeighable]);
        final resolver = ProductResolver(repository: repo);

        final resolved = await resolver.resolveProduct(
          query: '1234567890123',
          businessId: 'BIZ-01',
          branchId: 'BR-01',
        );

        expect(resolved, isNotNull);
        expect(resolved!.productId, colaProduct.productId);
        expect(resolved.name, colaProduct.name);
      });

      test('7. invalid quantity <= 0 is strictly rejected', () {
        var cart = const Cart();
        expect(
          () => cart.addItem(CartItem(
            itemId: 'ITM-INV',
            productId: colaProduct.productId,
            sku: colaProduct.sku,
            name: colaProduct.name,
            unitPrice: Money.fromAmount(colaProduct.sellingPrice),
            costPrice: Money.fromAmount(colaProduct.costPrice),
            quantity: 0.0,
          )),
          throwsArgumentError,
        );
      });
    });

    // ────────────────────────────────────────────
    // GROUP B: Pricing, Discounts & Tax (8 to 14)
    // ────────────────────────────────────────────
    group('Group B: Pricing, Discounts & Tax', () {
      test('8. base price calculation for simple product', () {
        final item = CartItem(
          itemId: 'ITM-COLA',
          productId: colaProduct.productId,
          sku: colaProduct.sku,
          name: colaProduct.name,
          unitPrice: Money.fromAmount(1000.0),
          costPrice: Money.fromAmount(750.0),
          quantity: 3.0,
        );

        expect(item.lineSubtotal.minorUnits, 3000);
        expect(item.totalCost.minorUnits, 2250);
        expect(item.grossMargin.minorUnits, 750);
      });

      test('9. variant price calculation', () {
        final variant = tshirtProduct.variants.first;
        final item = CartItem(
          itemId: 'ITM-VAR',
          productId: tshirtProduct.productId,
          variantId: variant.variantId,
          sku: variant.sku,
          name: tshirtProduct.name,
          unitPrice: Money.fromAmount(variant.sellingPrice),
          costPrice: Money.fromAmount(variant.costPrice),
          quantity: 2.0,
        );

        expect(item.lineSubtotal.minorUnits, 40000);
        expect(item.totalCost.minorUnits, 22000);
        expect(item.grossMargin.minorUnits, 18000);
      });

      test('10. percentage discount calculation (10%)', () {
        const discount = Discount(type: DiscountType.percentage, value: 10.0);
        final base = Money.fromAmount(20000.0);

        final discountAmount = discount.calculateDiscountAmount(base);
        expect(discountAmount.minorUnits, 2000);
      });

      test('11. fixed discount calculation (2,000 IQD)', () {
        const discount = Discount(type: DiscountType.fixed, value: 2000.0);
        final base = Money.fromAmount(15000.0);

        final discountAmount = discount.calculateDiscountAmount(base);
        expect(discountAmount.minorUnits, 2000);
      });

      test('12. tax calculation with TaxPolicy.rate', () {
        final taxPolicy = TaxPolicy.rate(percentage: 5.0, name: 'ضريبة مبيعات');
        final taxable = Money.fromAmount(10000.0);

        final tax = taxPolicy.calculateTax(taxable);
        expect(tax.minorUnits, 500);
      });

      test('13. zero tax policy produces 0 tax', () {
        final taxPolicy = TaxPolicy.none();
        final taxable = Money.fromAmount(10000.0);

        final tax = taxPolicy.calculateTax(taxable);
        expect(tax.isZero, isTrue);
      });

      test('14. weighable product exact decimal calculation (1.750 kg)', () {
        final item = CartItem(
          itemId: 'ITM-RICE',
          productId: riceWeighable.productId,
          sku: riceWeighable.sku,
          name: riceWeighable.name,
          unitPrice: Money.fromAmount(3000.0),
          costPrice: Money.fromAmount(2000.0),
          quantity: 1.750,
          isWeighable: true,
          unitOfMeasure: 'kg',
        );

        // 3000 * 1.750 = 5250 IQD
        expect(item.lineSubtotal.minorUnits, 5250);
        // Cost: 2000 * 1.750 = 3500 IQD
        expect(item.totalCost.minorUnits, 3500);
        // Profit: 5250 - 3500 = 1750 IQD
        expect(item.grossMargin.minorUnits, 1750);
      });
    });

    // ────────────────────────────────────────────
    // GROUP C: Payment & Multi-Payment (15 to 20)
    // ────────────────────────────────────────────
    group('Group C: Payment & Multi-Payment', () {
      test('15. exact cash payment completes allocation with zero change', () {
        final allocation = PaymentAllocation(
          grandTotal: Money.fromAmount(10000.0),
          payments: [
            Payment(
              id: 'PAY-1',
              method: PaymentMethod.cash,
              amount: Money.fromAmount(10000.0),
              receivedAt: DateTime.now(),
            ),
          ],
        );

        expect(allocation.paidTotal.minorUnits, 10000);
        expect(allocation.remainingTotal.isZero, isTrue);
        expect(allocation.changeTotal.isZero, isTrue);
        expect(allocation.isFullyAllocated, isTrue);
      });

      test('16. cash overpayment calculates change correctly', () {
        final allocation = PaymentAllocation(
          grandTotal: Money.fromAmount(10000.0),
          payments: [
            Payment(
              id: 'PAY-1',
              method: PaymentMethod.cash,
              amount: Money.fromAmount(15000.0),
              receivedAt: DateTime.now(),
            ),
          ],
        );

        expect(allocation.paidTotal.minorUnits, 15000);
        expect(allocation.remainingTotal.isZero, isTrue);
        expect(allocation.changeTotal.minorUnits, 5000);
      });

      test('17. exact card payment completes allocation', () {
        final allocation = PaymentAllocation(
          grandTotal: Money.fromAmount(25000.0),
          payments: [
            Payment(
              id: 'PAY-CARD-1',
              method: PaymentMethod.card,
              amount: Money.fromAmount(25000.0),
              reference: 'POS-TXN-998811',
              receivedAt: DateTime.now(),
            ),
          ],
        );

        expect(allocation.isFullyAllocated, isTrue);
        expect(allocation.remainingTotal.isZero, isTrue);
      });

      test('18. split payment (Cash + Card)', () {
        final allocation = PaymentAllocation(
          grandTotal: Money.fromAmount(10000.0),
          payments: [
            Payment(
              id: 'PAY-SPLIT-1',
              method: PaymentMethod.cash,
              amount: Money.fromAmount(6000.0),
              receivedAt: DateTime.now(),
            ),
            Payment(
              id: 'PAY-SPLIT-2',
              method: PaymentMethod.card,
              amount: Money.fromAmount(4000.0),
              reference: 'CARD-AUTH-11',
              receivedAt: DateTime.now(),
            ),
          ],
        );

        expect(allocation.paidTotal.minorUnits, 10000);
        expect(allocation.remainingTotal.isZero, isTrue);
        expect(allocation.changeTotal.isZero, isTrue);
      });

      test('19. insufficient payment leaves remaining amount', () {
        final allocation = PaymentAllocation(
          grandTotal: Money.fromAmount(10000.0),
          payments: [
            Payment(
              id: 'PAY-PARTIAL',
              method: PaymentMethod.cash,
              amount: Money.fromAmount(7000.0),
              receivedAt: DateTime.now(),
            ),
          ],
        );

        expect(allocation.isFullyAllocated, isFalse);
        expect(allocation.remainingTotal.minorUnits, 3000);
      });

      test('20. non-cash overpayment is rejected by PaymentValidator', () {
        final allocation = PaymentAllocation(
          grandTotal: Money.fromAmount(10000.0),
          payments: [
            Payment(
              id: 'PAY-CARD-OVER',
              method: PaymentMethod.card,
              amount: Money.fromAmount(15000.0),
              receivedAt: DateTime.now(),
            ),
          ],
        );

        final result = PaymentValidator.validate(allocation: allocation, customerId: null);
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('غير النقدية'));
      });
    });

    // ────────────────────────────────────────────
    // GROUP D: Credit Sale & Customer Ledger (21 to 23)
    // ────────────────────────────────────────────
    group('Group D: Credit Sale & Customer Ledger', () {
      test('21. full credit sale generates customer ledger entry', () {
        final allocation = PaymentAllocation(
          grandTotal: Money.fromAmount(50000.0),
          payments: [
            Payment(
              id: 'PAY-CREDIT',
              method: PaymentMethod.credit,
              amount: Money.fromAmount(50000.0),
              receivedAt: DateTime.now(),
            ),
          ],
        );

        final result = PaymentValidator.validate(allocation: allocation, customerId: 'CUST-001');
        expect(result.isValid, isTrue);

        final ledger = CustomerLedgerEntry.fromCreditSale(
          entryId: 'LEDG-1',
          customerId: 'CUST-001',
          saleId: 'SALE-101',
          businessId: 'BIZ-01',
          branchId: 'BR-01',
          grandTotal: allocation.grandTotal,
          immediatePaid: allocation.immediatePaidTotal,
          creditBalance: allocation.creditAmountTotal,
        );

        expect(ledger.debit.minorUnits, 50000);
        expect(ledger.credit.isZero, isTrue);
        expect(ledger.balanceDelta.minorUnits, 50000);
      });

      test('22. partial cash and partial credit sale', () {
        // Total: 50,000 | Paid: 20,000 Cash | Remaining: 30,000 Credit
        final allocation = PaymentAllocation(
          grandTotal: Money.fromAmount(50000.0),
          payments: [
            Payment(
              id: 'PAY-PART-CASH',
              method: PaymentMethod.cash,
              amount: Money.fromAmount(20000.0),
              receivedAt: DateTime.now(),
            ),
            Payment(
              id: 'PAY-PART-CREDIT',
              method: PaymentMethod.credit,
              amount: Money.fromAmount(30000.0),
              receivedAt: DateTime.now(),
            ),
          ],
        );

        final validation = PaymentValidator.validate(allocation: allocation, customerId: 'CUST-777');
        expect(validation.isValid, isTrue);

        final ledger = CustomerLedgerEntry.fromCreditSale(
          entryId: 'LEDG-2',
          customerId: 'CUST-777',
          saleId: 'SALE-102',
          businessId: 'BIZ-01',
          branchId: 'BR-01',
          grandTotal: allocation.grandTotal,
          immediatePaid: allocation.immediatePaidTotal,
          creditBalance: allocation.creditAmountTotal,
        );

        expect(ledger.debit.minorUnits, 50000);
        expect(ledger.credit.minorUnits, 20000);
        expect(ledger.balanceDelta.minorUnits, 30000);
      });

      test('23. credit sale without customer is strictly rejected', () {
        final allocation = PaymentAllocation(
          grandTotal: Money.fromAmount(30000.0),
          payments: [
            Payment(
              id: 'PAY-ANON-CREDIT',
              method: PaymentMethod.credit,
              amount: Money.fromAmount(30000.0),
              receivedAt: DateTime.now(),
            ),
          ],
        );

        final validation = PaymentValidator.validate(allocation: allocation, customerId: null);
        expect(validation.isValid, isFalse);
        expect(validation.errorMessage, contains('العميل'));
      });
    });

    // ────────────────────────────────────────────
    // GROUP E: State Machine (24 to 27)
    // ────────────────────────────────────────────
    group('Group E: State Machine', () {
      test('24. draft to payment pending transition is allowed', () {
        final res = SaleStateMachine.validateTransition(
          currentStatus: SaleStatus.draft,
          targetStatus: SaleStatus.paymentPending,
        );
        expect(res.isAllowed, isTrue);
      });

      test('25. payment pending to completed is allowed', () {
        final res = SaleStateMachine.validateTransition(
          currentStatus: SaleStatus.paymentPending,
          targetStatus: SaleStatus.completed,
        );
        expect(res.isAllowed, isTrue);
      });

      test('26. invalid backward transition completed -> draft is blocked', () {
        final res = SaleStateMachine.validateTransition(
          currentStatus: SaleStatus.completed,
          targetStatus: SaleStatus.draft,
        );
        expect(res.isAllowed, isFalse);
        expect(res.rejectionReason, contains('مغلقة'));
      });

      test('27. cancelled sale requires mandatory reason', () {
        final withoutReason = SaleStateMachine.validateTransition(
          currentStatus: SaleStatus.draft,
          targetStatus: SaleStatus.cancelled,
          reason: null,
        );
        expect(withoutReason.isAllowed, isFalse);

        final withReason = SaleStateMachine.validateTransition(
          currentStatus: SaleStatus.draft,
          targetStatus: SaleStatus.cancelled,
          reason: 'الزبون غيّر رأيه قبل الدفع',
        );
        expect(withReason.isAllowed, isTrue);
      });
    });

    // ────────────────────────────────────────────
    // GROUP F: Idempotency (28 to 29)
    // ────────────────────────────────────────────
    group('Group F: Idempotency', () {
      test('28. same idempotency key twice returns the original sale and no second sale is created', () async {
        final posRepo = ShopPosRepositoryImpl();
        final idempotencyStore = InMemorySaleIdempotencyStore();
        final auditRepo = FakePosAuditRepository();

        final coordinator = PosCheckoutCoordinator(
          identityCoordinator: identityCoordinator,
          posRepository: posRepo,
          idempotencyStore: idempotencyStore,
          auditRepository: auditRepo,
        );

        final cart = Cart().addItem(CartItem(
          itemId: 'ITM-1',
          productId: colaProduct.productId,
          sku: colaProduct.sku,
          name: colaProduct.name,
          unitPrice: Money.fromAmount(1000.0),
          costPrice: Money.fromAmount(750.0),
          quantity: 1.0,
        ));

        final command = CheckoutCommand(
          commandId: 'CMD-1',
          businessId: 'BIZ-01',
          branchId: 'BR-01',
          terminalId: 'TERM-01',
          sessionId: 'SESS-101',
          idempotencyKey: 'IDEM-EXACT-KEY',
          cart: cart,
          payments: [
            Payment(
              id: 'P-1',
              method: PaymentMethod.cash,
              amount: Money.fromAmount(1000.0),
              receivedAt: DateTime.now(),
            ),
          ],
        );

        // First attempt -> created
        final result1 = await coordinator.processCheckout(command);
        expect(result1.isIdempotentReplay, isFalse);
        final originalSaleId = result1.sale.id;

        // Second attempt with exact same key -> replayed from idempotency store
        final result2 = await coordinator.processCheckout(command);
        expect(result2.isIdempotentReplay, isTrue);
        expect(result2.sale.id, originalSaleId);
      });

      test('29. different idempotency keys create independent sales', () async {
        final posRepo = ShopPosRepositoryImpl();
        final idempotencyStore = InMemorySaleIdempotencyStore();
        final auditRepo = FakePosAuditRepository();

        final coordinator = PosCheckoutCoordinator(
          identityCoordinator: identityCoordinator,
          posRepository: posRepo,
          idempotencyStore: idempotencyStore,
          auditRepository: auditRepo,
        );

        final cart = Cart().addItem(CartItem(
          itemId: 'ITM-1',
          productId: colaProduct.productId,
          sku: colaProduct.sku,
          name: colaProduct.name,
          unitPrice: Money.fromAmount(1000.0),
          costPrice: Money.fromAmount(750.0),
          quantity: 1.0,
        ));

        final cmd1 = CheckoutCommand(
          commandId: 'CMD-1',
          businessId: 'BIZ-01',
          branchId: 'BR-01',
          terminalId: 'TERM-01',
          sessionId: 'SESS-101',
          idempotencyKey: 'KEY-AAA',
          cart: cart,
          payments: [
            Payment(
              id: 'P-1',
              method: PaymentMethod.cash,
              amount: Money.fromAmount(1000.0),
              receivedAt: DateTime.now(),
            ),
          ],
        );

        final cmd2 = CheckoutCommand(
          commandId: 'CMD-2',
          businessId: 'BIZ-01',
          branchId: 'BR-01',
          terminalId: 'TERM-01',
          sessionId: 'SESS-101',
          idempotencyKey: 'KEY-BBB',
          cart: cart,
          payments: [
            Payment(
              id: 'P-2',
              method: PaymentMethod.cash,
              amount: Money.fromAmount(1000.0),
              receivedAt: DateTime.now(),
            ),
          ],
        );

        final res1 = await coordinator.processCheckout(cmd1);
        final res2 = await coordinator.processCheckout(cmd2);

        expect(res1.sale.id != res2.sale.id, isTrue);
        expect(res1.isIdempotentReplay, isFalse);
        expect(res2.isIdempotentReplay, isFalse);
      });
    });

    // ────────────────────────────────────────────
    // GROUP G: RBAC & Security (30 to 32)
    // ────────────────────────────────────────────
    group('Group G: RBAC & Security', () {
      test('30. cashier with POS permissions is authorized to checkout', () {
        expect(identityCoordinator.hasPermission(ShopPermission.accessPos), isTrue);
        expect(identityCoordinator.hasPermission(ShopPermission.createSalesOrder), isTrue);
      });

      test('31. unauthorized role (Inventory Clerk) is rejected from checkout', () async {
        final clerk = ShopUser(
          userId: 'U-CLERK-1',
          businessId: 'BIZ-01',
          fullName: 'أمين المخزن',
          phone: '07700000000',
          email: 'clerk@madar.iq',
          role: ShopRole.inventoryClerk,
          createdAt: DateTime.now(),
        );
        identityCoordinator.setSession(user: clerk, session: activeSession);

        final coordinator = PosCheckoutCoordinator(
          identityCoordinator: identityCoordinator,
          posRepository: ShopPosRepositoryImpl(),
          idempotencyStore: InMemorySaleIdempotencyStore(),
          auditRepository: FakePosAuditRepository(),
        );

        final cart = Cart().addItem(CartItem(
          itemId: 'ITM-1',
          productId: colaProduct.productId,
          sku: colaProduct.sku,
          name: colaProduct.name,
          unitPrice: Money.fromAmount(1000.0),
          costPrice: Money.fromAmount(750.0),
          quantity: 1.0,
        ));

        final cmd = CheckoutCommand(
          commandId: 'CMD-CLERK',
          businessId: 'BIZ-01',
          branchId: 'BR-01',
          terminalId: 'TERM-01',
          sessionId: 'SESS-101',
          idempotencyKey: 'KEY-CLERK',
          cart: cart,
          payments: [
            Payment(
              id: 'P-1',
              method: PaymentMethod.cash,
              amount: Money.fromAmount(1000.0),
              receivedAt: DateTime.now(),
            ),
          ],
        );

        expect(() => coordinator.processCheckout(cmd), throwsA(isA<UnauthorizedCashierFailure>()));
      });

      test('32. branch mismatch is rejected', () async {
        final coordinator = PosCheckoutCoordinator(
          identityCoordinator: identityCoordinator,
          posRepository: ShopPosRepositoryImpl(),
          idempotencyStore: InMemorySaleIdempotencyStore(),
          auditRepository: FakePosAuditRepository(),
        );

        final cart = Cart().addItem(CartItem(
          itemId: 'ITM-1',
          productId: colaProduct.productId,
          sku: colaProduct.sku,
          name: colaProduct.name,
          unitPrice: Money.fromAmount(1000.0),
          costPrice: Money.fromAmount(750.0),
          quantity: 1.0,
        ));

        final cmd = CheckoutCommand(
          commandId: 'CMD-MISMATCH',
          businessId: 'BIZ-01',
          branchId: 'BR-OTHER-BRANCH', // Mismatch!
          terminalId: 'TERM-01',
          sessionId: 'SESS-101',
          idempotencyKey: 'KEY-MISMATCH',
          cart: cart,
          payments: [
            Payment(
              id: 'P-1',
              method: PaymentMethod.cash,
              amount: Money.fromAmount(1000.0),
              receivedAt: DateTime.now(),
            ),
          ],
        );

        expect(() => coordinator.processCheckout(cmd), throwsA(isA<BranchMismatchFailure>()));
      });
    });

    // ────────────────────────────────────────────
    // GROUP H: Inventory Movement Intent (33 to 35)
    // ────────────────────────────────────────────
    group('Group H: Inventory Movement Intent', () {
      test('33. checkout generates InventoryMovementIntent for sold items', () async {
        final posRepo = ShopPosRepositoryImpl();
        final coordinator = PosCheckoutCoordinator(
          identityCoordinator: identityCoordinator,
          posRepository: posRepo,
          idempotencyStore: InMemorySaleIdempotencyStore(),
          auditRepository: FakePosAuditRepository(),
        );

        final cart = Cart().addItem(CartItem(
          itemId: 'ITM-COLA',
          productId: colaProduct.productId,
          sku: colaProduct.sku,
          name: colaProduct.name,
          unitPrice: Money.fromAmount(1000.0),
          costPrice: Money.fromAmount(750.0),
          quantity: 3.0,
        ));

        final cmd = CheckoutCommand(
          commandId: 'CMD-INV',
          businessId: 'BIZ-01',
          branchId: 'BR-01',
          terminalId: 'TERM-01',
          sessionId: 'SESS-101',
          idempotencyKey: 'KEY-INV',
          cart: cart,
          payments: [
            Payment(
              id: 'P-1',
              method: PaymentMethod.cash,
              amount: Money.fromAmount(3000.0),
              receivedAt: DateTime.now(),
            ),
          ],
        );

        final result = await coordinator.processCheckout(cmd);
        expect(result.inventoryIntents.length, 1);
        expect(posRepo.inventoryIntents.length, 1);
        expect(posRepo.inventoryIntents.first.movementType, InventoryMovementType.sale);
      });

      test('34. correct quantity preserved in movement intent', () async {
        final posRepo = ShopPosRepositoryImpl();
        final coordinator = PosCheckoutCoordinator(
          identityCoordinator: identityCoordinator,
          posRepository: posRepo,
          idempotencyStore: InMemorySaleIdempotencyStore(),
          auditRepository: FakePosAuditRepository(),
        );

        final cart = Cart().addItem(CartItem(
          itemId: 'ITM-RICE',
          productId: riceWeighable.productId,
          sku: riceWeighable.sku,
          name: riceWeighable.name,
          unitPrice: Money.fromAmount(3000.0),
          costPrice: Money.fromAmount(2000.0),
          quantity: 2.450,
          isWeighable: true,
        ));

        final cmd = CheckoutCommand(
          commandId: 'CMD-RICE',
          businessId: 'BIZ-01',
          branchId: 'BR-01',
          terminalId: 'TERM-01',
          sessionId: 'SESS-101',
          idempotencyKey: 'KEY-RICE',
          cart: cart,
          payments: [
            Payment(
              id: 'P-1',
              method: PaymentMethod.cash,
              amount: Money.fromAmount(7350.0),
              receivedAt: DateTime.now(),
            ),
          ],
        );

        final result = await coordinator.processCheckout(cmd);
        expect(result.inventoryIntents.first.quantity, 2.450);
      });

      test('35. variantId preserved in movement intent', () async {
        final posRepo = ShopPosRepositoryImpl();
        final coordinator = PosCheckoutCoordinator(
          identityCoordinator: identityCoordinator,
          posRepository: posRepo,
          idempotencyStore: InMemorySaleIdempotencyStore(),
          auditRepository: FakePosAuditRepository(),
        );

        final variant = tshirtProduct.variants.first;
        final cart = Cart().addItem(CartItem(
          itemId: 'ITM-TSHIRT',
          productId: tshirtProduct.productId,
          variantId: variant.variantId,
          sku: variant.sku,
          name: tshirtProduct.name,
          unitPrice: Money.fromAmount(variant.sellingPrice),
          costPrice: Money.fromAmount(variant.costPrice),
          quantity: 1.0,
        ));

        final cmd = CheckoutCommand(
          commandId: 'CMD-TSHIRT',
          businessId: 'BIZ-01',
          branchId: 'BR-01',
          terminalId: 'TERM-01',
          sessionId: 'SESS-101',
          idempotencyKey: 'KEY-TSHIRT',
          cart: cart,
          payments: [
            Payment(
              id: 'P-1',
              method: PaymentMethod.cash,
              amount: Money.fromAmount(20000.0),
              receivedAt: DateTime.now(),
            ),
          ],
        );

        final result = await coordinator.processCheckout(cmd);
        expect(result.inventoryIntents.first.variantId, 'VAR-BLK-L');
      });
    });

    // ────────────────────────────────────────────
    // GROUP I: Audit Logging (36 to 38)
    // ────────────────────────────────────────────
    group('Group I: Audit Logging', () {
      test('36. sale completion audit entry recorded', () async {
        final auditRepo = FakePosAuditRepository();
        final coordinator = PosCheckoutCoordinator(
          identityCoordinator: identityCoordinator,
          posRepository: ShopPosRepositoryImpl(),
          idempotencyStore: InMemorySaleIdempotencyStore(),
          auditRepository: auditRepo,
        );

        final cart = Cart().addItem(CartItem(
          itemId: 'ITM-1',
          productId: colaProduct.productId,
          sku: colaProduct.sku,
          name: colaProduct.name,
          unitPrice: Money.fromAmount(1000.0),
          costPrice: Money.fromAmount(750.0),
          quantity: 1.0,
        ));

        final cmd = CheckoutCommand(
          commandId: 'CMD-AUDIT-1',
          businessId: 'BIZ-01',
          branchId: 'BR-01',
          terminalId: 'TERM-01',
          sessionId: 'SESS-101',
          idempotencyKey: 'KEY-AUDIT-1',
          cart: cart,
          payments: [
            Payment(
              id: 'P-1',
              method: PaymentMethod.cash,
              amount: Money.fromAmount(1000.0),
              receivedAt: DateTime.now(),
            ),
          ],
        );

        await coordinator.processCheckout(cmd);
        expect(auditRepo.entries.length, 1);
        expect(auditRepo.entries.first.userId, 'U-CASHIER-101');
      });

      test('37. manual price override audit check via CartCoordinator', () {
        final cartCoord = CartCoordinator(identityCoordinator: identityCoordinator);
        final resolved = ResolvedProduct(
          productId: 'P-1',
          sku: 'SKU-1',
          name: 'سلعة',
          unitOfMeasure: 'piece',
          price: Money.fromAmount(5000.0),
          cost: Money.fromAmount(3000.0),
          stockQuantity: 10.0,
        );

        // Cashier doesn't have overrideItemPrice by default
        expect(
          () => cartCoord.addResolvedProduct(
            product: resolved,
            manualOverridePrice: Money.fromAmount(4000.0),
            overrideReason: 'تخفيض خاص',
          ),
          throwsA(isA<UnauthorizedCashierFailure>()),
        );
      });

      test('38. audit entry is append-only with full terminal context', () async {
        final auditRepo = FakePosAuditRepository();
        final coordinator = PosCheckoutCoordinator(
          identityCoordinator: identityCoordinator,
          posRepository: ShopPosRepositoryImpl(),
          idempotencyStore: InMemorySaleIdempotencyStore(),
          auditRepository: auditRepo,
        );

        final cart = Cart().addItem(CartItem(
          itemId: 'ITM-1',
          productId: colaProduct.productId,
          sku: colaProduct.sku,
          name: colaProduct.name,
          unitPrice: Money.fromAmount(1000.0),
          costPrice: Money.fromAmount(750.0),
          quantity: 1.0,
        ));

        final cmd = CheckoutCommand(
          commandId: 'CMD-CTX',
          businessId: 'BIZ-01',
          branchId: 'BR-01',
          terminalId: 'TERM-01',
          sessionId: 'SESS-101',
          idempotencyKey: 'KEY-CTX',
          cart: cart,
          payments: [
            Payment(
              id: 'P-1',
              method: PaymentMethod.cash,
              amount: Money.fromAmount(1000.0),
              receivedAt: DateTime.now(),
            ),
          ],
        );

        await coordinator.processCheckout(cmd);
        final entry = auditRepo.entries.first;
        expect(entry.terminalId, 'TERM-01');
        expect(entry.businessId, 'BIZ-01');
        expect(entry.branchId, 'BR-01');
      });
    });

    // ────────────────────────────────────────────
    // GROUP J: Receipt Snapshot (39 to 40)
    // ────────────────────────────────────────────
    group('Group J: Receipt Snapshot', () {
      test('39. receipt snapshot contains stable pricing independent of future product price changes', () async {
        final posRepo = ShopPosRepositoryImpl();
        final coordinator = PosCheckoutCoordinator(
          identityCoordinator: identityCoordinator,
          posRepository: posRepo,
          idempotencyStore: InMemorySaleIdempotencyStore(),
          auditRepository: FakePosAuditRepository(),
        );

        final cart = Cart().addItem(CartItem(
          itemId: 'ITM-COLA',
          productId: colaProduct.productId,
          sku: colaProduct.sku,
          name: colaProduct.name,
          unitPrice: Money.fromAmount(1000.0),
          costPrice: Money.fromAmount(750.0),
          quantity: 2.0,
        ));

        final cmd = CheckoutCommand(
          commandId: 'CMD-RCPT',
          businessId: 'BIZ-01',
          branchId: 'BR-01',
          terminalId: 'TERM-01',
          sessionId: 'SESS-101',
          idempotencyKey: 'KEY-RCPT',
          cart: cart,
          payments: [
            Payment(
              id: 'P-1',
              method: PaymentMethod.cash,
              amount: Money.fromAmount(2000.0),
              receivedAt: DateTime.now(),
            ),
          ],
        );

        final result = await coordinator.processCheckout(cmd);
        final receipt = result.receipt;

        expect(receipt.lines.first.unitPriceAmount, 1000.0);
        expect(receipt.lines.first.quantity, 2.0);
        expect(receipt.grandTotalAmount, 2000.0);
        expect(receipt.payments.first.methodDisplayName, 'نقداً');
      });

      test('40. receipt snapshot captures change and customer if provided', () async {
        final posRepo = ShopPosRepositoryImpl();
        final coordinator = PosCheckoutCoordinator(
          identityCoordinator: identityCoordinator,
          posRepository: posRepo,
          idempotencyStore: InMemorySaleIdempotencyStore(),
          auditRepository: FakePosAuditRepository(),
        );

        final cart = Cart(customerName: 'حيدر علي').addItem(CartItem(
          itemId: 'ITM-COLA',
          productId: colaProduct.productId,
          sku: colaProduct.sku,
          name: colaProduct.name,
          unitPrice: Money.fromAmount(1000.0),
          costPrice: Money.fromAmount(750.0),
          quantity: 1.0,
        ));

        final cmd = CheckoutCommand(
          commandId: 'CMD-CHG',
          businessId: 'BIZ-01',
          branchId: 'BR-01',
          terminalId: 'TERM-01',
          sessionId: 'SESS-101',
          idempotencyKey: 'KEY-CHG',
          cart: cart,
          customerName: 'حيدر علي',
          payments: [
            Payment(
              id: 'P-1',
              method: PaymentMethod.cash,
              amount: Money.fromAmount(5000.0), // 4000 change
              receivedAt: DateTime.now(),
            ),
          ],
        );

        final result = await coordinator.processCheckout(cmd);
        expect(result.receipt.changeTotalAmount, 4000.0);
        expect(result.receipt.customerName, 'حيدر علي');
      });
    });

    // ────────────────────────────────────────────
    // GROUP K: Failures & Edge Cases (41 to 45)
    // ────────────────────────────────────────────
    group('Group K: Failures & Edge Cases', () {
      test('41. unavailable product throws ProductUnavailableFailure in CartCoordinator', () {
        final cartCoord = CartCoordinator(identityCoordinator: identityCoordinator);
        final unavailable = ResolvedProduct(
          productId: 'P-UNAVAIL',
          sku: 'SKU-UN',
          name: 'سلعة غير متوفرة',
          unitOfMeasure: 'piece',
          price: Money.fromAmount(1000.0),
          cost: Money.fromAmount(500.0),
          stockQuantity: 0.0,
          isAvailable: false,
        );

        expect(
          () => cartCoord.addResolvedProduct(product: unavailable),
          throwsA(isA<ProductUnavailableFailure>()),
        );
      });

      test('42. unauthenticated user throws UnauthorizedCashierFailure', () async {
        final unauthIdentity = ShopIdentityCoordinator();
        final coordinator = PosCheckoutCoordinator(
          identityCoordinator: unauthIdentity,
          posRepository: ShopPosRepositoryImpl(),
          idempotencyStore: InMemorySaleIdempotencyStore(),
          auditRepository: FakePosAuditRepository(),
        );

        final cart = Cart().addItem(CartItem(
          itemId: 'ITM-1',
          productId: 'P1',
          sku: 'S1',
          name: 'سلعة',
          unitPrice: Money.fromAmount(1000.0),
          costPrice: Money.fromAmount(500.0),
          quantity: 1.0,
        ));

        final cmd = CheckoutCommand(
          commandId: 'CMD-UNAUTH',
          businessId: 'BIZ-01',
          branchId: 'BR-01',
          terminalId: 'TERM-01',
          sessionId: 'SESS-101',
          idempotencyKey: 'KEY-UNAUTH',
          cart: cart,
          payments: [],
        );

        expect(() => coordinator.processCheckout(cmd), throwsA(isA<UnauthorizedCashierFailure>()));
      });

      test('43. expired session throws SessionExpiredFailure', () async {
        final expiredSession = ShopSession(
          sessionId: 'SESS-EXP',
          installationId: 'INST-01',
          terminalId: 'TERM-01',
          userId: 'U-CASHIER-101',
          businessId: 'BIZ-01',
          activeBranchId: 'BR-01',
          startedAt: DateTime.now().subtract(const Duration(days: 1)),
          lastHeartbeatAt: DateTime.now().subtract(const Duration(minutes: 10)),
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          status: ShopSessionStatus.expired,
        );
        identityCoordinator.setSession(user: cashierUser, session: expiredSession);

        final coordinator = PosCheckoutCoordinator(
          identityCoordinator: identityCoordinator,
          posRepository: ShopPosRepositoryImpl(),
          idempotencyStore: InMemorySaleIdempotencyStore(),
          auditRepository: FakePosAuditRepository(),
        );

        final cart = Cart().addItem(CartItem(
          itemId: 'ITM-1',
          productId: 'P1',
          sku: 'S1',
          name: 'سلعة',
          unitPrice: Money.fromAmount(1000.0),
          costPrice: Money.fromAmount(500.0),
          quantity: 1.0,
        ));

        final cmd = CheckoutCommand(
          commandId: 'CMD-EXP',
          businessId: 'BIZ-01',
          branchId: 'BR-01',
          terminalId: 'TERM-01',
          sessionId: 'SESS-EXP',
          idempotencyKey: 'KEY-EXP',
          cart: cart,
          payments: [],
        );

        expect(() => coordinator.processCheckout(cmd), throwsA(isA<SessionExpiredFailure>()));
      });

      test('44. payment mismatch throws InvalidPaymentFailure', () async {
        final coordinator = PosCheckoutCoordinator(
          identityCoordinator: identityCoordinator,
          posRepository: ShopPosRepositoryImpl(),
          idempotencyStore: InMemorySaleIdempotencyStore(),
          auditRepository: FakePosAuditRepository(),
        );

        final cart = Cart().addItem(CartItem(
          itemId: 'ITM-1',
          productId: 'P1',
          sku: 'S1',
          name: 'سلعة',
          unitPrice: Money.fromAmount(10000.0),
          costPrice: Money.fromAmount(5000.0),
          quantity: 1.0,
        ));

        final cmd = CheckoutCommand(
          commandId: 'CMD-MISMATCH',
          businessId: 'BIZ-01',
          branchId: 'BR-01',
          terminalId: 'TERM-01',
          sessionId: 'SESS-101',
          idempotencyKey: 'KEY-MISMATCH',
          cart: cart,
          payments: [
            Payment(
              id: 'P-1',
              method: PaymentMethod.cash,
              amount: Money.fromAmount(4000.0), // 6000 short!
              receivedAt: DateTime.now(),
            ),
          ],
        );

        expect(() => coordinator.processCheckout(cmd), throwsA(isA<InvalidPaymentFailure>()));
      });

      test('45. empty cart throws InvalidCartFailure', () async {
        final coordinator = PosCheckoutCoordinator(
          identityCoordinator: identityCoordinator,
          posRepository: ShopPosRepositoryImpl(),
          idempotencyStore: InMemorySaleIdempotencyStore(),
          auditRepository: FakePosAuditRepository(),
        );

        final cmd = CheckoutCommand(
          commandId: 'CMD-EMPTY',
          businessId: 'BIZ-01',
          branchId: 'BR-01',
          terminalId: 'TERM-01',
          sessionId: 'SESS-101',
          idempotencyKey: 'KEY-EMPTY',
          cart: const Cart(), // Empty!
          payments: [],
        );

        expect(() => coordinator.processCheckout(cmd), throwsA(isA<InvalidCartFailure>()));
      });
    });

    // ────────────────────────────────────────────
    // GROUP L: Financial Properties & Invariants (46 to 48)
    // ────────────────────────────────────────────
    group('Group L: Financial Invariants & Property Tests', () {
      test('46. grandTotal is strictly >= 0 and never drifts', () {
        final cart = Cart(cartDiscount: const Discount(type: DiscountType.fixed, value: 50000.0))
            .addItem(CartItem(
          itemId: 'ITM-1',
          productId: 'P1',
          sku: 'S1',
          name: 'سلعة',
          unitPrice: Money.fromAmount(10000.0),
          costPrice: Money.fromAmount(5000.0),
          quantity: 1.0,
        ));

        final totals = PricingCalculator.calculateCartTotals(cart: cart);
        // Discount 50,000 on 10,000 item -> capped at 10,000
        expect(totals.grandTotal.minorUnits, 0);
        expect(totals.grandTotal >= Money.zero(), isTrue);
      });

      test('47. mathematical invariant: paidTotal == sum(payments)', () {
        final p1 = Payment(id: '1', method: PaymentMethod.cash, amount: Money.fromAmount(1250.0), receivedAt: DateTime.now());
        final p2 = Payment(id: '2', method: PaymentMethod.card, amount: Money.fromAmount(3750.0), receivedAt: DateTime.now());

        final allocation = PaymentAllocation(grandTotal: Money.fromAmount(5000.0), payments: [p1, p2]);
        expect(allocation.paidTotal.minorUnits, p1.amount.minorUnits + p2.amount.minorUnits);
      });

      test('48. zero floating point drift across multiple decimal additions', () {
        // Adding 0.1 IQD 100 times in floating point produces 9.99999999999998
        // With Money minor units, it is EXACTLY 10 units!
        Money sum = Money.zero(Currency.usd);
        for (int i = 0; i < 100; i++) {
          sum = sum + Money.fromAmount(0.10, Currency.usd);
        }
        expect(sum.minorUnits, 1000); // 10.00 USD exactly
        expect(sum.toAmount(), 10.0);
      });
    });
  });
}
