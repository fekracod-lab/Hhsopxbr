// طرق استرداد أموال المرتجع (MADAR SHOP Refund Method Enum)
// Pure Dart — Zero UI Dependencies

enum RefundMethod {
  /// استرداد نقدي فوري
  cash,

  /// استرداد إلى البطاقة المصرفية للزبون
  card,

  /// محفظة رقمية (ZainCash, Qi, FastPay)
  digital,

  /// قيد رصيد دائن في حساب العميل لدى المتجر (Store Credit / Customer Ledger)
  customerCredit;

  bool get isCash => this == RefundMethod.cash;
  bool get isCard => this == RefundMethod.card;
  bool get isDigital => this == RefundMethod.digital;
  bool get isCustomerCredit => this == RefundMethod.customerCredit;

  String get displayNameAr {
    switch (this) {
      case RefundMethod.cash:
        return 'نقدي';
      case RefundMethod.card:
        return 'بطاقة بنكية';
      case RefundMethod.digital:
        return 'محفظة إلكترونية';
      case RefundMethod.customerCredit:
        return 'رصيد دائن بحساب العميل';
    }
  }

  static RefundMethod fromString(String? val) {
    if (val == null) return RefundMethod.cash;
    switch (val.trim().toLowerCase()) {
      case 'card':
        return RefundMethod.card;
      case 'digital':
        return RefundMethod.digital;
      case 'customercredit':
      case 'customer_credit':
      case 'store_credit':
        return RefundMethod.customerCredit;
      case 'cash':
      default:
        return RefundMethod.cash;
    }
  }
}
