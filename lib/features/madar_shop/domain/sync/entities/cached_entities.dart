// الكيانات المخزنة محلياً لدعم العمليات الحيوية بدون اتصال (MADAR SHOP Cached Entities)
// Pure Dart — Zero UI Dependencies

import '../enums/cache_freshness.dart';

class CachedProduct {
  final String id;
  final String sku;
  final String barcode;
  final String nameAr;
  final int priceMinorUnits;
  final int costMinorUnits;
  final String? variantId;
  final int version;
  final DateTime fetchedAt;

  const CachedProduct({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.nameAr,
    required this.priceMinorUnits,
    required this.costMinorUnits,
    this.variantId,
    required this.version,
    required this.fetchedAt,
  });

  CacheFreshness getFreshness({
    Duration freshDuration = const Duration(hours: 4),
    Duration expiredDuration = const Duration(days: 7),
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final age = current.difference(fetchedAt);
    if (age <= freshDuration) return CacheFreshness.fresh;
    if (age <= expiredDuration) return CacheFreshness.stale;
    return CacheFreshness.expired;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sku': sku,
        'barcode': barcode,
        'nameAr': nameAr,
        'priceMinorUnits': priceMinorUnits,
        'costMinorUnits': costMinorUnits,
        'variantId': variantId,
        'version': version,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory CachedProduct.fromJson(Map<String, dynamic> json) {
    return CachedProduct(
      id: json['id'] as String,
      sku: json['sku'] as String,
      barcode: json['barcode'] as String,
      nameAr: json['nameAr'] as String,
      priceMinorUnits: (json['priceMinorUnits'] as num).toInt(),
      costMinorUnits: (json['costMinorUnits'] as num).toInt(),
      variantId: json['variantId'] as String?,
      version: (json['version'] as num).toInt(),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
    );
  }
}

class CachedInventory {
  final String productId;
  final String branchId;
  final double onHandQuantity;
  final double reservedQuantity;
  final double offlineReservedQuantity;
  final int version;
  final DateTime fetchedAt;

  const CachedInventory({
    required this.productId,
    required this.branchId,
    required this.onHandQuantity,
    this.reservedQuantity = 0.0,
    this.offlineReservedQuantity = 0.0,
    required this.version,
    required this.fetchedAt,
  });

  /// الكمية المتوفرة للبيع محلياً بعد استقطاع المحجوز المركزي والمحجوز محلياً
  double get localAvailableQuantity {
    final available = onHandQuantity - reservedQuantity - offlineReservedQuantity;
    return available > 0 ? available : 0.0;
  }

  CachedInventory reserveOffline(double quantity) {
    return CachedInventory(
      productId: productId,
      branchId: branchId,
      onHandQuantity: onHandQuantity,
      reservedQuantity: reservedQuantity,
      offlineReservedQuantity: offlineReservedQuantity + quantity,
      version: version,
      fetchedAt: fetchedAt,
    );
  }

  CachedInventory releaseOffline(double quantity) {
    final newOffline = offlineReservedQuantity - quantity;
    return CachedInventory(
      productId: productId,
      branchId: branchId,
      onHandQuantity: onHandQuantity,
      reservedQuantity: reservedQuantity,
      offlineReservedQuantity: newOffline > 0 ? newOffline : 0.0,
      version: version,
      fetchedAt: fetchedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'branchId': branchId,
        'onHandQuantity': onHandQuantity,
        'reservedQuantity': reservedQuantity,
        'offlineReservedQuantity': offlineReservedQuantity,
        'version': version,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory CachedInventory.fromJson(Map<String, dynamic> json) {
    return CachedInventory(
      productId: json['productId'] as String,
      branchId: json['branchId'] as String,
      onHandQuantity: (json['onHandQuantity'] as num).toDouble(),
      reservedQuantity: (json['reservedQuantity'] as num?)?.toDouble() ?? 0.0,
      offlineReservedQuantity:
          (json['offlineReservedQuantity'] as num?)?.toDouble() ?? 0.0,
      version: (json['version'] as num).toInt(),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
    );
  }
}

class CachedCustomer {
  final String id;
  final String name;
  final String phone;
  final int creditBalanceMinorUnits;
  final int creditLimitMinorUnits;
  final int version;
  final DateTime fetchedAt;

  const CachedCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.creditBalanceMinorUnits,
    required this.creditLimitMinorUnits,
    required this.version,
    required this.fetchedAt,
  });

  int get availableCreditMinorUnits {
    final rem = creditLimitMinorUnits - creditBalanceMinorUnits;
    return rem > 0 ? rem : 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'creditBalanceMinorUnits': creditBalanceMinorUnits,
        'creditLimitMinorUnits': creditLimitMinorUnits,
        'version': version,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory CachedCustomer.fromJson(Map<String, dynamic> json) {
    return CachedCustomer(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      creditBalanceMinorUnits: (json['creditBalanceMinorUnits'] as num).toInt(),
      creditLimitMinorUnits: (json['creditLimitMinorUnits'] as num).toInt(),
      version: (json['version'] as num).toInt(),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
    );
  }
}

class CachedSupplier {
  final String id;
  final String name;
  final int balanceMinorUnits;
  final int version;
  final DateTime fetchedAt;

  const CachedSupplier({
    required this.id,
    required this.name,
    required this.balanceMinorUnits,
    required this.version,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'balanceMinorUnits': balanceMinorUnits,
        'version': version,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory CachedSupplier.fromJson(Map<String, dynamic> json) {
    return CachedSupplier(
      id: json['id'] as String,
      name: json['name'] as String,
      balanceMinorUnits: (json['balanceMinorUnits'] as num).toInt(),
      version: (json['version'] as num).toInt(),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
    );
  }
}
