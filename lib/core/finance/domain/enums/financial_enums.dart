/// أنواع الحسابات المالية في مدار
enum FinancialAccountType {
  customer('customer'),
  driver('driver'),
  restaurant('restaurant'),
  store('store'),
  platform('platform');

  final String key;
  const FinancialAccountType(this.key);

  static FinancialAccountType fromString(String? val) {
    if (val == null || val.isEmpty) return FinancialAccountType.customer;
    final normalized = val.trim().toLowerCase();
    for (final type in FinancialAccountType.values) {
      if (type.key == normalized) return type;
    }
    return FinancialAccountType.customer;
  }
}

/// نوع القيد المحاسبي (مدين أو دائن)
enum LedgerEntryType {
  debit('debit'),
  credit('credit');

  final String key;
  const LedgerEntryType(this.key);

  static LedgerEntryType fromString(String? val) {
    if (val == null) return LedgerEntryType.debit;
    return LedgerEntryType.values.firstWhere(
      (e) => e.key == val.trim().toLowerCase(),
      orElse: () => LedgerEntryType.debit,
    );
  }
}

/// تصنيف المعاملة المالية
enum TransactionCategory {
  orderPayment('order_payment'),
  orderRefund('order_refund'),
  driverPayout('driver_payout'),
  merchantSettlement('merchant_settlement'),
  platformCommission('platform_commission'),
  walletDeposit('wallet_deposit'),
  walletWithdrawal('wallet_withdrawal'),
  pointsConversion('points_conversion');

  final String key;
  const TransactionCategory(this.key);

  static TransactionCategory fromString(String? val) {
    if (val == null) return TransactionCategory.orderPayment;
    return TransactionCategory.values.firstWhere(
      (e) => e.key == val.trim().toLowerCase(),
      orElse: () => TransactionCategory.orderPayment,
    );
  }
}

/// حالة المعاملة المالية
enum FinancialTransactionStatus {
  pending('pending'),
  processing('processing'),
  committed('committed'),
  rolledBack('rolled_back'),
  failed('failed');

  final String key;
  const FinancialTransactionStatus(this.key);

  static FinancialTransactionStatus fromString(String? val) {
    if (val == null) return FinancialTransactionStatus.pending;
    return FinancialTransactionStatus.values.firstWhere(
      (e) => e.key == val.trim().toLowerCase(),
      orElse: () => FinancialTransactionStatus.pending,
    );
  }
}

/// حالة التسوية المالية
enum SettlementStatus {
  pending('pending'),
  settled('settled'),
  disputed('disputed'),
  cancelled('cancelled');

  final String key;
  const SettlementStatus(this.key);

  static SettlementStatus fromString(String? val) {
    if (val == null) return SettlementStatus.pending;
    return SettlementStatus.values.firstWhere(
      (e) => e.key == val.trim().toLowerCase(),
      orElse: () => SettlementStatus.pending,
    );
  }
}
