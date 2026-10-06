import '../../../products/domain/entities/shop_product.dart';

/// عنصر داخل سلة مبيعات الكاشير (POS Cart Item)
class PosCartItem {
  final ShopProduct product;
  int quantity;
  double customPrice;
  double discount;
  String notes;

  PosCartItem({
    required this.product,
    this.quantity = 1,
    double? customPrice,
    this.discount = 0.0,
    this.notes = '',
  }) : customPrice = customPrice ?? product.price;

  double get unitPrice => customPrice;
  double get subtotal => unitPrice * quantity;
  double get totalPrice {
    final t = subtotal - discount;
    return t < 0 ? 0.0 : t;
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': product.id,
      'name': product.name,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'discount': discount,
      'totalPrice': totalPrice,
      'imageUrl': product.imageUrl,
      'barcode': product.barcode,
      'unit': product.unit,
      'notes': notes,
    };
  }

  factory PosCartItem.fromMap(Map<String, dynamic> map, ShopProduct product) {
    return PosCartItem(
      product: product,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      customPrice: (map['unitPrice'] as num?)?.toDouble() ?? product.price,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      notes: (map['notes'] ?? '').toString(),
    );
  }
}
