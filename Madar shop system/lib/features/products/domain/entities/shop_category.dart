import 'package:cloud_firestore/cloud_firestore.dart';

/// كيان فئة / تصنيف منتجات المتجر (Shop Category Entity)
class ShopCategory {
  final String id;
  final String name;
  final int iconCode;
  final int colorValue;
  final DateTime? createdAt;

  const ShopCategory({
    required this.id,
    required this.name,
    this.iconCode = 0xe148,
    this.colorValue = 0xFFF5F5F5,
    this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name.trim(),
      'iconCode': iconCode,
      'colorValue': colorValue,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ShopCategory.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ShopCategory.fromMap(doc.id, data);
  }

  factory ShopCategory.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ShopCategory(
      id: id,
      name: (data['name'] ?? 'عام').toString(),
      iconCode: (data['iconCode'] as num?)?.toInt() ?? 0xe148,
      colorValue: (data['colorValue'] as num?)?.toInt() ?? 0xFFF5F5F5,
      createdAt: parseDate(data['createdAt']),
    );
  }
}
