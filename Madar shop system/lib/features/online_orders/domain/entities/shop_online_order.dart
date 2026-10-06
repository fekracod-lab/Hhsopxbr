import 'package:cloud_firestore/cloud_firestore.dart';

/// عنصر داخل طلب تطبيق مدار أونلاين
class ShopOnlineOrderItem {
  final String itemId;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final String notes;

  const ShopOnlineOrderItem({
    required this.itemId,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.imageUrl = '',
    this.notes = '',
  });

  double get total => price * quantity;

  factory ShopOnlineOrderItem.fromMap(Map<String, dynamic> map) {
    final p = map['price'];
    return ShopOnlineOrderItem(
      itemId: (map['itemId'] ?? map['id'] ?? '').toString(),
      name: (map['name'] ?? 'منتج').toString(),
      price: (p is num) ? p.toDouble() : 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      imageUrl: (map['imageUrl'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
    );
  }
}

/// طلب وارد من زبون عبر تطبيق مدار الرئيسي (Shop Online Order)
class ShopOnlineOrder {
  final String orderId;
  final String status; // 'pending', 'accepted', 'ready', 'delivering', 'completed', 'cancelled'
  final String customerName;
  final String customerPhone;
  final String address;
  final double total;
  final List<ShopOnlineOrderItem> items;
  final String paymentStatus;
  final DateTime createdAt;

  const ShopOnlineOrder({
    required this.orderId,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.total,
    required this.items,
    required this.paymentStatus,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isReady => status == 'ready';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  factory ShopOnlineOrder.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    final rawItems = data['items'];
    final List<ShopOnlineOrderItem> parsedItems = [];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map<String, dynamic>) {
          parsedItems.add(ShopOnlineOrderItem.fromMap(it));
        } else if (it is Map) {
          parsedItems.add(ShopOnlineOrderItem.fromMap(Map<String, dynamic>.from(it)));
        }
      }
    }

    final rawTotal = data['total'];

    return ShopOnlineOrder(
      orderId: doc.id,
      status: (data['status'] ?? 'pending').toString().toLowerCase(),
      customerName: (data['customerName'] ?? data['userName'] ?? 'زبون مدار').toString(),
      customerPhone: (data['customerPhone'] ?? data['phone'] ?? '').toString(),
      address: (data['address'] ?? data['customerAddress'] ?? '').toString(),
      total: (rawTotal is num) ? rawTotal.toDouble() : 0.0,
      items: parsedItems,
      paymentStatus: (data['paymentStatus'] ?? 'cash').toString(),
      createdAt: parseDate(data['createdAt']),
    );
  }
}
