// المنسق المركزي لعمليات المرتجعات واسترداد الأموال (MADAR SHOP Returns Coordinator)
// Pure Dart — Zero UI Dependencies

import 'dart:async';

import '../../../domain/audit/contracts/shop_audit_repository.dart';
import '../../../domain/audit/entities/shop_audit_entry.dart';
import '../../../domain/identity/rbac/shop_permission.dart';
import '../../../domain/identity/rbac/shop_permission_matrix.dart';
import '../../../domain/identity/rbac/shop_role.dart';
import '../../../domain/inventory/contracts/return_inventory_intent.dart';
import '../../../domain/inventory/enums/inventory_movement_type.dart';
import '../../../domain/inventory/value_objects/stock_quantity.dart';
import '../../../domain/pos/entities/customer_ledger_entry.dart';
import '../../../domain/pos/entities/sale.dart';
import '../../../domain/pos/enums/sale_status.dart';
import '../../../domain/pos/services/i_shop_pos_repository.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/purchasing/entities/supplier_ledger_entry.dart';
import '../../../domain/purchasing/enums/supplier_ledger_entry_type.dart';
import '../../../domain/purchasing/repositories/i_purchase_receipt_repository.dart';
import '../../../domain/purchasing/repositories/i_supplier_ledger_repository.dart';
import '../../../domain/purchasing/repositories/i_supplier_repository.dart';
import '../../../domain/returns/entities/refund.dart';
import '../../../domain/returns/entities/return_item.dart';
import '../../../domain/returns/entities/return_order.dart';
import '../../../domain/returns/entities/supplier_credit_note.dart';
import '../../../domain/returns/entities/supplier_return.dart';
import '../../../domain/returns/entities/supplier_return_item.dart';
import '../../../domain/returns/enums/refund_method.dart';
import '../../../domain/returns/enums/refund_status.dart';
import '../../../domain/returns/enums/return_order_status.dart';
import '../../../domain/returns/enums/supplier_return_status.dart';
import '../../../domain/returns/repositories/i_refund_repository.dart';
import '../../../domain/returns/repositories/i_return_order_repository.dart';
import '../../../domain/returns/repositories/i_returns_idempotency_store.dart';
import '../../../domain/returns/repositories/i_supplier_credit_note_repository.dart';
import '../../../domain/returns/repositories/i_supplier_return_repository.dart';
import '../../../domain/returns/rules/return_rules.dart';
import '../../../domain/returns/rules/return_state_machine.dart';
import '../../inventory/commands/inventory_commands.dart';
import '../../inventory/services/inventory_transaction_service.dart';
import '../commands/returns_commands.dart';
import '../events/returns_domain_events.dart';
import '../failures/returns_failures.dart';
import '../results/returns_operation_results.dart';

class ReturnsCoordinator {
  final IReturnOrderRepository _returnOrderRepo;
  final IRefundRepository _refundRepo;
  final ISupplierReturnRepository _supplierReturnRepo;
  final ISupplierCreditNoteRepository _supplierCreditNoteRepo;
  final IReturnsIdempotencyStore _idempotencyStore;
  final IShopPosRepository _posRepo;
  final InventoryTransactionService _inventoryTxService;
  final IPurchaseReceiptRepository _purchaseReceiptRepo;
  final ISupplierLedgerRepository _supplierLedgerRepo;
  final ISupplierRepository _supplierRepo;
  final IShopAuditRepository _auditRepo;
  final void Function(ReturnsDomainEvent)? _eventSink;

  // سياق الصلاحيات والعزل المتعدد
  final String currentBusinessId;
  final String currentBranchId;
  final ShopRole currentRole;
  final Set<ShopPermission>? customPermissions;

  // أقفال التزامن لمنع Race Conditions
  final Map<String, Completer<void>> _locks = {};

