// كائن قيمة العملة لنظام نقاط البيع (MADAR SHOP Currency Value Object)
// Pure Dart — Zero UI Dependencies

class Currency {
  final String code;
  final String symbol;
  final int decimalDigits;
  final String displayNameAr;

  const Currency({
    required this.code,
    required this.symbol,
    this.decimalDigits = 0,
    required this.displayNameAr,
  });

  static const Currency iqd = Currency(
    code: 'IQD',
    symbol: 'د.ع',
    decimalDigits: 0,
    displayNameAr: 'دينار عراقي',
  );

  static const Currency usd = Currency(
    code: 'USD',
    symbol: '\$',
    decimalDigits: 2,
    displayNameAr: 'دولار أمريكي',
  );

  static Currency fromCode(String? code) {
    if (code == null) return iqd;
    switch (code.trim().toUpperCase()) {
      case 'USD':
        return usd;
      case 'IQD':
      default:
        return iqd;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Currency &&
          runtimeType == other.runtimeType &&
          code.toUpperCase() == other.code.toUpperCase();

  @override
  int get hashCode => code.toUpperCase().hashCode;

  @override
  String toString() => code;
}
