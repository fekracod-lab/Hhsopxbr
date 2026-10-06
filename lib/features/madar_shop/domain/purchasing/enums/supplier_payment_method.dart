// طرق سداد دفعات الموردين (MADAR SHOP Supplier Payment Method)
// Pure Dart — Zero UI Dependencies

enum SupplierPaymentMethod {
  cash,
  bankTransfer,
  card,
  digital;

  bool get isCash => this == SupplierPaymentMethod.cash;
  bool get isBankTransfer => this == SupplierPaymentMethod.bankTransfer;
  bool get isCard => this == SupplierPaymentMethod.card;
  bool get isDigital => this == SupplierPaymentMethod.digital;

  String get displayNameAr {
    switch (this) {
      case SupplierPaymentMethod.cash:
        return 'نقدي';
      case SupplierPaymentMethod.bankTransfer:
        return 'تحويل بنكي / حوالة';
      case SupplierPaymentMethod.card:
        return 'بطاقة مصرفية';
      case SupplierPaymentMethod.digital:
        return 'محفظة إلكترونية';
    }
  }

  static SupplierPaymentMethod fromString(String? value) {
    if (value == null) return SupplierPaymentMethod.cash;
    switch (value.trim().toLowerCase()) {
      case 'banktransfer':
      case 'bank_transfer':
        return SupplierPaymentMethod.bankTransfer;
      case 'card':
        return SupplierPaymentMethod.card;
      case 'digital':
        return SupplierPaymentMethod.digital;
      case 'cash':
      default:
        return SupplierPaymentMethod.cash;
    }
  }
}
