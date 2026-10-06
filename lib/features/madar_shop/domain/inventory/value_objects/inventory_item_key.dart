// كائن مفتاح صنف المخزون المعزول بالفروع والمتغيرات (MADAR SHOP Inventory Item Key)
// Pure Dart — Zero UI Dependencies

class InventoryItemKey {
  final String businessId;
  final String branchId;
  final String productId;
  final String? variantId;

  const InventoryItemKey({
    required this.businessId,
    required this.branchId,
    required this.productId,
    this.variantId,
  });

  String get compositeKey {
    if (variantId == null || variantId!.trim().isEmpty) {
      return '$businessId:$branchId:$productId:main';
    }
    return '$businessId:$branchId:$productId:$variantId';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryItemKey &&
          runtimeType == other.runtimeType &&
          businessId == other.businessId &&
          branchId == other.branchId &&
          productId == other.productId &&
          variantId == other.variantId;

  @override
  int get hashCode =>
      businessId.hashCode ^
      branchId.hashCode ^
      productId.hashCode ^
      (variantId?.hashCode ?? 0);

  @override
  String toString() => compositeKey;
}
