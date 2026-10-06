// عقد مستودع طبقات تكلفة المخزون (MADAR SHOP Inventory Cost Layer Repository Interface)
// Pure Dart — Zero UI Dependencies

import '../value_objects/inventory_cost_layer.dart';

abstract class IInventoryCostLayerRepository {
  Future<List<InventoryCostLayer>> getLayersForProduct({
    required String businessId,
    required String branchId,
    required String productId,
    String? variantId,
  });

  Future<List<InventoryCostLayer>> getAllLayers({
    required String businessId,
    String? branchId,
  });

  Future<void> saveLayer(InventoryCostLayer layer);

  Future<void> saveLayers(List<InventoryCostLayer> layers);
}
