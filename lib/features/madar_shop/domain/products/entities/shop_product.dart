// كيان المنتج المركزي لمنظومة المتجر (MADAR SHOP Core Product Entity)
// Pure Dart — Zero UI Dependencies

import 'shop_product_variant.dart';

enum ShopBarcodeType {
  ean13,    // الباركود الدولي القياسي 13 رقم
  upc,      // النظام الموحد الأمريكي
  code128,  // باركود تجاري عام أبجدي رقمي
  internal; // باركود داخلي يتم توليده تلقائياً للأصناف غير المرمزة

  static ShopBarcodeType fromString(String? val) {
    if (val == null) return ShopBarcodeType.internal;
    switch (val.trim().toLowerCase()) {
      case 'ean13':
      case 'ean_13':
        return ShopBarcodeType.ean13;
      case 'upc':
        return ShopBarcodeType.upc;
      case 'code128':
      case 'code_128':
        return ShopBarcodeType.code128;
      default:
        return ShopBarcodeType.internal;
    }
  }
}

class ShopProduct {
  final String productId;
  final String businessId;
  final String branchId;
  final String categoryId;
  final String name;
  final String description;
  final String sku;
  final String? barcode;
  final ShopBarcodeType barcodeType;
  final double costPrice;
  final double sellingPrice;
  final double stockQuantity;
  final double minStockAlert;
  final String unitOfMeasure; // e.g. "piece", "kg", "liter", "box"
  final bool isWeighable;
  final String? imageUrl;
  final List<ShopProductVariant> variants;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> customAttributes;

  const ShopProduct({
    required this.productId,
    required this.businessId,
    required this.branchId,
    required this.categoryId,
    required this.name,
    this.description = '',
    required this.sku,
    this.barcode,
    this.barcodeType = ShopBarcodeType.internal,
    required this.costPrice,
    required this.sellingPrice,
    required this.stockQuantity,
    this.minStockAlert = 5.0,
    this.unitOfMeasure = 'piece',
    this.isWeighable = false,
    this.imageUrl,
    this.variants = const [],
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
    this.customAttributes = const {},
  });

  /// هل المخزون وصل إلى حد الخطر ويحتاج إعادة طلب
  bool get isLowStock => stockQuantity <= minStockAlert && stockQuantity > 0;

  /// هل المنتج نافد تماماً من المخزن
  bool get isOutOfStock => stockQuantity <= 0;

  /// حساب هامش الربح النقدي
  double get grossProfit => sellingPrice - costPrice;

  /// حساب نسبة هامش الربح المئوية
  double get grossMarginPercentage {
    if (sellingPrice <= 0) return 0.0;
    return (grossProfit / sellingPrice) * 100.0;
  }

  /// القيمة الإجمالية للمخزون بسعر التكلفة
  double get totalInventoryCostValue => stockQuantity * costPrice;

  /// القيمة الإجمالية للمخزون بسعر البيع المتوقع
  double get totalInventoryRetailValue => stockQuantity * sellingPrice;

  /// الباركود الفعلي أو توليد باركود داخلي قياسي (200 + SKU)
  String get effectiveBarcode => barcode ?? '200${productId.hashCode.abs().toString().padLeft(10, '0')}';

  ShopProduct copyWith({
    String? productId,
    String? businessId,
    String? branchId,
    String? categoryId,
    String? name,
    String? description,
    String? sku,
    String? barcode,
    ShopBarcodeType? barcodeType,
    double? costPrice,
    double? sellingPrice,
    double? stockQuantity,
    double? minStockAlert,
    String? unitOfMeasure,
    bool? isWeighable,
    String? imageUrl,
    List<ShopProductVariant>? variants,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? customAttributes,
  }) {
    return ShopProduct(
      productId: productId ?? this.productId,
      businessId: businessId ?? this.businessId,
      branchId: branchId ?? this.branchId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      barcodeType: barcodeType ?? this.barcodeType,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      isWeighable: isWeighable ?? this.isWeighable,
      imageUrl: imageUrl ?? this.imageUrl,
      variants: variants ?? this.variants,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customAttributes: customAttributes ?? this.customAttributes,
    );
  }
}