  ReturnsCoordinator({
    required IReturnOrderRepository returnOrderRepo,
    required IRefundRepository refundRepo,
    required ISupplierReturnRepository supplierReturnRepo,
    required ISupplierCreditNoteRepository supplierCreditNoteRepo,
    required IReturnsIdempotencyStore idempotencyStore,
    required IShopPosRepository posRepo,
    required InventoryTransactionService inventoryTxService,
    required IPurchaseReceiptRepository purchaseReceiptRepo,
    required ISupplierLedgerRepository supplierLedgerRepo,
    required ISupplierRepository supplierRepo,
    required IShopAuditRepository auditRepo,
    void Function(ReturnsDomainEvent)? eventSink,
    required this.currentBusinessId,
    required this.currentBranchId,
    required this.currentRole,
    this.customPermissions,
  })  : _returnOrderRepo = returnOrderRepo,
        _refundRepo = refundRepo,
        _supplierReturnRepo = supplierReturnRepo,
        _supplierCreditNoteRepo = supplierCreditNoteRepo,
        _idempotencyStore = idempotencyStore,
        _posRepo = posRepo,
        _inventoryTxService = inventoryTxService,
        _purchaseReceiptRepo = purchaseReceiptRepo,
        _supplierLedgerRepo = supplierLedgerRepo,
        _supplierRepo = supplierRepo,
        _auditRepo = auditRepo,
        _eventSink = eventSink;

  // ─── إدارة الأقفال التزامنية (Mutex) ───

  Future<void> _acquireLock(String key) async {
    while (_locks.containsKey(key)) {
      await _locks[key]!.future;
    }
    _locks[key] = Completer<void>();
  }

  void _releaseLock(String key) {
    if (_locks.containsKey(key)) {
      final completer = _locks.remove(key);
      completer?.complete();
    }
  }

  void _assertBusinessMatches(String businessId) {
    if (businessId != currentBusinessId) {
      throw const ReturnsBusinessMismatchFailure();
    }
  }

  void _assertBranchMatches(String branchId) {
    if (branchId != currentBranchId) {
      throw const ReturnsBranchMismatchFailure();
    }
  }

  void _assertHasPermission(ShopPermission permission) {
    final allowed = ShopPermissionMatrix.hasPermission(
      role: currentRole,
      permission: permission,
      customPermissions: customPermissions,
    );
    if (!allowed) {
      throw ReturnsPermissionDeniedFailure(
        'الدور الحالي (${currentRole.name}) لا يملك الصلاحية (${permission.name}).',
      );
    }
  }

  // ─── أوامر مرتجعات الزبائن (Customer Returns) ───

