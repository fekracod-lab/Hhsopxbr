// محرك المعاملات المخزنية الذرية وضبط التزامن (MADAR SHOP Inventory Transaction Service)
// Pure Dart — Zero UI Dependencies

import 'dart:async';
import '../../../domain/audit/contracts/shop_audit_repository.dart';
import '../../../domain/audit/entities/shop_audit_entry.dart';
import '../../../domain/identity/rbac/shop_permission.dart';
import '../../../domain/inventory/entities/inventory_item.dart';
import '../../../domain/inventory/entities/inventory_ledger_entry.dart';
import '../../../domain/inventory/enums/inventory_movement_type.dart';
import '../../../domain/inventory/enums/negative_stock_policy.dart';
import '../../../domain/inventory/repositories/i_inventory_idempotency_store.dart';
import '../../../domain/inventory/repositories/i_inventory_ledger_repository.dart';
import '../../../domain/inventory/repositories/i_inventory_repository.dart';
import '../../../domain/inventory/rules/stock_rules.dart';
import '../../../domain/inventory/value_objects/stock_quantity.dart';
import '../../../domain/pos/entities/inventory_movement_intent.dart';
import '../../shop_identity_coordinator.dart';
import '../commands/inventory_commands.dart';
import '../events/inventory_domain_events.dart';
import '../failures/inventory_failures.dart';
import '../results/inventory_operation_result.dart';

typedef InventoryEventSink = void Function(InventoryDomainEvent);

class InventoryTransactionService {
  final IInventoryRepository _inventoryRepo;
  final IInventoryLedgerRepository _ledgerRepo;
  final IInventoryIdempotencyStore _idempotencyStore;
  final ShopIdentityCoordinator _identityCoordinator;
  final IShopAuditRepository _auditRepo;
  final InventoryEventSink? _eventSink;

  static int _ledgerSeq = 0;

  // قفل متزامن محلي لمنع الـ Race Conditions أثناء المعالجة المتزامنة في نفس المعالج
  final Map<String, Completer<void>> _itemLocks = {};

  InventoryTransactionService({
    required IInventoryRepository inventoryRepository,
    required IInventoryLedgerRepository ledgerRepository,
    required IInventoryIdempotencyStore idempotencyStore,
    required ShopIdentityCoordinator identityCoordinator,
    required IShopAuditRepository auditRepository,
    InventoryEventSink? eventSink,
  })  : _inventoryRepo = inventoryRepository,
        _ledgerRepo = ledgerRepository,
        _idempotencyStore = idempotencyStore,
        _identityCoordinator = identityCoordinator,
        _auditRepo = auditRepository,
        _eventSink = eventSink;

  /// المستهلك الرسمي لنيات حركة المخزون الصادرة عن محرك البيع S2 POS
  Future<InventoryOperationResult> consumeSaleMovementIntent({
    required InventoryMovementIntent intent,
    required String actorId,
    String? terminalId,
    String? sessionId,
    int? expectedVersion,
  }) async {
    final command = ApplyInventoryMovementCommand(
      commandId: 'CMD-${intent.intentId}',
      businessId: intent.businessId,
      branchId: intent.branchId,
      productId: intent.productId,
      variantId: intent.variantId,
      quantity: StockQuantity.fromDouble(intent.quantity),
      movementType: InventoryMovementType.sale,
      referenceType: intent.referenceType,
      referenceId: intent.referenceId,
      actorId: actorId,
      terminalId: terminalId,
      sessionId: sessionId,
      reason: 'صرف مخزني لمبيعات الفاتورة #${intent.referenceId}',
      idempotencyKey: 'IDEM-SALE-${intent.intentId}',
      expectedVersion: expectedVersion,
    );

    return applyMovement(command);
  }

