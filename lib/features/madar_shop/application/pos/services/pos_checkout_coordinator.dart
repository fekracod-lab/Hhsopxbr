// منسق ومحرك تنفيذ معاملات البيع الذرية (MADAR SHOP POS Checkout Coordinator)
// Pure Dart — Zero UI Dependencies

import '../../../domain/audit/contracts/shop_audit_repository.dart';
import '../../../domain/audit/entities/shop_audit_entry.dart';
import '../../../domain/identity/rbac/shop_permission.dart';
import '../../../domain/pos/calculators/discount_calculator.dart';
import '../../../domain/pos/calculators/pricing_calculator.dart';
import '../../../domain/pos/entities/customer_ledger_entry.dart';
import '../../../domain/pos/entities/inventory_movement_intent.dart';
import '../../../domain/pos/entities/payment_allocation.dart';
import '../../../domain/pos/entities/receipt_snapshot.dart';
import '../../../domain/pos/entities/sale.dart';
import '../../../domain/pos/entities/sale_item.dart';
import '../../../domain/pos/enums/inventory_movement_type.dart';
import '../../../domain/pos/enums/sale_status.dart';
import '../../../domain/pos/rules/sale_state_machine.dart';
import '../../../domain/pos/services/i_sale_idempotency_store.dart';
import '../../../domain/pos/services/i_shop_pos_repository.dart';
import '../../../domain/pos/services/i_transaction_boundary.dart';
import '../../../domain/pos/validators/payment_validator.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/pos/value_objects/pricing_snapshot.dart';
import '../../shop_identity_coordinator.dart';
import '../commands/checkout_command.dart';
import '../commands/checkout_result.dart';
import '../events/pos_domain_events.dart';
import '../failures/pos_failures.dart';

class PosCheckoutCoordinator {
  final ShopIdentityCoordinator _identityCoordinator;
  final IShopPosRepository _posRepository;
  final ISaleIdempotencyStore _idempotencyStore;
  final ITransactionBoundary _transactionBoundary;
  final IShopAuditRepository _auditRepository;
  final IPosEventBus _eventBus;

  PosCheckoutCoordinator({
    required ShopIdentityCoordinator identityCoordinator,
    required IShopPosRepository posRepository,
    required ISaleIdempotencyStore idempotencyStore,
    ITransactionBoundary? transactionBoundary,
    required IShopAuditRepository auditRepository,
    IPosEventBus? eventBus,
  })  : _identityCoordinator = identityCoordinator,
        _posRepository = posRepository,
        _idempotencyStore = idempotencyStore,
        _transactionBoundary = transactionBoundary ?? const DefaultLocalTransactionBoundary(),
        _auditRepository = auditRepository,
        _eventBus = eventBus ?? DefaultPosEventBus();