  /// إنشاء أمر مرتجع جديد بحالة REQUESTED
  Future<ReturnOrderOperationResult> createReturnOrder(CreateReturnOrderCommand command) async {
    _assertBusinessMatches(command.businessId);
    _assertBranchMatches(command.branchId);
    _assertHasPermission(ShopPermission.createReturnOrder);

    if (await _idempotencyStore.hasKey(command.idempotencyKey)) {
      final cached = await _idempotencyStore.getResult(command.idempotencyKey);
      if (cached is ReturnOrderOperationResult) return cached;
    }

    if (command.items.isEmpty) {
      throw const InvalidReturnQuantityFailure('لا يمكن إنشاء مرتجع بدون بنود.');
    }

    // 1. قفل الفاتورة الأصلية لمنع التنافس المتزامن على إرجاع نفس القطعة (Critical Test A)
    final lockKey = 'lock:sale_return:${command.originalSaleId}';
    await _acquireLock(lockKey);

    try {
      // 2. التحقق من وجود الفاتورة الأصلية وحالتها
      final sale = await _posRepo.getSaleById(
        businessId: command.businessId,
        branchId: command.branchId,
        saleId: command.originalSaleId,
      );
      if (sale == null || sale.status != SaleStatus.completed) {
        throw const OriginalSaleNotFoundFailure();
      }

      // 3. احتساب الكميات المرتجعة مسبقاً لهذه الفاتورة
      final existingReturns = await _returnOrderRepo.getReturnOrdersForSale(
        businessId: command.businessId,
        saleId: command.originalSaleId,
      );

      final returnedQuantitiesMap = <String, StockQuantity>{};
      for (final prevRet in existingReturns) {
        if (prevRet.status.isCancelled || prevRet.status.isRejected) continue;
        for (final item in prevRet.items) {
          final cur = returnedQuantitiesMap[item.originalSaleItemId] ?? StockQuantity.zero(item.quantity.unit);
          returnedQuantitiesMap[item.originalSaleItemId] = cur + item.quantity;
        }
      }

      // 4. بناء بنود المرتجع مع التحقق الصارم من الكمية وتجميد الأسعار الأصلية
      final returnItems = <ReturnItem>[];

      for (int i = 0; i < command.items.length; i++) {
        final input = command.items[i];
        final saleItem = sale.items.firstWhere(
          (it) => it.itemId == input.originalSaleItemId,
          orElse: () => throw InvalidReturnQuantityFailure(
            'البند ${input.originalSaleItemId} غير موجود في الفاتورة الأصلية.',
          ),
        );

        final soldQty = StockQuantity.discrete(saleItem.quantity.toInt());
        final alreadyRet = returnedQuantitiesMap[input.originalSaleItemId] ?? StockQuantity.zero(soldQty.unit);

        final validation = ReturnRules.validateReturnQuantity(
          soldQuantity: soldQty,
          alreadyReturnedQuantity: alreadyRet,
          requestedQuantity: input.quantity,
        );

        if (!validation.isAllowed) {
          throw InvalidReturnQuantityFailure(validation.reason!);
        }

        // تجميد التكلفة والسعر والخصم الأصلي للبند
        final unitPrice = saleItem.pricingSnapshot.unitPrice;
        final unitDiscount = saleItem.quantity > 0
            ? saleItem.lineDiscount * (1 / saleItem.quantity)
            : Money.zero(unitPrice.currency);
        final unitTax = saleItem.quantity > 0
            ? saleItem.lineTax * (1 / saleItem.quantity)
            : Money.zero(unitPrice.currency);
        final originalCost = saleItem.pricingSnapshot.costPrice;

        returnItems.add(ReturnItem(
          id: 'RET-ITEM-${command.commandId}-${i + 1}',
          originalSaleItemId: input.originalSaleItemId,
          productId: input.productId,
          variantId: input.variantId,
          descriptionSnapshot: saleItem.name,
          skuSnapshot: saleItem.sku,
          quantity: input.quantity,
          unitRefundPrice: unitPrice,
          unitDiscountDeduction: unitDiscount,
          unitTaxRefund: unitTax,
          originalCostBasis: originalCost,
          restockCondition: input.restockCondition,
          reason: input.reason,
          reasonNotes: input.reasonNotes,
        ));
      }

      final returnOrder = ReturnOrder(
        id: command.commandId,
        businessId: command.businessId,
        branchId: command.branchId,
        originalSaleId: command.originalSaleId,
        returnNumber: command.returnNumber,
        type: command.type,
        status: ReturnOrderStatus.requested,
        items: returnItems,
        currency: sale.currency,
        customerId: command.customerId ?? sale.customerId,
        customerName: command.customerName ?? sale.customerName,
        createdBy: command.actorId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        idempotencyKey: command.idempotencyKey,
      );

      await _returnOrderRepo.saveReturnOrder(returnOrder);

      await _auditRepo.recordAuditEntry(ShopAuditEntry(
        auditId: 'AUD-RET-C-${DateTime.now().microsecondsSinceEpoch}',
        businessId: command.businessId,
        branchId: command.branchId,
        userId: command.actorId,
        userName: 'Staff Actor',
        terminalId: command.terminalId ?? 'SERVER',
        action: ShopAuditAction.returnCreated,
        referenceId: returnOrder.id,
        timestamp: DateTime.now(),
        metadata: {
          'originalSaleId': command.originalSaleId,
          'grandTotalRefund': returnOrder.grandTotalRefund.toAmount(),
        },
      ));

      _eventSink?.call(ReturnCreatedEvent(
        eventId: 'EVT-RET-C-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: DateTime.now(),
        order: returnOrder,
        actorId: command.actorId,
      ));

      final result = ReturnOrderOperationResult(
        isSuccess: true,
        order: returnOrder,
        message: 'تم إنشاء أمر المرتجع بنجاح.',
      );

      await _idempotencyStore.saveResult(command.idempotencyKey, result);
      return result;
    } finally {
      _releaseLock(lockKey);
    }
  }

