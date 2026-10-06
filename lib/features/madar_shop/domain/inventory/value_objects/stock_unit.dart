// وحدات قياس المخزون المدعومة (MADAR SHOP Stock Unit Value Object)
// Pure Dart — Zero UI Dependencies

enum StockUnit {
  piece, // قطعة / عدد
  kg,    // كيلوغرام
  gram,  // غرام
  liter, // لتر
  meter; // متر

  static StockUnit fromString(String? val) {
    if (val == null) return StockUnit.piece;
    switch (val.trim().toLowerCase()) {
      case 'kg':
      case 'kilogram':
        return StockUnit.kg;
      case 'g':
      case 'gram':
        return StockUnit.gram;
      case 'l':
      case 'liter':
      case 'litre':
        return StockUnit.liter;
      case 'm':
      case 'meter':
        return StockUnit.meter;
      case 'piece':
      case 'unit':
      default:
        return StockUnit.piece;
    }
  }

  String toDbString() {
    switch (this) {
      case StockUnit.piece:
        return 'piece';
      case StockUnit.kg:
        return 'kg';
      case StockUnit.gram:
        return 'gram';
      case StockUnit.liter:
        return 'liter';
      case StockUnit.meter:
        return 'meter';
    }
  }

  String get displayNameAr {
    switch (this) {
      case StockUnit.piece:
        return 'قطعة';
      case StockUnit.kg:
        return 'كغم';
      case StockUnit.gram:
        return 'غرام';
      case StockUnit.liter:
        return 'لتر';
      case StockUnit.meter:
        return 'متر';
    }
  }
}
