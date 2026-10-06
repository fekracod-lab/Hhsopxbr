// خدمة اكتشاف الطابعات بالذاكرة للاختبار والمحاكاة (MADAR SHOP In-Memory Printer Discovery)
// Pure Dart — Zero UI Dependencies

import '../../../domain/printing/contracts/i_printer_discovery.dart';
import '../../../domain/printing/entities/printer.dart';
import '../../../domain/printing/enums/printer_connection_type.dart';
import '../../../domain/printing/enums/printer_status.dart';

class MemoryPrinterDiscovery implements IPrinterDiscovery {
  final List<Printer> _discoverablePrinters = [];
  final Map<String, PrinterStatus> _printerStatusMap = {};

  void addDiscoverablePrinter(Printer printer, {PrinterStatus status = PrinterStatus.online}) {
    _discoverablePrinters.add(printer);
    _printerStatusMap[printer.id] = status;
  }

  void setPrinterStatus(String printerId, PrinterStatus status) {
    _printerStatusMap[printerId] = status;
  }

  @override
  Future<List<Printer>> discover({
    required String businessId,
    required String branchId,
    PrinterConnectionType? connectionType,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    return _discoverablePrinters.where((p) {
      final matchesBiz = p.businessId == businessId;
      final matchesBranch = p.branchId == branchId;
      final matchesType = connectionType == null || p.connectionType == connectionType;
      return matchesBiz && matchesBranch && matchesType;
    }).toList();
  }

  @override
  Future<PrinterStatus> checkStatus(Printer printer) async {
    return _printerStatusMap[printer.id] ?? printer.status;
  }

  void clear() {
    _discoverablePrinters.clear();
    _printerStatusMap.clear();
  }
}
