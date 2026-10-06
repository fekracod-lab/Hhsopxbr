// واجهة مستودع أصناف المخزون (MADAR SHOP Inventory Repository Interface)
// Pure Dart — Zero UI Dependencies

import '../entities/inventory_item.dart';

abstract class IInventoryRepository {
  /// جلب صنف المخزون المحدد بالنشاط والفرع والمنتج والمتغير
  Future<InventoryItem?> getInventoryItem({
    required String businessId,
    required String branchId,
    required String productId,
    String? variantId,
  });

  /// حفظ أو تحديث صنف المخزون
  Future<void> saveInventoryItem(InventoryItem item);

  /// جلب كافة أصناف المخزون لفرع محدد
  Future<List<InventoryItem>> listBranchInventory({
    required String businessId,
    required String branchId,
  });

  /// جلب الأصناف التي بلغت حد المخزون المنخفض أو النفاد
  Future<List<InventoryItem>> getLowStockItems({
    required String businessId,
    required String branchId,
  });
}