  /// معالجة عملية الـ Checkout وإتمام الفاتورة بشكل ذري ومقاوم للتكرار
  Future<CheckoutResult> processCheckout(CheckoutCommand command) async {
    // 1. فحص مفتاح منع التكرار (Idempotency Check)
    final existingSale = await _idempotencyStore.getSaleByIdempotencyKey(
      businessId: command.businessId,
      branchId: command.branchId,
      idempotencyKey: command.idempotencyKey,
    );

    if (existingSale != null) {
      final receipt = ReceiptSnapshot.fromSale(
        sale: existingSale,
        businessName: command.businessId,
        branchName: command.branchId,
      );
      return CheckoutResult(
        sale: existingSale,
        receipt: receipt,
        inventoryIntents: const [],
        isIdempotentReplay: true,
        processedAt: DateTime.now(),
      );
    }

    // 2. التحقق من الهوية وصلاحية الجلسة والمحطة
    _validateSessionAndTerminal(command);

    // 3. التحقق من صلاحيات الكاشير
    _validateCashierPermissions();

    // 4. التحقق من محتويات السلة
    if (command.cart.isEmpty) {
      throw const InvalidCartFailure('سلة المشتريات فارغة؛ لا يمكن إتمام البيع.');
    }

    for (final item in command.cart.items) {
      if (item.quantity <= 0) {
        throw InvalidQuantityFailure(
          'الكمية المحددة للمنتج "${item.name}" غير صالحة (${item.quantity}).',
        );
      }
    }

    // 5. حساب الإجماليات المالية الشاملة
    final totals = PricingCalculator.calculateCartTotals(
      cart: command.cart,
      taxPolicy: command.taxPolicy,
    );

    // 6. التحقق من الدفعات وتوزيعها
    final allocation = PaymentAllocation(
      grandTotal: totals.grandTotal,
      payments: command.payments,
    );

    final paymentValidation = PaymentValidator.validate(
      allocation: allocation,
      customerId: command.customerId,
    );

    if (!paymentValidation.isValid) {
      if (allocation.hasCredit && (command.customerId == null || command.customerId!.trim().isEmpty)) {
        throw CreditCustomerRequiredFailure(
          paymentValidation.errorMessage ?? 'البيع الآجل يتطلب تحديد العميل.',
        );
      }
      throw InvalidPaymentFailure(
        paymentValidation.errorMessage ?? 'بيانات الدفع غير متسقة.',
      );
    }

    // 7. التحقق من آلة الحالة
    final stateValidation = SaleStateMachine.validateTransition(
      currentStatus: SaleStatus.draft,
      targetStatus: SaleStatus.completed,
    );
    if (!stateValidation.isAllowed) {
      throw TransactionConflictFailure(stateValidation.rejectionReason ?? 'تعذر إتمام البيع.');
    }

    // 8. توزيع خصم السلة على البنود وبناء SaleItems
    final cartDiscountAllocations = DiscountCalculator.allocateCartDiscountAcrossItems(
      items: command.cart.items,
      totalCartDiscount: totals.discountTotal - command.cart.itemsDiscountTotal,
    );

    final saleId = 'SALE-${DateTime.now().microsecondsSinceEpoch}-${command.commandId}';
    final saleNumber = 'INV-${DateTime.now().microsecondsSinceEpoch.toString().substring(5)}';
    final user = _identityCoordinator.currentUser!;
    final session = _identityCoordinator.currentSession!;

    final List<SaleItem> saleItems = command.cart.items.map((cartItem) {
      final allocatedCartDiscount = cartDiscountAllocations[cartItem.itemId] ??
          Money.zero(command.cart.currency);
      final totalItemDiscount = cartItem.discountAmount + allocatedCartDiscount;

      // ضريبة البند التناسبية
      final itemTaxable = cartItem.lineSubtotal - totalItemDiscount;
      final itemTax = command.taxPolicy.calculateTax(
        itemTaxable.isNegative ? Money.zero(command.cart.currency) : itemTaxable,
      );

      final pricingSnapshot = cartItem.pricingSnapshot ??
          PricingSnapshot.create(
            basePrice: cartItem.unitPrice,
            costPrice: cartItem.costPrice,
            unitPrice: cartItem.unitPrice,
            unitDiscount: cartItem.quantity > 0 ? (totalItemDiscount * (1.0 / cartItem.quantity)) : Money.zero(command.cart.currency),
            unitTax: cartItem.quantity > 0 ? (itemTax * (1.0 / cartItem.quantity)) : Money.zero(command.cart.currency),
          );

      return SaleItem(
        itemId: cartItem.itemId,
        productId: cartItem.productId,
        variantId: cartItem.variantId,
        variantTitle: cartItem.variantTitle,
        sku: cartItem.sku,
        barcode: cartItem.barcode,
        name: cartItem.name,
        pricingSnapshot: pricingSnapshot,
        quantity: cartItem.quantity,
        unitOfMeasure: cartItem.unitOfMeasure,
        isWeighable: cartItem.isWeighable,
        lineDiscount: totalItemDiscount,
        lineTax: itemTax,
        notes: cartItem.notes,
      );
    }).toList();

    // 9. إنشاء كيان الفاتورة المكتملة
    final sale = Sale(
      id: saleId,
      businessId: command.businessId,
      branchId: command.branchId,
      terminalId: command.terminalId,
      sessionId: command.sessionId,
      cashierId: user.userId,
      cashierName: user.fullName,
      saleNumber: saleNumber,
      source: 'POS_TERMINAL',
      status: SaleStatus.completed,
      items: saleItems,
      subtotal: totals.subtotal,
      discountTotal: totals.discountTotal,
      taxTotal: totals.taxTotal,
      grandTotal: totals.grandTotal,
      paidTotal: allocation.paidTotal,
      remainingTotal: allocation.remainingTotal,
      changeTotal: allocation.changeTotal,
      customerId: command.customerId,
      customerName: command.customerName,
      payments: command.payments,
      currency: command.cart.currency,
      createdAt: command.createdAt,
      completedAt: DateTime.now(),
      version: 1,
      idempotencyKey: command.idempotencyKey,
      metadata: command.metadata,
    );

    // 10. إنشاء نيات حركة المخزون
    final List<InventoryMovementIntent> movementIntents = command.cart.items.map((it) {
      return InventoryMovementIntent(
        intentId: 'INTENT-${DateTime.now().microsecondsSinceEpoch}-${it.productId}',
        businessId: command.businessId,
        branchId: command.branchId,
        productId: it.productId,
        variantId: it.variantId,
        quantity: it.quantity,
        movementType: InventoryMovementType.sale,
        referenceType: 'SALE',
        referenceId: saleId,
        requestedAt: DateTime.now(),
      );
    }).toList();

    // 11. إنشاء قيد دفتر الأستاذ للعميل في حالة البيع الآجل
    CustomerLedgerEntry? ledgerEntry;
    if (allocation.hasCredit && command.customerId != null) {
      ledgerEntry = CustomerLedgerEntry.fromCreditSale(
        entryId: 'LEDGER-${DateTime.now().millisecondsSinceEpoch}',
        customerId: command.customerId!,
        saleId: saleId,
        businessId: command.businessId,
        branchId: command.branchId,
        grandTotal: totals.grandTotal,
        immediatePaid: allocation.immediatePaidTotal,
        creditBalance: allocation.creditAmountTotal,
        note: command.notes,
      );
    }

    // 12. إنشاء لقطة الإيصال الجاهزة للطباعة
    final receipt = ReceiptSnapshot.fromSale(
      sale: sale,
      businessName: command.businessId,
      branchName: command.branchId,
    );

    // 13. الالتزام الذري للمعاملة (Atomic Transactional Commit)
    await _transactionBoundary.runTransaction(() async {
      // أ. حفظ الفاتورة
      await _posRepository.saveSale(sale);

      // ب. تسجيل نيات حركة المخزون
      for (final intent in movementIntents) {
        await _posRepository.recordInventoryMovementIntent(intent);
      }

      // ج. تسجيل قيد دفتر الأستاذ
      if (ledgerEntry != null) {
        await _posRepository.recordCustomerLedgerEntry(ledgerEntry);
      }

      // د. حفظ الإيصال
      await _posRepository.saveReceiptSnapshot(receipt);

      // هـ. حفظ مفتاح عدم التكرار
      await _idempotencyStore.recordIdempotentSale(
        businessId: command.businessId,
        branchId: command.branchId,
        idempotencyKey: command.idempotencyKey,
        sale: sale,
      );

      // و. توثيق العملية في سجل التدقيق غير القابل للتعديل
      await _auditRepository.recordAuditEntry(
        ShopAuditEntry(
          auditId: 'AUDIT-SALE-${DateTime.now().microsecondsSinceEpoch}',
          businessId: command.businessId,
          branchId: command.branchId,
          userId: user.userId,
          userName: user.fullName,
          terminalId: session.terminalId,
          action: ShopAuditAction.priceOverride, // أو عملية بيع
          referenceId: saleId,
          afterState: {
            'saleNumber': saleNumber,
            'grandTotal': totals.grandTotal.minorUnits,
            'itemsCount': saleItems.length,
            'isCredit': allocation.hasCredit,
          },
          reason: 'إتمام معاملة بيع بنقطة البيع #$saleNumber',
          timestamp: DateTime.now(),
        ),
      );
    });

    // 14. إطلاق أحداث النطاق (Domain Events)
    _eventBus.publish(SaleCompletedEvent(
      eventId: 'EVT-${DateTime.now().microsecondsSinceEpoch}',
      occurredAt: DateTime.now(),
      sale: sale,
    ));

    _eventBus.publish(InventoryMovementRequestedEvent(
      eventId: 'EVT-INV-${DateTime.now().microsecondsSinceEpoch}',
      occurredAt: DateTime.now(),
      movementIntents: movementIntents,
    ));

    if (ledgerEntry != null) {
      _eventBus.publish(CreditCreatedEvent(
        eventId: 'EVT-CR-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: DateTime.now(),
        ledgerEntry: ledgerEntry,
      ));
    }

    _eventBus.publish(ReceiptReadyEvent(
      eventId: 'EVT-RCPT-${DateTime.now().microsecondsSinceEpoch}',
      occurredAt: DateTime.now(),
      receiptSnapshot: receipt,
    ));

    return CheckoutResult(
      sale: sale,
      receipt: receipt,
      inventoryIntents: movementIntents,
      customerLedgerEntry: ledgerEntry,
      isIdempotentReplay: false,
      processedAt: DateTime.now(),
    );
  }

