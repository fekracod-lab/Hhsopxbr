// مستودع القيود المالية التشغيلية في الذاكرة (MADAR SHOP Memory Financial Entry Repository)
// Pure Dart — Zero UI Dependencies

import '../../../domain/finance/entities/financial_entry.dart';
import '../../../domain/finance/enums/financial_entry_type.dart';
import '../../../domain/finance/repositories/i_financial_entry_repository.dart';

class MemoryFinancialEntryRepository implements IFinancialEntryRepository {
  final List<FinancialEntry> _entries = [];

  @override
  Future<FinancialEntry?> getEntryById({
    required String businessId,
    required String entryId,
  }) async {
    return _entries.firstWhere(
      (e) => e.businessId == businessId && e.id == entryId,
      orElse: () => null as dynamic,
    );
  }

  @override
  Future<List<FinancialEntry>> getEntriesForReference({
    required String referenceType,
    required String referenceId,
  }) async {
    return _entries
        .where((e) => e.referenceType == referenceType && e.referenceId == referenceId)
        .toList();
  }

  @override
  Future<List<FinancialEntry>> getEntries({
    required String businessId,
    String? branchId,
    FinancialEntryType? entryType,
    DateTime? from,
    DateTime? to,
  }) async {
    return _entries.where((e) {
      if (e.businessId != businessId) return false;
      if (branchId != null && e.branchId != branchId) return false;
      if (entryType != null && e.entryType != entryType) return false;
      if (from != null && e.createdAt.isBefore(from)) return false;
      if (to != null && e.createdAt.isAfter(to)) return false;
      return true;
    }).toList();
  }

  @override
  Future<void> appendEntry(FinancialEntry entry) async {
    if (_entries.any((e) => e.id == entry.id)) {
      throw StateError('FinancialEntry with id ${entry.id} already exists. Append-only enforcement.');
    }
    _entries.add(entry);
  }

  void clear() => _entries.clear();
}