  /// تنفيذ حركة مخزنية عامة بشكل ذري مع فحص التكرار والتزامن
  Future<InventoryOperationResult> applyMovement(ApplyInventoryMovementCommand command) async {
    final lockKey = '${command.businessId}:${command.branchId}:${command.productId}:${command.variantId ?? "main"}';
    await _acquireLock(lockKey);

    try {
      // 0. التحقق من الهوية والفرع والنشاط عند توفر جلسة نشطة
      if (_identityCoordinator.isAuthenticated) {
        if (_identityCoordinator.currentUser?.businessId != command.businessId) {
          throw const UnauthorizedInventoryOperationFailure(
            'تعارض في النشاط التجاري: لا يمكن إجراء حركات لمخزون نشاط تجاري آخر.',
          );
        }
        if (!_identityCoordinator.canOperateOnActiveBranch(command.branchId)) {
          throw const InventoryBranchMismatchFailure(
            'المستخدم ليس لديه صلاحية الوصول إلى هذا الفرع.',
          );
        }
      }

      // 1. التحقق من التكرار (Idempotency Check)
      final hasProcessed = await _idempotencyStore.hasProcessed(
        businessId: command.businessId,
        branchId: command.branchId,
        idempotencyKey: command.idempotencyKey,
      );

      final currentItem = await _inventoryRepo.getInventoryItem(
        businessId: command.businessId,
        branchId: command.branchId,
        productId: command.productId,
        variantId: command.variantId,
      );

      if (hasProcessed && currentItem != null) {
        return InventoryOperationResult(
          isSuccess: true,
          item: currentItem,
          isIdempotentReplay: true,
          message: 'تمت معالجة هذه الحركة مسبقاً بنجاح.',
        );
      }

      // 1.5 التحقق من صحة الكمية الممررة
      if (command.quantity.isZero || command.quantity.isNegative) {
        throw const InvalidStockQuantityFailure('يجب أن تكون كمية الحركة المخزنية أكبر من صفر.');
      }

      final InventoryItem effectiveItem;
      if (currentItem == null) {
        if (command.movementType == InventoryMovementType.purchase ||
            command.movementType == InventoryMovementType.initialBalance) {
          effectiveItem = InventoryItem.initialize(
            inventoryId: 'INV-${command.businessId}-${command.branchId}-${command.productId}-${command.variantId ?? "main"}',
            businessId: command.businessId,
            branchId: command.branchId,
            productId: command.productId,
            variantId: command.variantId,
            unit: command.quantity.unit,
            initialOnHand: StockQuantity.zero(command.quantity.unit),
          );
          await _inventoryRepo.saveInventoryItem(effectiveItem);
        } else {
          throw InventoryItemNotFoundFailure(
            'صنف المخزون غير مسجل في الفرع المحدد (منتج: ${command.productId}).',
          );
        }
      } else {
        effectiveItem = currentItem;
      }

      // 2. التحقق من التزامن المتفائل (Optimistic Concurrency Control)
      if (command.expectedVersion != null && command.expectedVersion != effectiveItem.version) {
        _eventSink?.call(InventoryConflictDetectedEvent(
          eventId: 'EVT-CONF-${DateTime.now().microsecondsSinceEpoch}',
          occurredAt: DateTime.now(),
          businessId: command.businessId,
          branchId: command.branchId,
          productId: command.productId,
          variantId: command.variantId,
          attemptedVersion: command.expectedVersion!,
          currentVersion: effectiveItem.version,
        ));
        throw InventoryConflictFailure(
          'تعارض في التزامن: تم تعديل المخزون من محطة أخرى (الإصدار الحالي: ${effectiveItem.version}، المتوقع: ${command.expectedVersion}).',
        );
      }

      // 3. توحيد وحدة القياس مع الصنف المخزني الفعلي (لتجنب تعارض وحدات القياس الحسابية)
      final normalizedQuantity = command.quantity.unit == effectiveItem.unit
          ? command.quantity
          : StockQuantity.fromMilliUnits(command.quantity.milliUnits, effectiveItem.unit);

      // 4. احتساب التغير في الرصيد
      final StockQuantity qtyDelta;
      if (command.movementType.isPositiveOnHandDelta) {
        qtyDelta = normalizedQuantity;
      } else {
        qtyDelta = -normalizedQuantity;
      }

      // 5. فحص قيود المخزون وسياسة السالب
      final projectedOnHand = effectiveItem.onHand + qtyDelta;
      final projectedAvailable = projectedOnHand - effectiveItem.reserved;

      if (projectedAvailable.isNegative && effectiveItem.negativeStockPolicy == NegativeStockPolicy.block) {
        throw InsufficientStockFailure(
          'الرصيد المتاح غير كافٍ. المتاح: ${effectiveItem.available}، المطلوب صرفه: $normalizedQuantity.',
        );
      }

      // 6. بناء الكيان المحدث وزيادة رقم الإصدار
      final updatedItem = effectiveItem.copyWith(
        onHand: projectedOnHand,
        version: effectiveItem.version + 1,
        updatedAt: DateTime.now(),
      );

      final ledgerId = 'LEDGER-${DateTime.now().microsecondsSinceEpoch}-${++_ledgerSeq}';
      final ledgerEntry = InventoryLedgerEntry(
        id: ledgerId,
        businessId: command.businessId,
        branchId: command.branchId,
        productId: command.productId,
        variantId: command.variantId,
        movementType: command.movementType,
        quantityDelta: qtyDelta,
        reservedDelta: StockQuantity.zero(effectiveItem.unit),
        unit: effectiveItem.unit,
        beforeOnHand: effectiveItem.onHand,
        afterOnHand: projectedOnHand,
        beforeReserved: effectiveItem.reserved,
        afterReserved: effectiveItem.reserved,
        beforeAvailable: effectiveItem.available,
        afterAvailable: projectedAvailable,
        referenceType: command.referenceType,
        referenceId: command.referenceId,
        actorId: command.actorId,
        terminalId: command.terminalId,
        sessionId: command.sessionId,
        reason: command.reason ?? command.movementType.displayNameAr,
        createdAt: DateTime.now(),
        version: updatedItem.version,
        idempotencyKey: command.idempotencyKey,
      );

      // 7. الحفظ الذري
      await _inventoryRepo.saveInventoryItem(updatedItem);
      await _ledgerRepo.appendLedgerEntry(ledgerEntry);
      await _idempotencyStore.recordProcessed(
        businessId: command.businessId,
        branchId: command.branchId,
        idempotencyKey: command.idempotencyKey,
        resultSummary: 'Movement ${command.movementType.toDbString()} $qtyDelta completed',
      );

      // 8. تسجيل في سجل التدقيق
      await _auditRepo.recordAuditEntry(
        ShopAuditEntry(
          auditId: 'AUDIT-INV-${DateTime.now().microsecondsSinceEpoch}',
          businessId: command.businessId,
          branchId: command.branchId,
          userId: command.actorId,
          userName: 'Staff Actor',
          terminalId: command.terminalId ?? 'SERVER',
          action: ShopAuditAction.manualStockAdjustment,
          referenceId: command.referenceId,
          beforeState: {'onHand': currentItem?.onHand.milliUnits ?? 0},
          afterState: {'onHand': updatedItem.onHand.milliUnits, 'delta': qtyDelta.milliUnits},
          reason: command.reason,
          timestamp: DateTime.now(),
        ),
      );

      // 9. إطلاق الأحداث
      _eventSink?.call(InventoryMovementRecordedEvent(
        eventId: 'EVT-MOV-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: DateTime.now(),
        item: updatedItem,
        ledgerEntry: ledgerEntry,
      ));

      if (updatedItem.isOutOfStock) {
        _eventSink?.call(InventoryOutOfStockEvent(
          eventId: 'EVT-OOS-${DateTime.now().microsecondsSinceEpoch}',
          occurredAt: DateTime.now(),
          item: updatedItem,
        ));
      } else if (updatedItem.isLowStock) {
        _eventSink?.call(InventoryLowStockEvent(
          eventId: 'EVT-LOW-${DateTime.now().microsecondsSinceEpoch}',
          occurredAt: DateTime.now(),
          item: updatedItem,
        ));
      }

      return InventoryOperationResult(
        isSuccess: true,
        item: updatedItem,
        ledgerEntry: ledgerEntry,
        isIdempotentReplay: false,
      );
    } finally {
      _releaseLock(lockKey);
    }
  }

