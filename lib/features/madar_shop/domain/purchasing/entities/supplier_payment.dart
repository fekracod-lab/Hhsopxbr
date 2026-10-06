// دفعة سداد للمورد (MADAR SHOP Supplier Payment Entity)
// Pure Dart — Zero UI Dependencies

import '../../pos/value_objects/currency.dart';
import '../../pos/value_objects/money.dart';
import '../enums/supplier_payment_method.dart';
import '../enums/supplier_payment_status.dart';

class SupplierPayment {
  final String id;
  final String supplierId;
  final String businessId;
  final Money amount;
  final Currency currency;
  final SupplierPaymentMethod method;
  final String? reference;
  final SupplierPaymentStatus status;
  final DateTime createdAt;
  final String actorId;
  final String idempotencyKey;
  final String? purchaseOrderId; // تخصيص الدفعة لأمر شراء محدد (اختياري)
  final String? notes;

  const SupplierPayment({
    required this.id,
    required this.supplierId,
    required this.businessId,
    required this.amount,
    required this.currency,
    required this.method,
    this.reference,
    this.status = SupplierPaymentStatus.completed,
    required this.createdAt,
    required this.actorId,
    required this.idempotencyKey,
    this.purchaseOrderId,
    this.notes,
  });

  bool get isCompleted => status == SupplierPaymentStatus.completed;

  SupplierPayment copyWith({
    SupplierPaymentStatus? status,
    String? reference,
    String? notes,
  }) {
    return SupplierPayment(
      id: id,
      supplierId: supplierId,
      businessId: businessId,
      amount: amount,
      currency: currency,
      method: method,
      reference: reference ?? this.reference,
      status: status ?? this.status,
      createdAt: createdAt,
      actorId: actorId,
      idempotencyKey: idempotencyKey,
      purchaseOrderId: purchaseOrderId,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierPayment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SupplierPayment(id: $id, supplier: $supplierId, amount: $amount, status: $status)';
}
