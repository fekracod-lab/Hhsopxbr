// لقطة سريعة لحالة المخزون للقراءة والاستعلام (MADAR SHOP Inventory Snapshot)
// Pure Dart — Zero UI Dependencies

import '../enums/stock_status.dart';
import '../value_objects/stock_unit.dart';
import 'inventory_item.dart';

class InventorySnapshot {
  final String inventoryId;
  final String businessId;
  final String branchId;
  final String productId;
  final String? variantId;
  final double onHandQuantity;
  final double reservedQuantity;
  final double availableQuantity;
  final StockUnit unit;
  final StockStatus status;
  final int version;
  final DateTime snapshotTime;

  const InventorySnapshot({
    required this.inventoryId,
    required this.businessId,
    required this.branchId,
    required this.productId,
    this.variantId,
    required this.onHandQuantity,
    required this.reservedQuantity,
    required this.availableQuantity,
    required this.unit,
    required this.status,
    required this.version,
    required this.snapshotTime,
  });

  factory InventorySnapshot.fromItem(InventoryItem item) {
    return InventorySnapshot(
      inventoryId: item.inventoryId,
      businessId: item.businessId,
      branchId: item.branchId,
      productId: item.productId,
      variantId: item.variantId,
      onHandQuantity: item.onHand.toDouble(),
      reservedQuantity: item.reserved.toDouble(),
      availableQuantity: item.available.toDouble(),
      unit: item.unit,
      status: item.status,
      version: item.version,
      snapshotTime: item.updatedAt,
    );
  }
}
