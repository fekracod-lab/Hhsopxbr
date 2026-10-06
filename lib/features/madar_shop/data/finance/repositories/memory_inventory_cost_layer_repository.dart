// مستودع طبقات تكلفة المخزون في الذاكرة (MADAR SHOP Memory Inventory Cost Layer Repository)
// Pure Dart — Zero UI Dependencies

import '../../../domain/finance/repositories/i_inventory_cost_layer_repository.dart';
import '../../../domain/finance/value_objects/inventory_cost_layer.dart';

class MemoryInventoryCostLayerRepository implements IInventoryCostLayerRepository {
  final Map<String, InventoryCostLayer> _store = {};

  @override
  Future<List<InventoryCostLayer>> getLayersForProduct({
    required String businessId,
    required String branchId,
    required String productId,
    String? variantId,
  }) async {
    return _store.values.where((l) {
      if (l.businessId != businessId) return false;
      if (l.branchId != branchId) return false;
      if (l.productId != productId) return false;
      if (variantId != null && l.variantId != variantId) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<InventoryCostLayer>> getAllLayers({
    required String businessId,
    String? branchId,
  }) async {
    return _store.values.where((l) {
      if (l.businessId != businessId) return false;
      if (branchId != null && l.branchId != branchId) return false;
      return true;
    }).toList();
  }

  @override
  Future<void> saveLayer(InventoryCostLayer layer) async {
    _store[layer.id] = layer;
  }

  @override
  Future<void> saveLayers(List<InventoryCostLayer> layers) async {
    for (final l in layers) {
      _store[l.id] = l;
    }
  }

  void clear() => _store.clear();
}
