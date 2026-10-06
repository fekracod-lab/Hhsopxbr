// كيان عنصر سلة المشتريات لمتجر مدار (Store Cart Item Domain Entity)
// Pure Dart — Zero Flutter / Firebase Dependencies

/// عنصر سلة المشتريات الصافي والمحمي ضد القيم السالبة أو غير المعرفة
class StoreCartItemEntity {
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final String category;
  final String notes;

  StoreCartItemEntity({
    required this.productId,
    required this.name,
    required double price,
    int quantity = 1,
    this.imageUrl = '',
    this.category = '',
    this.notes = '',
  }) : price = (price.isNaN || price.isInfinite || price < 0.0) ? 0.0 : price,
        quantity = quantity <= 0 ? 1 : quantity;

  /// إجمالي سعر العنصر (السعر × الكمية)
  double get itemSubtotal => price * quantity;

  /// إنشاء نسخة معدلة من العنصر
  StoreCartItemEntity copyWith({
    String? productId,
    String? name,
    double? price,
    int? quantity,
    String? imageUrl,
    String? category,
    String? notes,
  }) {
    return StoreCartItemEntity(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      notes: notes ?? this.notes,
    );
  }

  /// تحويل آمن إلى Map لأغراض السلة والطلب
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'category': category,
      'notes': notes,
      'subtotal': itemSubtotal,
    };
  }

  /// استخراج آمن من Map
  factory StoreCartItemEntity.fromMap(Map<String, dynamic> map) {
    final rawPrice = map['price'];
    double parsedPrice = 0.0;
    if (rawPrice is num) {
      parsedPrice = rawPrice.toDouble();
    } else if (rawPrice is String) {
      final sanitized = rawPrice.replaceAll(RegExp(r'[^0-9.]'), '');
      parsedPrice = double.tryParse(sanitized) ?? 0.0;
    }

    final rawQuantity = map['quantity'];
    int parsedQty = 1;
    if (rawQuantity is num) {
      parsedQty = rawQuantity.toInt();
    } else if (rawQuantity is String) {
      parsedQty = int.tryParse(rawQuantity) ?? 1;
    }

    return StoreCartItemEntity(
      productId: (map['productId'] ?? map['id'] ?? '').toString(),
      name: (map['name'] ?? map['title'] ?? '').toString(),
      price: parsedPrice,
      quantity: parsedQty,
      imageUrl: (map['imageUrl'] ?? map['image'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoreCartItemEntity &&
        other.productId == productId &&
        other.name == name &&
        other.price == price &&
        other.quantity == quantity &&
        other.imageUrl == imageUrl &&
        other.category == category &&
        other.notes == notes;
  }

  @override
  int get hashCode => Object.hash(
        productId,
        name,
        price,
        quantity,
        imageUrl,
        category,
        notes,
      );

  @override
  String toString() {
    return 'StoreCartItemEntity(id: $productId, name: $name, price: $price, qty: $quantity, total: $itemSubtotal)';
  }
}
