// نموذج تسلسل بيانات النشاط التجاري (MADAR SHOP Business DTO)
// Data Layer — Serialization / Deserialization

import '../../domain/identity/entities/shop_business.dart';

class ShopBusinessModel extends ShopBusiness {
  const ShopBusinessModel({
    required super.businessId,
    required super.tradeName,
    required super.legalName,
    super.taxNumber,
    super.defaultCurrency,
    required super.phone,
    required super.email,
    super.logoUrl,
    super.coverUrl,
    super.isVerified,
    super.isActive,
    required super.createdAt,
    required super.updatedAt,
    super.metadata,
  });

  factory ShopBusinessModel.fromJson(Map<String, dynamic> json, {String? id}) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    return ShopBusinessModel(
      businessId: id ?? (json['businessId'] ?? json['id'] ?? '').toString(),
      tradeName: (json['tradeName'] ?? json['name'] ?? '').toString(),
      legalName: (json['legalName'] ?? json['tradeName'] ?? json['name'] ?? '').toString(),
      taxNumber: json['taxNumber']?.toString(),
      defaultCurrency: (json['defaultCurrency'] ?? 'IQD').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      logoUrl: json['logoUrl']?.toString(),
      coverUrl: json['coverUrl']?.toString(),
      isVerified: json['isVerified'] == true,
      isActive: json['isActive'] != false,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'businessId': businessId,
      'tradeName': tradeName,
      'legalName': legalName,
      'taxNumber': taxNumber,
      'defaultCurrency': defaultCurrency,
      'phone': phone,
      'email': email,
      'logoUrl': logoUrl,
      'coverUrl': coverUrl,
      'isVerified': isVerified,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}
