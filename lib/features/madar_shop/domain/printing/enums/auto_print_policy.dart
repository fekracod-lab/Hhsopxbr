// سياسة الطباعة التلقائية (MADAR SHOP Auto Print Policy Enum)
// Pure Dart — Zero UI Dependencies

enum AutoPrintPolicy {
  off,
  saleOnly,
  saleAndReturn,
  allDocuments,
  custom;

  static AutoPrintPolicy fromString(String? val) {
    if (val == null) return AutoPrintPolicy.saleOnly;
    switch (val.trim().toLowerCase()) {
      case 'off':
      case 'disabled':
        return AutoPrintPolicy.off;
      case 'sale_only':
      case 'saleonly':
        return AutoPrintPolicy.saleOnly;
      case 'sale_and_return':
      case 'saleandreturn':
        return AutoPrintPolicy.saleAndReturn;
      case 'all':
      case 'all_documents':
      case 'alldocuments':
        return AutoPrintPolicy.allDocuments;
      case 'custom':
      default:
        return AutoPrintPolicy.custom;
    }
  }

  String toDbString() {
    switch (this) {
      case AutoPrintPolicy.off:
        return 'off';
      case AutoPrintPolicy.saleOnly:
        return 'sale_only';
      case AutoPrintPolicy.saleAndReturn:
        return 'sale_and_return';
      case AutoPrintPolicy.allDocuments:
        return 'all_documents';
      case AutoPrintPolicy.custom:
        return 'custom';
    }
  }

  String get displayNameAr {
    switch (this) {
      case AutoPrintPolicy.off:
        return 'معطلة بالكامل (طباعة يدوية فقط)';
      case AutoPrintPolicy.saleOnly:
        return 'طباعة تلقائية لمبيعات الـ POS فقط';
      case AutoPrintPolicy.saleAndReturn:
        return 'طباعة تلقائية للمبيعات والمرتجعات';
      case AutoPrintPolicy.allDocuments:
        return 'طباعة تلقائية لجميع المستندات والإيصالات';
      case AutoPrintPolicy.custom:
        return 'سياسة مخصصة لكل نوع مستند';
    }
  }
}
