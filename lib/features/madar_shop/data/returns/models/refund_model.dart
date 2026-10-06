// نموذج بيانات استرداد الأموال للتخزين (MADAR SHOP Refund Model)
// Pure Dart — Zero UI Dependencies

import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/returns/entities/refund.dart';
import '../../../domain/returns/enums/refund_method.dart';
import '../../../domain/returns/enums/refund_status.dart';

class RefundModel {
  const RefundModel._();

  static Map<String, dynamic> toMap(Refund refund) {
    return {
      'id': refund.id,
      'saleId': refund.saleId,
      'returnId': refund.returnId,
      'customerId': refund.customerId,
      'amountUnits': refund.amount.minorUnits,
      'currency': refund.amount.currency.code,
      'method': refund.method.name,
      'status': refund.status.name,
      'reference': refund.reference,
      'createdAt': refund.createdAt.toIso8601String(),
      'actorId': refund.actorId,
      'idempotencyKey': refund.idempotencyKey,
      'metadata': refund.metadata,
    };
  }

  static Refund fromMap(Map<String, dynamic> map) {
    final currency = Currency.fromCode(map['currency'] as String?);
    return Refund(
      id: map['id'] as String,
      saleId: map['saleId'] as String,
      returnId: map['returnId'] as String,
      customerId: map['customerId'] as String?,
      amount: Money.fromMinorUnits(map['amountUnits'] as int? ?? 0, currency),
      method: RefundMethod.fromString(map['method'] as String?),
      status: RefundStatus.fromString(map['status'] as String?),
      reference: map['reference'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      actorId: map['actorId'] as String,
      idempotencyKey: map['idempotencyKey'] as String? ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? const {}),
    );
  }
}
