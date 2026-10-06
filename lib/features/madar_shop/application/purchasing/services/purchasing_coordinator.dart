// منسق ومحرك عمليات المشتريات والموردين والمدفوعات (MADAR SHOP Purchasing Coordinator)
// Pure Dart — Zero UI Dependencies

import 'dart:async';

import '../../../domain/audit/contracts/shop_audit_repository.dart';
import '../../../domain/audit/entities/shop_audit_entry.dart';
import '../../../domain/identity/rbac/shop_permission.dart';
import '../../../domain/inventory/value_objects/stock_quantity.dart';
import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/purchasing/entities/purchase_item.dart';
import '../../../domain/purchasing/entities/purchase_order.dart';
import '../../../domain/purchasing/entities/purchase_receipt.dart';
import '../../../domain/purchasing/entities/purchase_receipt_item.dart';
import '../../../domain/purchasing/entities/supplier.dart';
import '../../../domain/purchasing/entities/supplier_account.dart';
import '../../../domain/purchasing/entities/supplier_ledger_entry.dart';
import '../../../domain/purchasing/entities/supplier_payment.dart';
import '../../../domain/purchasing/enums/purchase_order_status.dart';
import '../../../domain/purchasing/enums/supplier_ledger_entry_type.dart';
import '../../../domain/purchasing/enums/supplier_status.dart';
import '../../../domain/purchasing/repositories/i_purchase_order_repository.dart';
import '../../../domain/purchasing/repositories/i_purchase_receipt_repository.dart';
import '../../../domain/purchasing/repositories/i_purchasing_idempotency_store.dart';
import '../../../domain/purchasing/repositories/i_supplier_ledger_repository.dart';
import '../../../domain/purchasing/repositories/i_supplier_payment_repository.dart';
import '../../../domain/purchasing/repositories/i_supplier_repository.dart';
import '../../../domain/purchasing/rules/purchase_order_state_machine.dart';
import '../../../domain/purchasing/rules/purchasing_rules.dart';
import '../../../domain/purchasing/value_objects/cost_snapshot.dart';
import '../../inventory/commands/inventory_commands.dart';
import '../../inventory/services/inventory_transaction_service.dart';
import '../../shop_identity_coordinator.dart';
import '../commands/purchasing_commands.dart';
import '../events/purchasing_domain_events.dart';
import '../failures/purchasing_failures.dart';
import '../results/purchasing_operation_result.dart';

typedef PurchasingEventSink = void Function(PurchasingDomainEvent);

class PurchasingCoordinator {
  final ISupplierRepository _supplierRepo;
  final ISupplierLedgerRepository _supplierLedgerRepo;
  final IPurchaseOrderRepository _purchaseOrderRepo;
  final IPurchaseReceiptRepository _purchaseReceiptRepo;
  final ISupplierPaymentRepository _supplierPaymentRepo;
  final IPurchasingIdempotencyStore _idempotencyStore;
  final InventoryTransactionService _inventoryService;
  final ShopIdentityCoordinator _identityCoordinator;
  final IShopAuditRepository _auditRepo;
  final PurchasingEventSink? _eventSink;

  static int _seq = 0;
  final Map<String, Completer<void>> _locks = {};

  PurchasingCoordinator({
    required ISupplierRepository supplierRepository,
    required ISupplierLedgerRepository supplierLedgerRepository,
    required IPurchaseOrderRepository purchaseOrderRepository,
    required IPurchaseReceiptRepository purchaseReceiptRepository,
    required ISupplierPaymentRepository supplierPaymentRepository,
    required IPurchasingIdempotencyStore idempotencyStore,
    required InventoryTransactionService inventoryService,
    required ShopIdentityCoordinator identityCoordinator,
    required IShopAuditRepository auditRepository,
    PurchasingEventSink? eventSink,
  })  : _supplierRepo = supplierRepository,
        _supplierLedgerRepo = supplierLedgerRepository,
        _purchaseOrderRepo = purchaseOrderRepository,
        _purchaseReceiptRepo = purchaseReceiptRepository,
        _supplierPaymentRepo = supplierPaymentRepository,
        _idempotencyStore = idempotencyStore,
        _inventoryService = inventoryService,
        _identityCoordinator = identityCoordinator,
        _auditRepo = auditRepository,
        _eventSink = eventSink;

  // ─── إدارة الموردين (Suppliers) ───

