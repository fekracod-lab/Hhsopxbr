// كيان الأقسام والتصنيفات لمنتجات المتجر (MADAR SHOP Category Entity)
// Pure Dart — Zero UI Dependencies

class ShopCategory {
  final String categoryId;
  final String businessId;
  final String name;
  final String? parentCategoryId;
  final String? iconCode;
  final String? imageUrl;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;

  const ShopCategory({
    required this.categoryId,
    required this.businessId,
    required this.name,
    this.parentCategoryId,
    this.iconCode,
    this.imageUrl,
    this.displayOrder = 0,
    this.isActive = true,
    required this.createdAt,
  });

  bool get isSubCategory => parentCategoryId != null && parentCategoryId!.isNotEmpty;

  ShopCategory copyWith({
    String? categoryId,
    String? businessId,
    String? name,
    String? parentCategoryId,
    String? iconCode,
    String? imageUrl,
    int? displayOrder,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ShopCategory(
      categoryId: categoryId ?? this.categoryId,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      parentCategoryId: parentCategoryId ?? this.parentCategoryId,
      iconCode: iconCode ?? this.iconCode,
      imageUrl: imageUrl ?? this.imageUrl,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
