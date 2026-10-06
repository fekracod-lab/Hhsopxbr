// نية حركة مخزنية صادرة عن عمليات نقطة البيع (MADAR SHOP Inventory Movement Intent)
// Pure Dart — Zero UI Dependencies

import '../enums/inventory_movement_type.dart';

class InventoryMovementIntent {
  final String intentId;
  final String businessId;
  final String branchId;
  final String productId;
  final String? variantId;
  final double quantity;
  final InventoryMovementType movementType;
  final String referenceType; // e.g. "SALE", "REFUND"
  final String referenceId; // saleId
  final DateTime requestedAt;
  final Map<String, dynamic> metadata;

  const InventoryMovementIntent({
    required this.intentId,
    required this.businessId,
    required this.branchId,
    required this.productId,
    this.variantId,
    required this.quantity,
    this.movementType = InventoryMovementType.sale,
    this.referenceType = 'SALE',
    required this.referenceId,
    required this.requestedAt,
    this.metadata = const {},
  });
}
