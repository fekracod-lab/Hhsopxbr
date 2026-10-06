// أوامر معالجة عمليات الطباعة والأجهزة (MADAR SHOP Printing Commands)
// Pure Dart — Zero UI Dependencies

import '../../../domain/printing/entities/print_document.dart';
import '../../../domain/printing/entities/printer.dart';
import '../../../domain/printing/entities/printer_profile.dart';
import '../../../domain/printing/enums/print_trigger_type.dart';

/// أمر إرسال مهمة طباعة جديدة
class SubmitPrintJobCommand {
  final String businessId;
  final String branchId;
  final PrintDocument document;
  final PrintTriggerType triggerType;
  final String? printerIdOverride;
  final int copies;
  final String requestedBy;
  final String? reprintReason;
  final String idempotencyKey;

  const SubmitPrintJobCommand({
    required this.businessId,
    required this.branchId,
    required this.document,
    required this.triggerType,
    this.printerIdOverride,
    this.copies = 1,
    required this.requestedBy,
    this.reprintReason,
    required this.idempotencyKey,
  });
}

/// أمر إعادة الطباعة اليدوية الصريحة
class ReprintCommand {
  final String businessId;
  final String branchId;
  final String originalJobIdOrDocumentId;
  final PrintDocument document;
  final String? printerIdOverride;
  final int copies;
  final String requestedBy;
  final String reason;
  final String idempotencyKey;

  const ReprintCommand({
    required this.businessId,
    required this.branchId,
    required this.originalJobIdOrDocumentId,
    required this.document,
    this.printerIdOverride,
    this.copies = 1,
    required this.requestedBy,
    required this.reason,
    required this.idempotencyKey,
  });
}

/// أمر تسجيل طابعة جديدة
class RegisterPrinterCommand {
  final String businessId;
  final String branchId;
  final Printer printer;

  const RegisterPrinterCommand({
    required this.businessId,
    required this.branchId,
    required this.printer,
  });
}

/// أمر تهيئة ملف تعريف الطابعة للفرع
class ConfigurePrinterProfileCommand {
  final String businessId;
  final String branchId;
  final PrinterProfile profile;

  const ConfigurePrinterProfileCommand({
    required this.businessId,
    required this.branchId,
    required this.profile,
  });
}

/// أمر إلغاء مهمة طباعة قيد الانتظار
class CancelPrintJobCommand {
  final String businessId;
  final String branchId;
  final String jobId;
  final String cancelledBy;
  final String reason;

  const CancelPrintJobCommand({
    required this.businessId,
    required this.branchId,
    required this.jobId,
    required this.cancelledBy,
    required this.reason,
  });
}
