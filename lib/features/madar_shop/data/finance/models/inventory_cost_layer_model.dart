// نموذج بيانات طبقة تكلفة المخزون للتخزين (MADAR SHOP Inventory Cost Layer Model)
// Pure Dart — Zero UI Dependencies

import '../../../domain/finance/value_objects/inventory_cost_layer.dart';
import '../../../domain/inventory/value_objects/stock_quantity.dart';
import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';

class InventoryCostLayerModel {
  const InventoryCostLayerModel._();

  static Map<String, dynamic> toMap(InventoryCostLayer layer) {
    return {
      'id': layer.id,
      'businessId': layer.businessId,
      'branchId': layer.branchId,
      'productId': layer.productId,
      'variantId': layer.variantId,
      'sourceType': layer.sourceType,
      'sourceId': layer.sourceId,
      'quantityMilli': layer.quantity.milliUnits,
      'remainingQuantityMilli': layer.remainingQuantity.milliUnits,
      'unit': layer.quantity.unit.name,
      'unitCostUnits': layer.unitCost.minorUnits,
      'currency': layer.currency.code,
      'createdAt': layer.createdAt.toIso8601String(),
      'version': layer.version,
    };
  }

  static InventoryCostLayer fromMap(Map<String, dynamic> map) {
    final currency = Currency.fromCode(map['currency'] as String?);
    return InventoryCostLayer(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      branchId: map['branchId'] as String,
      productId: map['productId'] as String,
      variantId: map['variantId'] as String?,
      sourceType: map['sourceType'] as String,
      sourceId: map['sourceId'] as String,
      quantity: StockQuantity.fromMilliUnits(map['quantityMilli'] as int? ?? 1000),
      remainingQuantity: StockQuantity.fromMilliUnits(map['remainingQuantityMilli'] as int? ?? 1000),
      unitCost: Money.fromMinorUnits(map['unitCostUnits'] as int? ?? 0, currency),
      currency: currency,
      createdAt: DateTime.parse(map['createdAt'] as String),
      version: map['version'] as int? ?? 1,
    );
  }
}
