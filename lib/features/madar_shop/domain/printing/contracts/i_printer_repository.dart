// عقد مستودع الطابعات (MADAR SHOP Printer Repository Interface)
// Pure Dart — Zero UI Dependencies

import '../entities/printer.dart';

abstract class IPrinterRepository {
  Future<void> savePrinter(Printer printer);

  Future<Printer?> getPrinterById({
    required String businessId,
    required String printerId,
  });

  Future<List<Printer>> getPrintersForBranch({
    required String businessId,
    required String branchId,
  });

  Future<Printer?> getDefaultPrinter({
    required String businessId,
    required String branchId,
  });

  Future<List<Printer>> getAllPrinters({
    required String businessId,
  });

  Future<void> deletePrinter({
    required String businessId,
    required String printerId,
  });
}