  /// إنشاء مورد جديد مع فتح حسابه المالي
  Future<SupplierOperationResult> createSupplier(CreateSupplierCommand command) async {
    _assertBusinessMatches(command.businessId);
    _assertHasPermission(ShopPermission.createSupplier);

    if (await _idempotencyStore.hasKey(command.idempotencyKey)) {
      final cached = await _idempotencyStore.getResult(command.idempotencyKey);
      if (cached is SupplierOperationResult) return cached;
    }

    final supplier = Supplier(
      id: command.commandId,
      businessId: command.businessId,
      name: command.name.trim(),
      phone: command.phone.trim(),
      email: command.email?.trim(),
      address: command.address?.trim(),
      taxId: command.taxId?.trim(),
      status: SupplierStatus.active,
      createdAt: command.createdAt,
      updatedAt: command.createdAt,
    );

    final account = SupplierAccount.initial(
      supplierId: supplier.id,
      businessId: command.businessId,
    );

    await _supplierRepo.saveSupplier(supplier);
    await _supplierRepo.saveSupplierAccount(account);

    await _auditRepo.recordAuditEntry(ShopAuditEntry(
      auditId: 'AUD-SUP-CREATE-${DateTime.now().microsecondsSinceEpoch}',
      businessId: command.businessId,
      branchId: 'MAIN',
      userId: command.actorId,
      userName: 'Staff Actor',
      terminalId: 'SERVER',
      action: ShopAuditAction.supplierCreated,
      referenceId: supplier.id,
      timestamp: command.createdAt,
      metadata: {'name': supplier.name, 'phone': supplier.phone},
    ));

    final result = SupplierOperationResult(
      isSuccess: true,
      supplier: supplier,
      account: account,
      message: 'تم تسجيل المورد وحسابه بنجاح.',
    );

    await _idempotencyStore.recordKey(
      idempotencyKey: command.idempotencyKey,
      result: result,
    );

    return result;
  }

  /// تحديث بيانات مورد
  Future<SupplierOperationResult> updateSupplier(UpdateSupplierCommand command) async {
    _assertBusinessMatches(command.businessId);
    _assertHasPermission(ShopPermission.editSupplier);

    final supplier = await _supplierRepo.getSupplierById(
      businessId: command.businessId,
      supplierId: command.supplierId,
    );

    if (supplier == null) {
      throw const SupplierNotFoundFailure();
    }

    final updated = supplier.copyWith(
      name: command.name,
      phone: command.phone,
      email: command.email,
      address: command.address,
      taxId: command.taxId,
      status: command.status,
      updatedAt: command.updatedAt,
    );

    await _supplierRepo.saveSupplier(updated);

    final account = await _supplierRepo.getSupplierAccount(
      businessId: command.businessId,
      supplierId: command.supplierId,
    );

    await _auditRepo.recordAuditEntry(ShopAuditEntry(
      auditId: 'AUD-SUP-UPDATE-${DateTime.now().microsecondsSinceEpoch}',
      businessId: command.businessId,
      branchId: 'MAIN',
      userId: command.actorId,
      userName: 'Staff Actor',
      terminalId: 'SERVER',
      action: ShopAuditAction.supplierUpdated,
      referenceId: updated.id,
      timestamp: command.updatedAt,
    ));

    return SupplierOperationResult(
      isSuccess: true,
      supplier: updated,
      account: account,
      message: 'تم تحديث بيانات المورد.',
    );
  }

  /// حظر مورد من التعامل التجاري
  Future<SupplierOperationResult> blockSupplier(BlockSupplierCommand command) async {
    _assertBusinessMatches(command.businessId);
    _assertHasPermission(ShopPermission.blockSupplier);

    final supplier = await _supplierRepo.getSupplierById(
      businessId: command.businessId,
      supplierId: command.supplierId,
    );

    if (supplier == null) {
      throw const SupplierNotFoundFailure();
    }

    final blocked = supplier.copyWith(
      status: SupplierStatus.blocked,
      updatedAt: command.blockedAt,
      metadata: {...supplier.metadata, 'blockReason': command.reason},
    );

    await _supplierRepo.saveSupplier(blocked);

    await _auditRepo.recordAuditEntry(ShopAuditEntry(
      auditId: 'AUD-SUP-BLOCK-${DateTime.now().microsecondsSinceEpoch}',
      businessId: command.businessId,
      branchId: 'MAIN',
      userId: command.actorId,
      userName: 'Staff Actor',
      terminalId: 'SERVER',
      action: ShopAuditAction.supplierBlocked,
      referenceId: blocked.id,
      timestamp: command.blockedAt,
      metadata: {'reason': command.reason},
    ));

    return SupplierOperationResult(
      isSuccess: true,
      supplier: blocked,
      message: 'تم حظر المورد بنجاح.',
    );
  }

  // ─── أوامر الشراء (Purchase Orders) ───

