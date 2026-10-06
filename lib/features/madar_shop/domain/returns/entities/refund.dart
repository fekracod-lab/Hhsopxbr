// كيان وثيقة استرداد المبالغ للعميل (MADAR SHOP Customer Refund Entity)
// Pure Dart — Zero UI Dependencies

import '../../pos/value_objects/money.dart';
import '../enums/refund_method.dart';
import '../enums/refund_status.dart';

class Refund {
  final String id;
  final String saleId;
  final String returnId;
  final String? customerId;
  final Money amount;
  final RefundMethod method;
  final RefundStatus status;
  final String? reference;
  final DateTime createdAt;
  final String actorId;
  final String idempotencyKey;
  final Map<String, dynamic> metadata;

  const Refund({
    required this.id,
    required this.saleId,
    required this.returnId,
    this.customerId,
    required this.amount,
    required this.method,
    required this.status,
    this.reference,
    required this.createdAt,
    required this.actorId,
    required this.idempotencyKey,
    this.metadata = const {},
  });

  bool get isCompleted => status.isCompleted;

  Refund copyWith({
    String? id,
    String? saleId,
    String? returnId,
    String? customerId,
    Money? amount,
    RefundMethod? method,
    RefundStatus? status,
    String? reference,
    DateTime? createdAt,
    String? actorId,
    String? idempotencyKey,
    Map<String, dynamic>? metadata,
  }) {
    return Refund(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      returnId: returnId ?? this.returnId,
      customerId: customerId ?? this.customerId,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      status: status ?? this.status,
      reference: reference ?? this.reference,
      createdAt: createdAt ?? this.createdAt,
      actorId: actorId ?? this.actorId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      metadata: metadata ?? this.metadata,
    );
  }
}
