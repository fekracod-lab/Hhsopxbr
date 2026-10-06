// مستودع دفتر أستاذ الموردين غير القابل للتعديل في الذاكرة (MADAR SHOP Memory Supplier Ledger Repository)
// Pure Dart — Zero UI Dependencies

import '../../../domain/purchasing/entities/supplier_ledger_entry.dart';
import '../../../domain/purchasing/repositories/i_supplier_ledger_repository.dart';

class MemorySupplierLedgerRepository implements ISupplierLedgerRepository {
  final List<SupplierLedgerEntry> _entries = [];
  final Set<String> _entryIds = {};

  @override
  Future<void> appendEntry(SupplierLedgerEntry entry) async {
    if (_entryIds.contains(entry.id)) {
      throw StateError(
        'انتهاك أمان دفتر الأستاذ: لا يمكن إعادة كتابة أو تكرار قيد موجود مسبقاً (${entry.id}). السجل Append-Only حصراً.',
      );
    }
    _entryIds.add(entry.id);
    _entries.add(entry);
  }

  @override
  Future<List<SupplierLedgerEntry>> getEntriesForSupplier({
    required String businessId,
    required String supplierId,
  }) async {
    return List.unmodifiable(
      _entries.where((e) => e.businessId == businessId && e.supplierId == supplierId),
    );
  }

  @override
  Future<SupplierLedgerEntry?> getEntryByIdempotencyKey(String idempotencyKey) async {
    try {
      return _entries.firstWhere((e) => e.idempotencyKey == idempotencyKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<SupplierLedgerEntry>> getEntriesByReference({
    required String businessId,
    required String referenceType,
    required String referenceId,
  }) async {
    return List.unmodifiable(
      _entries.where((e) =>
          e.businessId == businessId &&
          e.referenceType == referenceType &&
          e.referenceId == referenceId),
    );
  }

  List<SupplierLedgerEntry> get allEntries => List.unmodifiable(_entries);

  void clear() {
    _entries.clear();
    _entryIds.clear();
  }
}