  /// إنشاء أمر شراء جديد بحالة مسودة (DRAFT)
  Future<PurchaseOrderOperationResult> createPurchaseOrder(CreatePurchaseOrderCommand command) async {
    _assertBusinessMatches(command.businessId);
    _assertBranchMatches(command.branchId);
    _assertHasPermission(ShopPermission.createPurchase);

    if (await _idempotencyStore.hasKey(command.idempotencyKey)) {
      final cached = await _idempotencyStore.getResult(command.idempotencyKey);
      if (cached is PurchaseOrderOperationResult) return cached;
    }

    if (command.items.isEmpty) {
      throw const InvalidPurchaseQuantityFailure('لا يمكن إنشاء أمر شراء بدون بنود.');
    }

    final supplier = await _supplierRepo.getSupplierById(
      businessId: command.businessId,
      supplierId: command.supplierId,
    );
    if (supplier == null) {
      throw const SupplierNotFoundFailure();
    }

    final eligibility = PurchasingRules.validateSupplierEligibility(supplier);
    if (!eligibility.isAllowed) {
      if (supplier.isBlocked) throw const SupplierBlockedFailure();
      throw const SupplierInactiveFailure();
    }

    final purchaseItems = <PurchaseItem>[];
    for (int i = 0; i < command.items.length; i++) {
      final input = command.items[i];
      if (input.quantity.isZero || input.quantity.isNegative) {
        throw const InvalidPurchaseQuantityFailure('كمية أمر الشراء يجب أن تكون موجبة.');
      }
      if (input.unitCost.isNegative) {
        throw const InvalidPurchaseCostFailure('تكلفة الوحدة لا يمكن أن تكون سالبة.');
      }

      final costSnapshot = CostSnapshot(
        unitCost: input.unitCost,
        discountPerUnit: (input.discount != null && !input.quantity.isZero)
            ? input.discount! * (1 / input.quantity.toDouble())
            : Money.zero(input.unitCost.currency),
        taxPerUnit: (input.tax != null && !input.quantity.isZero)
            ? input.tax! * (1 / input.quantity.toDouble())
            : Money.zero(input.unitCost.currency),
        effectiveAt: command.createdAt,
      );

      purchaseItems.add(PurchaseItem(
        id: 'PI-${command.commandId}-${i + 1}',
        productId: input.productId,
        variantId: input.variantId,
        descriptionSnapshot: input.description,
        skuSnapshot: input.sku,
        barcodeSnapshot: input.barcode,
        quantityOrdered: input.quantity,
        unit: input.unit,
        unitCost: input.unitCost,
        discount: input.discount,
        tax: input.tax,
        costSnapshot: costSnapshot,
      ));
    }

    final order = PurchaseOrder(
      id: command.commandId,
      businessId: command.businessId,
      branchId: command.branchId,
      supplierId: command.supplierId,
      orderNumber: command.orderNumber,
      status: PurchaseOrderStatus.draft,
      items: purchaseItems,
      currency: command.currency,
      createdBy: command.actorId,
      createdAt: command.createdAt,
      updatedAt: command.createdAt,
      version: 1,
      idempotencyKey: command.idempotencyKey,
      notes: command.notes,
    );

    await _purchaseOrderRepo.savePurchaseOrder(order);

    await _auditRepo.recordAuditEntry(ShopAuditEntry(
      auditId: 'AUD-PO-CREATE-${DateTime.now().microsecondsSinceEpoch}',
      businessId: command.businessId,
      branchId: command.branchId,
      userId: command.actorId,
      userName: 'Staff Actor',
      terminalId: command.terminalId ?? 'SERVER',
      action: ShopAuditAction.purchaseCreated,
      referenceId: order.id,
      timestamp: command.createdAt,
      metadata: {'orderNumber': order.orderNumber, 'grandTotal': order.grandTotal.toString()},
    ));

    _eventSink?.call(PurchaseCreatedEvent(
      eventId: 'EVT-PO-CREATE-${DateTime.now().microsecondsSinceEpoch}',
      occurredAt: command.createdAt,
      order: order,
    ));

    final result = PurchaseOrderOperationResult(
      isSuccess: true,
      order: order,
      message: 'تم إنشاء أمر الشراء بنجاح.',
    );

    await _idempotencyStore.recordKey(
      idempotencyKey: command.idempotencyKey,
      result: result,
    );

    return result;
  }

  /// تقديم أمر الشراء للاعتماد (SUBMIT)
  Future<PurchaseOrderOperationResult> submitPurchaseOrder(SubmitPurchaseOrderCommand command) async {
    _assertBusinessMatches(command.businessId);
    _assertHasPermission(ShopPermission.submitPurchase);

    final lockKey = 'PO:${command.purchaseOrderId}';
    await _acquireLock(lockKey);

    try {
      final order = await _purchaseOrderRepo.getPurchaseOrderById(
        businessId: command.businessId,
        purchaseOrderId: command.purchaseOrderId,
      );
      if (order == null) throw const PurchaseOrderNotFoundFailure();

      final validation = PurchaseOrderStateMachine.validateTransition(
        currentStatus: order.status,
        nextStatus: PurchaseOrderStatus.submitted,
      );
      if (!validation.isAllowed) {
        throw InvalidPurchaseStateTransitionFailure(validation.rejectionReason!);
      }

      final updated = order.copyWith(
        status: PurchaseOrderStatus.submitted,
        version: order.version + 1,
        updatedAt: command.submittedAt,
      );

      await _purchaseOrderRepo.savePurchaseOrder(updated);

      await _auditRepo.recordAuditEntry(ShopAuditEntry(
        auditId: 'AUD-PO-SUBMIT-${DateTime.now().microsecondsSinceEpoch}',
        businessId: command.businessId,
        branchId: order.branchId,
        userId: command.actorId,
        userName: 'Staff Actor',
        terminalId: 'SERVER',
        action: ShopAuditAction.purchaseSubmitted,
        referenceId: updated.id,
        timestamp: command.submittedAt,
      ));

      _eventSink?.call(PurchaseSubmittedEvent(
        eventId: 'EVT-PO-SUBMIT-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: command.submittedAt,
        order: updated,
      ));

      return PurchaseOrderOperationResult(isSuccess: true, order: updated);
    } finally {
      _releaseLock(lockKey);
    }
  }

