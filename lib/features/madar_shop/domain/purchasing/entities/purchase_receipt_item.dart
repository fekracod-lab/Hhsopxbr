// بند إيصال استلام بضاعة المشتريات (MADAR SHOP Purchase Receipt Item Entity)
// Pure Dart — Zero UI Dependencies

import '../../inventory/value_objects/stock_quantity.dart';
import '../../inventory/value_objects/stock_unit.dart';
import '../../pos/value_objects/money.dart';

class PurchaseReceiptItem {
  final String purchaseItemId;
  final String productId;
  final String? variantId;
  final StockQuantity quantityReceived;
  final StockUnit unit;
  final Money unitCost;
  final Money lineTotal;
  final String? batchId;
  final String? lotNumber;
  final DateTime? expiryDate;

  PurchaseReceiptItem({
    required this.purchaseItemId,
    required this.productId,
    this.variantId,
    required this.quantityReceived,
    required this.unit,
    required this.unitCost,
    Money? lineTotal,
    this.batchId,
    this.lotNumber,
    this.expiryDate,
  }) : lineTotal = lineTotal ?? (unitCost * quantityReceived.toDouble());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseReceiptItem &&
          runtimeType == other.runtimeType &&
          purchaseItemId == other.purchaseItemId &&
          productId == other.productId &&
          variantId == other.variantId &&
          quantityReceived == other.quantityReceived;

  @override
  int get hashCode =>
      purchaseItemId.hashCode ^
      productId.hashCode ^
      variantId.hashCode ^
      quantityReceived.hashCode;

  @override
  String toString() =>
      'PurchaseReceiptItem(item: $purchaseItemId, received: $quantityReceived, cost: $unitCost)';
}
