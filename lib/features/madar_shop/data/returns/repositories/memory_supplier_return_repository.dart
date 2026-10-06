// مستودع مرتجعات الموردين في الذاكرة (MADAR SHOP Memory Supplier Return Repository)
// Pure Dart — Zero UI Dependencies

import '../../../domain/returns/entities/supplier_return.dart';
import '../../../domain/returns/repositories/i_supplier_return_repository.dart';

class MemorySupplierReturnRepository implements ISupplierReturnRepository {
  final Map<String, SupplierReturn> _store = {};

  @override
  Future<SupplierReturn?> getSupplierReturnById({
    required String businessId,
    required String supplierReturnId,
  }) async {
    final ret = _store[supplierReturnId];
    if (ret != null && ret.businessId == businessId) return ret;
    return null;
  }

  @override
  Future<List<SupplierReturn>> getSupplierReturnsForPurchase({
    required String businessId,
    required String purchaseId,
  }) async {
    return _store.values
        .where((r) => r.businessId == businessId && r.originalPurchaseId == purchaseId)
        .toList();
  }

  @override
  Future<List<SupplierReturn>> getSupplierReturns({
    required String businessId,
    String? supplierId,
    String? branchId,
    DateTime? from,
    DateTime? to,
  }) async {
    return _store.values.where((r) {
      if (r.businessId != businessId) return false;
      if (supplierId != null && r.supplierId != supplierId) return false;
      if (branchId != null && r.branchId != branchId) return false;
      if (from != null && r.createdAt.isBefore(from)) return false;
      if (to != null && r.createdAt.isAfter(to)) return false;
      return true;
    }).toList();
  }

  @override
  Future<void> saveSupplierReturn(SupplierReturn supplierReturn) async {
    _store[supplierReturn.id] = supplierReturn;
  }

  void clear() => _store.clear();
}