  /// اعتماد أمر الشراء (APPROVE)
  Future<PurchaseOrderOperationResult> approvePurchaseOrder(ApprovePurchaseOrderCommand command) async {
    _assertBusinessMatches(command.businessId);
    _assertHasPermission(ShopPermission.approvePurchase);

    final lockKey = 'PO:${command.purchaseOrderId}';
    await _acquireLock(lockKey);

    try {
      final order = await _purchaseOrderRepo.getPurchaseOrderById(
        businessId: command.businessId,
        purchaseOrderId: command.purchaseOrderId,
      );
      if (order == null) throw const PurchaseOrderNotFoundFailure();

      // التحقق من أهلية المورد عند الاعتماد
      final supplier = await _supplierRepo.getSupplierById(
        businessId: command.businessId,
        supplierId: order.supplierId,
      );
      if (supplier == null) throw const SupplierNotFoundFailure();
      final eligibility = PurchasingRules.validateSupplierEligibility(supplier);
      if (!eligibility.isAllowed) {
        if (supplier.isBlocked) throw const SupplierBlockedFailure();
        throw const SupplierInactiveFailure();
      }

      final validation = PurchaseOrderStateMachine.validateTransition(
        currentStatus: order.status,
        nextStatus: PurchaseOrderStatus.approved,
      );
      if (!validation.isAllowed) {
        throw InvalidPurchaseStateTransitionFailure(validation.rejectionReason!);
      }

      final updated = order.copyWith(
        status: PurchaseOrderStatus.approved,
        approvedBy: command.actorId,
        version: order.version + 1,
        updatedAt: command.approvedAt,
      );

      await _purchaseOrderRepo.savePurchaseOrder(updated);

      await _auditRepo.recordAuditEntry(ShopAuditEntry(
        auditId: 'AUD-PO-APPROVE-${DateTime.now().microsecondsSinceEpoch}',
        businessId: command.businessId,
        branchId: order.branchId,
        userId: command.actorId,
        userName: 'Staff Actor',
        terminalId: 'SERVER',
        action: ShopAuditAction.purchaseApproved,
        referenceId: updated.id,
        timestamp: command.approvedAt,
        metadata: {'approvedBy': command.actorId},
      ));

      _eventSink?.call(PurchaseApprovedEvent(
        eventId: 'EVT-PO-APPROVE-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: command.approvedAt,
        order: updated,
        approvedBy: command.actorId,
      ));

      return PurchaseOrderOperationResult(isSuccess: true, order: updated);
    } finally {
      _releaseLock(lockKey);
    }
  }

  // ─── استلام البضاعة وربط المخزون ودفتر المورد الذري ───

