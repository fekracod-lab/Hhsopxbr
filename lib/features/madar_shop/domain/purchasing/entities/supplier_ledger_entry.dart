// قيد دفتر أستاذ الموردين غير القابل للتعديل (MADAR SHOP Supplier Ledger Entry - Immutable Append-Only)
// Pure Dart — Zero UI Dependencies

import '../../pos/value_objects/currency.dart';
import '../../pos/value_objects/money.dart';
import '../enums/supplier_ledger_entry_type.dart';

class SupplierLedgerEntry {
  final String id;
  final String businessId;
  final String supplierId;
  final String referenceType; // e.g., 'PURCHASE_RECEIPT', 'PURCHASE_ORDER', 'PAYMENT', 'ADJUSTMENT'
  final String referenceId;
  final SupplierLedgerEntryType entryType;
  final Money debit; // مدين (تخفيض التزام المورد)
  final Money credit; // دائن (زيادة التزام المورد)
  final Money balanceDelta; // التغير الصافي (+ للمشتريات، - للمدفوعات)
  final Money balanceAfter; // الرصيد التراكمي بعد القيد
  final Currency currency;
  final String actorId;
  final DateTime createdAt;
  final int version;
  final String idempotencyKey;
  final String? description;

  const SupplierLedgerEntry({
    required this.id,
    required this.businessId,
    required this.supplierId,
    required this.referenceType,
    required this.referenceId,
    required this.entryType,
    required this.debit,
    required this.credit,
    required this.balanceDelta,
    required this.balanceAfter,
    required this.currency,
    required this.actorId,
    required this.createdAt,
    required this.version,
    required this.idempotencyKey,
    this.description,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierLedgerEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SupplierLedgerEntry(id: $id, type: $entryType, delta: $balanceDelta, after: $balanceAfter)';
}
