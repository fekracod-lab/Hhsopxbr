// كيان متغيرات المنتج (الأحجام، الأوزان، الألوان) (MADAR SHOP Product Variant Entity)
// Pure Dart — Zero UI Dependencies

class ShopProductVariant {
  final String variantId;
  final String sku;
  final String? barcode;
  final String title; // e.g. "حجم كبير 500 مل", "وزن 1 كغم", "لون أسود"
  final double costPrice;
  final double sellingPrice;
  final double stockQuantity;
  final bool isAvailable;

  const ShopProductVariant({
    required this.variantId,
    required this.sku,
    this.barcode,
    required this.title,
    required this.costPrice,
    required this.sellingPrice,
    required this.stockQuantity,
    this.isAvailable = true,
  });

  /// حساب هامش الربح الإجمالي للمتغير
  double get grossMargin => sellingPrice - costPrice;

  /// حساب نسبة هامش الربح
  double get grossMarginPercentage {
    if (sellingPrice <= 0) return 0.0;
    return (grossMargin / sellingPrice) * 100.0;
  }

  ShopProductVariant copyWith({
    String? variantId,
    String? sku,
    String? barcode,
    String? title,
    double? costPrice,
    double? sellingPrice,
    double? stockQuantity,
    bool? isAvailable,
  }) {
    return ShopProductVariant(
      variantId: variantId ?? this.variantId,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      title: title ?? this.title,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}