  /// استلام بضاعة أمر الشراء (كلي أو جزئي) مع الربط الإلزامي بمخزون S3 وسجل المورد
  Future<ReceiveGoodsOperationResult> receiveGoods(ReceiveGoodsCommand command) async {
    _assertBusinessMatches(command.businessId);
    _assertBranchMatches(command.branchId);
    _assertHasPermission(ShopPermission.receivePurchasedGoods);

    // تفادي تكرار الاستلام Idempotency Replay Protection
    if (await _idempotencyStore.hasKey(command.idempotencyKey)) {
      _eventSink?.call(DuplicateReceiveDetectedEvent(
        eventId: 'EVT-DUP-REC-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: DateTime.now(),
        businessId: command.businessId,
        purchaseOrderId: command.purchaseOrderId,
        idempotencyKey: command.idempotencyKey,
      ));
      final cached = await _idempotencyStore.getResult(command.idempotencyKey);
      if (cached is ReceiveGoodsOperationResult) return cached;
    }

    final lockKey = 'PO:${command.purchaseOrderId}';
    await _acquireLock(lockKey);

    try {
      final order = await _purchaseOrderRepo.getPurchaseOrderById(
        businessId: command.businessId,
        purchaseOrderId: command.purchaseOrderId,
      );
      if (order == null) throw const PurchaseOrderNotFoundFailure();

      if (order.branchId != command.branchId) {
        throw const PurchasingBranchMismatchFailure(
          'لا يمكن استلام بضاعة أمر شراء مسند لفرع آخر دون أمر تحويل رسمي.',
        );
      }

      if (!order.status.canReceive) {
        throw InvalidPurchaseStateTransitionFailure(
          'أمر الشراء بحالة (${order.status.name})؛ لا يمكن استلام بضاعة إلا للأوامر المعتمدة (APPROVED) أو المستلمة جزئياً (PARTIALLY_RECEIVED).',
        );
      }

      if (command.items.isEmpty) {
        throw const InvalidPurchaseQuantityFailure('لا توجد أصناف للاستلام.');
      }

      // 1. فحص الكميات مقابل المتبقي بالبنود
      final receiptItems = <PurchaseReceiptItem>[];
      final updatedOrderItems = <PurchaseItem>[...order.items];

      for (final receiveInput in command.items) {
        final itemIndex = updatedOrderItems.indexWhere(
          (item) =>
              item.id == receiveInput.purchaseItemId ||
              (item.productId == receiveInput.productId && item.variantId == receiveInput.variantId),
        );

        if (itemIndex == -1) {
          throw InvalidPurchaseQuantityFailure(
            'الصنف ${receiveInput.productId} غير مدرج في أمر الشراء هذا.',
          );
        }

        final currentItem = updatedOrderItems[itemIndex];
        final remaining = currentItem.remainingQuantity;

        final qtyCheck = PurchasingRules.validateReceivingQuantity(
          requestedQuantity: receiveInput.quantityToReceive,
          remainingQuantity: remaining,
          policy: command.policy,
          hasApproval: command.hasOverReceivingApproval,
        );

        if (!qtyCheck.isAllowed) {
          throw OverReceivingBlockedFailure(qtyCheck.rejectionReason!);
        }

        // تجميد التكلفة Snapshot
        final effectiveUnitCost = receiveInput.overrideUnitCost ?? currentItem.unitCost;

        receiptItems.add(PurchaseReceiptItem(
          purchaseItemId: currentItem.id,
          productId: currentItem.productId,
          variantId: currentItem.variantId,
          quantityReceived: receiveInput.quantityToReceive,
          unit: currentItem.unit,
          unitCost: effectiveUnitCost,
          batchId: receiveInput.batchId,
          lotNumber: receiveInput.lotNumber,
          expiryDate: receiveInput.expiryDate,
        ));

        // تحديث البند داخل أمر الشراء
        final newReceived = currentItem.quantityReceived + receiveInput.quantityToReceive;
        updatedOrderItems[itemIndex] = currentItem.copyWith(
          quantityReceived: newReceived,
        );
      }

      // 2. ترحيل البضاعة إلى محرك المخزون S3 بشكل إلزامي وحصري
      for (final rItem in receiptItems) {
        final s3ReceiveCmd = ReceivePurchaseCommand(
          commandId: 'S3-REC-${command.commandId}-${rItem.purchaseItemId}',
          businessId: command.businessId,
          branchId: command.branchId,
          productId: rItem.productId,
          variantId: rItem.variantId,
          quantity: rItem.quantityReceived,
          purchaseOrderId: order.id,
          supplierId: order.supplierId,
          unitCost: rItem.unitCost.toAmount(),
          actorId: command.actorId,
          idempotencyKey: 'IDEM-S3-REC-${command.idempotencyKey}-${rItem.purchaseItemId}',
        );

        final s3Result = await _inventoryService.receivePurchase(s3ReceiveCmd);
        if (!s3Result.isSuccess) {
          throw PurchasingConflictFailure(
            'أخفق محرك المخزون S3 في تسجيل حركة التوريد للصنف ${rItem.productId}: ${s3Result.message}',
          );
        }
      }

      // 3. بناء وحفظ إيصال الاستلام PurchaseReceipt
      final receipt = PurchaseReceipt(
        id: 'REC-${command.commandId}',
        businessId: command.businessId,
        branchId: command.branchId,
        purchaseOrderId: order.id,
        supplierId: order.supplierId,
        items: receiptItems,
        receivedBy: command.actorId,
        receivedAt: command.receivedAt,
        reference: command.reference,
        idempotencyKey: command.idempotencyKey,
        notes: command.notes,
      );
      await _purchaseReceiptRepo.saveReceipt(receipt);

      // 4. تسجيل قيد دائن في دفتر أستاذ المورد (Supplier Ledger) لزيادة رصيد التزامه المالي (Accounts Payable)
      SupplierLedgerEntry? ledgerEntry;
      if (!receipt.totalCost.isZero) {
        final account = (await _supplierRepo.getSupplierAccount(
              businessId: command.businessId,
              supplierId: order.supplierId,
            )) ??
            SupplierAccount.initial(
              supplierId: order.supplierId,
              businessId: command.businessId,
              currency: receipt.totalCost.currency,
            );

        final beforeBalance = account.currentBalance;
        final balanceDelta = receipt.totalCost; // مدين/دائن: شراء بضاعة يزيد الالتزام المالي للمورد
        final afterBalance = beforeBalance + balanceDelta;

        ledgerEntry = SupplierLedgerEntry(
          id: 'LEDGER-REC-${DateTime.now().microsecondsSinceEpoch}-${++_seq}',
          businessId: command.businessId,
          supplierId: order.supplierId,
          referenceType: 'PURCHASE_RECEIPT',
          referenceId: receipt.id,
          entryType: SupplierLedgerEntryType.purchase,
          debit: Money.zero(receipt.totalCost.currency),
          credit: receipt.totalCost,
          balanceDelta: balanceDelta,
          balanceAfter: afterBalance,
          currency: receipt.totalCost.currency,
          actorId: command.actorId,
          createdAt: command.receivedAt,
          version: account.version + 1,
          idempotencyKey: 'IDEM-LEDGER-REC-${command.idempotencyKey}',
          description: 'استلام بضاعة بموجب إيصال #${receipt.id} لأمر الشراء #${order.orderNumber}',
        );

        await _supplierLedgerRepo.appendEntry(ledgerEntry);

        final updatedAccount = account.copyWith(
          currentBalance: afterBalance,
          version: account.version + 1,
          updatedAt: command.receivedAt,
        );
        await _supplierRepo.saveSupplierAccount(updatedAccount);

        _eventSink?.call(SupplierBalanceChangedEvent(
          eventId: 'EVT-SUP-BAL-${DateTime.now().microsecondsSinceEpoch}',
          occurredAt: command.receivedAt,
          supplierId: order.supplierId,
          businessId: command.businessId,
          ledgerEntry: ledgerEntry,
        ));
      }

      // 5. تحديد حالة أمر الشراء المحدثة
      final isFullyReceived = updatedOrderItems.every((i) => i.isFullyReceived);
      final nextStatus = isFullyReceived
          ? PurchaseOrderStatus.received
          : PurchaseOrderStatus.partiallyReceived;

      final updatedOrder = order.copyWith(
        status: nextStatus,
        items: updatedOrderItems,
        version: order.version + 1,
        updatedAt: command.receivedAt,
      );
      await _purchaseOrderRepo.savePurchaseOrder(updatedOrder);

      // 6. تدقيق العملية وإرسال الأحداث
      await _auditRepo.recordAuditEntry(ShopAuditEntry(
        auditId: 'AUD-PO-RECEIVE-${DateTime.now().microsecondsSinceEpoch}',
        businessId: command.businessId,
        branchId: command.branchId,
        userId: command.actorId,
        userName: 'Staff Actor',
        terminalId: command.terminalId ?? 'SERVER',
        action: ShopAuditAction.purchaseReceived,
        referenceId: receipt.id,
        timestamp: command.receivedAt,
        metadata: {
          'purchaseOrderId': order.id,
          'totalCost': receipt.totalCost.toString(),
          'status': nextStatus.name,
        },
      ));

      if (isFullyReceived) {
        _eventSink?.call(PurchaseReceivedEvent(
          eventId: 'EVT-PO-REC-${DateTime.now().microsecondsSinceEpoch}',
          occurredAt: command.receivedAt,
          order: updatedOrder,
          receipt: receipt,
        ));
      } else {
        _eventSink?.call(PurchasePartiallyReceivedEvent(
          eventId: 'EVT-PO-PART-REC-${DateTime.now().microsecondsSinceEpoch}',
          occurredAt: command.receivedAt,
          order: updatedOrder,
          receipt: receipt,
        ));
      }

      final result = ReceiveGoodsOperationResult(
        isSuccess: true,
        order: updatedOrder,
        receipt: receipt,
        ledgerEntry: ledgerEntry,
        message: isFullyReceived ? 'تم استلام كامل أمر الشراء.' : 'تم استلام الدفعة الجزئية بنجاح.',
      );

      await _idempotencyStore.recordKey(
        idempotencyKey: command.idempotencyKey,
        result: result,
      );

      return result;
    } finally {
      _releaseLock(lockKey);
    }
  }

