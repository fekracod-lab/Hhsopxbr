// نموذج بيانات إشعار الدائن من المورد للتخزين (MADAR SHOP Supplier Credit Note Model)
// Pure Dart — Zero UI Dependencies

import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/returns/entities/supplier_credit_note.dart';

class SupplierCreditNoteModel {
  const SupplierCreditNoteModel._();

  static Map<String, dynamic> toMap(SupplierCreditNote note) {
    return {
      'id': note.id,
      'businessId': note.businessId,
      'supplierId': note.supplierId,
      'supplierReturnId': note.supplierReturnId,
      'creditNoteNumber': note.creditNoteNumber,
      'amountUnits': note.amount.minorUnits,
      'currency': note.amount.currency.code,
      'reason': note.reason,
      'createdAt': note.createdAt.toIso8601String(),
      'actorId': note.actorId,
      'idempotencyKey': note.idempotencyKey,
      'metadata': note.metadata,
    };
  }

  static SupplierCreditNote fromMap(Map<String, dynamic> map) {
    final currency = Currency.fromCode(map['currency'] as String?);
    return SupplierCreditNote(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      supplierId: map['supplierId'] as String,
      supplierReturnId: map['supplierReturnId'] as String,
      creditNoteNumber: map['creditNoteNumber'] as String,
      amount: Money.fromMinorUnits(map['amountUnits'] as int? ?? 0, currency),
      reason: map['reason'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      actorId: map['actorId'] as String,
      idempotencyKey: map['idempotencyKey'] as String? ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? const {}),
    );
  }
}
