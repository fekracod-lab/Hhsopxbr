// أوامر تطبيق مشتريات وموردي مدار (MADAR SHOP Purchasing Commands)
// Pure Dart — Zero UI Dependencies

import '../../../domain/inventory/value_objects/stock_quantity.dart';
import '../../../domain/inventory/value_objects/stock_unit.dart';
import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/purchasing/enums/over_receiving_policy.dart';
import '../../../domain/purchasing/enums/supplier_overpayment_policy.dart';
import '../../../domain/purchasing/enums/supplier_payment_method.dart';
import '../../../domain/purchasing/enums/supplier_status.dart';

class CreateSupplierCommand {
  final String commandId;
  final String businessId;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final String? taxId;
  final String actorId;
  final String idempotencyKey;
  final DateTime createdAt;

  CreateSupplierCommand({
    required this.commandId,
    required this.businessId,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.taxId,
    required this.actorId,
    required this.idempotencyKey,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class UpdateSupplierCommand {
  final String commandId;
  final String businessId;
  final String supplierId;
  final String? name;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxId;
  final SupplierStatus? status;
  final String actorId;
  final String idempotencyKey;
  final DateTime updatedAt;

  UpdateSupplierCommand({
    required this.commandId,
    required this.businessId,
    required this.supplierId,
    this.name,
    this.phone,
    this.email,
    this.address,
    this.taxId,
    this.status,
    required this.actorId,
    required this.idempotencyKey,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();
}

class BlockSupplierCommand {
  final String commandId;
  final String businessId;
  final String supplierId;
  final String reason;
  final String actorId;
  final String idempotencyKey;
  final DateTime blockedAt;

  BlockSupplierCommand({
    required this.commandId,
    required this.businessId,
    required this.supplierId,
    required this.reason,
    required this.actorId,
    required this.idempotencyKey,
    DateTime? blockedAt,
  }) : blockedAt = blockedAt ?? DateTime.now();
}

class PurchaseItemInput {
  final String productId;
  final String? variantId;
  final String description;
  final String sku;
  final String? barcode;
  final StockQuantity quantity;
  final StockUnit unit;
  final Money unitCost;
  final Money? discount;
  final Money? tax;

  const PurchaseItemInput({
    required this.productId,
    this.variantId,
    required this.description,
    required this.sku,
    this.barcode,
    required this.quantity,
    required this.unit,
    required this.unitCost,
    this.discount,
    this.tax,
  });
}

class CreatePurchaseOrderCommand {
  final String commandId;
  final String businessId;
  final String branchId;
  final String supplierId;
  final String orderNumber;
  final List<PurchaseItemInput> items;
  final Currency currency;
  final String actorId;
  final String idempotencyKey;
  final String? notes;
  final String? terminalId;
  final String? sessionId;
  final DateTime createdAt;

  CreatePurchaseOrderCommand({
    required this.commandId,
    required this.businessId,
    required this.branchId,
    required this.supplierId,
    required this.orderNumber,
    required this.items,
    this.currency = Currency.iqd,
    required this.actorId,
    required this.idempotencyKey,
    this.notes,
    this.terminalId,
    this.sessionId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class SubmitPurchaseOrderCommand {
  final String commandId;
  final String businessId;
  final String purchaseOrderId;
  final String actorId;
  final String idempotencyKey;
  final DateTime submittedAt;

  SubmitPurchaseOrderCommand({
    required this.commandId,
    required this.businessId,
    required this.purchaseOrderId,
    required this.actorId,
    required this.idempotencyKey,
    DateTime? submittedAt,
  }) : submittedAt = submittedAt ?? DateTime.now();
}

class ApprovePurchaseOrderCommand {
  final String commandId;
  final String businessId;
  final String purchaseOrderId;
  final String actorId;
  final String idempotencyKey;
  final DateTime approvedAt;

  ApprovePurchaseOrderCommand({
    required this.commandId,
    required this.businessId,
    required this.purchaseOrderId,
    required this.actorId,
    required this.idempotencyKey,
    DateTime? approvedAt,
  }) : approvedAt = approvedAt ?? DateTime.now();
}

class ReceiveGoodsItemInput {
  final String purchaseItemId;
  final String productId;
  final String? variantId;
  final StockQuantity quantityToReceive;
  final Money? overrideUnitCost; // اختياري إذا تغيرت التكلفة في إشعار التوريد الفعلي
  final String? batchId;
  final String? lotNumber;
  final DateTime? expiryDate;

  const ReceiveGoodsItemInput({
    required this.purchaseItemId,
    required this.productId,
    this.variantId,
    required this.quantityToReceive,
    this.overrideUnitCost,
    this.batchId,
    this.lotNumber,
    this.expiryDate,
  });
}

class ReceiveGoodsCommand {
  final String commandId;
  final String businessId;
  final String branchId;
  final String purchaseOrderId;
  final List<ReceiveGoodsItemInput> items;
  final OverReceivingPolicy policy;
  final bool hasOverReceivingApproval;
  final String actorId;
  final String idempotencyKey;
  final String? reference;
  final String? notes;
  final String? terminalId;
  final String? sessionId;
  final DateTime receivedAt;

  ReceiveGoodsCommand({
    required this.commandId,
    required this.businessId,
    required this.branchId,
    required this.purchaseOrderId,
    required this.items,
    this.policy = OverReceivingPolicy.block,
    this.hasOverReceivingApproval = false,
    required this.actorId,
    required this.idempotencyKey,
    this.reference,
    this.notes,
    this.terminalId,
    this.sessionId,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();
}

class CancelPurchaseOrderCommand {
  final String commandId;
  final String businessId;
  final String purchaseOrderId;
  final String reason;
  final bool cancelRemainingOnly; // عند الاستلام الجزئي، يلغي فقط ما تبقى
  final String actorId;
  final String idempotencyKey;
  final DateTime cancelledAt;

  CancelPurchaseOrderCommand({
    required this.commandId,
    required this.businessId,
    required this.purchaseOrderId,
    required this.reason,
    this.cancelRemainingOnly = false,
    required this.actorId,
    required this.idempotencyKey,
    DateTime? cancelledAt,
  }) : cancelledAt = cancelledAt ?? DateTime.now();
}

class PaySupplierCommand {
  final String commandId;
  final String businessId;
  final String supplierId;
  final Money amount;
  final SupplierPaymentMethod method;
  final String? reference;
  final String? purchaseOrderId;
  final SupplierOverpaymentPolicy policy;
  final bool hasOverpaymentApproval;
  final String actorId;
  final String idempotencyKey;
  final String? notes;
  final String? terminalId;
  final String? sessionId;
  final DateTime paidAt;

  PaySupplierCommand({
    required this.commandId,
    required this.businessId,
    required this.supplierId,
    required this.amount,
    this.method = SupplierPaymentMethod.cash,
    this.reference,
    this.purchaseOrderId,
    this.policy = SupplierOverpaymentPolicy.block,
    this.hasOverpaymentApproval = false,
    required this.actorId,
    required this.idempotencyKey,
    this.notes,
    this.terminalId,
    this.sessionId,
    DateTime? paidAt,
  }) : paidAt = paidAt ?? DateTime.now();
}
