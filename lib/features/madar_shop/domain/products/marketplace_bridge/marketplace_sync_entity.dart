// كيان مزامنة ونشر المنتج في تطبيق مدار للمستهلكين (MADAR Marketplace Sync Entity)
// Pure Dart — Zero UI Dependencies

enum MarketplacePublishStatus {
  draft,       // مسودة داخلية لم يتم نشرها للمستهلكين بعد
  published,   // معروض ونشط في تطبيق مدار للزبائن
  hidden,      // مخفي مؤقتاً من التطبيق (بناءً على رغبة التاجر)
  outOfStock,  // محجوب آلياً لنفاد الكمية الأونلاين
  archived;    // مؤرشف

  static MarketplacePublishStatus fromString(String? val) {
    if (val == null) return MarketplacePublishStatus.draft;
    switch (val.trim().toLowerCase()) {
      case 'published':
      case 'active':
        return MarketplacePublishStatus.published;
      case 'hidden':
      case 'paused':
        return MarketplacePublishStatus.hidden;
      case 'out_of_stock':
      case 'outofstock':
        return MarketplacePublishStatus.outOfStock;
      case 'archived':
        return MarketplacePublishStatus.archived;
      default:
        return MarketplacePublishStatus.draft;
    }
  }

  String toDbString() {
    switch (this) {
      case MarketplacePublishStatus.draft:
        return 'draft';
      case MarketplacePublishStatus.published:
        return 'published';
      case MarketplacePublishStatus.hidden:
        return 'hidden';
      case MarketplacePublishStatus.outOfStock:
        return 'out_of_stock';
      case MarketplacePublishStatus.archived:
        return 'archived';
    }
  }
}

class MarketplaceSyncEntity {
  final String productId;
  final String businessId;
  final String branchId;
  final MarketplacePublishStatus status;
  final bool isVisibleInMarketplace;      // هل يظهر في نتائج البحث وقوائم التطبيق
  final double? marketplacePriceOverride; // سعر خاص للتطبيق (إذا كان مختلفاً عن المحل)
  final double onlineStockBuffer;          // كمية احتياطية للمحل لتفادي البيع المزدوج
  final bool isFeaturedOnMadar;           // هل يظهر في قائمة المنتجات المميزة
  final DateTime? lastSyncedAt;
  final String? syncError;

  const MarketplaceSyncEntity({
    required this.productId,
    required this.businessId,
    required this.branchId,
    this.status = MarketplacePublishStatus.draft,
    this.isVisibleInMarketplace = true,
    this.marketplacePriceOverride,
    this.onlineStockBuffer = 0.0,
    this.isFeaturedOnMadar = false,
    this.lastSyncedAt,
    this.syncError,
  });

  /// حساب الكمية المتاحة للبيع أونلاين بعد خصم هامش أمان المحل
  double computeOnlineStock(double currentPhysicalStock) {
    final available = currentPhysicalStock - onlineStockBuffer;
    return available > 0 ? available : 0.0;
  }

  /// حساب السعر النهائي الذي سيظهر للزبون في تطبيق مدار
  double resolveCustomerPrice(double localSellingPrice) {
    return marketplacePriceOverride ?? localSellingPrice;
  }

  MarketplaceSyncEntity copyWith({
    String? productId,
    String? businessId,
    String? branchId,
    MarketplacePublishStatus? status,
    bool? isVisibleInMarketplace,
    double? marketplacePriceOverride,
    bool clearPriceOverride = false,
    double? onlineStockBuffer,
    bool? isFeaturedOnMadar,
    DateTime? lastSyncedAt,
    String? syncError,
  }) {
    return MarketplaceSyncEntity(
      productId: productId ?? this.productId,
      businessId: businessId ?? this.businessId,
      branchId: branchId ?? this.branchId,
      status: status ?? this.status,
      isVisibleInMarketplace:
          isVisibleInMarketplace ?? this.isVisibleInMarketplace,
      marketplacePriceOverride: clearPriceOverride
          ? null
          : (marketplacePriceOverride ?? this.marketplacePriceOverride),
      onlineStockBuffer: onlineStockBuffer ?? this.onlineStockBuffer,
      isFeaturedOnMadar: isFeaturedOnMadar ?? this.isFeaturedOnMadar,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncError: syncError ?? this.syncError,
    );
  }
}
