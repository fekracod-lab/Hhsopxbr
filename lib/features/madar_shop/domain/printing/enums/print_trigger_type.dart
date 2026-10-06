// نوع إطلاق الطباعة (MADAR SHOP Print Trigger Type Enum)
// Pure Dart — Zero UI Dependencies

enum PrintTriggerType {
  autoPrint,
  manualReprint;

  bool get isAuto => this == PrintTriggerType.autoPrint;
  bool get isManual => this == PrintTriggerType.manualReprint;

  static PrintTriggerType fromString(String? val) {
    if (val == null) return PrintTriggerType.autoPrint;
    switch (val.trim().toLowerCase()) {
      case 'reprint':
      case 'manual':
      case 'manual_reprint':
        return PrintTriggerType.manualReprint;
      case 'auto':
      case 'auto_print':
      default:
        return PrintTriggerType.autoPrint;
    }
  }

  String toDbString() {
    switch (this) {
      case PrintTriggerType.autoPrint:
        return 'auto_print';
      case PrintTriggerType.manualReprint:
        return 'manual_reprint';
    }
  }

  String get displayNameAr {
    switch (this) {
      case PrintTriggerType.autoPrint:
        return 'طباعة تلقائية عند اكتمال العملية';
      case PrintTriggerType.manualReprint:
        return 'إعادة طباعة يدوية بناءً على طلب المستخدم';
    }
  }
}