  /// اعتماد أمر المرتجع من المشرف (REQUESTED -> APPROVED)
  Future<ReturnOrderOperationResult> approveReturnOrder(ApproveReturnOrderCommand command) async {
    _assertBusinessMatches(command.businessId);
    _assertHasPermission(ShopPermission.approveReturnOrder);

    final lockKey = 'lock:return_order:${command.returnOrderId}';
    await _acquireLock(lockKey);

    try {
      final order = await _returnOrderRepo.getReturnOrderById(
        businessId: command.businessId,
        returnOrderId: command.returnOrderId,
      );
      if (order == null) throw const ReturnOrderNotFoundFailure();

      final validation = ReturnStateMachine.validateTransition(
        currentStatus: order.status,
        nextStatus: ReturnOrderStatus.approved,
      );
      if (!validation.isAllowed) {
        throw InvalidReturnStateTransitionFailure(validation.rejectionReason!);
      }

      final approved = order.copyWith(
        status: ReturnOrderStatus.approved,
        approvedBy: command.actorId,
        updatedAt: DateTime.now(),
        version: order.version + 1,
      );

      await _returnOrderRepo.saveReturnOrder(approved);

      await _auditRepo.recordAuditEntry(ShopAuditEntry(
        auditId: 'AUD-RET-A-${DateTime.now().microsecondsSinceEpoch}',
        businessId: command.businessId,
        branchId: approved.branchId,
        userId: command.actorId,
        userName: 'Approver Actor',
        terminalId: 'SERVER',
        action: ShopAuditAction.returnApproved,
        referenceId: approved.id,
        timestamp: DateTime.now(),
        metadata: {'approvedBy': command.actorId},
      ));

      _eventSink?.call(ReturnApprovedEvent(
        eventId: 'EVT-RET-A-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: DateTime.now(),
        order: approved,
        approvedBy: command.actorId,
      ));

      return ReturnOrderOperationResult(isSuccess: true, order: approved);
    } finally {
      _releaseLock(lockKey);
    }
  }

  /// استلام بضاعة المرتجع وفحصها وإعادة تخزينها في S3 إن كانت صالحة (APPROVED -> RECEIVED)
  Future<ReturnOrderOperationResult> receiveReturnOrder(ReceiveReturnOrderCommand command) async {
    _assertBusinessMatches(command.businessId);
    _assertBranchMatches(command.branchId);
    _assertHasPermission(ShopPermission.receiveReturnOrder);

    final lockKey = 'lock:return_order:${command.returnOrderId}';
    await _acquireLock(lockKey);

    try {
      final order = await _returnOrderRepo.getReturnOrderById(
        businessId: command.businessId,
        returnOrderId: command.returnOrderId,
      );
      if (order == null) throw const ReturnOrderNotFoundFailure();

      final validation = ReturnStateMachine.validateTransition(
        currentStatus: order.status,
        nextStatus: ReturnOrderStatus.received,
      );
      if (!validation.isAllowed) {
        throw InvalidReturnStateTransitionFailure(validation.rejectionReason!);
      }

      // 1. معالجة المخزون عبر S3 Inventory Authority
      for (final item in order.items) {
        if (item.isRestockable) {
          // بضاعة صالحة: زيادة المخزون الفعلي OnHand بحركة customerReturn
          await _inventoryTxService.applyMovement(ApplyInventoryMovementCommand(
            commandId: 'MOV-RET-${order.id}-${item.id}',
            businessId: order.businessId,
            branchId: order.branchId,
            productId: item.productId,
            variantId: item.variantId,
            movementType: InventoryMovementType.customerReturn,
            quantity: item.quantity,
            referenceType: 'CUSTOMER_RETURN',
            referenceId: order.id,
            reason: 'إرجاع بضاعة صالحة لإعادة البيع بموجب المرتجع #${order.returnNumber}',
            actorId: command.actorId,
            idempotencyKey: 'IDEM-INV-RET-${order.id}-${item.id}',
          ));
        } else {
          // بضاعة تالفة / منتهية الصلاحية: لا تضاف للمخزون الصالح، بل تسجل حركة تلف أو خسارة دون زيادة OnHand
          await _auditRepo.recordAuditEntry(ShopAuditEntry(
            auditId: 'AUD-DAMAGED-RET-${DateTime.now().microsecondsSinceEpoch}',
            businessId: order.businessId,
            branchId: order.branchId,
            userId: command.actorId,
            userName: 'Receiver Actor',
            terminalId: command.terminalId ?? 'SERVER',
            action: ShopAuditAction.manualStockAdjustment,
            referenceId: order.id,
            timestamp: DateTime.now(),
            metadata: {
              'productId': item.productId,
              'variantId': item.variantId,
              'condition': item.restockCondition.name,
              'quantity': item.quantity.toDouble(),
              'lossAmount': item.totalCostBasis.toAmount(),
            },
          ));
        }
      }

      final received = order.copyWith(
        status: ReturnOrderStatus.received,
        receivedBy: command.actorId,
        updatedAt: DateTime.now(),
        version: order.version + 1,
      );

      await _returnOrderRepo.saveReturnOrder(received);

      await _auditRepo.recordAuditEntry(ShopAuditEntry(
        auditId: 'AUD-RET-R-${DateTime.now().microsecondsSinceEpoch}',
        businessId: command.businessId,
        branchId: received.branchId,
        userId: command.actorId,
        userName: 'Receiver Actor',
        terminalId: command.terminalId ?? 'SERVER',
        action: ShopAuditAction.returnReceived,
        referenceId: received.id,
        timestamp: DateTime.now(),
        metadata: {'receivedBy': command.actorId},
      ));

      _eventSink?.call(ReturnReceivedEvent(
        eventId: 'EVT-RET-R-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: DateTime.now(),
        order: received,
        receivedBy: command.actorId,
      ));

      return ReturnOrderOperationResult(isSuccess: true, order: received);
    } finally {
      _releaseLock(lockKey);
    }
  }

