// كيان فرع المتجر (MADAR SHOP Branch Entity)
// Pure Dart — Zero UI Dependencies

class ShopBranch {
  final String branchId;
  final String businessId;
  final String name;
  final String code;
  final String address;
  final double? latitude;
  final double? longitude;
  final String phone;
  final bool isMainBranch;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  const ShopBranch({
    required this.branchId,
    required this.businessId,
    required this.name,
    required this.code,
    required this.address,
    this.latitude,
    this.longitude,
    required this.phone,
    this.isMainBranch = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  ShopBranch copyWith({
    String? branchId,
    String? businessId,
    String? name,
    String? code,
    String? address,
    double? latitude,
    double? longitude,
    String? phone,
    bool? isMainBranch,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return ShopBranch(
      branchId: branchId ?? this.branchId,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      code: code ?? this.code,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phone: phone ?? this.phone,
      isMainBranch: isMainBranch ?? this.isMainBranch,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
