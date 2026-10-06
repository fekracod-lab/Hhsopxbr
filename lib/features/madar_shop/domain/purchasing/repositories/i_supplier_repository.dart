// واجهة مستودع الموردين وحساباتهم (MADAR SHOP Supplier Repository Contract)
// Pure Dart — Zero UI Dependencies

import '../entities/supplier.dart';
import '../entities/supplier_account.dart';

abstract class ISupplierRepository {
  Future<Supplier?> getSupplierById({
    required String businessId,
    required String supplierId,
  });

  Future<List<Supplier>> getSuppliers({
    required String businessId,
  });

  Future<void> saveSupplier(Supplier supplier);

  Future<SupplierAccount?> getSupplierAccount({
    required String businessId,
    required String supplierId,
  });

  Future<void> saveSupplierAccount(SupplierAccount account);
}
