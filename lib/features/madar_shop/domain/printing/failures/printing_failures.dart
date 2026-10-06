// إخفاقات واستثناءات نظام الطباعة والعتاد (MADAR SHOP Printing Domain Failures)
// Pure Dart — Zero UI Dependencies

abstract class PrintingFailure implements Exception {
  final String message;
  final String code;

  const PrintingFailure(this.message, this.code);

  @override
  String toString() => '$runtimeType: $message ($code)';
}

class PrinterNotFoundFailure extends PrintingFailure {
  const PrinterNotFoundFailure([String message = 'الطابعة المحددة غير موجودة أو غير مسجلة.'])
      : super(message, 'PRINTER_NOT_FOUND');
}

class PrinterOfflineFailure extends PrintingFailure {
  const PrinterOfflineFailure([String message = 'الطابعة غير متصلة أو خارج نطاق الشبكة.'])
      : super(message, 'PRINTER_OFFLINE');
}

class UnsupportedPrinterCapabilityFailure extends PrintingFailure {
  const UnsupportedPrinterCapabilityFailure(String capability, [String message = 'ميزة العتاد غير مدعومة في هذه الطابعة.'])
      : super('$message ($capability)', 'UNSUPPORTED_PRINTER_CAPABILITY');
}

class PrintJobCancelledFailure extends PrintingFailure {
  const PrintJobCancelledFailure([String message = 'تم إلغاء مهمة الطباعة.'])
      : super(message, 'PRINT_JOB_CANCELLED');
}

class PrintTimeoutFailure extends PrintingFailure {
  const PrintTimeoutFailure([String message = 'انتهت المهلة المحددة للاتصال بالطابعة أو استلام التأكيد.'])
      : super(message, 'PRINT_TIMEOUT');
}

class DuplicateAutoPrintFailure extends PrintingFailure {
  const DuplicateAutoPrintFailure([String message = 'تمت طباعة المستند تلقائياً مسبقاً. لإعادة الطباعة استخدم أمر Reprint اليدوي.'])
      : super(message, 'DUPLICATE_AUTO_PRINT');
}

class UnknownPrintStateFailure extends PrintingFailure {
  const UnknownPrintStateFailure([String message = 'فقد الاتصال بعد إرسال الأمر. حالة الطباعة غير مؤكدة وتتطلب تأكيداً يدوياً منعاً للازدواج.'])
      : super(message, 'UNKNOWN_PRINT_STATE');
}

class PrintingPermissionDeniedFailure extends PrintingFailure {
  const PrintingPermissionDeniedFailure([String message = 'المستخدم لا يملك صلاحية الطباعة أو إعادة الطباعة.'])
      : super(message, 'PRINTING_PERMISSION_DENIED');
}

class PrintingBranchMismatchFailure extends PrintingFailure {
  const PrintingBranchMismatchFailure([String message = 'لا يمكن توجيه الطباعة إلى طابعة تابعة لفرع آخر دون تفويض.'])
      : super(message, 'PRINTING_BRANCH_MISMATCH');
}

class InvalidPrintDocumentFailure extends PrintingFailure {
  const InvalidPrintDocumentFailure([String message = 'مستند الطباعة غير صالح أو فارغ من أي محتوى.'])
      : super(message, 'INVALID_PRINT_DOCUMENT');
}

class InvalidPrintStateTransitionFailure extends PrintingFailure {
  const InvalidPrintStateTransitionFailure([String message = 'الانتقال بين حالات مهمة الطباعة غير مسموح برمجياً.'])
      : super(message, 'INVALID_PRINT_STATE_TRANSITION');
}

class PrintAckTimeoutFailure extends PrintingFailure {
  const PrintAckTimeoutFailure([String message = 'انتهت مهلة استلام التأكيد بعد إرسال الأمر (ACK Timeout).'])
      : super(message, 'PRINT_ACK_TIMEOUT');
}

class PrintJobNotFoundFailure extends PrintingFailure {
  const PrintJobNotFoundFailure([String message = 'مهمة الطباعة المحددة غير موجودة.'])
      : super(message, 'PRINT_JOB_NOT_FOUND');
}

class PrinterHardwareFailure extends PrintingFailure {
  const PrinterHardwareFailure([String message = 'حدث خطأ في عتاد الطابعة أو تعذر إتمام النقل.'])
      : super(message, 'PRINTER_HARDWARE_FAILURE');
}

class PaperOutFailure extends PrintingFailure {
  const PaperOutFailure([String message = 'نفد ورق الطابعة أو الغطاء مفتوح.'])
      : super(message, 'PAPER_OUT');
}

class UnsupportedPrinterOperationFailure extends PrintingFailure {
  const UnsupportedPrinterOperationFailure([String message = 'العملية أو وسيط التشغيل غير مدعوم على هذه المنصة.'])
      : super(message, 'UNSUPPORTED_PRINTER_OPERATION');
}

class NoAvailablePrinterFailure extends PrintingFailure {
  const NoAvailablePrinterFailure([String message = 'لا توجد أي طابعة مهيأة للفرع المحدد.'])
      : super(message, 'NO_AVAILABLE_PRINTER');
}

class CrossBranchPrinterAccessFailure extends PrintingFailure {
  const CrossBranchPrinterAccessFailure([String message = 'ممنوع أمنياً: محاولة استخدام طابعة أو ملف تعريف يتبع فرعاً أو متجراً آخر.'])
      : super(message, 'CROSS_BRANCH_PRINTER_ACCESS');
}

class DuplicatePrintRequestFailure extends PrintingFailure {
  const DuplicatePrintRequestFailure([String message = 'طلب الطباعة مكرر بالمفتاح المعطى.'])
      : super(message, 'DUPLICATE_PRINT_REQUEST');
}

class InvalidReprintReasonFailure extends PrintingFailure {
  const InvalidReprintReasonFailure([String message = 'إعادة الطباعة اليدوية تتطلب تحديد سبب واضح ومبرر للتدقيق.'])
      : super(message, 'INVALID_REPRINT_REASON');
}

class AutoPrintSuppressedFailure extends PrintingFailure {
  const AutoPrintSuppressedFailure([String message = 'تم حجب الطباعة التلقائية وفقاً لسياسة المتجر أو الفرع المعتمدة.'])
      : super(message, 'AUTO_PRINT_SUPPRESSED');
}