  // ─── إلغاء أوامر الشراء (Cancellation) ───

  /// إلغاء أمر الشراء مع مراعاة الحالة والبضائع المستلمة
  Future<PurchaseOrderOperationResult> cancelPurchaseOrder(CancelPurchaseOrderCommand command) async {
    _assertBusinessMatches(command.businessId);
    _assertHasPermission(ShopPermission.cancelPurchase);

    final lockKey = 'PO:${command.purchaseOrderId}';
    await _acquireLock(lockKey);

    try {
      final order = await _purchaseOrderRepo.getPurchaseOrderById(
        businessId: command.businessId,
        purchaseOrderId: command.purchaseOrderId,
      );
      if (order == null) throw const PurchaseOrderNotFoundFailure();

      if (order.status.isTerminal) {
        throw InvalidPurchaseStateTransitionFailure(
          'أمر الشراء بحالة نهائية (${order.status.name})؛ لا يمكن إلغاؤه.',
        );
      }

      // إذا تم استلام بضائع جزئياً
      if (order.status == PurchaseOrderStatus.partiallyReceived) {
        if (!command.cancelRemainingOnly) {
          throw const InvalidPurchaseStateTransitionFailure(
            'تم استلام بضائع جزئياً بالفعل بموجب هذا الأمر. لا يمكن إلغاؤه بالكامل؛ يمكنك فقط إلغاء الكميات المتبقية وإغلاق الأمر.',
          );
        }

        // إغلاق الأمر مع حصر الكمية المطلوبة بالكمية المستلمة فعلياً
        final closedItems = order.items.map((item) {
          return item.copyWith(quantityOrdered: item.quantityReceived);
        }).toList();

        final closedOrder = order.copyWith(
          status: PurchaseOrderStatus.closed,
          items: closedItems,
          cancelledBy: command.actorId,
          cancellationReason: 'إلغاء الكميات المتبقية غير المستلمة: ${command.reason}',
          version: order.version + 1,
          updatedAt: command.cancelledAt,
        );

        await _purchaseOrderRepo.savePurchaseOrder(closedOrder);

        await _auditRepo.recordAuditEntry(ShopAuditEntry(
          auditId: 'AUD-PO-CANCEL-REM-${DateTime.now().microsecondsSinceEpoch}',
          businessId: command.businessId,
          branchId: order.branchId,
          userId: command.actorId,
          userName: 'Staff Actor',
          terminalId: 'SERVER',
          action: ShopAuditAction.purchaseCancelled,
          referenceId: closedOrder.id,
          timestamp: command.cancelledAt,
          metadata: {'reason': command.reason, 'cancelRemainingOnly': true},
        ));

        _eventSink?.call(PurchaseCancelledEvent(
          eventId: 'EVT-PO-CANCEL-${DateTime.now().microsecondsSinceEpoch}',
          occurredAt: command.cancelledAt,
          order: closedOrder,
          cancelledBy: command.actorId,
          reason: command.reason,
        ));

        return PurchaseOrderOperationResult(
          isSuccess: true,
          order: closedOrder,
          message: 'تم إلغاء الكميات المتبقية وإغلاق أمر الشراء بنجاح.',
        );
      }

      // التحقق من الانتقال للحالات الأخرى (DRAFT, SUBMITTED, APPROVED بدون استلام)
      final validation = PurchaseOrderStateMachine.validateTransition(
        currentStatus: order.status,
        nextStatus: PurchaseOrderStatus.cancelled,
        hasReceivedItems: order.hasAnyItemReceived,
      );

      if (!validation.isAllowed) {
        throw InvalidPurchaseStateTransitionFailure(validation.rejectionReason!);
      }

      final cancelledOrder = order.copyWith(
        status: PurchaseOrderStatus.cancelled,
        cancelledBy: command.actorId,
        cancellationReason: command.reason,
        version: order.version + 1,
        updatedAt: command.cancelledAt,
      );

      await _purchaseOrderRepo.savePurchaseOrder(cancelledOrder);

      await _auditRepo.recordAuditEntry(ShopAuditEntry(
        auditId: 'AUD-PO-CANCEL-${DateTime.now().microsecondsSinceEpoch}',
        businessId: command.businessId,
        branchId: order.branchId,
        userId: command.actorId,
        userName: 'Staff Actor',
        terminalId: 'SERVER',
        action: ShopAuditAction.purchaseCancelled,
        referenceId: cancelledOrder.id,
        timestamp: command.cancelledAt,
        metadata: {'reason': command.reason},
      ));

      _eventSink?.call(PurchaseCancelledEvent(
        eventId: 'EVT-PO-CANCEL-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: command.cancelledAt,
        order: cancelledOrder,
        cancelledBy: command.actorId,
        reason: command.reason,
      ));

      return PurchaseOrderOperationResult(
        isSuccess: true,
        order: cancelledOrder,
        message: 'تم إلغاء أمر الشراء بنجاح.',
      );
    } finally {
      _releaseLock(lockKey);
    }
  }

