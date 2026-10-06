// كيان النشاط التجاري لمتجر مدار (MADAR SHOP Business Entity)
// Pure Dart — Zero UI Dependencies

class ShopBusiness {
  final String businessId;
  final String tradeName;
  final String legalName;
  final String? taxNumber;
  final String defaultCurrency; // e.g. "IQD", "USD"
  final String phone;
  final String email;
  final String? logoUrl;
  final String? coverUrl;
  final bool isVerified;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  const ShopBusiness({
    required this.businessId,
    required this.tradeName,
    required this.legalName,
    this.taxNumber,
    this.defaultCurrency = 'IQD',
    required this.phone,
    required this.email,
    this.logoUrl,
    this.coverUrl,
    this.isVerified = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  ShopBusiness copyWith({
    String? businessId,
    String? tradeName,
    String? legalName,
    String? taxNumber,
    String? defaultCurrency,
    String? phone,
    String? email,
    String? logoUrl,
    String? coverUrl,
    bool? isVerified,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return ShopBusiness(
      businessId: businessId ?? this.businessId,
      tradeName: tradeName ?? this.tradeName,
      legalName: legalName ?? this.legalName,
      taxNumber: taxNumber ?? this.taxNumber,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      logoUrl: logoUrl ?? this.logoUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
