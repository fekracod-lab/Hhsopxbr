import 'package:flutter/foundation.dart';

/// التسعير والتخفيضات للطلب الموحد (Order Pricing & Discounts)
@immutable
class OrderPricing {
  final int subtotal; // IQD
  final int deliveryFee; // IQD
  final int couponDiscount; // IQD
  final int pointsDiscount; // IQD
  final int walletDiscount; // IQD
  final int pointsUsed;
  final int pointsEarned;

  const OrderPricing({
    required this.subtotal,
    this.deliveryFee = 0,
    this.couponDiscount = 0,
    this.pointsDiscount = 0,
    this.walletDiscount = 0,
    this.pointsUsed = 0,
    this.pointsEarned = 0,
  });

  /// إجمالي الخصومات
  int get totalDiscount => couponDiscount + pointsDiscount + walletDiscount;

  /// المبلغ النهائي المطلوب دفعه بعد كافة الخصومات ورسوم التوصيل
  int get finalTotal {
    final raw = subtotal + deliveryFee - totalDiscount;
    return raw > 0 ? raw : 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'couponDiscount': couponDiscount,
      'pointsDiscount': pointsDiscount,
      'walletDiscount': walletDiscount,
      'totalDiscount': totalDiscount,
      'finalTotal': finalTotal,
      'pointsUsed': pointsUsed,
      'pointsEarned': pointsEarned,
    };
  }

  factory OrderPricing.fromMap(Map<String, dynamic> map) {
    return OrderPricing(
      subtotal: (map['subtotal'] as num?)?.toInt() ?? (map['subTotal'] as num?)?.toInt() ?? 0,
      deliveryFee: (map['deliveryFee'] as num?)?.toInt() ?? 0,
      couponDiscount: (map['couponDiscount'] as num?)?.toInt() ?? 0,
      pointsDiscount: (map['pointsDiscount'] as num?)?.toInt() ?? 0,
      walletDiscount: (map['walletDiscount'] as num?)?.toInt() ?? 0,
      pointsUsed: (map['pointsUsed'] as num?)?.toInt() ?? 0,
      pointsEarned: (map['pointsEarned'] as num?)?.toInt() ?? 0,
    );
  }
}
