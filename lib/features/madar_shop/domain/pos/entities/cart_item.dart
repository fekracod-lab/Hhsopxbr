// كيان بند سلة الشراء بنقطة البيع (MADAR SHOP POS Cart Item Entity)
// Pure Dart — Zero UI Dependencies

import '../value_objects/discount.dart';
import '../value_objects/money.dart';
import '../value_objects/pricing_snapshot.dart';

class CartItem {
  final String itemId;
  final String productId;
  final String? variantId;
  final String? variantTitle;
  final String sku;
  final String? barcode;
  final String name;
  final Money unitPrice;
  final Money costPrice;
  final double quantity;
  final String unitOfMeasure; // piece, kg, etc.
  final bool isWeighable;
  final Discount lineDiscount;
  final String? notes;
  final PricingSnapshot? pricingSnapshot;

  const CartItem({
    required this.itemId,
    required this.productId,
    this.variantId,
    this.variantTitle,
    required this.sku,
    this.barcode,
    required this.name,
    required this.unitPrice,
    required this.costPrice,
    required this.quantity,
    this.unitOfMeasure = 'piece',
    this.isWeighable = false,
    this.lineDiscount = const Discount.none(),
    this.notes,
    this.pricingSnapshot,
  });

  /// المجموع الفرعي قبل الخصم: الكمية × سعر الوحدة
  Money get lineSubtotal {
    if (quantity <= 0) return Money.zero(unitPrice.currency);
    return unitPrice * quantity;
  }

  /// قيمة الخصم المطبق على مستوى هذا البند
  Money get discountAmount => lineDiscount.calculateDiscountAmount(lineSubtotal);

  /// الصافي الإجمالي للبند بعد الخصم
  Money get lineTotal {
    final net = lineSubtotal - discountAmount;
    return net.isNegative ? Money.zero(unitPrice.currency) : net;
  }

  /// التكلفة الإجمالية للبند
  Money get totalCost {
    if (quantity <= 0) return Money.zero(costPrice.currency);
    return costPrice * quantity;
  }

  /// صافي هامش الربح المحقق من هذا البند
  Money get grossMargin => lineTotal - totalCost;

  CartItem copyWith({
    String? itemId,
    String? productId,
    String? variantId,
    String? variantTitle,
    String? sku,
    String? barcode,
    String? name,
    Money? unitPrice,
    Money? costPrice,
    double? quantity,
    String? unitOfMeasure,
    bool? isWeighable,
    Discount? lineDiscount,
    String? notes,
    PricingSnapshot? pricingSnapshot,
  }) {
    return CartItem(
      itemId: itemId ?? this.itemId,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      variantTitle: variantTitle ?? this.variantTitle,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      costPrice: costPrice ?? this.costPrice,
      quantity: quantity ?? this.quantity,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      isWeighable: isWeighable ?? this.isWeighable,
      lineDiscount: lineDiscount ?? this.lineDiscount,
      notes: notes ?? this.notes,
      pricingSnapshot: pricingSnapshot ?? this.pricingSnapshot,
    );
  }
}