  /// صرف الاسترداد المالي أو الرصيد الدائن للزبون (RECEIVED -> REFUNDED -> COMPLETED)
  Future<RefundOperationResult> processRefund(ProcessRefundCommand command) async {
    _assertBusinessMatches(command.businessId);
    _assertBranchMatches(command.branchId);
    _assertHasPermission(ShopPermission.refundReturnOrder);

    // فحص عدم التكرار المسبق (Critical Test B)
    if (await _idempotencyStore.hasKey(command.idempotencyKey)) {
      final cached = await _idempotencyStore.getResult(command.idempotencyKey);
      if (cached is RefundOperationResult) return cached;
    }

    final lockKey = 'lock:return_order:${command.returnOrderId}';
    await _acquireLock(lockKey);

    try {
      final order = await _returnOrderRepo.getReturnOrderById(
        businessId: command.businessId,
        returnOrderId: command.returnOrderId,
      );
      if (order == null) throw const ReturnOrderNotFoundFailure();

      final validation = ReturnStateMachine.validateTransition(
        currentStatus: order.status,
        nextStatus: ReturnOrderStatus.refunded,
      );
      if (!validation.isAllowed) {
        throw InvalidReturnStateTransitionFailure(validation.rejectionReason!);
      }

      if (command.refundAmount != order.grandTotalRefund) {
        throw RefundAmountMismatchFailure(
          'مبلغ الاسترداد (${command.refundAmount.toAmount()}) لا يطابق إجمالي المرتجع (${order.grandTotalRefund.toAmount()}).',
        );
      }

      // 1. إنشاء قيد الاسترداد المالي
      final refund = Refund(
        id: command.commandId,
        saleId: order.originalSaleId,
        returnId: order.id,
        customerId: order.customerId,
        amount: command.refundAmount,
        method: command.method,
        status: RefundStatus.completed,
        reference: command.reference,
        createdAt: DateTime.now(),
        actorId: command.actorId,
        idempotencyKey: command.idempotencyKey,
      );

      await _refundRepo.saveRefund(refund);

      // 2. إذا كانت طريقة الاسترداد رصيد دائن للعميل (Customer Credit): قيد في دفتر أستاذ العميل
      if (command.method == RefundMethod.customerCredit) {
        if (order.customerId == null || order.customerId!.isEmpty) {
          throw const RefundProcessingFailure('لا يمكن إيداع رصيد دائن لعميل غير معرف.');
        }

        final customerLedgerEntry = CustomerLedgerEntry.fromRefundCredit(
          entryId: 'CUST-LED-${refund.id}',
          customerId: order.customerId!,
          returnId: order.id,
          businessId: order.businessId,
          branchId: order.branchId,
          refundAmount: command.refundAmount,
          note: 'رصيد دائن ناتج عن مرتجع مبيعات #${order.returnNumber}',
        );

        await _posRepo.recordCustomerLedgerEntry(customerLedgerEntry);
      }

      // 3. اكتمال المرتجع وانتقاله إلى REFUNDED ثم COMPLETED
      final completed = order.copyWith(
        status: ReturnOrderStatus.completed,
        refundedBy: command.actorId,
        closedBy: command.actorId,
        updatedAt: DateTime.now(),
        version: order.version + 1,
      );

      await _returnOrderRepo.saveReturnOrder(completed);

      await _auditRepo.recordAuditEntry(ShopAuditEntry(
        auditId: 'AUD-REFUND-${DateTime.now().microsecondsSinceEpoch}',
        businessId: command.businessId,
        branchId: completed.branchId,
        userId: command.actorId,
        userName: 'Refund Actor',
        terminalId: command.terminalId ?? 'SERVER',
        action: ShopAuditAction.refundCompleted,
        referenceId: refund.id,
        timestamp: DateTime.now(),
        metadata: {
          'returnId': order.id,
          'amount': refund.amount.toAmount(),
          'method': refund.method.name,
        },
      ));

      _eventSink?.call(RefundCompletedEvent(
        eventId: 'EVT-REFUND-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: DateTime.now(),
        refund: refund,
        order: completed,
      ));

      final result = RefundOperationResult(
        isSuccess: true,
        refund: refund,
        order: completed,
        message: 'تم إتمام عملية الاسترداد بنجاح.',
      );

      await _idempotencyStore.saveResult(command.idempotencyKey, result);
      return result;
    } finally {
      _releaseLock(lockKey);
    }
  }

