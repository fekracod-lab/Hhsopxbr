import 'package:flutter/foundation.dart';

/// سجل الاسترداد المالي في دفتر الأستاذ (Refund Ledger Record)
@immutable
class RefundLedgerRecord {
  final String id;
  final String refundRequestId;
  final String orderId;
  final String orderSource;
  final String customerId;
  final int refundAmount; // IQD minor units
  final int refundPoints;
  final int originalOrderAmount;
  final String reason;
  final String idempotencyKey;
  final DateTime processedAt;

  const RefundLedgerRecord({
    required this.id,
    required this.refundRequestId,
    required this.orderId,
    required this.orderSource,
    required this.customerId,
    required this.refundAmount,
    this.refundPoints = 0,
    required this.originalOrderAmount,
    required this.reason,
    required this.idempotencyKey,
    required this.processedAt,
  });

  /// التحقق من عدم تجاوز مبلغ الاسترداد لقيمة الطلب الأصلية
  bool get isValidRefundAmount => refundAmount > 0 && refundAmount <= originalOrderAmount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'refundRequestId': refundRequestId,
      'orderId': orderId,
      'orderSource': orderSource,
      'customerId': customerId,
      'refundAmount': refundAmount,
      'refundPoints': refundPoints,
      'originalOrderAmount': originalOrderAmount,
      'reason': reason,
      'idempotencyKey': idempotencyKey,
      'processedAt': processedAt.toIso8601String(),
    };
  }

  factory RefundLedgerRecord.fromMap(Map<String, dynamic> map, String docId) {
    return RefundLedgerRecord(
      id: docId,
      refundRequestId: map['refundRequestId']?.toString() ?? '',
      orderId: map['orderId']?.toString() ?? '',
      orderSource: map['orderSource']?.toString() ?? 'store',
      customerId: map['customerId']?.toString() ?? '',
      refundAmount: (map['refundAmount'] as num?)?.toInt() ?? 0,
      refundPoints: (map['refundPoints'] as num?)?.toInt() ?? 0,
      originalOrderAmount: (map['originalOrderAmount'] as num?)?.toInt() ?? 0,
      reason: map['reason']?.toString() ?? '',
      idempotencyKey: map['idempotencyKey']?.toString() ?? '',
      processedAt: map['processedAt'] != null
          ? DateTime.tryParse(map['processedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
