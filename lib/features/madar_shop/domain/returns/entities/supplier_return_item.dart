// كيان بند مرتجع المشتريات للمورد (MADAR SHOP Supplier Return Item Entity)
// Pure Dart — Zero UI Dependencies

import '../../inventory/value_objects/stock_quantity.dart';
import '../../pos/value_objects/money.dart';

class SupplierReturnItem {
  final String id;
  final String purchaseReceiptItemId;
  final String productId;
  final String? variantId;
  final StockQuantity quantity;
  final Money unitCost;
  final String reason;

  const SupplierReturnItem({
    required this.id,
    required this.purchaseReceiptItemId,
    required this.productId,
    this.variantId,
    required this.quantity,
    required this.unitCost,
    required this.reason,
  });

  /// إجمالي القيمة المرتجعة للبند
  Money get lineTotal => unitCost * quantity.toDouble();

  SupplierReturnItem copyWith({
    String? id,
    String? purchaseReceiptItemId,
    String? productId,
    String? variantId,
    StockQuantity? quantity,
    Money? unitCost,
    String? reason,
  }) {
    return SupplierReturnItem(
      id: id ?? this.id,
      purchaseReceiptItemId: purchaseReceiptItemId ?? this.purchaseReceiptItemId,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      reason: reason ?? this.reason,
    );
  }
}
