import 'package:flutter/foundation.dart';
import '../enums/financial_enums.dart';

/// كيان التسوية المالية متعددة الأطراف (Multi-Party Settlement Entity)
@immutable
class SettlementEntity {
  final String id;
  final String orderId;
  final String orderSource; // 'food', 'store', 'mersal', 'taxi'
  final String customerId;
  final String? driverId;
  final String? merchantId;
  final int grossOrderAmount; // Total paid by customer (IQD)
  final int deliveryFee; // Delivery portion
  final int merchantAmount; // Amount owed to restaurant/store
  final int driverAmount; // Net earnings for driver/captain
  final int platformCommission; // Platform net revenue (IQD)
  final String paymentMethod; // 'wallet', 'cash', 'online'
  final SettlementStatus status;
  final String idempotencyKey;
  final DateTime createdAt;
  final DateTime? settledAt;

  const SettlementEntity({
    required this.id,
    required this.orderId,
    required this.orderSource,
    required this.customerId,
    this.driverId,
    this.merchantId,
    required this.grossOrderAmount,
    this.deliveryFee = 0,
    this.merchantAmount = 0,
    this.driverAmount = 0,
    this.platformCommission = 0,
    required this.paymentMethod,
    this.status = SettlementStatus.pending,
    required this.idempotencyKey,
    required this.createdAt,
    this.settledAt,
  });

  /// التحقق من التوازن الحسابي للتسوية:
  /// إجمالي المبلغ = مستحقات التاجر + مستحقات السائق + عمولة المنصة
  bool get isFinanciallyConsistent {
    return grossOrderAmount == (merchantAmount + driverAmount + platformCommission);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'orderSource': orderSource,
      'customerId': customerId,
      'driverId': driverId,
      'merchantId': merchantId,
      'grossOrderAmount': grossOrderAmount,
      'deliveryFee': deliveryFee,
      'merchantAmount': merchantAmount,
      'driverAmount': driverAmount,
      'platformCommission': platformCommission,
      'paymentMethod': paymentMethod,
      'status': status.key,
      'idempotencyKey': idempotencyKey,
      'createdAt': createdAt.toIso8601String(),
      'settledAt': settledAt?.toIso8601String(),
    };
  }

  factory SettlementEntity.fromMap(Map<String, dynamic> map, String docId) {
    return SettlementEntity(
      id: docId,
      orderId: map['orderId']?.toString() ?? '',
      orderSource: map['orderSource']?.toString() ?? 'food',
      customerId: map['customerId']?.toString() ?? '',
      driverId: map['driverId']?.toString(),
      merchantId: map['merchantId']?.toString(),
      grossOrderAmount: (map['grossOrderAmount'] as num?)?.toInt() ?? 0,
      deliveryFee: (map['deliveryFee'] as num?)?.toInt() ?? 0,
      merchantAmount: (map['merchantAmount'] as num?)?.toInt() ?? 0,
      driverAmount: (map['driverAmount'] as num?)?.toInt() ?? 0,
      platformCommission: (map['platformCommission'] as num?)?.toInt() ?? 0,
      paymentMethod: map['paymentMethod']?.toString() ?? 'wallet',
      status: SettlementStatus.fromString(map['status']?.toString()),
      idempotencyKey: map['idempotencyKey']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      settledAt: map['settledAt'] != null
          ? DateTime.tryParse(map['settledAt'].toString())
          : null,
    );
  }
}
