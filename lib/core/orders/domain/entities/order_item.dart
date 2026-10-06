import 'package:flutter/foundation.dart';

/// عنصر الطلب الموحد في مدار (Unified Order Item)
@immutable
class OrderItem {
  final String id;
  final String name;
  final int price; // IQD minor units
  final int quantity;
  final String? imageUrl;
  final Map<String, dynamic> options;

  const OrderItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.options = const {},
  });

  /// إجمالي سعر هذا البند (السعر × الكمية)
  int get totalItemPrice => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'options': options,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map, [String? fallbackId]) {
    return OrderItem(
      id: map['id']?.toString() ?? map['productId']?.toString() ?? fallbackId ?? '',
      name: map['name']?.toString() ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      imageUrl: map['imageUrl']?.toString() ?? map['image']?.toString(),
      options: map['options'] is Map ? Map<String, dynamic>.from(map['options'] as Map) : {},
    );
  }
}
