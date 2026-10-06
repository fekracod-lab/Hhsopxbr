import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_item.dart';

/// فاتورة / معاملة بيع الكاشير المباشرة في المتجر (POS Sale Transaction)
class PosTransaction {
  final String id;
  final String invoiceNumber;
  final String storeId;
  final String storeName;
  final List<PosCartItem> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double paidAmount;
  final double changeAmount;
  final String paymentMethod; // 'cash', 'card', 'points', 'zain_cash'
  final String cashierName;
  final String customerName;
  final String customerPhone;
  final DateTime createdAt;

  const PosTransaction({
    required this.id,
    required this.invoiceNumber,
    required this.storeId,
    required this.storeName,
    required this.items,
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.total,
    required this.paidAmount,
    required this.changeAmount,
    required this.paymentMethod,
    this.cashierName = 'كاشير مدار',
    this.customerName = 'زبون نقدي',
    this.customerPhone = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'storeId': storeId,
      'storeName': storeName,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'paidAmount': paidAmount,
      'changeAmount': changeAmount,
      'paymentMethod': paymentMethod,
      'cashierName': cashierName,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PosTransaction.fromMap(Map<String, dynamic> map, List<PosCartItem> loadedItems) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return PosTransaction(
      id: (map['id'] ?? '').toString(),
      invoiceNumber: (map['invoiceNumber'] ?? '').toString(),
      storeId: (map['storeId'] ?? '').toString(),
      storeName: (map['storeName'] ?? '').toString(),
      items: loadedItems,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      changeAmount: (map['changeAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: (map['paymentMethod'] ?? 'cash').toString(),
      cashierName: (map['cashierName'] ?? 'كاشير مدار').toString(),
      customerName: (map['customerName'] ?? 'زبون نقدي').toString(),
      customerPhone: (map['customerPhone'] ?? '').toString(),
      createdAt: parseDate(map['createdAt']),
    );
  }
}
