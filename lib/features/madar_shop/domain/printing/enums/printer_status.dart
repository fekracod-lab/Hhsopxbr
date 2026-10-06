// حالة الطابعة التشغيلية (MADAR SHOP Printer Status Enum)
// Pure Dart — Zero UI Dependencies

enum PrinterStatus {
  online,
  offline,
  busy,
  error,
  paperOut,
  coverOpen,
  unknown;

  bool get isReady => this == PrinterStatus.online;
  bool get isUnavailable => this == PrinterStatus.offline || this == PrinterStatus.error || this == PrinterStatus.unknown;
  bool get hasHardwareWarning => this == PrinterStatus.paperOut || this == PrinterStatus.coverOpen;

  static PrinterStatus fromString(String? val) {
    if (val == null) return PrinterStatus.unknown;
    switch (val.trim().toLowerCase()) {
      case 'online':
      case 'ready':
        return PrinterStatus.online;
      case 'offline':
        return PrinterStatus.offline;
      case 'busy':
        return PrinterStatus.busy;
      case 'error':
        return PrinterStatus.error;
      case 'paper_out':
      case 'paperout':
        return PrinterStatus.paperOut;
      case 'cover_open':
      case 'coveropen':
        return PrinterStatus.coverOpen;
      default:
        return PrinterStatus.unknown;
    }
  }

  String toDbString() {
    switch (this) {
      case PrinterStatus.online:
        return 'online';
      case PrinterStatus.offline:
        return 'offline';
      case PrinterStatus.busy:
        return 'busy';
      case PrinterStatus.error:
        return 'error';
      case PrinterStatus.paperOut:
        return 'paper_out';
      case PrinterStatus.coverOpen:
        return 'cover_open';
      case PrinterStatus.unknown:
        return 'unknown';
    }
  }

  String get displayNameAr {
    switch (this) {
      case PrinterStatus.online:
        return 'متصلة وجاهزة للطباعة';
      case PrinterStatus.offline:
        return 'غير متصلة (Offline)';
      case PrinterStatus.busy:
        return 'مشغولة حالياً بطباعة أخرى';
      case PrinterStatus.error:
        return 'خطأ في الطابعة';
      case PrinterStatus.paperOut:
        return 'نفد ورق الطباعة';
      case PrinterStatus.coverOpen:
        return 'غطاء الطابعة مفتوح';
      case PrinterStatus.unknown:
        return 'حالة غير معروفة';
    }
  }
}
