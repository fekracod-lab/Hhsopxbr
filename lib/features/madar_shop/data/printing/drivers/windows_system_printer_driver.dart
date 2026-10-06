// وسيط طابعات نظام تشغيل ويندوز (MADAR SHOP Windows System Printer Driver)
// Pure Dart — Zero UI Dependencies

import '../../../domain/printing/contracts/i_printer_driver.dart';
import '../../../domain/printing/entities/print_job.dart';
import '../../../domain/printing/enums/printer_status.dart';
import '../../../domain/printing/failures/printing_failures.dart';
import '../../../domain/printing/value_objects/rendered_payload.dart';

class WindowsSystemPrinterDriver implements IPrinterDriver {
  final String systemPrinterName;
  final bool isDriverAvailable;

  WindowsSystemPrinterDriver({
    required this.systemPrinterName,
    this.isDriverAvailable = false,
  });

  @override
  Future<bool> connect({Duration timeout = const Duration(seconds: 5)}) async {
    if (!isDriverAvailable) {
      return false;
    }
    return true;
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> printPayload(PrintJob job, RenderedPayload payload) async {
    if (!isDriverAvailable) {
      throw const UnsupportedPrinterOperationFailure(
        'وسيط طباعة نظام ويندوز (Windows Spooler) غير متصل بمكتبة المنصة الأصلية',
      );
    }
  }

  @override
  Future<bool> testPrint() async {
    if (!isDriverAvailable) return false;
    return true;
  }

  @override
  Future<void> openCashDrawer() async {
    if (!isDriverAvailable) {
      throw const UnsupportedPrinterOperationFailure(
        'أمر فتح درج النقد عبر ويندوز يتطلب توافر وسيط المنصة',
      );
    }
  }

  @override
  Future<void> cutPaper() async {
    if (!isDriverAvailable) {
      throw const UnsupportedPrinterOperationFailure(
        'أمر قطع الورق عبر ويندوز يتطلب توافر وسيط المنصة',
      );
    }
  }

  @override
  Future<PrinterStatus> getStatus() async {
    if (!isDriverAvailable) return PrinterStatus.unknown;
    return PrinterStatus.online;
  }
}
