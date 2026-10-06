// أوامر عمليات المرتجعات واسترداد المبالغ (MADAR SHOP Returns Commands)
// Pure Dart — Zero UI Dependencies

import '../../../domain/inventory/enums/return_restock_condition.dart';
import '../../../domain/inventory/value_objects/stock_quantity.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/returns/enums/refund_method.dart';
import '../../../domain/returns/enums/return_reason.dart';
import '../../../domain/returns/enums/return_type.dart';

class CreateReturnItemInput {
  final String originalSaleItemId;
  final String productId;
  final String? variantId;
  final StockQuantity quantity;
  final ReturnRestockCondition restockCondition;
  final ReturnReason reason;
  final String? reasonNotes;

  const CreateReturnItemInput({
    required this.originalSaleItemId,
    required this.productId,
    this.variantId,
    required this.quantity,
    this.restockCondition = ReturnRestockCondition.restock,
    this.reason = ReturnReason.customerChangedMind,
    this.reasonNotes,
  });
}

typedef ReturnItemInput = CreateReturnItemInput;

class CreateReturnOrderCommand {
  final String commandId;
  final String businessId;
  final String branchId;
  final String originalSaleId;
  final String returnNumber;
  final ReturnType type;
  final List<CreateReturnItemInput> items;
  final String actorId;
  final String? customerId;
  final String? customerName;
  final String idempotencyKey;
  final String? terminalId;

  const CreateReturnOrderCommand({
    required this.commandId,
    required this.businessId,
    required this.branchId,
    required this.originalSaleId,
    required this.returnNumber,
    this.type = ReturnType.partialReturn,
    required this.items,
    required this.actorId,
    this.customerId,
    this.customerName,
    required this.idempotencyKey,
    this.terminalId,
  });
}

class ApproveReturnOrderCommand {
  final String commandId;
  final String businessId;
  final String? branchId;
  final String returnOrderId;
  final String actorId;
  final String idempotencyKey;
  final String? notes;

  const ApproveReturnOrderCommand({
    this.commandId = '',
    required this.businessId,
    this.branchId,
    required this.returnOrderId,
    required this.actorId,
    this.idempotencyKey = '',
    this.notes,
  });
}

class ReceiveReturnOrderCommand {
  final String commandId;
  final String businessId;
  final String branchId;
  final String returnOrderId;
  final String actorId;
  final String idempotencyKey;
  final String? terminalId;

  const ReceiveReturnOrderCommand({
    this.commandId = '',
    required this.businessId,
    required this.branchId,
    required this.returnOrderId,
    required this.actorId,
    this.idempotencyKey = '',
    this.terminalId,
  });
}

class ProcessRefundCommand {
  final String commandId;
  final String businessId;
  final String branchId;
  final String returnOrderId;
  final Money refundAmount;
  final RefundMethod method;
  final String? reference;
  final String actorId;
  final String idempotencyKey;
  final String? terminalId;

  const ProcessRefundCommand({
    required this.commandId,
    required this.businessId,
    required this.branchId,
    required this.returnOrderId,
    required this.refundAmount,
    required this.method,
    this.reference,
    required this.actorId,
    required this.idempotencyKey,
    this.terminalId,
  });
}

class CancelReturnOrderCommand {
  final String commandId;
  final String businessId;
  final String returnOrderId;
  final String reason;
  final String actorId;
  final String idempotencyKey;

  const CancelReturnOrderCommand({
    required this.commandId,
    required this.businessId,
    required this.returnOrderId,
    required this.reason,
    required this.actorId,
    required this.idempotencyKey,
  });
}

class SupplierReturnItemInput {
  final String purchaseReceiptItemId;
  final String productId;
  final String? variantId;
  final StockQuantity quantity;
  final String reason;

  const SupplierReturnItemInput({
    required this.purchaseReceiptItemId,
    required this.productId,
    this.variantId,
    required this.quantity,
    this.reason = 'Returned to supplier',
    Money? unitCost,
  });
}

class CreateSupplierReturnCommand {
  final String commandId;
  final String businessId;
  final String branchId;
  final String supplierId;
  final String originalPurchaseId;
  final String originalReceiptId;
  final String returnNumber;
  final List<SupplierReturnItemInput> items;
  final String reason;
  final String actorId;
  final String idempotencyKey;
  final String? terminalId;

  const CreateSupplierReturnCommand({
    required this.commandId,
    required this.businessId,
    required this.branchId,
    required this.supplierId,
    required this.originalPurchaseId,
    required this.originalReceiptId,
    required this.returnNumber,
    required this.items,
    this.reason = 'Supplier Return',
    required this.actorId,
    required this.idempotencyKey,
    this.terminalId,
  });
}

class ApproveSupplierReturnCommand {
  final String commandId;
  final String businessId;
  final String? branchId;
  final String supplierReturnId;
  final String actorId;
  final String idempotencyKey;

  const ApproveSupplierReturnCommand({
    this.commandId = '',
    required this.businessId,
    this.branchId,
    required this.supplierReturnId,
    required this.actorId,
    this.idempotencyKey = '',
  });
}
