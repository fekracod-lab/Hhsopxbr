// بند تقييم المخزون المالي (MADAR SHOP Inventory Valuation Item)
// Pure Dart — Zero UI Dependencies

import '../../inventory/value_objects/stock_quantity.dart';
import '../../pos/value_objects/money.dart';
import '../enums/costing_method.dart';

class InventoryValuationItem {
  final String productId;
  final String? variantId;
  final String sku;
  final String name;
  final StockQuantity quantityOnHand;
  final Money unitCostBasis;
  final CostingMethod method;
  final DateTime asOf;

  const InventoryValuationItem({
    required this.productId,
    this.variantId,
    required this.sku,
    required this.name,
    required this.quantityOnHand,
    required this.unitCostBasis,
    required this.method,
    required this.asOf,
  });

  /// إجمالي القيمة النقدية للمخزون لهذا الصنف
  Money get totalValuation => unitCostBasis * quantityOnHand.toDouble();
}
