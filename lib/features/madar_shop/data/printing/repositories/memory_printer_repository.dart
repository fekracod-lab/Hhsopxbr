// مستودع طابعات بالذاكرة (MADAR SHOP In-Memory Printer Repository)
// Pure Dart — Zero UI Dependencies

import '../../../domain/printing/contracts/i_printer_repository.dart';
import '../../../domain/printing/entities/printer.dart';

class MemoryPrinterRepository implements IPrinterRepository {
  final Map<String, Printer> _storage = {};

  @override
  Future<void> savePrinter(Printer printer) async {
    _storage['${printer.businessId}_${printer.id}'] = printer;
  }

  @override
  Future<Printer?> getPrinterById({
    required String businessId,
    required String printerId,
  }) async {
    return _storage['${businessId}_$printerId'];
  }

  @override
  Future<List<Printer>> getPrintersForBranch({
    required String businessId,
    required String branchId,
  }) async {
    return _storage.values
        .where((p) => p.businessId == businessId && p.branchId == branchId)
        .toList();
  }

  @override
  Future<Printer?> getDefaultPrinter({
    required String businessId,
    required String branchId,
  }) async {
    final branchPrinters = await getPrintersForBranch(
      businessId: businessId,
      branchId: branchId,
    );
    for (final p in branchPrinters) {
      if (p.isDefault) return p;
    }
    return branchPrinters.isNotEmpty ? branchPrinters.first : null;
  }

  @override
  Future<List<Printer>> getAllPrinters({
    required String businessId,
  }) async {
    return _storage.values.where((p) => p.businessId == businessId).toList();
  }

  @override
  Future<void> deletePrinter({
    required String businessId,
    required String printerId,
  }) async {
    _storage.remove('${businessId}_$printerId');
  }

  void clear() {
    _storage.clear();
  }
}