  /// إلغاء أمر المرتجع
  Future<ReturnOrderOperationResult> cancelReturnOrder(CancelReturnOrderCommand command) async {
    _assertBusinessMatches(command.businessId);

    final lockKey = 'lock:return_order:${command.returnOrderId}';
    await _acquireLock(lockKey);

    try {
      final order = await _returnOrderRepo.getReturnOrderById(
        businessId: command.businessId,
        returnOrderId: command.returnOrderId,
      );
      if (order == null) throw const ReturnOrderNotFoundFailure();

      final validation = ReturnStateMachine.validateTransition(
        currentStatus: order.status,
        nextStatus: ReturnOrderStatus.cancelled,
      );
      if (!validation.isAllowed) {
        throw InvalidReturnStateTransitionFailure(validation.rejectionReason!);
      }

      final cancelled = order.copyWith(
        status: ReturnOrderStatus.cancelled,
        closedBy: command.actorId,
        updatedAt: DateTime.now(),
        version: order.version + 1,
      );

      await _returnOrderRepo.saveReturnOrder(cancelled);

      _eventSink?.call(ReturnCancelledEvent(
        eventId: 'EVT-RET-X-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: DateTime.now(),
        order: cancelled,
        cancelledBy: command.actorId,
        reason: command.reason,
      ));

      return ReturnOrderOperationResult(isSuccess: true, order: cancelled);
    } finally {
      _releaseLock(lockKey);
    }
  }

  // ─── مرتجعات الموردين وإشعارات الدائن (Supplier Returns & Credit Notes) ───