  // ─── سداد دفعات الموردين (Supplier Payments & Accounts Payable) ───

  /// سداد دفعة مالية للمورد وتخفيض الالتزام المالي مع تسجيل قيد ذري في دفتر الأستاذ
  Future<SupplierPaymentOperationResult> paySupplier(PaySupplierCommand command) async {
    _assertBusinessMatches(command.businessId);
    _assertHasPermission(ShopPermission.createSupplierPayment);

    if (await _idempotencyStore.hasKey(command.idempotencyKey)) {
      final cached = await _idempotencyStore.getResult(command.idempotencyKey);
      if (cached is SupplierPaymentOperationResult) return cached;
    }

    final lockKey = 'SUP:${command.supplierId}';
    await _acquireLock(lockKey);

    try {
      final supplier = await _supplierRepo.getSupplierById(
        businessId: command.businessId,
        supplierId: command.supplierId,
      );
      if (supplier == null) throw const SupplierNotFoundFailure();

      final account = (await _supplierRepo.getSupplierAccount(
            businessId: command.businessId,
            supplierId: command.supplierId,
          )) ??
          SupplierAccount.initial(
            supplierId: command.supplierId,
            businessId: command.businessId,
            currency: command.amount.currency,
          );

      // التحقق من صحة السداد مقابل الرصيد المستحق وسياسة السداد الزائد
      final paymentCheck = PurchasingRules.validateSupplierPayment(
        paymentAmount: command.amount,
        currentPayableBalance: account.currentBalance,
        policy: command.policy,
        hasApproval: command.hasOverpaymentApproval,
      );

      if (!paymentCheck.isAllowed) {
        throw SupplierOverpaymentBlockedFailure(paymentCheck.rejectionReason!);
      }

      // 1. إنشاء وحفظ كيان الدفعة
      final payment = SupplierPayment(
        id: command.commandId,
        supplierId: command.supplierId,
        businessId: command.businessId,
        amount: command.amount,
        currency: command.amount.currency,
        method: command.method,
        reference: command.reference,
        createdAt: command.paidAt,
        actorId: command.actorId,
        idempotencyKey: command.idempotencyKey,
        purchaseOrderId: command.purchaseOrderId,
        notes: command.notes,
      );
      await _supplierPaymentRepo.savePayment(payment);

      // 2. تسجيل قيد مدين في دفتر أستاذ الموردين (Supplier Ledger Debit)
      final beforeBalance = account.currentBalance;
      final balanceDelta = -command.amount; // السداد يخفض الالتزام المالي
      final afterBalance = beforeBalance - command.amount;

      final ledgerEntry = SupplierLedgerEntry(
        id: 'LEDGER-PAY-${DateTime.now().microsecondsSinceEpoch}-${++_seq}',
        businessId: command.businessId,
        supplierId: command.supplierId,
        referenceType: 'SUPPLIER_PAYMENT',
        referenceId: payment.id,
        entryType: SupplierLedgerEntryType.payment,
        debit: command.amount,
        credit: Money.zero(command.amount.currency),
        balanceDelta: balanceDelta,
        balanceAfter: afterBalance,
        currency: command.amount.currency,
        actorId: command.actorId,
        createdAt: command.paidAt,
        version: account.version + 1,
        idempotencyKey: command.idempotencyKey,
        description: 'سداد دفعة للمورد #${supplier.name}: ${command.reference ?? ""}',
      );

      await _supplierLedgerRepo.appendEntry(ledgerEntry);

      // 3. تحديث حساب المورد
      final updatedAccount = account.copyWith(
        currentBalance: afterBalance,
        version: account.version + 1,
        updatedAt: command.paidAt,
      );
      await _supplierRepo.saveSupplierAccount(updatedAccount);

      // 4. تدقيق العملية وإرسال الأحداث
      await _auditRepo.recordAuditEntry(ShopAuditEntry(
        auditId: 'AUD-SUP-PAY-${DateTime.now().microsecondsSinceEpoch}',
        businessId: command.businessId,
        branchId: 'MAIN',
        userId: command.actorId,
        userName: 'Staff Actor',
        terminalId: command.terminalId ?? 'SERVER',
        action: ShopAuditAction.supplierPaymentCompleted,
        referenceId: payment.id,
        timestamp: command.paidAt,
        metadata: {
          'supplierId': command.supplierId,
          'amount': command.amount.toString(),
          'remainingBalance': afterBalance.toString(),
        },
      ));

      _eventSink?.call(SupplierPaymentCompletedEvent(
        eventId: 'EVT-PAY-COMP-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: command.paidAt,
        payment: payment,
        ledgerEntry: ledgerEntry,
      ));

      _eventSink?.call(SupplierBalanceChangedEvent(
        eventId: 'EVT-SUP-BAL-PAY-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: command.paidAt,
        supplierId: command.supplierId,
        businessId: command.businessId,
        ledgerEntry: ledgerEntry,
      ));

      final result = SupplierPaymentOperationResult(
        isSuccess: true,
        payment: payment,
        ledgerEntry: ledgerEntry,
        updatedAccount: updatedAccount,
        message: 'تم سداد الدفعة وتحديث الرصيد المستحق بنجاح.',
      );

      await _idempotencyStore.recordKey(
        idempotencyKey: command.idempotencyKey,
        result: result,
      );

      return result;
    } finally {
      _releaseLock(lockKey);
    }
  }

