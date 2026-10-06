// اختبارات المنتجات والمخزون وجسر الماركت بليس لمنظومة MADAR SHOP
// Unit & Domain Tests — Zero Mocks

import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/madar_shop/madar_shop.dart';

// Fake implementation for test verification
class FakeMarketplaceBridgeRepository implements IMarketplaceBridgeRepository {
  final Map<String, MarketplaceSyncEntity> publishedItems = {};

  @override
  Future<void> publishProduct({
    required ShopProduct product,
    required MarketplaceSyncEntity syncConfig,
  }) async {
    publishedItems[product.productId] = syncConfig;
  }

  @override
  Future<void> hideProductFromMarketplace({
    required String productId,
    required String businessId,
  }) async {
    if (publishedItems.containsKey(productId)) {
      publishedItems[productId] = publishedItems[productId]!.copyWith(
        status: MarketplacePublishStatus.hidden,
      );
    }
  }

  @override
  Future<void> syncStockAndPrice({
    required String productId,
    required String businessId,
    required double updatedPhysicalStock,
    required double sellingPrice,
    double? priceOverride,
  }) async {
    if (publishedItems.containsKey(productId)) {
      publishedItems[productId] = publishedItems[productId]!.copyWith(
        marketplacePriceOverride: priceOverride,
        lastSyncedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<MarketplaceSyncEntity?> getProductSyncStatus({
    required String productId,
    required String businessId,
  }) async {
    return publishedItems[productId];
  }

  @override
  Future<List<MarketplaceSyncEntity>> getMarketplaceCatalog({
    required String businessId,
    required String branchId,
  }) async {
    return publishedItems.values.toList();
  }
}

void main() {
  group('MADAR SHOP Phase S1 — Products & Marketplace Bridge Tests', () {
    test('1. ShopProduct profit margin and stock warning calculations', () {
      final product = ShopProduct(
        productId: 'PROD-01',
        businessId: 'BIZ-01',
        branchId: 'BR-01',
        categoryId: 'CAT-01',
        name: 'شاي عراقي ممتاز',
        sku: 'SKU-TEA-01',
        barcode: '628100000001',
        costPrice: 4000.0,
        sellingPrice: 5000.0,
        stockQuantity: 4.0,
        minStockAlert: 5.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Gross profit = 5000 - 4000 = 1000 IQD
      expect(product.grossProfit, 1000.0);
      // Margin % = (1000 / 5000) * 100 = 20%
      expect(product.grossMarginPercentage, 20.0);

      // Low stock = stockQuantity(4) <= minStockAlert(5)
      expect(product.isLowStock, isTrue);
      expect(product.isOutOfStock, isFalse);

      // Valuation calculations
      expect(product.totalInventoryCostValue, 16000.0); // 4 * 4000
      expect(product.totalInventoryRetailValue, 20000.0); // 4 * 5000
    });

    test('2. MarketplaceSyncEntity buffer and price override logic', () {
      final syncConfig = const MarketplaceSyncEntity(
        productId: 'PROD-01',
        businessId: 'BIZ-01',
        branchId: 'BR-01',
        status: MarketplacePublishStatus.published,
        marketplacePriceOverride: 5500.0, // 500 IQD extra on marketplace
        onlineStockBuffer: 2.0,            // Reserve 2 units for walk-in in-store
      );

      // If physical stock is 10 units:
      // Online stock should be: 10 - 2 = 8 units
      expect(syncConfig.computeOnlineStock(10.0), 8.0);

      // If physical stock drops to 1 unit (below buffer):
      // Online stock should be 0 (do not oversell)
      expect(syncConfig.computeOnlineStock(1.0), 0.0);

      // Price resolution: should pick the override price
      expect(syncConfig.resolveCustomerPrice(5000.0), 5500.0);

      // Without override, should fall back to local price
      final syncConfigNoOverride = syncConfig.copyWith(
        clearPriceOverride: true,
      );
      expect(syncConfigNoOverride.resolveCustomerPrice(5000.0), 5000.0);
    });

    test('3. ShopCatalogCoordinator catalog valuation and publishing', () async {
      final fakeBridge = FakeMarketplaceBridgeRepository();
      final coordinator = ShopCatalogCoordinator(marketplaceBridge: fakeBridge);

      final p1 = ShopProduct(
        productId: 'P1',
        businessId: 'BIZ-01',
        branchId: 'BR-01',
        categoryId: 'C1',
        name: 'منتج 1',
        sku: 'SKU-1',
        costPrice: 2000,
        sellingPrice: 3000,
        stockQuantity: 10,
        minStockAlert: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final p2 = ShopProduct(
        productId: 'P2',
        businessId: 'BIZ-01',
        branchId: 'BR-01',
        categoryId: 'C1',
        name: 'منتج 2 منخفض',
        sku: 'SKU-2',
        costPrice: 5000,
        sellingPrice: 8000,
        stockQuantity: 1,
        minStockAlert: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final p3 = ShopProduct(
        productId: 'P3',
        businessId: 'BIZ-01',
        branchId: 'BR-01',
        categoryId: 'C1',
        name: 'منتج 3 نافد',
        sku: 'SKU-3',
        costPrice: 1000,
        sellingPrice: 1500,
        stockQuantity: 0,
        minStockAlert: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final products = [p1, p2, p3];

      final lowStock = coordinator.filterLowStockProducts(products);
      expect(lowStock.length, 1);
      expect(lowStock.first.productId, 'P2');

      final outOfStock = coordinator.filterOutOfStockProducts(products);
      expect(outOfStock.length, 1);
      expect(outOfStock.first.productId, 'P3');

      // Total cost = (10*2000) + (1*5000) + (0*1000) = 25000
      expect(coordinator.calculateTotalInventoryCost(products), 25000.0);

      // Publishing test
      await coordinator.publishProductToMadar(
        product: p1,
        marketplacePriceOverride: 3250.0,
        onlineStockBuffer: 2.0,
        isFeatured: true,
      );

      final status = await fakeBridge.getProductSyncStatus(
        productId: 'P1',
        businessId: 'BIZ-01',
      );
      expect(status, isNotNull);
      expect(status!.status, MarketplacePublishStatus.published);
      expect(status.marketplacePriceOverride, 3250.0);
      expect(status.onlineStockBuffer, 2.0);
      expect(status.isFeaturedOnMadar, isTrue);
    });
  });
}