  /// حجز كمية من المخزون (مثل حجوزات الماركت بليس والطلبات الأونلاين)
  Future<InventoryOperationResult> reserveStock(ReserveStockCommand command) async {
    final lockKey = '${command.businessId}:${command.branchId}:${command.productId}:${command.variantId ?? "main"}';
    await _acquireLock(lockKey);

    try {
      final currentItem = await _inventoryRepo.getInventoryItem(
        businessId: command.businessId,
        branchId: command.branchId,
        productId: command.productId,
        variantId: command.variantId,
      );

      if (currentItem == null) {
        throw const InventoryItemNotFoundFailure('صنف المخزون غير موجود للحجز.');
      }

      final validation = StockRules.validateReservation(
        item: currentItem,
        reservationQuantity: command.quantity,
      );

      if (!validation.isAllowed) {
        throw ReservationExceededFailure(validation.rejectionReason ?? 'تعذر إتمام الحجز.');
      }

      final updatedItem = currentItem.copyWith(
        reserved: currentItem.reserved + command.quantity,
        version: currentItem.version + 1,
        updatedAt: DateTime.now(),
      );

      final ledgerEntry = InventoryLedgerEntry(
        id: 'LEDGER-RES-${DateTime.now().microsecondsSinceEpoch}-${++_ledgerSeq}',
        businessId: command.businessId,
        branchId: command.branchId,
        productId: command.productId,
        variantId: command.variantId,
        movementType: InventoryMovementType.reservation,
        quantityDelta: StockQuantity.zero(currentItem.unit),
        reservedDelta: command.quantity,
        unit: currentItem.unit,
        beforeOnHand: currentItem.onHand,
        afterOnHand: currentItem.onHand,
        beforeReserved: currentItem.reserved,
        afterReserved: updatedItem.reserved,
        beforeAvailable: currentItem.available,
        afterAvailable: updatedItem.available,
        referenceType: command.referenceType,
        referenceId: command.referenceId,
        actorId: command.actorId,
        reason: command.reason ?? 'حجز مخزني لطلب #${command.referenceId}',
        createdAt: DateTime.now(),
        version: updatedItem.version,
        idempotencyKey: command.idempotencyKey,
      );

      await _inventoryRepo.saveInventoryItem(updatedItem);
      await _ledgerRepo.appendLedgerEntry(ledgerEntry);

      _eventSink?.call(InventoryReservedEvent(
        eventId: 'EVT-RES-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: DateTime.now(),
        item: updatedItem,
        ledgerEntry: ledgerEntry,
      ));

      return InventoryOperationResult(
        isSuccess: true,
        item: updatedItem,
        ledgerEntry: ledgerEntry,
      );
    } finally {
      _releaseLock(lockKey);
    }
  }

