// نموذج تسلسل بيانات المنتجات (MADAR SHOP Product DTO)
// Data Layer — Serialization / Deserialization

import '../../domain/products/entities/shop_product.dart';
import '../../domain/products/entities/shop_product_variant.dart';

class ShopProductModel extends ShopProduct {
  const ShopProductModel({
    required super.productId,
    required super.businessId,
    required super.branchId,
    required super.categoryId,
    required super.name,
    super.description,
    required super.sku,
    super.barcode,
    super.barcodeType,
    required super.costPrice,
    required super.sellingPrice,
    required super.stockQuantity,
    super.minStockAlert,
    super.unitOfMeasure,
    super.isWeighable,
    super.imageUrl,
    super.variants,
    super.isArchived,
    required super.createdAt,
    required super.updatedAt,
    super.customAttributes,
  });

  factory ShopProductModel.fromJson(Map<String, dynamic> json, {String? id}) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    double parseDouble(dynamic val, [double defaultVal = 0.0]) {
      if (val == null) return defaultVal;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? defaultVal;
    }

    List<ShopProductVariant> parseVariants(dynamic list) {
      if (list is! List) return const [];
      return list.map((item) {
        if (item is! Map<String, dynamic>) return null;
        return ShopProductVariant(
          variantId: (item['variantId'] ?? item['id'] ?? '').toString(),
          sku: (item['sku'] ?? '').toString(),
          barcode: item['barcode']?.toString(),
          title: (item['title'] ?? item['name'] ?? '').toString(),
          costPrice: parseDouble(item['costPrice']),
          sellingPrice: parseDouble(item['sellingPrice'] ?? item['price']),
          stockQuantity: parseDouble(item['stockQuantity'] ?? item['quantity']),
          isAvailable: item['isAvailable'] != false,
        );
      }).whereType<ShopProductVariant>().toList();
    }

    final pId = id ?? (json['productId'] ?? json['id'] ?? '').toString();

    return ShopProductModel(
      productId: pId,
      businessId: (json['businessId'] ?? json['storeId'] ?? '').toString(),
      branchId: (json['branchId'] ?? json['storeId'] ?? '').toString(),
      categoryId: (json['categoryId'] ?? json['category'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      sku: (json['sku'] ?? 'SKU-$pId').toString(),
      barcode: json['barcode']?.toString(),
      barcodeType: ShopBarcodeType.fromString(json['barcodeType']?.toString()),
      costPrice: parseDouble(json['costPrice']),
      sellingPrice: parseDouble(json['sellingPrice'] ?? json['price']),
      stockQuantity: parseDouble(json['stockQuantity'] ?? json['quantity'] ?? json['stock']),
      minStockAlert: parseDouble(json['minStockAlert'], 5.0),
      unitOfMeasure: (json['unitOfMeasure'] ?? 'piece').toString(),
      isWeighable: json['isWeighable'] == true,
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString(),
      variants: parseVariants(json['variants']),
      isArchived: json['isArchived'] == true,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      customAttributes: json['customAttributes'] is Map<String, dynamic>
          ? json['customAttributes']
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'businessId': businessId,
      'branchId': branchId,
      'categoryId': categoryId,
      'name': name,
      'description': description,
      'sku': sku,
      'barcode': barcode,
      'barcodeType': barcodeType.name,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'stockQuantity': stockQuantity,
      'minStockAlert': minStockAlert,
      'unitOfMeasure': unitOfMeasure,
      'isWeighable': isWeighable,
      'imageUrl': imageUrl,
      'variants': variants
          .map((v) => {
                'variantId': v.variantId,
                'sku': v.sku,
                'barcode': v.barcode,
                'title': v.title,
                'costPrice': v.costPrice,
                'sellingPrice': v.sellingPrice,
                'stockQuantity': v.stockQuantity,
                'isAvailable': v.isAvailable,
              })
          .toList(),
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'customAttributes': customAttributes,
    };
  }
}
