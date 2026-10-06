// طرق الدفع المدعومة في نقطة البيع (MADAR SHOP Payment Method Enum)
// Pure Dart — Zero UI Dependencies

enum PaymentMethod {
  cash,
  card,
  digital,
  credit;

  static PaymentMethod fromString(String? val) {
    if (val == null) return PaymentMethod.cash;
    switch (val.trim().toLowerCase()) {
      case 'card':
      case 'pos_card':
        return PaymentMethod.card;
      case 'digital':
      case 'zain_cash':
      case 'wallet':
        return PaymentMethod.digital;
      case 'credit':
      case 'debt':
        return PaymentMethod.credit;
      case 'cash':
      default:
        return PaymentMethod.cash;
    }
  }

  String toDbString() {
    switch (this) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.card:
        return 'card';
      case PaymentMethod.digital:
        return 'digital';
      case PaymentMethod.credit:
        return 'credit';
    }
  }

  String get displayNameAr {
    switch (this) {
      case PaymentMethod.cash:
        return 'نقداً';
      case PaymentMethod.card:
        return 'بطاقة إلكترونية / POS';
      case PaymentMethod.digital:
        return 'محفظة رقمية';
      case PaymentMethod.credit:
        return 'آجل (ذمة العميل)';
    }
  }
}
