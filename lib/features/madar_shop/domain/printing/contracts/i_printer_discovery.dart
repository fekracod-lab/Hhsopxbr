// عقد اكتشاف الطابعات المتاحة (MADAR SHOP Printer Discovery Interface)
// Pure Dart — Zero UI Dependencies

import '../entities/printer.dart';
import '../enums/printer_connection_type.dart';
import '../enums/printer_status.dart';

abstract class IPrinterDiscovery {
  /// اكتشاف الطابعات المتاحة على الشبكة أو المنافذ المحلية
  Future<List<Printer>> discover({
    required String businessId,
    required String branchId,
    PrinterConnectionType? connectionType,
    Duration timeout = const Duration(seconds: 4),
  });

  /// فحص حالة طابعة معينة وتحديثها
  Future<PrinterStatus> checkStatus(Printer printer);
}
