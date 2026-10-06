// عقد مستودع مرتجعات المشتريات للموردين (MADAR SHOP Supplier Return Repository Interface)
// Pure Dart — Zero UI Dependencies

import '../entities/supplier_return.dart';

abstract class ISupplierReturnRepository {
  Future<SupplierReturn?> getSupplierReturnById({
    required String businessId,
    required String supplierReturnId,
  });

  Future<List<SupplierReturn>> getSupplierReturnsForPurchase({
    required String businessId,
    required String purchaseId,
  });

  Future<List<SupplierReturn>> getSupplierReturns({
    required String businessId,
    String? supplierId,
    String? branchId,
    DateTime? from,
    DateTime? to,
  });

  Future<void> saveSupplierReturn(SupplierReturn supplierReturn);
}
