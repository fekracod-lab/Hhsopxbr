// حالة مهمة الطباعة في قائمة الانتظار (MADAR SHOP Print Job Status Enum)
// Pure Dart — Zero UI Dependencies

enum PrintJobStatus {
  queued,
  printing,
  completed,
  failed,
  cancelled,
  unknownRequiresConfirmation;

  bool get isTerminal => this == PrintJobStatus.completed || this == PrintJobStatus.failed || this == PrintJobStatus.cancelled;
  bool get isPending => this == PrintJobStatus.queued || this == PrintJobStatus.printing;
  bool get requiresConfirmation => this == PrintJobStatus.unknownRequiresConfirmation;

  static PrintJobStatus fromString(String? val) {
    if (val == null) return PrintJobStatus.queued;
    switch (val.trim().toLowerCase()) {
      case 'queued':
        return PrintJobStatus.queued;
      case 'printing':
        return PrintJobStatus.printing;
      case 'completed':
        return PrintJobStatus.completed;
      case 'failed':
        return PrintJobStatus.failed;
      case 'cancelled':
      case 'canceled':
        return PrintJobStatus.cancelled;
      case 'unknown':
      case 'unknown_requires_confirmation':
      case 'requires_confirmation':
        return PrintJobStatus.unknownRequiresConfirmation;
      default:
        return PrintJobStatus.queued;
    }
  }

  String toDbString() {
    switch (this) {
      case PrintJobStatus.queued:
        return 'queued';
      case PrintJobStatus.printing:
        return 'printing';
      case PrintJobStatus.completed:
        return 'completed';
      case PrintJobStatus.failed:
        return 'failed';
      case PrintJobStatus.cancelled:
        return 'cancelled';
      case PrintJobStatus.unknownRequiresConfirmation:
        return 'unknown_requires_confirmation';
    }
  }

  String get displayNameAr {
    switch (this) {
      case PrintJobStatus.queued:
        return 'في قائمة الانتظار (Queued)';
      case PrintJobStatus.printing:
        return 'جارٍ الإرسال والطباعة';
      case PrintJobStatus.completed:
        return 'اكتملت الطباعة بنجاح';
      case PrintJobStatus.failed:
        return 'فشلت الطباعة';
      case PrintJobStatus.cancelled:
        return 'أُلغيت المهمة';
      case PrintJobStatus.unknownRequiresConfirmation:
        return 'حالة غير مؤكدة — تتطلب تأكيد الكاشير لمنع الطباعة المزدوجة';
    }
  }
}