  // ─── أدوات حماية الهوية والأمان والقفل المتزامن ───

  void _assertBusinessMatches(String businessId) {
    if (_identityCoordinator.isAuthenticated) {
      if (_identityCoordinator.currentUser?.businessId != businessId) {
        throw const PurchasingBusinessMismatchFailure(
          'تعارض في هوية النشاط التجاري: لا يمكن تنفيذ عمليات لنشاط تجاري آخر.',
        );
      }
    }
  }

  void _assertBranchMatches(String branchId) {
    if (_identityCoordinator.isAuthenticated) {
      if (!_identityCoordinator.canOperateOnActiveBranch(branchId)) {
        throw const PurchasingBranchMismatchFailure(
          'المستخدم الحالي لا يملك صلاحية تنفيذ عمليات على هذا الفرع.',
        );
      }
    }
  }

  void _assertHasPermission(ShopPermission permission) {
    if (_identityCoordinator.isAuthenticated) {
      if (!_identityCoordinator.hasPermission(permission)) {
        throw UnauthorizedPurchasingOperationFailure(
          'ليس لديك الصلاحية اللازمة: ${permission.name}',
        );
      }
    }
  }

  Future<void> _acquireLock(String key) async {
    while (_locks.containsKey(key)) {
      await _locks[key]!.future;
    }
    _locks[key] = Completer<void>();
  }

  void _releaseLock(String key) {
    final completer = _locks.remove(key);
    completer?.complete();
  }
}
