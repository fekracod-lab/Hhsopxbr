// وسيط طابعات USB المجرد (MADAR SHOP USB Printer Driver)
// Pure Dart — Zero UI Dependencies

import '../../../domain/printing/contracts/i_printer_driver.dart';
import '../../../domain/printing/entities/print_job.dart';
import '../../../domain/printing/enums/printer_status.dart';
import '../../../domain/printing/failures/printing_failures.dart';
import '../../../domain/printing/value_objects/rendered_payload.dart';

class UsbPrinterDriver implements IPrinterDriver {
  final String deviceIdentifier;
  final bool isHardwareAttached;

  UsbPrinterDriver({
    required this.deviceIdentifier,
    this.isHardwareAttached = false,
  });

  @override
  Future<bool> connect({Duration timeout = const Duration(seconds: 5)}) async {
    if (!isHardwareAttached) {
      return false;
    }
    return true;
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> printPayload(PrintJob job, RenderedPayload payload) async {
    if (!isHardwareAttached) {
      throw const UnsupportedPrinterOperationFailure(
        'منفذ USB الأصلي غير متصل أو يتطلب برنامج تشغيل الجهاز المخصص',
      );
    }
  }

  @override
  Future<bool> testPrint() async {
    if (!isHardwareAttached) return false;
    return true;
  }

  @override
  Future<void> openCashDrawer() async {
    if (!isHardwareAttached) {
      throw const UnsupportedPrinterOperationFailure('منفذ USB غير متصل لفتح الدرج');
    }
  }

  @override
  Future<void> cutPaper() async {
    if (!isHardwareAttached) {
      throw const UnsupportedPrinterOperationFailure('منفذ USB غير متصل لقطع الورق');
    }
  }

  @override
  Future<PrinterStatus> getStatus() async {
    if (!isHardwareAttached) return PrinterStatus.offline;
    return PrinterStatus.online;
  }
}
