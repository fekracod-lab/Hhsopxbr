// حالات حالة المخزون المشتقة (MADAR SHOP Derived Stock Status Enum)
// Pure Dart — Zero UI Dependencies

enum StockStatus {
  inStock,      // متوفر
  lowStock,     // مخزون منخفض (تحت حد إعادة الطلب)
  outOfStock,   // نفد المخزون (صفر)
  negative;     // رصيد سالب (في السياسات التي تسمح بذلك فقط)

  String get displayNameAr {
    switch (this) {
      case StockStatus.inStock:
        return 'متوفر';
      case StockStatus.lowStock:
        return 'مخزون منخفض';
      case StockStatus.outOfStock:
        return 'نفد المخزون';
      case StockStatus.negative:
        return 'رصيد سالب';
    }
  }
}