  /// فك حجز كمية من المخزون
  Future<InventoryOperationResult> releaseReservation(ReleaseReservationCommand command) async {
    final lockKey = '${command.businessId}:${command.branchId}:${command.productId}:${command.variantId ?? "main"}';
    await _acquireLock(lockKey);

    try {
      final currentItem = await _inventoryRepo.getInventoryItem(
        businessId: command.businessId,
        branchId: command.branchId,
        productId: command.productId,
        variantId: command.variantId,
      );

      if (currentItem == null) {
        throw const InventoryItemNotFoundFailure('صنف المخزون غير موجود لفك الحجز.');
      }

      final validation = StockRules.validateReleaseReservation(
        item: currentItem,
        releaseQuantity: command.quantity,
      );

      if (!validation.isAllowed) {
        throw ReservationExceededFailure(validation.rejectionReason ?? 'تعذر فك الحجز.');
      }

      final updatedItem = currentItem.copyWith(
        reserved: currentItem.reserved - command.quantity,
        version: currentItem.version + 1,
        updatedAt: DateTime.now(),
      );

      final ledgerEntry = InventoryLedgerEntry(
        id: 'LEDGER-REL-${DateTime.now().microsecondsSinceEpoch}-${++_ledgerSeq}',
        businessId: command.businessId,
        branchId: command.branchId,
        productId: command.productId,
        variantId: command.variantId,
        movementType: InventoryMovementType.releaseReservation,
        quantityDelta: StockQuantity.zero(currentItem.unit),
        reservedDelta: -command.quantity,
        unit: currentItem.unit,
        beforeOnHand: currentItem.onHand,
        afterOnHand: currentItem.onHand,
        beforeReserved: currentItem.reserved,
        afterReserved: updatedItem.reserved,
        beforeAvailable: currentItem.available,
        afterAvailable: updatedItem.available,
        referenceType: command.referenceType,
        referenceId: command.referenceId,
        actorId: command.actorId,
        reason: command.reason ?? 'فك حجز مخزني للطلب #${command.referenceId}',
        createdAt: DateTime.now(),
        version: updatedItem.version,
        idempotencyKey: command.idempotencyKey,
      );

      await _inventoryRepo.saveInventoryItem(updatedItem);
      await _ledgerRepo.appendLedgerEntry(ledgerEntry);

      _eventSink?.call(InventoryReservationReleasedEvent(
        eventId: 'EVT-REL-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: DateTime.now(),
        item: updatedItem,
        ledgerEntry: ledgerEntry,
      ));

      return InventoryOperationResult(
        isSuccess: true,
        item: updatedItem,
        ledgerEntry: ledgerEntry,
      );
    } finally {
      _releaseLock(lockKey);
    }
  }

