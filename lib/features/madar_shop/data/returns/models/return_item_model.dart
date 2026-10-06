// نموذج بيانات بند المرتجع للتخزين (MADAR SHOP Return Item Model)
// Pure Dart — Zero UI Dependencies

import '../../../domain/inventory/enums/return_restock_condition.dart';
import '../../../domain/inventory/value_objects/stock_quantity.dart';
import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/returns/entities/return_item.dart';
import '../../../domain/returns/enums/return_reason.dart';

class ReturnItemModel {
  const ReturnItemModel._();

  static Map<String, dynamic> toMap(ReturnItem item) {
    return {
      'id': item.id,
      'originalSaleItemId': item.originalSaleItemId,
      'productId': item.productId,
      'variantId': item.variantId,
      'descriptionSnapshot': item.descriptionSnapshot,
      'skuSnapshot': item.skuSnapshot,
      'quantityMilli': item.quantity.milliUnits,
      'unit': item.quantity.unit.name,
      'unitRefundPriceUnits': item.unitRefundPrice.minorUnits,
      'unitDiscountDeductionUnits': item.unitDiscountDeduction.minorUnits,
      'unitTaxRefundUnits': item.unitTaxRefund.minorUnits,
      'originalCostBasisUnits': item.originalCostBasis.minorUnits,
      'currency': item.unitRefundPrice.currency.code,
      'restockCondition': item.restockCondition.name,
      'reason': item.reason.name,
      'reasonNotes': item.reasonNotes,
    };
  }

  static ReturnItem fromMap(Map<String, dynamic> map, [Currency defaultCurrency = Currency.iqd]) {
    final currency = Currency.fromCode(map['currency'] as String?);
    return ReturnItem(
      id: map['id'] as String,
      originalSaleItemId: map['originalSaleItemId'] as String,
      productId: map['productId'] as String,
      variantId: map['variantId'] as String?,
      descriptionSnapshot: map['descriptionSnapshot'] as String? ?? '',
      skuSnapshot: map['skuSnapshot'] as String? ?? '',
      quantity: StockQuantity.fromMilliUnits(map['quantityMilli'] as int? ?? 1000),
      unitRefundPrice: Money.fromMinorUnits(map['unitRefundPriceUnits'] as int? ?? 0, currency),
      unitDiscountDeduction: Money.fromMinorUnits(map['unitDiscountDeductionUnits'] as int? ?? 0, currency),
      unitTaxRefund: Money.fromMinorUnits(map['unitTaxRefundUnits'] as int? ?? 0, currency),
      originalCostBasis: Money.fromMinorUnits(map['originalCostBasisUnits'] as int? ?? 0, currency),
      restockCondition: ReturnRestockCondition.values.firstWhere(
        (e) => e.name == map['restockCondition'],
        orElse: () => ReturnRestockCondition.restock,
      ),
      reason: ReturnReason.fromString(map['reason'] as String?),
      reasonNotes: map['reasonNotes'] as String?,
    );
  }
}
