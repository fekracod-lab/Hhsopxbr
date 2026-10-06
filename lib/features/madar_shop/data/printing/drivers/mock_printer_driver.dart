// سائق وهمي للاختبارات والمحاكاة المنضبطة (MADAR SHOP Mock Printer Driver)
// Pure Dart — Zero UI Dependencies

import '../../../domain/printing/contracts/i_printer_driver.dart';
import '../../../domain/printing/entities/print_job.dart';
import '../../../domain/printing/enums/printer_status.dart';
import '../../../domain/printing/failures/printing_failures.dart';
import '../../../domain/printing/value_objects/rendered_payload.dart';

class MockPrinterDriver implements IPrinterDriver {
  PrinterStatus status;
  bool shouldFailConnect;
  bool shouldTimeoutAck;
  bool shouldFailPrint;
  Duration simulatedDelay;
  int drawerKickCount = 0;
  int cutCount = 0;
  bool isConnected = false;

  final List<PrintJob> printedJobs = [];
  final List<RenderedPayload> printedPayloads = [];

  MockPrinterDriver({
    this.status = PrinterStatus.online,
    this.shouldFailConnect = false,
    this.shouldTimeoutAck = false,
    this.shouldFailPrint = false,
    this.simulatedDelay = Duration.zero,
  });

  @override
  Future<bool> connect({Duration timeout = const Duration(seconds: 5)}) async {
    if (simulatedDelay > Duration.zero) {
      await Future.delayed(simulatedDelay);
    }
    if (shouldFailConnect || status == PrinterStatus.offline) {
      isConnected = false;
      return false;
    }
    isConnected = true;
    return true;
  }

  @override
  Future<void> disconnect() async {
    isConnected = false;
  }

  @override
  Future<void> printPayload(PrintJob job, RenderedPayload payload) async {
    if (simulatedDelay > Duration.zero) {
      await Future.delayed(simulatedDelay);
    }

    if (!isConnected && status == PrinterStatus.offline) {
      throw const PrinterOfflineFailure('الطابعة غير متصلة بالشبكة');
    }

    if (shouldFailPrint || status == PrinterStatus.error) {
      throw const PrinterHardwareFailure('حدث خطأ في عتاد الطابعة');
    }

    if (status == PrinterStatus.paperOut) {
      throw const PaperOutFailure('نفد ورق الطابعة');
    }

    if (shouldTimeoutAck) {
      // تم إرسال البيانات ولكن انقطع اتصال التأكيد (ACK Timeout)
      // النظام لا يستطيع التأكد هل طبع الورق أم لا
      throw const PrintAckTimeoutFailure(
        'انتهت مهلة استلام التأكيد بعد إرسال الأمر (ACK Timeout)',
      );
    }

    // تسجيل النجاح
    printedJobs.add(job);
    printedPayloads.add(payload);

    if (payload.hasDrawerKick) {
      drawerKickCount++;
    }
    if (payload.hasCutCommand) {
      cutCount++;
    }
  }

  @override
  Future<bool> testPrint() async {
    return isConnected && status == PrinterStatus.online;
  }

  @override
  Future<void> openCashDrawer() async {
    drawerKickCount++;
  }

  @override
  Future<void> cutPaper() async {
    cutCount++;
  }

  @override
  Future<PrinterStatus> getStatus() async {
    return status;
  }

  void reset() {
    status = PrinterStatus.online;
    shouldFailConnect = false;
    shouldTimeoutAck = false;
    shouldFailPrint = false;
    simulatedDelay = Duration.zero;
    drawerKickCount = 0;
    cutCount = 0;
    isConnected = false;
    printedJobs.clear;
    printedPayloads.clear;
  }
}
