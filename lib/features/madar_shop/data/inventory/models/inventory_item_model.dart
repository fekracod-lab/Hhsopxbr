// نموذج بيانات صنف المخزون للتحويل من وإلى التخزين (MADAR SHOP Inventory Item Model)
// Pure Dart — Zero Flutter / Firebase SDK Dependencies

import '../../../domain/inventory/entities/inventory_item.dart';
import '../../../domain/inventory/enums/negative_stock_policy.dart';
import '../../../domain/inventory/value_objects/stock_quantity.dart';
import '../../../domain/inventory/value_objects/stock_unit.dart';

class InventoryItemModel {
  static Map<String, dynamic> toMap(InventoryItem item) {
    return {
      'inventoryId': item.inventoryId,
      'businessId': item.businessId,
      'branchId': item.branchId,
      'productId': item.productId,
      'variantId': item.variantId,
      'onHandMilliUnits': item.onHand.milliUnits,
      'reservedMilliUnits': item.reserved.milliUnits,
      'unit': item.unit.name,
      'version': item.version,
      'reorderPointMilliUnits': item.reorderPoint.milliUnits,
      'lowStockThresholdMilliUnits': item.lowStockThreshold.milliUnits,
      'negativeStockPolicy': item.negativeStockPolicy.name,
      'updatedAt': item.updatedAt.toIso8601String(),
    };
  }

  static InventoryItem fromMap(Map<String, dynamic> map) {
    final unit = StockUnit.values.firstWhere(
      (u) => u.name == map['unit'],
      orElse: () => StockUnit.piece,
    );

    final policy = NegativeStockPolicy.values.firstWhere(
      (p) => p.name == map['negativeStockPolicy'],
      orElse: () => NegativeStockPolicy.block,
    );

    return InventoryItem(
      inventoryId: map['inventoryId'] as String,
      businessId: map['businessId'] as String,
      branchId: map['branchId'] as String,
      productId: map['productId'] as String,
      variantId: map['variantId'] as String?,
      onHand: StockQuantity.fromMilliUnits(
        (map['onHandMilliUnits'] as num?)?.toInt() ?? 0,
        unit,
      ),
      reserved: StockQuantity.fromMilliUnits(
        (map['reservedMilliUnits'] as num?)?.toInt() ?? 0,
        unit,
      ),
      version: (map['version'] as num?)?.toInt() ?? 1,
      reorderPoint: StockQuantity.fromMilliUnits(
        (map['reorderPointMilliUnits'] as num?)?.toInt() ?? 5000,
        unit,
      ),
      lowStockThreshold: StockQuantity.fromMilliUnits(
        (map['lowStockThresholdMilliUnits'] as num?)?.toInt() ?? 2000,
        unit,
      ),
      negativeStockPolicy: policy,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
