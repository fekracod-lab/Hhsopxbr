// سياسة السداد الزائد للمورد (MADAR SHOP Supplier Overpayment Policy)
// Pure Dart — Zero UI Dependencies

enum SupplierOverpaymentPolicy {
  /// منع السداد الذي يتجاوز الرصيد المستحق (الافتراضي الصارم)
  block,

  /// تسجيل المبلغ الزائد كرصيد مدين/دائن لصالح المتجر (Advance payment / Credit balance)
  creditBalance,

  /// السماح فقط بموافقة إدارية خاصة
  allowWithApproval;

  bool get isBlock => this == SupplierOverpaymentPolicy.block;
  bool get isCreditBalance => this == SupplierOverpaymentPolicy.creditBalance;
  bool get isAllowWithApproval => this == SupplierOverpaymentPolicy.allowWithApproval;

  static SupplierOverpaymentPolicy fromString(String? value) {
    if (value == null) return SupplierOverpaymentPolicy.block;
    switch (value.trim().toLowerCase()) {
      case 'creditbalance':
      case 'credit_balance':
        return SupplierOverpaymentPolicy.creditBalance;
      case 'allowwithapproval':
      case 'allow_with_approval':
        return SupplierOverpaymentPolicy.allowWithApproval;
      case 'block':
      default:
        return SupplierOverpaymentPolicy.block;
    }
  }
}
