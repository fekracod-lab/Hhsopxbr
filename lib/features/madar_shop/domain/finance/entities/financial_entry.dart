// كيان القيد المالي التشغيلي غير القابل للتعديل (MADAR SHOP Operational Financial Entry)
// Pure Dart — Zero UI Dependencies

import '../../pos/value_objects/currency.dart';
import '../../pos/value_objects/money.dart';
import '../enums/financial_direction.dart';
import '../enums/financial_entry_type.dart';

class FinancialEntry {
  final String id;
  final String businessId;
  final String branchId;
  final FinancialEntryType entryType;
  final String referenceType;
  final String referenceId;
  final Money amount;
  final Currency currency;
  final FinancialDirection direction;
  final String actorId;
  final DateTime createdAt;
  final int version;
  final String idempotencyKey;
  final Map<String, dynamic> metadata;

  const FinancialEntry({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.entryType,
    required this.referenceType,
    required this.referenceId,
    required this.amount,
    this.currency = Currency.iqd,
    required this.direction,
    required this.actorId,
    required this.createdAt,
    this.version = 1,
    required this.idempotencyKey,
    this.metadata = const {},
  });

  bool get isDebit => direction.isDebit;
  bool get isCredit => direction.isCredit;

  FinancialEntry copyWith({
    String? id,
    String? businessId,
    String? branchId,
    FinancialEntryType? entryType,
    String? referenceType,
    String? referenceId,
    Money? amount,
    Currency? currency,
    FinancialDirection? direction,
    String? actorId,
    DateTime? createdAt,
    int? version,
    String? idempotencyKey,
    Map<String, dynamic>? metadata,
  }) {
    return FinancialEntry(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      branchId: branchId ?? this.branchId,
      entryType: entryType ?? this.entryType,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      direction: direction ?? this.direction,
      actorId: actorId ?? this.actorId,
      createdAt: createdAt ?? this.createdAt,
      version: version ?? this.version,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      metadata: metadata ?? this.metadata,
    );
  }
}
