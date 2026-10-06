// كيان الدفعة المالية لنقطة البيع (MADAR SHOP Payment Entity)
// Pure Dart — Zero UI Dependencies

import '../enums/payment_method.dart';
import '../enums/payment_status.dart';
import '../value_objects/money.dart';

class Payment {
  final String id;
  final PaymentMethod method;
  final Money amount;
  final String? reference; // رقم المعاملة من جهاز الدفع أو الحوالة
  final PaymentStatus status;
  final DateTime receivedAt;
  final Map<String, dynamic> metadata;

  const Payment({
    required this.id,
    required this.method,
    required this.amount,
    this.reference,
    this.status = PaymentStatus.completed,
    required this.receivedAt,
    this.metadata = const {},
  });

  Payment copyWith({
    String? id,
    PaymentMethod? method,
    Money? amount,
    String? reference,
    PaymentStatus? status,
    DateTime? receivedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Payment(
      id: id ?? this.id,
      method: method ?? this.method,
      amount: amount ?? this.amount,
      reference: reference ?? this.reference,
      status: status ?? this.status,
      receivedAt: receivedAt ?? this.receivedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
