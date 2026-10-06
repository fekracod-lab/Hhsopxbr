// مستودع الموردين وحساباتهم في الذاكرة (MADAR SHOP Memory Supplier Repository)
// Pure Dart — Zero UI Dependencies

import '../../../domain/purchasing/entities/supplier.dart';
import '../../../domain/purchasing/entities/supplier_account.dart';
import '../../../domain/purchasing/repositories/i_supplier_repository.dart';

class MemorySupplierRepository implements ISupplierRepository {
  final Map<String, Supplier> _suppliers = {};
  final Map<String, SupplierAccount> _accounts = {};

  String _supplierKey(String businessId, String supplierId) => '$businessId:$supplierId';

  @override
  Future<Supplier?> getSupplierById({
    required String businessId,
    required String supplierId,
  }) async {
    return _suppliers[_supplierKey(businessId, supplierId)];
  }

  @override
  Future<List<Supplier>> getSuppliers({required String businessId}) async {
    return _suppliers.values.where((s) => s.businessId == businessId).toList();
  }

  @override
  Future<void> saveSupplier(Supplier supplier) async {
    _suppliers[_supplierKey(supplier.businessId, supplier.id)] = supplier;
  }

  @override
  Future<SupplierAccount?> getSupplierAccount({
    required String businessId,
    required String supplierId,
  }) async {
    return _accounts[_supplierKey(businessId, supplierId)];
  }

  @override
  Future<void> saveSupplierAccount(SupplierAccount account) async {
    _accounts[_supplierKey(account.businessId, account.supplierId)] = account;
  }

  void clear() {
    _suppliers.clear();
    _accounts.clear();
  }
}
