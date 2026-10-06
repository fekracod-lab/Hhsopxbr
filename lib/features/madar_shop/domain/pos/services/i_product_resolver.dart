// واجهة عقد حل وتحديد المنتجات لنقطة البيع (MADAR SHOP Product Resolver Interface)
// Pure Dart — Zero UI Dependencies

import '../entities/resolved_product.dart';

abstract class IProductResolver {
  /// حل المنتج بأولوية: Barcode ➔ SKU ➔ Product ID ➔ Name Search
  Future<ResolvedProduct?> resolveProduct({
    required String query,
    required String businessId,
    required String branchId,
  });

  /// البحث المتعدد في الكتالوج
  Future<List<ResolvedProduct>> searchProducts({
    required String query,
    required String businessId,
    required String branchId,
    int limit = 20,
  });
}
