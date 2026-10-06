// التنفيذ الفعلي لمستودع الذاكرة المؤقتة المحلية (MADAR SHOP Local Cache Repository)
// Pure Dart — Zero UI Dependencies

import '../../../domain/sync/contracts/i_cache_repository.dart';
import '../../../domain/sync/contracts/i_local_database.dart';
import '../../../domain/sync/entities/cached_entities.dart';

class LocalCacheRepository implements ICacheRepository {
  static const String tableProducts = 'cached_products';
  static const String tableInventory = 'cached_inventory';
  static const String tableCustomers = 'cached_customers';
  static const String tableSuppliers = 'cached_suppliers';

  final ILocalDatabase _db;

  LocalCacheRepository(this._db);

  @override
  Future<void> saveProduct(CachedProduct product, {ILocalTransaction? tx}) async {
    final existing = await getProduct(product.id);
    final row = product.toJson();

    if (existing != null) {
      if (tx != null) {
        await tx.update(tableProducts, row, where: 'id = ?', whereArgs: [product.id]);
      } else {
        await _db.update(tableProducts, row, where: 'id = ?', whereArgs: [product.id]);
      }
    } else {
      if (tx != null) {
        await tx.insert(tableProducts, row);
      } else {
        await _db.insert(tableProducts, row);
      }
    }
  }

  @override
  Future<CachedProduct?> getProduct(String id) async {
    final row = await _db.findById(tableProducts, 'id', id);
    if (row == null) return null;
    return CachedProduct.fromJson(row);
  }

  @override
  Future<CachedProduct?> getProductByBarcode(String barcode) async {
    final rows = await _db.query(
      tableProducts,
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CachedProduct.fromJson(rows.first);
  }

  @override
  Future<List<CachedProduct>> getAllProducts() async {
    final rows = await _db.query(tableProducts, orderBy: 'nameAr ASC');
    return rows.map((r) => CachedProduct.fromJson(r)).toList();
  }

  @override
  Future<void> saveInventory(CachedInventory inventory, {ILocalTransaction? tx}) async {
    final existing = await getInventory(inventory.productId, inventory.branchId);
    final row = inventory.toJson();

    if (existing != null) {
      if (tx != null) {
        await tx.update(
          tableInventory,
          row,
          where: 'productId = ? AND branchId = ?',
          whereArgs: [inventory.productId, inventory.branchId],
        );
      } else {
        await _db.update(
          tableInventory,
          row,
          where: 'productId = ? AND branchId = ?',
          whereArgs: [inventory.productId, inventory.branchId],
        );
      }
    } else {
      if (tx != null) {
        await tx.insert(tableInventory, row);
      } else {
        await _db.insert(tableInventory, row);
      }
    }
  }

  @override
  Future<CachedInventory?> getInventory(String productId, String branchId) async {
    final rows = await _db.query(
      tableInventory,
      where: 'productId = ? AND branchId = ?',
      whereArgs: [productId, branchId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CachedInventory.fromJson(rows.first);
  }

  @override
  Future<void> saveCustomer(CachedCustomer customer, {ILocalTransaction? tx}) async {
    final existing = await getCustomer(customer.id);
    final row = customer.toJson();

    if (existing != null) {
      if (tx != null) {
        await tx.update(tableCustomers, row, where: 'id = ?', whereArgs: [customer.id]);
      } else {
        await _db.update(tableCustomers, row, where: 'id = ?', whereArgs: [customer.id]);
      }
    } else {
      if (tx != null) {
        await tx.insert(tableCustomers, row);
      } else {
        await _db.insert(tableCustomers, row);
      }
    }
  }

  @override
  Future<CachedCustomer?> getCustomer(String id) async {
    final row = await _db.findById(tableCustomers, 'id', id);
    if (row == null) return null;
    return CachedCustomer.fromJson(row);
  }

  @override
  Future<void> saveSupplier(CachedSupplier supplier, {ILocalTransaction? tx}) async {
    final existing = await getSupplier(supplier.id);
    final row = supplier.toJson();

    if (existing != null) {
      if (tx != null) {
        await tx.update(tableSuppliers, row, where: 'id = ?', whereArgs: [supplier.id]);
      } else {
        await _db.update(tableSuppliers, row, where: 'id = ?', whereArgs: [supplier.id]);
      }
    } else {
      if (tx != null) {
        await tx.insert(tableSuppliers, row);
      } else {
        await _db.insert(tableSuppliers, row);
      }
    }
  }

  @override
  Future<CachedSupplier?> getSupplier(String id) async {
    final row = await _db.findById(tableSuppliers, 'id', id);
    if (row == null) return null;
    return CachedSupplier.fromJson(row);
  }

  @override
  Future<int> purgeExpiredCache(DateTime cutoff) async {
    final products = await _db.query(tableProducts);
    int purged = 0;
    for (final p in products) {
      final fetchedAt = DateTime.parse(p['fetchedAt'] as String);
      if (fetchedAt.isBefore(cutoff)) {
        await _db.delete(tableProducts, where: 'id = ?', whereArgs: [p['id']]);
        purged++;
      }
    }
    return purged;
  }
}