  /// إنشاء أمر إرجاع بضاعة للمورد بحالة DRAFT
  Future<SupplierReturnOperationResult> createSupplierReturn(CreateSupplierReturnCommand command) async {
    _assertBusinessMatches(command.businessId);
    _assertBranchMatches(command.branchId);
    _assertHasPermission(ShopPermission.createSupplierReturn);

    if (await _idempotencyStore.hasKey(command.idempotencyKey)) {
      final cached = await _idempotencyStore.getResult(command.idempotencyKey);
      if (cached is SupplierReturnOperationResult) return cached;
    }

    if (command.items.isEmpty) {
      throw const InvalidSupplierReturnQuantityFailure('لا يمكن إنشاء مرتجع مورد بدون بنود.');
    }

    final lockKey = 'lock:sup_return:${command.originalReceiptId}';
    await _acquireLock(lockKey);

    try {
      // 1. التحقق من إيصال الاستلام الأصلي
      final receipt = await _purchaseReceiptRepo.getReceiptById(
        businessId: command.businessId,
        receiptId: command.originalReceiptId,
      );
      if (receipt == null) {
        throw const SupplierReturnNotFoundFailure('إيصال الاستلام الأصلي للمشتريات غير موجود.');
      }

      // 2. التحقق من الكميات المرتجعة سابقاً لنفس الإيصال
      final existingReturns = await _supplierReturnRepo.getSupplierReturnsForPurchase(
        businessId: command.businessId,
        purchaseId: command.originalPurchaseId,
      );

      final returnedMap = <String, StockQuantity>{};
      for (final prev in existingReturns) {
        if (prev.status.isCancelled) continue;
        for (final it in prev.items) {
          final cur = returnedMap[it.purchaseReceiptItemId] ?? StockQuantity.zero(it.quantity.unit);
          returnedMap[it.purchaseReceiptItemId] = cur + it.quantity;
        }
      }

      // 3. فحص البنود وتطابق الكميات والتكلفة
      final returnItems = <SupplierReturnItem>[];

      for (int i = 0; i < command.items.length; i++) {
        final input = command.items[i];
        final receiptItem = receipt.items.firstWhere(
          (it) => it.purchaseItemId == input.purchaseReceiptItemId || it.productId == input.productId,
          orElse: () => throw InvalidSupplierReturnQuantityFailure(
            'البند ${input.purchaseReceiptItemId} غير مدرج في إيصال الاستلام.',
          ),
        );

        final alreadyRet = returnedMap[input.purchaseReceiptItemId] ?? StockQuantity.zero(input.quantity.unit);

        final validation = ReturnRules.validateSupplierReturnQuantity(
          receivedQuantity: receiptItem.quantityReceived,
          alreadyReturnedQuantity: alreadyRet,
          requestedQuantity: input.quantity,
        );

        if (!validation.isAllowed) {
          throw InvalidSupplierReturnQuantityFailure(validation.reason!);
        }

        returnItems.add(SupplierReturnItem(
          id: 'SUP-RET-ITM-${command.commandId}-${i + 1}',
          purchaseReceiptItemId: input.purchaseReceiptItemId,
          productId: input.productId,
          variantId: input.variantId,
          quantity: input.quantity,
          unitCost: receiptItem.unitCost,
          reason: input.reason,
        ));
      }

      final supplierReturn = SupplierReturn(
        id: command.commandId,
        businessId: command.businessId,
        branchId: command.branchId,
        supplierId: command.supplierId,
        originalPurchaseId: command.originalPurchaseId,
        originalReceiptId: command.originalReceiptId,
        returnNumber: command.returnNumber,
        status: SupplierReturnStatus.draft,
        items: returnItems,
        currency: returnItems.first.unitCost.currency,
        reason: command.reason,
        actorId: command.actorId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        idempotencyKey: command.idempotencyKey,
      );

      await _supplierReturnRepo.saveSupplierReturn(supplierReturn);

      await _auditRepo.recordAuditEntry(ShopAuditEntry(
        auditId: 'AUD-SUP-RET-C-${DateTime.now().microsecondsSinceEpoch}',
        businessId: command.businessId,
        branchId: command.branchId,
        userId: command.actorId,
        userName: 'Staff Actor',
        terminalId: command.terminalId ?? 'SERVER',
        action: ShopAuditAction.supplierReturn,
        referenceId: supplierReturn.id,
        timestamp: DateTime.now(),
        metadata: {
          'supplierId': command.supplierId,
          'totalAmount': supplierReturn.totalAmount.toAmount(),
        },
      ));

      _eventSink?.call(SupplierReturnCreatedEvent(
        eventId: 'EVT-SUP-RET-C-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: DateTime.now(),
        supplierReturn: supplierReturn,
        actorId: command.actorId,
      ));

      final result = SupplierReturnOperationResult(
        isSuccess: true,
        supplierReturn: supplierReturn,
        message: 'تم إنشاء أمر مرتجع المورد بنجاح.',
      );

      await _idempotencyStore.saveResult(command.idempotencyKey, result);
      return result;
    } finally {
      _releaseLock(lockKey);
    }
  }

