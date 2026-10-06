// عقد نية إرجاع بضاعة من مبيعات (MADAR SHOP Return Inventory Intent Contract)
// Pure Dart — Zero UI Dependencies

import '../enums/return_restock_condition.dart';
import '../value_objects/stock_quantity.dart';

class ReturnInventoryIntent {
  final String intentId;
  final String businessId;
  final String branchId;
  final String productId;
  final String? variantId;
  final StockQuantity quantity;
  final String saleId;
  final ReturnRestockCondition condition;
  final String reason;
  final DateTime receivedAt;
  final String idempotencyKey;
  final Map<String, dynamic> metadata;

  const ReturnInventoryIntent({
    required this.intentId,
    required this.businessId,
    required this.branchId,
    required this.productId,
    this.variantId,
    required this.quantity,
    required this.saleId,
    this.condition = ReturnRestockCondition.restock,
    required this.reason,
    required this.receivedAt,
    required this.idempotencyKey,
    this.metadata = const {},
  });
}
