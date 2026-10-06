// كيان بند الفاتورة المباعة التاريخية (MADAR SHOP Sale Item Entity)
// Pure Dart — Zero UI Dependencies

import '../value_objects/money.dart';
import '../value_objects/pricing_snapshot.dart';

class SaleItem {
  final String itemId;
  final String productId;
  final String? variantId;
  final String? variantTitle;
  final String sku;
  final String? barcode;
  final String name;
  final PricingSnapshot pricingSnapshot;
  final double quantity;
  final String unitOfMeasure;
  final bool isWeighable;
  final Money lineDiscount;
  final Money lineTax;
  final String? notes;

  const SaleItem({
    required this.itemId,
    required this.productId,
    this.variantId,
    this.variantTitle,
    required this.sku,
    this.barcode,
    required this.name,
    required this.pricingSnapshot,
    required this.quantity,
    this.unitOfMeasure = 'piece',
    this.isWeighable = false,
    required this.lineDiscount,
    required this.lineTax,
    this.notes,
  });

  /// المجموع الفرعي قبل الخصم والضريبة
  Money get lineSubtotal => pricingSnapshot.unitPrice * quantity;

  /// الصافي الإجمالي للبند
  Money get lineTotal => lineSubtotal - lineDiscount + lineTax;

  /// إجمالي التكلفة للبند
  Money get totalCost => pricingSnapshot.costPrice * quantity;

  /// صافي الربح للبند
  Money get grossProfit => (lineSubtotal - lineDiscount) - totalCost;
}
