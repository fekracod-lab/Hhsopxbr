// أسباب إرجاع البضاعة (MADAR SHOP Return Reason Enum)
// Pure Dart — Zero UI Dependencies

enum ReturnReason {
  /// عيب مصنعي أو سلعة معيبة
  defective,

  /// صنف خاطئ أو غير مطابق للمطلوب
  wrongItem,

  /// تراجع الزبون ورغبته بالإلغاء ضمن مهلة الإرجاع
  customerChangedMind,

  /// منتهية الصلاحية
  expired,

  /// تالف أثناء النقل أو التسليم
  damagedInTransit,

  /// سبب آخر محدد بالملاحظات
  other;

  String get displayNameAr {
    switch (this) {
      case ReturnReason.defective:
        return 'عيب مصنعي أو خلل فني';
      case ReturnReason.wrongItem:
        return 'صنف خاطئ أو غير مطابق';
      case ReturnReason.customerChangedMind:
        return 'رغبة الزبون بالاسترجاع';
      case ReturnReason.expired:
        return 'منتهي الصلاحية';
      case ReturnReason.damagedInTransit:
        return 'تالف أثناء التوصيل';
      case ReturnReason.other:
        return 'أخرى';
    }
  }

  static ReturnReason fromString(String? val) {
    if (val == null) return ReturnReason.other;
    switch (val.trim().toLowerCase()) {
      case 'defective':
        return ReturnReason.defective;
      case 'wrong_item':
      case 'wrongitem':
        return ReturnReason.wrongItem;
      case 'customer_changed_mind':
      case 'changed_mind':
        return ReturnReason.customerChangedMind;
      case 'expired':
        return ReturnReason.expired;
      case 'damaged_in_transit':
      case 'damaged':
        return ReturnReason.damagedInTransit;
      case 'other':
      default:
        return ReturnReason.other;
    }
  }
}
