// بند أمر الشراء المحتوي على لقطات الأسعار والكميات (MADAR SHOP Purchase Item Entity)
// Pure Dart — Zero UI Dependencies

import '../../inventory/value_objects/stock_quantity.dart';
import '../../inventory/value_objects/stock_unit.dart';
import '../../pos/value_objects/money.dart';
import '../value_objects/cost_snapshot.dart';

class PurchaseItem {
  final String id;
  final String productId;
  final String? variantId;
  final String descriptionSnapshot;
  final String skuSnapshot;
  final String? barcodeSnapshot;
  final StockQuantity quantityOrdered;
  final StockQuantity quantityReceived;
  final StockUnit unit;
  final Money unitCost;
  final Money discount;
  final Money tax;
  final Money lineSubtotal;
  final Money lineTotal;
  final CostSnapshot costSnapshot;

  PurchaseItem({
    required this.id,
    required this.productId,
    this.variantId,
    required this.descriptionSnapshot,
    required this.skuSnapshot,
    this.barcodeSnapshot,
    required this.quantityOrdered,
    StockQuantity? quantityReceived,
    required this.unit,
    required this.unitCost,
    Money? discount,
    Money? tax,
    CostSnapshot? costSnapshot,
  })  : quantityReceived = quantityReceived ?? StockQuantity.zero(unit),
        discount = discount ?? Money.zero(unitCost.currency),
        tax = tax ?? Money.zero(unitCost.currency),
        lineSubtotal = unitCost * quantityOrdered.toDouble(),
        lineTotal = (unitCost * quantityOrdered.toDouble()) -
            (discount ?? Money.zero(unitCost.currency)) +
            (tax ?? Money.zero(unitCost.currency)),
        costSnapshot = costSnapshot ??
            CostSnapshot(
              unitCost: unitCost,
              discountPerUnit: (discount != null && !quantityOrdered.isZero)
                  ? discount * (1 / quantityOrdered.toDouble())
                  : Money.zero(unitCost.currency),
              taxPerUnit: (tax != null && !quantityOrdered.isZero)
                  ? tax * (1 / quantityOrdered.toDouble())
                  : Money.zero(unitCost.currency),
            );

  StockQuantity get remainingQuantity {
    final diff = quantityOrdered - quantityReceived;
    return diff.isNegative ? StockQuantity.zero(unit) : diff;
  }

  bool get isFullyReceived => quantityReceived >= quantityOrdered;

  PurchaseItem copyWith({
    StockQuantity? quantityReceived,
    StockQuantity? quantityOrdered,
    Money? unitCost,
    Money? discount,
    Money? tax,
    CostSnapshot? costSnapshot,
  }) {
    return PurchaseItem(
      id: id,
      productId: productId,
      variantId: variantId,
      descriptionSnapshot: descriptionSnapshot,
      skuSnapshot: skuSnapshot,
      barcodeSnapshot: barcodeSnapshot,
      quantityOrdered: quantityOrdered ?? this.quantityOrdered,
      quantityReceived: quantityReceived ?? this.quantityReceived,
      unit: unit,
      unitCost: unitCost ?? this.unitCost,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      costSnapshot: costSnapshot ?? this.costSnapshot,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PurchaseItem(id: $id, prod: $productId, ordered: $quantityOrdered, received: $quantityReceived, total: $lineTotal)';
}
