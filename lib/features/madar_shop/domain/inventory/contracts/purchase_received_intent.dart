// عقد نية توريد واستلام بضاعة مشتريات (MADAR SHOP Purchase Received Intent Contract)
// Pure Dart — Zero UI Dependencies

import '../value_objects/stock_quantity.dart';

class PurchaseReceivedIntent {
  final String intentId;
  final String businessId;
  final String branchId;
  final String productId;
  final String? variantId;
  final StockQuantity quantity;
  final String? supplierId;
  final String? purchaseOrderId;
  final double? unitCost;
  final DateTime receivedAt;
  final String idempotencyKey;
  final Map<String, dynamic> metadata;

  const PurchaseReceivedIntent({
    required this.intentId,
    required this.businessId,
    required this.branchId,
    required this.productId,
    this.variantId,
    required this.quantity,
    this.supplierId,
    this.purchaseOrderId,
    this.unitCost,
    required this.receivedAt,
    required this.idempotencyKey,
    this.metadata = const {},
  });
}
