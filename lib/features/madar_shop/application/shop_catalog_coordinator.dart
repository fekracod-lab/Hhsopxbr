// منسق إدارة المنتجات والمخزون والتسعير (MADAR SHOP Catalog Coordinator)
// Application Layer — Decoupled State & Orchestration

import '../domain/products/entities/shop_product.dart';
import '../domain/products/marketplace_bridge/marketplace_bridge_contracts.dart';
import '../domain/products/marketplace_bridge/marketplace_sync_entity.dart';

class ShopCatalogCoordinator {
  final IMarketplaceBridgeRepository _marketplaceBridge;

  ShopCatalogCoordinator({
    required IMarketplaceBridgeRepository marketplaceBridge,
  }) : _marketplaceBridge = marketplaceBridge;

  /// فحص وحصر المنتجات التي وصلت لحد الخطر لإشعار التاجر
  List<ShopProduct> filterLowStockProducts(List<ShopProduct> products) {
    return products.where((p) => p.isLowStock && !p.isArchived).toList();
  }

  /// فحص وحصر المنتجات النافدة تماماً
  List<ShopProduct> filterOutOfStockProducts(List<ShopProduct> products) {
    return products.where((p) => p.isOutOfStock && !p.isArchived).toList();
  }

  /// حساب القيمة المالية الإجمالية لكامل المخزون الحالي بسعر التكلفة
  double calculateTotalInventoryCost(List<ShopProduct> products) {
    return products.fold(
      0.0,
      (acc, p) => p.isArchived ? acc : acc + p.totalInventoryCostValue,
    );
  }

  /// حساب القيمة المالية الإجمالية لكامل المخزون بسعر البيع المتوقع
  double calculateTotalInventoryRetailValue(List<ShopProduct> products) {
    return products.fold(
      0.0,
      (acc, p) => p.isArchived ? acc : acc + p.totalInventoryRetailValue,
    );
  }

  /// مزامنة تحديث كمية المخزون مع الماركت بليس تلقائياً
  Future<void> syncStockChangeToMarketplace({
    required ShopProduct product,
    required double newStockQuantity,
  }) async {
    final updatedProduct = product.copyWith(
      stockQuantity: newStockQuantity,
      updatedAt: DateTime.now(),
    );

    await _marketplaceBridge.syncStockAndPrice(
      productId: updatedProduct.productId,
      businessId: updatedProduct.businessId,
      updatedPhysicalStock: newStockQuantity,
      sellingPrice: updatedProduct.sellingPrice,
    );
  }

  /// نشر منتج إلى منصة وتطبيق مدار مع تطبيق إعدادات الماركت بليس
  Future<void> publishProductToMadar({
    required ShopProduct product,
    double? marketplacePriceOverride,
    double onlineStockBuffer = 0.0,
    bool isFeatured = false,
  }) async {
    final syncConfig = MarketplaceSyncEntity(
      productId: product.productId,
      businessId: product.businessId,
      branchId: product.branchId,
      status: MarketplacePublishStatus.published,
      marketplacePriceOverride: marketplacePriceOverride,
      onlineStockBuffer: onlineStockBuffer,
      isFeaturedOnMadar: isFeatured,
      lastSyncedAt: DateTime.now(),
    );

    await _marketplaceBridge.publishProduct(
      product: product,
      syncConfig: syncConfig,
    );
  }
}
