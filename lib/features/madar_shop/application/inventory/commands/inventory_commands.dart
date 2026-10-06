// أوامر محرك المخزون المكتوبة برمجياً (MADAR SHOP Typed Inventory Commands)
// Pure Dart — Zero UI Dependencies

import '../../../domain/inventory/enums/inventory_movement_type.dart';
import '../../../domain/inventory/enums/return_restock_condition.dart';
import '../../../domain/inventory/value_objects/stock_quantity.dart';

class ApplyInventoryMovementCommand {
  final String commandId;
  final String businessId;
  final String branchId;
  final String productId;
  final String? variantId;
  final StockQuantity quantity;
  final InventoryMovementType movementType;
  final String referenceType;
  final String referenceId;
  final String actorId;
  final String? terminalId;
  final String? sessionId;
  final String? reason;
  final String idempotencyKey;
  final int? expectedVersion;
  final DateTime createdAt;

  ApplyInventoryMovementCommand({
    required this.commandId,
    required this.businessId,
    required this.branchId,
    required this.productId,
    this.variantId,
    required this.quantity,
    required this.movementType,
    required this.referenceType,
    required this.referenceId,
    required this.actorId,
    this.terminalId,
    this.sessionId,
    this.reason,
    required this.idempotencyKey,
    this.expectedVersion,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class ReserveStockCommand {
  final String commandId;
  final String businessId;
  final String branchId;
  final String productId;
  final String? variantId;
  final StockQuantity quantity;
  final String referenceType; // e.g. "MARKETPLACE_ORDER", "PHONE_ORDER"
  final String referenceId;
  final String actorId;
  final String? reason;
  final String idempotencyKey;
  final DateTime createdAt;

  ReserveStockCommand({
    required this.commandId,
    required this.businessId,
    required this.branchId,
    required this.productId,
    this.variantId,
    required this.quantity,
    required this.referenceType,
    required this.referenceId,
    required this.actorId,
    this.reason,
    required this.idempotencyKey,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class ReleaseReservationCommand {
  final String commandId;
  final String businessId;
  final String branchId;
  final String productId;
  final String? variantId;
  final StockQuantity quantity;
  final String referenceType;
  final String referenceId;
  final String actorId;
  final String? reason;
  final String idempotencyKey;
  final DateTime createdAt;

  ReleaseReservationCommand({
    required this.commandId,
    required this.businessId,
    required this.branchId,
    required this.productId,
    this.variantId,
    required this.quantity,
    required this.referenceType,
    required this.referenceId,
    required this.actorId,
    this.reason,
    required this.idempotencyKey,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class AdjustStockCommand {
  final String commandId;
  final String businessId;
  final String branchId;
  final String productId;
  final String? variantId;
  final StockQuantity quantityDelta; // موجب للزيادة، سالب للنقصان
  final String actorId;
  final String reason;
  final String idempotencyKey;
  final DateTime createdAt;

  AdjustStockCommand({
    required this.commandId,
    required this.businessId,
    required this.branchId,
    required this.productId,
    this.variantId,
    required this.quantityDelta,
    required this.actorId,
    required this.reason,
    required this.idempotencyKey,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class ReceivePurchaseCommand {
  final String commandId;
  final String businessId;
  final String branchId;
  final String productId;
  final String? variantId;
  final StockQuantity quantity;
  final String purchaseOrderId;
  final String? supplierId;
  final double? unitCost;
  final String actorId;
  final String idempotencyKey;
  final DateTime createdAt;

  ReceivePurchaseCommand({
    required this.commandId,
    required this.businessId,
    required this.branchId,
    required this.productId,
    this.variantId,
    required this.quantity,
    required this.purchaseOrderId,
    this.supplierId,
    this.unitCost,
    required this.actorId,
    required this.idempotencyKey,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class ProcessReturnStockCommand {
  final String commandId;
  final String businessId;
  final String branchId;
  final String productId;
  final String? variantId;
  final StockQuantity quantity;
  final String saleId;
  final ReturnRestockCondition condition;
  final String actorId;
  final String reason;
  final String idempotencyKey;
  final DateTime createdAt;

  ProcessReturnStockCommand({
    required this.commandId,
    required this.businessId,
    required this.branchId,
    required this.productId,
    this.variantId,
    required this.quantity,
    required this.saleId,
    this.condition = ReturnRestockCondition.restock,
    required this.actorId,
    this.reason = 'مرتجع مبيعات',
    required this.idempotencyKey,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class TransferStockCommand {
  final String commandId;
  final String businessId;
  final String sourceBranchId;
  final String targetBranchId;
  final String productId;
  final String? variantId;
  final StockQuantity quantity;
  final String actorId;
  final String? reason;
  final String idempotencyKey;
  final DateTime createdAt;

  TransferStockCommand({
    required this.commandId,
    required this.businessId,
    required this.sourceBranchId,
    required this.targetBranchId,
    required this.productId,
    this.variantId,
    required this.quantity,
    required this.actorId,
    this.reason,
    required this.idempotencyKey,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
