// كيان المنتج المحلول لنقطة البيع (MADAR SHOP Resolved Product Entity)
// Pure Dart — Zero UI Dependencies

import '../value_objects/money.dart';

class ResolvedProduct {
  final String productId;
  final String sku;
  final String? barcode;
  final String name;
  final String? variantId;
  final String? variantTitle;
  final String unitOfMeasure;
  final Money price;
  final Money cost;
  final double stockQuantity;
  final bool isWeighable;
  final bool isAvailable;
  final Map<String, dynamic> metadata;

  const ResolvedProduct({
    required this.productId,
    required this.sku,
    this.barcode,
    required this.name,
    this.variantId,
    this.variantTitle,
    required this.unitOfMeasure,
    required this.price,
    required this.cost,
    required this.stockQuantity,
    this.isWeighable = false,
    this.isAvailable = true,
    this.metadata = const {},
  });
}
