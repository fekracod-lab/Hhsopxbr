// كيان إشعار دائن من المورد (MADAR SHOP Supplier Credit Note Entity)
// Pure Dart — Zero UI Dependencies

import '../../pos/value_objects/money.dart';

class SupplierCreditNote {
  final String id;
  final String businessId;
  final String supplierId;
  final String supplierReturnId;
  final String creditNoteNumber;
  final Money amount;
  final String reason;
  final DateTime createdAt;
  final String actorId;
  final String idempotencyKey;
  final Map<String, dynamic> metadata;

  const SupplierCreditNote({
    required this.id,
    required this.businessId,
    required this.supplierId,
    required this.supplierReturnId,
    required this.creditNoteNumber,
    required this.amount,
    required this.reason,
    required this.createdAt,
    required this.actorId,
    required this.idempotencyKey,
    this.metadata = const {},
  });

  SupplierCreditNote copyWith({
    String? id,
    String? businessId,
    String? supplierId,
    String? supplierReturnId,
    String? creditNoteNumber,
    Money? amount,
    String? reason,
    DateTime? createdAt,
    String? actorId,
    String? idempotencyKey,
    Map<String, dynamic>? metadata,
  }) {
    return SupplierCreditNote(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      supplierId: supplierId ?? this.supplierId,
      supplierReturnId: supplierReturnId ?? this.supplierReturnId,
      creditNoteNumber: creditNoteNumber ?? this.creditNoteNumber,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      actorId: actorId ?? this.actorId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      metadata: metadata ?? this.metadata,
    );
  }
}
