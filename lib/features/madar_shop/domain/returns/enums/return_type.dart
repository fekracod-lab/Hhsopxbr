// نوع الإرجاع (MADAR SHOP Return Type Enum)
// Pure Dart — Zero UI Dependencies

enum ReturnType {
  /// إرجاع كامل الفاتورة الأصلية
  fullReturn,

  /// إرجاع جزئي لبنود أو كميات محددة
  partialReturn;

  bool get isFull => this == ReturnType.fullReturn;
  bool get isPartial => this == ReturnType.partialReturn;

  static ReturnType fromString(String? val) {
    if (val == null) return ReturnType.partialReturn;
    switch (val.trim().toLowerCase()) {
      case 'full':
      case 'full_return':
        return ReturnType.fullReturn;
      case 'partial':
      case 'partial_return':
      default:
        return ReturnType.partialReturn;
    }
  }
}
