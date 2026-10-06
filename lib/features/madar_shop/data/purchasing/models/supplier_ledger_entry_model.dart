// نموذج بيانات قيد دفتر أستاذ الموردين (MADAR SHOP Supplier Ledger Entry Data Model)
// Pure Dart — Zero UI Dependencies

import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/purchasing/entities/supplier_ledger_entry.dart';
import '../../../domain/purchasing/enums/supplier_ledger_entry_type.dart';

class SupplierLedgerEntryModel {
  static Map<String, dynamic> toMap(SupplierLedgerEntry entry) {
    return {
      'id': entry.id,
      'businessId': entry.businessId,
      'supplierId': entry.supplierId,
      'referenceType': entry.referenceType,
      'referenceId': entry.referenceId,
      'entryType': entry.entryType.name,
      'debitMinorUnits': entry.debit.minorUnits,
      'creditMinorUnits': entry.credit.minorUnits,
      'balanceDeltaMinorUnits': entry.balanceDelta.minorUnits,
      'balanceAfterMinorUnits': entry.balanceAfter.minorUnits,
      'currency': entry.currency.code,
      'actorId': entry.actorId,
      'createdAt': entry.createdAt.toIso8601String(),
      'version': entry.version,
      'idempotencyKey': entry.idempotencyKey,
      'description': entry.description,
    };
  }

  static SupplierLedgerEntry fromMap(Map<String, dynamic> map) {
    final currency = Currency.fromCode(map['currency'] as String?);
    return SupplierLedgerEntry(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      supplierId: map['supplierId'] as String,
      referenceType: map['referenceType'] as String,
      referenceId: map['referenceId'] as String,
      entryType: SupplierLedgerEntryType.fromString(map['entryType'] as String?),
      debit: Money.fromMinorUnits(map['debitMinorUnits'] as int? ?? 0, currency),
      credit: Money.fromMinorUnits(map['creditMinorUnits'] as int? ?? 0, currency),
      balanceDelta: Money.fromMinorUnits(map['balanceDeltaMinorUnits'] as int, currency),
      balanceAfter: Money.fromMinorUnits(map['balanceAfterMinorUnits'] as int, currency),
      currency: currency,
      actorId: map['actorId'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      version: map['version'] as int? ?? 1,
      idempotencyKey: map['idempotencyKey'] as String,
      description: map['description'] as String?,
    );
  }
}
