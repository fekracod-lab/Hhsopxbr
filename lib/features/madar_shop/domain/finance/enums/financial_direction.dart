// اتجاه القيد المالي المحاسبي (MADAR SHOP Financial Direction Enum)
// Pure Dart — Zero UI Dependencies

enum FinancialDirection {
  /// مدين (Debit)
  debit,

  /// دائن (Credit)
  credit;

  bool get isDebit => this == FinancialDirection.debit;
  bool get isCredit => this == FinancialDirection.credit;

  static FinancialDirection fromString(String? val) {
    if (val == null) return FinancialDirection.debit;
    switch (val.trim().toLowerCase()) {
      case 'credit':
      case 'cr':
        return FinancialDirection.credit;
      case 'debit':
      case 'dr':
      default:
        return FinancialDirection.debit;
    }
  }
}
