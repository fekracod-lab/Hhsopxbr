// نموذج بيانات قيد دفتر الأستاذ للعميل (MADAR SHOP Customer Ledger Entry Model)
// Pure Dart — Zero Flutter / Firebase SDK Dependencies

import '../../../domain/pos/entities/customer_ledger_entry.dart';
import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';

class CustomerLedgerEntryModel {
  const CustomerLedgerEntryModel._();

  static Map<String, dynamic> toMap(CustomerLedgerEntry entry) {
    return {
      'entryId': entry.entryId,
      'customerId': entry.customerId,
      'saleId': entry.saleId,
      'businessId': entry.businessId,
      'branchId': entry.branchId,
      'debitUnits': entry.debit.minorUnits,
      'creditUnits': entry.credit.minorUnits,
      'balanceDeltaUnits': entry.balanceDelta.minorUnits,
      'currencyCode': entry.debit.currency.code,
      'timestamp': entry.timestamp.toIso8601String(),
      'reason': entry.reason,
      'metadata': entry.metadata,
    };
  }

  static CustomerLedgerEntry fromMap(Map<String, dynamic> map, [Currency defaultCurrency = Currency.iqd]) {
    final currency = Currency.fromCode(map['currencyCode'] as String? ?? defaultCurrency.code);

    return CustomerLedgerEntry(
      entryId: map['entryId'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      saleId: map['saleId'] as String? ?? '',
      businessId: map['businessId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      debit: Money.fromMinorUnits((map['debitUnits'] as num?)?.toInt() ?? 0, currency),
      credit: Money.fromMinorUnits((map['creditUnits'] as num?)?.toInt() ?? 0, currency),
      balanceDelta: Money.fromMinorUnits((map['balanceDeltaUnits'] as num?)?.toInt() ?? 0, currency),
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      reason: map['reason'] as String? ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }
}
