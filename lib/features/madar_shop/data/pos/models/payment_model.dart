// نموذج بيانات الدفعة المالية (MADAR SHOP Payment Model)
// Pure Dart — Zero Flutter / Firebase SDK Dependencies

import '../../../domain/pos/entities/payment.dart';
import '../../../domain/pos/enums/payment_method.dart';
import '../../../domain/pos/enums/payment_status.dart';
import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';

class PaymentModel {
  const PaymentModel._();

  static Map<String, dynamic> toMap(Payment payment) {
    return {
      'id': payment.id,
      'method': payment.method.toDbString(),
      'amountUnits': payment.amount.minorUnits,
      'currencyCode': payment.amount.currency.code,
      'reference': payment.reference,
      'status': payment.status.toDbString(),
      'receivedAt': payment.receivedAt.toIso8601String(),
      'metadata': payment.metadata,
    };
  }

  static Payment fromMap(Map<String, dynamic> map, [Currency defaultCurrency = Currency.iqd]) {
    final currency = Currency.fromCode(map['currencyCode'] as String? ?? defaultCurrency.code);
    final amountUnits = (map['amountUnits'] as num?)?.toInt() ?? 0;

    return Payment(
      id: map['id'] as String? ?? '',
      method: PaymentMethod.fromString(map['method'] as String?),
      amount: Money.fromMinorUnits(amountUnits, currency),
      reference: map['reference'] as String?,
      status: PaymentStatus.fromString(map['status'] as String?),
      receivedAt: DateTime.tryParse(map['receivedAt'] as String? ?? '') ?? DateTime.now(),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }
}
