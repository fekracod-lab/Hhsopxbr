// مخصص ومراقب المخزون بدون اتصال (MADAR SHOP Offline Stock Allocator)
// Pure Dart — Zero UI Dependencies — Strictly Forbids Negative Stock

import '../../../domain/sync/contracts/i_cache_repository.dart';
import '../../../domain/sync/contracts/i_local_database.dart';
import '../../../domain/sync/entities/cached_entities.dart';
import '../../../domain/sync/failures/sync_failures.dart';
import '../../../domain/sync/value_objects/offline_policy.dart';

class OfflineStockAllocator {
  final ICacheRepository _cacheRepo;
  final OfflinePolicy _policy;

  OfflineStockAllocator({
    required ICacheRepository cacheRepo,
    OfflinePolicy? policy,
  })  : _cacheRepo = cacheRepo,
        _policy = policy ?? const OfflinePolicy();

  /// التحقق من كفاية المخزون المحلي وحجزه مؤقتاً للبيع أوفلاين
  Future<CachedInventory> reserveStockOffline({
    required String productId,
    required String branchId,
    required double requestedQuantity,
    ILocalTransaction? tx,
  }) async {
    if (requestedQuantity <= 0) {
      throw ArgumentError('Requested quantity must be strictly positive');
    }

    final cached = await _cacheRepo.getInventory(productId, branchId);
    if (cached == null) {
      throw SyncInsufficientStockFailure(productId, requestedQuantity, 0.0);
    }

    // حساب الكمية المتاحة محلياً
    final available = cached.localAvailableQuantity;
    final maxAllowedToSellOffline = available * _policy.offlineStockAllowanceRatio;

    // منع الرصيد السالب وقواعد السقف الأوفلاين
    if (requestedQuantity > available || (!_policy.allowNegativeStock && requestedQuantity > maxAllowedToSellOffline)) {
      throw SyncInsufficientStockFailure(productId, requestedQuantity, available);
    }

    // حجز المخزون محلياً
    final updated = cached.reserveOffline(requestedQuantity);
    await _cacheRepo.saveInventory(updated, tx: tx);
    return updated;
  }

  /// تحرير الحجز المحلي للمخزون (عند إلغاء السلة أو فشل العملية)
  Future<CachedInventory> releaseStockOffline({
    required String productId,
    required String branchId,
    required double quantity,
    ILocalTransaction? tx,
  }) async {
    final cached = await _cacheRepo.getInventory(productId, branchId);
    if (cached == null) {
      throw SyncInsufficientStockFailure(productId, quantity, 0.0);
    }

    final updated = cached.releaseOffline(quantity);
    await _cacheRepo.saveInventory(updated, tx: tx);
    return updated;
  }
}