  /// تسوية جردية بالزيادة أو النقصان مع التحقق من الصلاحيات والسبب
  Future<InventoryOperationResult> adjustStock(AdjustStockCommand command) async {
    if (!_identityCoordinator.hasPermission(ShopPermission.adjustInventoryStock)) {
      throw const UnauthorizedInventoryOperationFailure(
        'ليس لديك صلاحية إجراء تسويات جردية على المخزون.',
      );
    }

    if (command.reason.trim().isEmpty) {
      throw const InvalidStockQuantityFailure('يجب ذكر سبب واضح لإجراء التسوية الجردية.');
    }

    if (command.quantityDelta.isZero) {
      throw const InvalidStockQuantityFailure('فارق التسوية الجردية لا يمكن أن يكون صفراً.');
    }

    final isPositive = command.quantityDelta.isPositive;
    final movementType = isPositive ? InventoryMovementType.adjustmentIn : InventoryMovementType.adjustmentOut;
    final absQuantity = isPositive ? command.quantityDelta : -command.quantityDelta;

    final applyCmd = ApplyInventoryMovementCommand(
      commandId: command.commandId,
      businessId: command.businessId,
      branchId: command.branchId,
      productId: command.productId,
      variantId: command.variantId,
      quantity: absQuantity,
      movementType: movementType,
      referenceType: 'ADJUSTMENT',
      referenceId: command.commandId,
      actorId: command.actorId,
      reason: command.reason,
      idempotencyKey: command.idempotencyKey,
    );

    return applyMovement(applyCmd);
  }

  /// استلام وتوريد بضاعة مشتريات (عقد مرحلة S4)
  Future<InventoryOperationResult> receivePurchase(ReceivePurchaseCommand command) async {
    final applyCmd = ApplyInventoryMovementCommand(
      commandId: command.commandId,
      businessId: command.businessId,
      branchId: command.branchId,
      productId: command.productId,
      variantId: command.variantId,
      quantity: command.quantity,
      movementType: InventoryMovementType.purchase,
      referenceType: 'PURCHASE',
      referenceId: command.purchaseOrderId,
      actorId: command.actorId,
      reason: 'توريد واستلام بضاعة بموجب أمر الشراء #${command.purchaseOrderId}',
      idempotencyKey: command.idempotencyKey,
    );

    return applyMovement(applyCmd);
  }