  /// اعتماد مرتجع المشتريات وإصدار إشعار الدائن وخصم المخزون
  Future<SupplierReturnOperationResult> approveSupplierReturn(
    ApproveSupplierReturnCommand command,
  ) async {
    _assertBusinessMatches(command.businessId);
    _assertHasPermission(ShopPermission.approveSupplierReturn);

    final lockKey = 'lock:supplier_return:${command.supplierReturnId}';
    await _acquireLock(lockKey);

    try {
      final supplierReturn = await _supplierReturnRepo.getSupplierReturnById(
        businessId: command.businessId,
        supplierReturnId: command.supplierReturnId,
      );
      if (supplierReturn == null) throw const SupplierReturnNotFoundFailure();

      if (supplierReturn.status != SupplierReturnStatus.draft) {
        throw const InvalidSupplierReturnQuantityFailure('لا يمكن اعتماد أمر مرتجع تم تنفيذه مسبقاً أو ملغى.');
      }

      // 1. خصم بضاعة المرتجع من مخزون S3 عبر حركة supplierReturn
      for (final item in supplierReturn.items) {
        await _inventoryTxService.applyMovement(ApplyInventoryMovementCommand(
          commandId: 'MOV-SUP-RET-${supplierReturn.id}-${item.id}',
          businessId: supplierReturn.businessId,
          branchId: supplierReturn.branchId,
          productId: item.productId,
          variantId: item.variantId,
          movementType: InventoryMovementType.supplierReturn,
          quantity: item.quantity,
          referenceType: 'SUPPLIER_RETURN',
          referenceId: supplierReturn.id,
          reason: 'إرجاع بضاعة للمورد بموجب أمر الإرجاع #${supplierReturn.returnNumber}',
          actorId: command.actorId,
          idempotencyKey: 'IDEM-INV-SUP-RET-${supplierReturn.id}-${item.id}',
        ));
      }

      // 2. إنشاء إشعار دائن من المورد (Credit Note)
      final creditNote = SupplierCreditNote(
        id: 'CN-${supplierReturn.id}',
        businessId: supplierReturn.businessId,
        supplierId: supplierReturn.supplierId,
        supplierReturnId: supplierReturn.id,
        creditNoteNumber: 'CN-NUM-${supplierReturn.returnNumber}',
        amount: supplierReturn.totalAmount,
        reason: 'إشعار دائن بموجب مرتجع بضاعة للمورد #${supplierReturn.returnNumber}',
        createdAt: DateTime.now(),
        actorId: command.actorId,
        idempotencyKey: 'IDEM-CN-${supplierReturn.id}',
      );

      await _supplierCreditNoteRepo.saveCreditNote(creditNote);

      // 3. قيد في دفتر أستاذ المورد S4 يخفض الذمة الدائنة (Credit Note Entry)
      final currentAccount = await _supplierRepo.getSupplierAccount(
        businessId: supplierReturn.businessId,
        supplierId: supplierReturn.supplierId,
      );
      final prevBalance = currentAccount?.currentBalance ?? Money.zero(creditNote.amount.currency);
      final newBalance = prevBalance - creditNote.amount;

      final ledgerEntry = SupplierLedgerEntry(
        id: 'LED-CN-${creditNote.id}',
        businessId: supplierReturn.businessId,
        supplierId: supplierReturn.supplierId,
        referenceType: 'SUPPLIER_CREDIT_NOTE',
        referenceId: creditNote.id,
        entryType: SupplierLedgerEntryType.creditNote,
        debit: creditNote.amount, // يخفض ذمة المورد
        credit: Money.zero(creditNote.amount.currency),
        balanceDelta: -creditNote.amount,
        balanceAfter: newBalance,
        currency: creditNote.amount.currency,
        actorId: command.actorId,
        createdAt: DateTime.now(),
        version: (currentAccount?.version ?? 0) + 1,
        idempotencyKey: 'IDEM-LED-CN-${creditNote.id}',
      );

      await _supplierLedgerRepo.appendEntry(ledgerEntry);

      if (currentAccount != null) {
        await _supplierRepo.saveSupplierAccount(currentAccount.copyWith(
          currentBalance: newBalance,
          version: currentAccount.version + 1,
          updatedAt: DateTime.now(),
        ));
      }

      // 4. تحديث حالة أمر المرتجع إلى COMPLETED
      final completed = supplierReturn.copyWith(
        status: SupplierReturnStatus.completed,
        updatedAt: DateTime.now(),
        version: supplierReturn.version + 1,
      );

      await _supplierReturnRepo.saveSupplierReturn(completed);

      await _auditRepo.recordAuditEntry(ShopAuditEntry(
        auditId: 'AUD-CN-CREATE-${DateTime.now().microsecondsSinceEpoch}',
        businessId: command.businessId,
        branchId: completed.branchId,
        userId: command.actorId,
        userName: 'Approver Actor',
        terminalId: 'SERVER',
        action: ShopAuditAction.creditNoteCreated,
        referenceId: creditNote.id,
        timestamp: DateTime.now(),
        metadata: {
          'supplierId': supplierReturn.supplierId,
          'creditNoteAmount': creditNote.amount.toAmount(),
        },
      ));

      _eventSink?.call(SupplierReturnCompletedEvent(
        eventId: 'EVT-SUP-RET-CMP-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: DateTime.now(),
        supplierReturn: completed,
        actorId: command.actorId,
      ));

      return SupplierReturnOperationResult(
        isSuccess: true,
        supplierReturn: completed,
        creditNote: creditNote,
        message: 'تم اعتماد مرتجع المورد وإصدار إشعار الدائن وخصم المخزون بنجاح.',
      );
    } finally {
      _releaseLock(lockKey);
    }
  }
}
