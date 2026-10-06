// عقد مستودع الذاكرة المحلية المؤقتة للبيانات الحيوية (MADAR SHOP ICacheRepository)
// Pure Dart — Zero UI Dependencies

import '../entities/cached_entities.dart';
import 'i_local_database.dart';

abstract class ICacheRepository {
  Future<void> saveProduct(CachedProduct product, {ILocalTransaction? tx});
  Future<CachedProduct?> getProduct(String id);
  Future<CachedProduct?> getProductByBarcode(String barcode);
  Future<List<CachedProduct>> getAllProducts();

  Future<void> saveInventory(CachedInventory inventory, {ILocalTransaction? tx});
  Future<CachedInventory?> getInventory(String productId, String branchId);

  Future<void> saveCustomer(CachedCustomer customer, {ILocalTransaction? tx});
  Future<CachedCustomer?> getCustomer(String id);

  Future<void> saveSupplier(CachedSupplier supplier, {ILocalTransaction? tx});
  Future<CachedSupplier?> getSupplier(String id);

  Future<int> purgeExpiredCache(DateTime cutoff);
}