  /// إرجاع بضاعة من مبيعات مع فرز الحالة (عقد مرحلة S5)
  Future<InventoryOperationResult> processReturn(ProcessReturnStockCommand command) async {
    if (!command.condition.isRestockable) {
      // إذا كانت البضاعة المرتجعة تالفة أو منتهية، لا تدخل الرصيد الصالح OnHand
      return InventoryOperationResult(
        isSuccess: true,
        item: (await _inventoryRepo.getInventoryItem(
          businessId: command.businessId,
          branchId: command.branchId,
          productId: command.productId,
          variantId: command.variantId,
        ))!,
        message: 'تم تسجيل المرتجع التالف/غير الصالح دون إضافته للمخزون الصالح.',
      );
    }

    final applyCmd = ApplyInventoryMovementCommand(
      commandId: command.commandId,
      businessId: command.businessId,
      branchId: command.branchId,
      productId: command.productId,
      variantId: command.variantId,
      quantity: command.quantity,
      movementType: InventoryMovementType.customerReturn,
      referenceType: 'RETURN',
      referenceId: command.saleId,
      actorId: command.actorId,
      reason: command.reason,
      idempotencyKey: command.idempotencyKey,
    );

    return applyMovement(applyCmd);
  }

  /// تحويل بضاعة بين فرعين لنفس النشاط التجاري
  Future<void> transferStock(TransferStockCommand command) async {
    if (!_identityCoordinator.hasPermission(ShopPermission.manageBranches) &&
        !_identityCoordinator.hasPermission(ShopPermission.adjustInventoryStock)) {
      throw const UnauthorizedInventoryOperationFailure(
        'ليس لديك صلاحية نقل وتحويل المخزون بين الفروع.',
      );
    }

    if (command.sourceBranchId == command.targetBranchId) {
      throw const InventoryBranchMismatchFailure('لا يمكن التحويل لنفس الفرع.');
    }

    // 1. خصم من الفرع المصدر (Transfer Out)
    final outCmd = ApplyInventoryMovementCommand(
      commandId: '${command.commandId}-OUT',
      businessId: command.businessId,
      branchId: command.sourceBranchId,
      productId: command.productId,
      variantId: command.variantId,
      quantity: command.quantity,
      movementType: InventoryMovementType.transferOut,
      referenceType: 'TRANSFER',
      referenceId: command.commandId,
      actorId: command.actorId,
      reason: 'تحويل صادر إلى الفرع ${command.targetBranchId}: ${command.reason ?? ""}',
      idempotencyKey: '${command.idempotencyKey}-OUT',
    );

    await applyMovement(outCmd);

    // 2. إضافة للفرع الهدف (Transfer In)
    final inCmd = ApplyInventoryMovementCommand(
      commandId: '${command.commandId}-IN',
      businessId: command.businessId,
      branchId: command.targetBranchId,
      productId: command.productId,
      variantId: command.variantId,
      quantity: command.quantity,
      movementType: InventoryMovementType.transferIn,
      referenceType: 'TRANSFER',
      referenceId: command.commandId,
      actorId: command.actorId,
      reason: 'تحويل وارد من الفرع ${command.sourceBranchId}: ${command.reason ?? ""}',
      idempotencyKey: '${command.idempotencyKey}-IN',
    );

    await applyMovement(inCmd);
  }

  // ─── دوال إدارة القفل المتزامن ───
  Future<void> _acquireLock(String key) async {
    while (_itemLocks.containsKey(key)) {
      await _itemLocks[key]!.future;
    }
    _itemLocks[key] = Completer<void>();
  }

  void _releaseLock(String key) {
    if (_itemLocks.containsKey(key)) {
      final completer = _itemLocks.remove(key)!;
      completer.complete();
    }
  }
}
