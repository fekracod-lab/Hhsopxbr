// كيان بند المرتجع للزبون (MADAR SHOP Return Item Entity)
// Pure Dart — Zero UI Dependencies

import '../../inventory/enums/return_restock_condition.dart';
import '../../inventory/value_objects/stock_quantity.dart';
import '../../pos/value_objects/money.dart';
import '../enums/return_reason.dart';

class ReturnItem {
  final String id;
  final String originalSaleItemId;
  final String productId;
  final String? variantId;
  final String descriptionSnapshot;
  final String skuSnapshot;
  final StockQuantity quantity;
  final Money unitRefundPrice;
  final Money unitDiscountDeduction;
  final Money unitTaxRefund;
  final Money originalCostBasis;
  final ReturnRestockCondition restockCondition;
  final ReturnReason reason;
  final String? reasonNotes;

  const ReturnItem({
    required this.id,
    required this.originalSaleItemId,
    required this.productId,
    this.variantId,
    required this.descriptionSnapshot,
    required this.skuSnapshot,
    required this.quantity,
    required this.unitRefundPrice,
    this.unitDiscountDeduction = const Money.fromMinorUnits(0),
    this.unitTaxRefund = const Money.fromMinorUnits(0),
    required this.originalCostBasis,
    this.restockCondition = ReturnRestockCondition.restock,
    this.reason = ReturnReason.customerChangedMind,
    this.reasonNotes,
  });

  /// صافي استرداد الوحدة الواحدة بعد الخصم وإضافة الضريبة المستردة
  Money get netUnitRefundPrice => (unitRefundPrice - unitDiscountDeduction) + unitTaxRefund;

  /// إجمالي الاسترداد المالي لهذا البند
  Money get lineRefundTotal => netUnitRefundPrice * quantity.toDouble();

  /// إجمالي التكلفة المعكوسة للبند (COGS Reversal Basis)
  Money get totalCostBasis => originalCostBasis * quantity.toDouble();

  /// هل الصنف مؤهل لإعادة التخزين في مخزون اليد المتاح
  bool get isRestockable => restockCondition.isRestockable;

  ReturnItem copyWith({
    String? id,
    String? originalSaleItemId,
    String? productId,
    String? variantId,
    String? descriptionSnapshot,
    String? skuSnapshot,
    StockQuantity? quantity,
    Money? unitRefundPrice,
    Money? unitDiscountDeduction,
    Money? unitTaxRefund,
    Money? originalCostBasis,
    ReturnRestockCondition? restockCondition,
    ReturnReason? reason,
    String? reasonNotes,
  }) {
    return ReturnItem(
      id: id ?? this.id,
      originalSaleItemId: originalSaleItemId ?? this.originalSaleItemId,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      descriptionSnapshot: descriptionSnapshot ?? this.descriptionSnapshot,
      skuSnapshot: skuSnapshot ?? this.skuSnapshot,
      quantity: quantity ?? this.quantity,
      unitRefundPrice: unitRefundPrice ?? this.unitRefundPrice,
      unitDiscountDeduction: unitDiscountDeduction ?? this.unitDiscountDeduction,
      unitTaxRefund: unitTaxRefund ?? this.unitTaxRefund,
      originalCostBasis: originalCostBasis ?? this.originalCostBasis,
      restockCondition: restockCondition ?? this.restockCondition,
      reason: reason ?? this.reason,
      reasonNotes: reasonNotes ?? this.reasonNotes,
    );
  }
}
