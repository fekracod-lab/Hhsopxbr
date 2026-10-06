// عقود جسر الماركت بليس مع تطبيق مدار العام (Marketplace Bridge Contracts)
// Pure Dart — Zero UI Dependencies

import 'marketplace_sync_entity.dart';
import '../entities/shop_product.dart';

abstract class IMarketplaceBridgeRepository {
  /// نشر منتج جديد أو تحديث بياناته في الماركت بليس
  Future<void> publishProduct({
    required ShopProduct product,
    required MarketplaceSyncEntity syncConfig,
  });

  /// إخفاء منتج مؤقتاً من الماركت بليس
  Future<void> hideProductFromMarketplace({
    required String productId,
    required String businessId,
  });

  /// مزامنة سريعة لكمية المخزون وسعر المنتج مع الماركت بليس
  Future<void> syncStockAndPrice({
    required String productId,
    required String businessId,
    required double updatedPhysicalStock,
    required double sellingPrice,
    double? priceOverride,
  });

  /// جلب حالة مزامنة المنتج
  Future<MarketplaceSyncEntity?> getProductSyncStatus({
    required String productId,
    required String businessId,
  });

  /// جلب كافة المنتجات المعروضة في الماركت بليس لمتجر معين
  Future<List<MarketplaceSyncEntity>> getMarketplaceCatalog({
    required String businessId,
    required String branchId,
  });
}
