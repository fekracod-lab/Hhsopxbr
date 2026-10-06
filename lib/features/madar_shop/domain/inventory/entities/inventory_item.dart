// كيان صنف المخزون الكلي (MADAR SHOP Inventory Item Aggregate)
// Pure Dart — Zero UI Dependencies

import '../enums/negative_stock_policy.dart';
import '../enums/stock_status.dart';
import '../value_objects/inventory_item_key.dart';
import '../value_objects/stock_quantity.dart';
import '../value_objects/stock_unit.dart';

class InventoryItem {
  final String inventoryId;
  final String businessId;
  final String branchId;
  final String productId;
  final String? variantId;
  final StockQuantity onHand;
  final StockQuantity reserved;
  final int version; // للتحكم في التزامن المتفائل ومنع تضارب التعديلات
  final StockQuantity reorderPoint;
  final StockQuantity lowStockThreshold;
  final NegativeStockPolicy negativeStockPolicy;
  final DateTime updatedAt;

  const InventoryItem({
    required this.inventoryId,
    required this.businessId,
    required this.branchId,
    required this.productId,
    this.variantId,
    required this.onHand,
    required this.reserved,
    this.version = 1,
    required this.reorderPoint,
    required this.lowStockThreshold,
    this.negativeStockPolicy = NegativeStockPolicy.block,
    required this.updatedAt,
  });

  /// إنشاء صنف مخزني جديد برصيد افتتاحي
  factory InventoryItem.initialize({
    required String inventoryId,
    required String businessId,
    required String branchId,
    required String productId,
    String? variantId,
    StockQuantity? initialOnHand,
    StockUnit unit = StockUnit.piece,
    StockQuantity? reorderPoint,
    StockQuantity? lowStockThreshold,
    NegativeStockPolicy policy = NegativeStockPolicy.block,
  }) {
    final onHand = initialOnHand ?? StockQuantity.zero(unit);
    final zero = StockQuantity.zero(unit);

    return InventoryItem(
      inventoryId: inventoryId,
      businessId: businessId,
      branchId: branchId,
      productId: productId,
      variantId: variantId,
      onHand: onHand,
      reserved: zero,
      version: 1,
      reorderPoint: reorderPoint ?? StockQuantity.fromDouble(5.0, unit),
      lowStockThreshold: lowStockThreshold ?? StockQuantity.fromDouble(2.0, unit),
      negativeStockPolicy: policy,
      updatedAt: DateTime.now(),
    );
  }

  InventoryItemKey get key => InventoryItemKey(
        businessId: businessId,
        branchId: branchId,
        productId: productId,
        variantId: variantId,
      );

  StockUnit get unit => onHand.unit;

  /// الرصيد المتاح للبيع الفعلي = الرصيد الفعلي - المحجوز
  StockQuantity get available => onHand - reserved;

  /// تحديد الحالة المشتقة للمخزون
  StockStatus get status {
    if (available.isNegative) {
      return StockStatus.negative;
    }
    if (available.isZero) {
      return StockStatus.outOfStock;
    }
    if (available <= lowStockThreshold || available <= reorderPoint) {
      return StockStatus.lowStock;
    }
    return StockStatus.inStock;
  }

  bool get isOutOfStock => status == StockStatus.outOfStock;
  bool get isLowStock => status == StockStatus.lowStock;

  InventoryItem copyWith({
    String? inventoryId,
    String? businessId,
    String? branchId,
    String? productId,
    String? variantId,
    StockQuantity? onHand,
    StockQuantity? reserved,
    int? version,
    StockQuantity? reorderPoint,
    StockQuantity? lowStockThreshold,
    NegativeStockPolicy? negativeStockPolicy,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      inventoryId: inventoryId ?? this.inventoryId,
      businessId: businessId ?? this.businessId,
      branchId: branchId ?? this.branchId,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      onHand: onHand ?? this.onHand,
      reserved: reserved ?? this.reserved,
      version: version ?? this.version,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      negativeStockPolicy: negativeStockPolicy ?? this.negativeStockPolicy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
