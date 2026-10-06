// عقد نية تحويل مخزني بين الفروع (MADAR SHOP Inventory Transfer Intent Contract)
// Pure Dart — Zero UI Dependencies

import '../value_objects/stock_quantity.dart';

class InventoryTransferIntent {
  final String transferId;
  final String businessId;
  final String sourceBranchId;
  final String targetBranchId;
  final String productId;
  final String? variantId;
  final StockQuantity quantity;
  final String actorId;
  final String? reason;
  final DateTime requestedAt;
  final String idempotencyKey;

  const InventoryTransferIntent({
    required this.transferId,
    required this.businessId,
    required this.sourceBranchId,
    required this.targetBranchId,
    required this.productId,
    this.variantId,
    required this.quantity,
    required this.actorId,
    this.reason,
    required this.requestedAt,
    required this.idempotencyKey,
  });
}
