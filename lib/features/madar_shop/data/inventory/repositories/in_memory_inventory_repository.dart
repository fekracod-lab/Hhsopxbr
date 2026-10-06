// تنفيذ مستودع أصناف المخزون في الذاكرة (In-Memory Inventory Repository)
// Pure Dart — Zero Flutter / Firebase SDK Dependencies

import '../../../domain/inventory/entities/inventory_item.dart';
import '../../../domain/inventory/repositories/i_inventory_repository.dart';

class InMemoryInventoryRepository implements IInventoryRepository {
  final Map<String, InventoryItem> _items = {};

  String _buildKey(String businessId, String branchId, String productId, String? variantId) {
    return '$businessId:$branchId:$productId:${variantId ?? "default"}';
  }

  @override
  Future<InventoryItem?> getInventoryItem({
    required String businessId,
    required String branchId,
    required String productId,
    String? variantId,
  }) async {
    final key = _buildKey(businessId, branchId, productId, variantId);
    return _items[key];
  }

  @override
  Future<void> saveInventoryItem(InventoryItem item) async {
    final key = _buildKey(item.businessId, item.branchId, item.productId, item.variantId);
    _items[key] = item;
  }

  @override
  Future<List<InventoryItem>> listBranchInventory({
    required String businessId,
    required String branchId,
  }) async {
    return _items.values
        .where((item) => item.businessId == businessId && item.branchId == branchId)
        .toList(growable: false);
  }

  @override
  Future<List<InventoryItem>> getLowStockItems({
    required String businessId,
    required String branchId,
  }) async {
    return _items.values
        .where((item) =>
            item.businessId == businessId &&
            item.branchId == branchId &&
            (item.isLowStock || item.isOutOfStock))
        .toList(growable: false);
  }

  void clear() {
    _items.clear();
  }
}
