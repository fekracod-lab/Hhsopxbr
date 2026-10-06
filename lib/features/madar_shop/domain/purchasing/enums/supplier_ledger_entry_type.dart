// أنواع قيود سجل حساب المورد (MADAR SHOP Supplier Ledger Entry Type)
// Pure Dart — Zero UI Dependencies

enum SupplierLedgerEntryType {
  /// شراء بضاعة (يزيد الالتزام المالي / Payable للمورد)
  purchase,

  /// سداد دفعة للمورد (يخفض الالتزام المالي / Payable)
  payment,

  /// إشعار دائن من المورد / مرتجع مشتريات (يخفض الالتزام المالي)
  creditNote,

  /// إشعار مدين للمورد (تسوية مدينة تخفض أو تعدل الالتزام)
  debitNote,

  /// تسوية حسابية (قد تزيد أو تخفض حسب قيمة الفارق)
  adjustment;

  bool get isPurchase => this == SupplierLedgerEntryType.purchase;
  bool get isPayment => this == SupplierLedgerEntryType.payment;
  bool get isCreditNote => this == SupplierLedgerEntryType.creditNote;
  bool get isDebitNote => this == SupplierLedgerEntryType.debitNote;
  bool get isAdjustment => this == SupplierLedgerEntryType.adjustment;

  static SupplierLedgerEntryType fromString(String? value) {
    if (value == null) return SupplierLedgerEntryType.purchase;
    switch (value.trim().toLowerCase()) {
      case 'payment':
        return SupplierLedgerEntryType.payment;
      case 'creditnote':
      case 'credit_note':
        return SupplierLedgerEntryType.creditNote;
      case 'debitnote':
      case 'debit_note':
        return SupplierLedgerEntryType.debitNote;
      case 'adjustment':
        return SupplierLedgerEntryType.adjustment;
      case 'purchase':
      default:
        return SupplierLedgerEntryType.purchase;
    }
  }
}
