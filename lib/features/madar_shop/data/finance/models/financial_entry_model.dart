// نموذج بيانات القيد المالي التشغيلي للتخزين (MADAR SHOP Financial Entry Model)
// Pure Dart — Zero UI Dependencies

import '../../../domain/finance/entities/financial_entry.dart';
import '../../../domain/finance/enums/financial_direction.dart';
import '../../../domain/finance/enums/financial_entry_type.dart';
import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';

class FinancialEntryModel {
  const FinancialEntryModel._();

  static Map<String, dynamic> toMap(FinancialEntry entry) {
    return {
      'id': entry.id,
      'businessId': entry.businessId,
      'branchId': entry.branchId,
      'entryType': entry.entryType.name,
      'referenceType': entry.referenceType,
      'referenceId': entry.referenceId,
      'amountUnits': entry.amount.minorUnits,
      'currency': entry.currency.code,
      'direction': entry.direction.name,
      'actorId': entry.actorId,
      'createdAt': entry.createdAt.toIso8601String(),
      'version': entry.version,
      'idempotencyKey': entry.idempotencyKey,
      'metadata': entry.metadata,
    };
  }

  static FinancialEntry fromMap(Map<String, dynamic> map) {
    final currency = Currency.fromCode(map['currency'] as String?);
    return FinancialEntry(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      branchId: map['branchId'] as String,
      entryType: FinancialEntryType.fromString(map['entryType'] as String?),
      referenceType: map['referenceType'] as String,
      referenceId: map['referenceId'] as String,
      amount: Money.fromMinorUnits(map['amountUnits'] as int? ?? 0, currency),
      currency: currency,
      direction: FinancialDirection.fromString(map['direction'] as String?),
      actorId: map['actorId'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      version: map['version'] as int? ?? 1,
      idempotencyKey: map['idempotencyKey'] as String? ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? const {}),
    );
  }
}
