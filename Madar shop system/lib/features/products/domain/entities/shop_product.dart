import 'package:cloud_firestore/cloud_firestore.dart';

/// كيان منتج المتجر والكاشير (Shop Product Entity)
/// متوافق تماماً مع بنية المنتجات في تطبيق مدار الرئيسي (dalal_alqaim)
class ShopProduct {
  final String id;
  final String name;
  final double price;
  final double costPrice;
  final String description;
  final String category;
  final String imageUrl;
  final bool isAvailable;
  final bool isFeatured; // حقل التمييز الذهبي في تطبيق مدار الرئيسي
  final String barcode; // كود الباركود لسرعة البيع عبر الماسح الضوئي
  final int stock; // رصيد المخزون في المتجر
  final int minAlertLevel; // الحد الأدنى لتنبيه نفاد المخزون
  final String unit; // وحدة القياس (قطعة، علبة، كرتون، كغم)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ShopProduct({
    required this.id,
    required this.name,
    required this.price,
    this.costPrice = 0.0,
    this.description = '',
    this.category = 'عام',
    this.imageUrl = '',
    this.isAvailable = true,
    this.isFeatured = false,
    this.barcode = '',
    this.stock = 100,
    this.minAlertLevel = 5,
    this.unit = 'قطعة',
    this.createdAt,
    this.updatedAt,
  });

  bool get isLowStock => stock <= minAlertLevel;
  bool get isOutOfStock => stock <= 0;

  Map<String, dynamic> toFirestore() {
    return {
      'name': name.trim(),
      'price': price,
      'costPrice': costPrice,
      'description': description.trim(),
      'category': category.trim().isEmpty ? 'عام' : category.trim(),
      'imageUrl': imageUrl.trim(),
      'isAvailable': isAvailable,
      'isFeatured': isFeatured, // يظهر في واجهة تطبيق مدار الرئيسي كمنتج مميز
      'barcode': barcode.trim(),
      'stock': stock,
      'minAlertLevel': minAlertLevel,
      'unit': unit.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ShopProduct.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return ShopProduct.fromMap(doc.id, data);
  }

  factory ShopProduct.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    final rawPrice = data['price'];
    final rawCost = data['costPrice'];

    return ShopProduct(
      id: id,
      name: (data['name'] ?? '').toString(),
      price: (rawPrice is num) ? rawPrice.toDouble() : (double.tryParse(rawPrice?.toString() ?? '0') ?? 0.0),
      costPrice: (rawCost is num) ? rawCost.toDouble() : (double.tryParse(rawCost?.toString() ?? '0') ?? 0.0),
      description: (data['description'] ?? '').toString(),
      category: (data['category'] ?? 'عام').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      isAvailable: data['isAvailable'] == true || data['isAvailable'] == null,
      isFeatured: data['isFeatured'] == true || data['isSpecialOffer'] == true,
      barcode: (data['barcode'] ?? data['sku'] ?? '').toString(),
      stock: (data['stock'] as num?)?.toInt() ?? 100,
      minAlertLevel: (data['minAlertLevel'] as num?)?.toInt() ?? 5,
      unit: (data['unit'] ?? 'قطعة').toString(),
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  ShopProduct copyWith({
    String? id,
    String? name,
    double? price,
    double? costPrice,
    String? description,
    String? category,
    String? imageUrl,
    bool? isAvailable,
    bool? isFeatured,
    String? barcode,
    int? stock,
    int? minAlertLevel,
    String? unit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShopProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      isFeatured: isFeatured ?? this.isFeatured,
      barcode: barcode ?? this.barcode,
      stock: stock ?? this.stock,
      minAlertLevel: minAlertLevel ?? this.minAlertLevel,
      unit: unit ?? this.unit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
