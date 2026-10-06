// عقد مستودع القيود المالية التشغيلية (MADAR SHOP Financial Entry Repository Interface)
// Pure Dart — Zero UI Dependencies

import '../entities/financial_entry.dart';
import '../enums/financial_entry_type.dart';

abstract class IFinancialEntryRepository {
  Future<FinancialEntry?> getEntryById({
    required String businessId,
    required String entryId,
  });

  Future<List<FinancialEntry>> getEntriesForReference({
    required String referenceType,
    required String referenceId,
  });

  Future<List<FinancialEntry>> getEntries({
    required String businessId,
    String? branchId,
    FinancialEntryType? entryType,
    DateTime? from,
    DateTime? to,
  });

  Future<void> appendEntry(FinancialEntry entry);
}
