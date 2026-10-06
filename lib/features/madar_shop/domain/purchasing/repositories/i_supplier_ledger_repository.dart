// واجهة دفتر أستاذ الموردين غير القابل للتعديل (MADAR SHOP Supplier Ledger Repository Contract)
// Pure Dart — Zero UI Dependencies

import '../entities/supplier_ledger_entry.dart';

abstract class ISupplierLedgerRepository {
  /// إضافة قيد جديد لسجل المورد (Append-Only)
  Future<void> appendEntry(SupplierLedgerEntry entry);

  /// استرجاع قيود دفتر الأستاذ لمورد معين مرتبة زمنياً
  Future<List<SupplierLedgerEntry>> getEntriesForSupplier({
    required String businessId,
    required String supplierId,
  });

  /// استرجاع قيد بواسطة مفتاح الـ Idempotency
  Future<SupplierLedgerEntry?> getEntryByIdempotencyKey(String idempotencyKey);

  /// استرجاع قيود دفتر أستاذ الموردين حسب مرجع معين (مثل رقم أمر الشراء أو إيصال الاستلام)
  Future<List<SupplierLedgerEntry>> getEntriesByReference({
    required String businessId,
    required String referenceType,
    required String referenceId,
  });
}