  void _validateSessionAndTerminal(CheckoutCommand command) {
    final user = _identityCoordinator.currentUser;
    final session = _identityCoordinator.currentSession;

    if (user == null || session == null) {
      throw const UnauthorizedCashierFailure('يجب تسجيل الدخول أولاً لإجراء البيع.');
    }

    if (session.isExpired || session.isHeartbeatStale()) {
      throw const SessionExpiredFailure('جلسة العمل منتهية أو خاملة؛ يرجى تجديد الجلسة.');
    }

    if (!_identityCoordinator.isAuthenticated) {
      throw const UnauthorizedCashierFailure('المستخدم غير مصرح له.');
    }

    if (session.terminalId != command.terminalId) {
      throw UnauthorizedTerminalFailure(
        'المحطة المحددة (${command.terminalId}) لا تطابق محطة الجلسة النشطة (${session.terminalId}).',
      );
    }

    if (session.businessId != command.businessId) {
      throw const UnauthorizedTerminalFailure('معرف النشاط التجاري غير متطابق مع الجلسة.');
    }

    if (session.activeBranchId != command.branchId) {
      throw BranchMismatchFailure(
        'الفرع المحدد (${command.branchId}) لا يطابق فرع الجلسة النشط (${session.activeBranchId}).',
      );
    }
  }

  void _validateCashierPermissions() {
    if (!_identityCoordinator.hasPermission(ShopPermission.accessPos)) {
      throw const UnauthorizedCashierFailure('ليس لديك صلاحية الوصول إلى نظام نقاط البيع.');
    }

    if (!_identityCoordinator.hasPermission(ShopPermission.createSalesOrder)) {
      throw const UnauthorizedCashierFailure('ليس لديك صلاحية إنشاء وتسجيل مبيعات جديدة.');
    }
  }
}
