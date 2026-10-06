// كيان بند الطلب (MADAR SHOP Order Item Entity)
// Pure Dart — Zero UI Dependencies

class ShopOrderItem {
  final String itemId;
  final String productId;
  final String? variantId;
  final String productName;
  final String sku;
  final String? barcode;
  final double unitPrice;
  final double unitCostPrice;
  final double quantity;
  final double discountAmount;
  final String? notes;

  const ShopOrderItem({
    required this.itemId,
    required this.productId,
    this.variantId,
    required this.productName,
    required this.sku,
    this.barcode,
    required this.unitPrice,
    this.unitCostPrice = 0.0,
    required this.quantity,
    this.discountAmount = 0.0,
    this.notes,
  });

  /// المجموع الفرعي للبند قبل الخصم
  double get lineSubtotal => unitPrice * quantity;

  /// المجموع النهائي للبند بعد الخصم
  double get lineTotal {
    final net = lineSubtotal - discountAmount;
    return net > 0 ? net : 0.0;
  }

  /// إجمالي تكلفة البند
  double get totalCost => unitCostPrice * quantity;

  /// صافي الربح الإجمالي المحقق من هذا البند
  double get netProfit => lineTotal - totalCost;

  ShopOrderItem copyWith({
    String? itemId,
    String? productId,
    String? variantId,
    String? productName,
    String? sku,
    String? barcode,
    double? unitPrice,
    double? unitCostPrice,
    double? quantity,
    double? discountAmount,
    String? notes,
  }) {
    return ShopOrderItem(
      itemId: itemId ?? this.itemId,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCostPrice: unitCostPrice ?? this.unitCostPrice,
      quantity: quantity ?? this.quantity,
      discountAmount: discountAmount ?? this.discountAmount,
      notes: notes ?? this.notes,
    );
  }
}
