// عقد وسيط تشغيل الطابعة (MADAR SHOP Printer Driver Interface)
// Pure Dart — Zero UI Dependencies

import '../entities/print_job.dart';
import '../enums/printer_status.dart';
import '../value_objects/rendered_payload.dart';

abstract class IPrinterDriver {
  /// الاتصال بالطابعة عبر البروتوكول المحدد
  Future<bool> connect({Duration timeout = const Duration(seconds: 5)});

  /// إنهاء الاتصال بالطابعة
  Future<void> disconnect();

  /// إرسال حمولة الطباعة
  Future<void> printPayload(PrintJob job, RenderedPayload payload);

  /// طباعة صفحة فحص للتأكد من جاهزية الطابعة
  Future<bool> testPrint();

  /// إصدار أمر فتح درج النقد (Pulse Cash Drawer)
  Future<void> openCashDrawer();

  /// إصدار أمر قطع الورق (Cut Paper)
  Future<void> cutPaper();

  /// التحقق من حالة الطابعة اللحظية
  Future<PrinterStatus> getStatus();
}
