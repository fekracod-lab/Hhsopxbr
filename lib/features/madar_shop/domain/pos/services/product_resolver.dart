// المحرك المعياري لحل المنتجات وفق سلم الأولويات (MADAR SHOP Product Resolver Implementation)
// Pure Dart — Zero UI Dependencies

import '../../contracts/shop_core_repository_contract.dart';
import '../../products/entities/shop_product.dart';
import '../entities/resolved_product.dart';
import '../value_objects/currency.dart';
import '../value_objects/money.dart';
import 'i_product_resolver.dart';

class ProductResolver implements IProductResolver {
  final IShopCoreRepository _repository;
  final Currency _currency;

  ProductResolver({
    required IShopCoreRepository repository,
    Currency currency = Currency.iqd,
  })  : _repository = repository,
        _currency = currency;

  @override
  Future<ResolvedProduct?> resolveProduct({
    required String query,
    required String businessId,
    required String branchId,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return null;

    final products = await _repository.getProducts(
      businessId: businessId,
      branchId: branchId,
    );

    // 1. أولوية مطابقة الباركود المباشر (Barcode Match)
    for (final product in products) {
      if (product.barcode != null && product.barcode == cleanQuery) {
        return _toResolvedProduct(product);
      }
      for (final variant in product.variants) {
        if (variant.barcode != null && variant.barcode == cleanQuery) {
          return _variantToResolvedProduct(product, variant);
        }
      }
    }

    // 2. أولوية مطابقة رمز الـ SKU
    for (final product in products) {
      if (product.sku.equalsIgnoreCase(cleanQuery)) {
        return _toResolvedProduct(product);
      }
      for (final variant in product.variants) {
        if (variant.sku.equalsIgnoreCase(cleanQuery)) {
          return _variantToResolvedProduct(product, variant);
        }
      }
    }

    // 3. أولوية مطابقة المعرف الفرعي (Product ID)
    for (final product in products) {
      if (product.productId == cleanQuery) {
        return _toResolvedProduct(product);
      }
    }

    // 4. البحث بالاسم (Text Name Fallback)
    for (final product in products) {
      if (product.name.toLowerCase().contains(cleanQuery.toLowerCase())) {
        return _toResolvedProduct(product);
      }
    }

    return null;
  }

  @override
  Future<List<ResolvedProduct>> searchProducts({
    required String query,
    required String businessId,
    required String branchId,
    int limit = 20,
  }) async {
    final cleanQuery = query.trim().toLowerCase();
    final products = await _repository.getProducts(
      businessId: businessId,
      branchId: branchId,
    );

    final List<ResolvedProduct> results = [];
    for (final product in products) {
      if (product.name.toLowerCase().contains(cleanQuery) ||
          product.sku.toLowerCase().contains(cleanQuery) ||
          (product.barcode != null && product.barcode!.contains(cleanQuery))) {
        results.add(_toResolvedProduct(product));
      }
      for (final variant in product.variants) {
        if (variant.title.toLowerCase().contains(cleanQuery) ||
            variant.sku.toLowerCase().contains(cleanQuery)) {
          results.add(_variantToResolvedProduct(product, variant));
        }
      }
      if (results.length >= limit) break;
    }

    return results;
  }

  ResolvedProduct _toResolvedProduct(ShopProduct product) {
    return ResolvedProduct(
      productId: product.productId,
      sku: product.sku,
      barcode: product.barcode,
      name: product.name,
      variantId: null,
      variantTitle: null,
      unitOfMeasure: product.unitOfMeasure,
      price: Money.fromAmount(product.sellingPrice, _currency),
      cost: Money.fromAmount(product.costPrice, _currency),
      stockQuantity: product.stockQuantity,
      isWeighable: product.isWeighable,
      isAvailable: !product.isArchived && product.stockQuantity > 0,
      metadata: {'categoryId': product.categoryId},
    );
  }

  ResolvedProduct _variantToResolvedProduct(ShopProduct product, dynamic variant) {
    return ResolvedProduct(
      productId: product.productId,
      sku: variant.sku as String,
      barcode: variant.barcode as String?,
      name: '${product.name} - ${variant.title}',
      variantId: variant.variantId as String,
      variantTitle: variant.title as String,
      unitOfMeasure: product.unitOfMeasure,
      price: Money.fromAmount(variant.sellingPrice as double, _currency),
      cost: Money.fromAmount(variant.costPrice as double, _currency),
      stockQuantity: variant.stockQuantity as double,
      isWeighable: product.isWeighable,
      isAvailable: (variant.isAvailable as bool) && (variant.stockQuantity as double) > 0,
      metadata: {'categoryId': product.categoryId, 'parentProductId': product.productId},
    );
  }
}

extension _StringCaseInsensitive on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
