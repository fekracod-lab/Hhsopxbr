// حالات معاملة البيع في نقطة البيع (MADAR SHOP POS Sale Status Enum)
// Pure Dart — Zero UI Dependencies

enum SaleStatus {
  draft,
  paymentPending,
  completed,
  cancelled,
  failed;

  static SaleStatus fromString(String? val) {
    if (val == null) return SaleStatus.draft;
    switch (val.trim().toLowerCase()) {
      case 'draft':
        return SaleStatus.draft;
      case 'payment_pending':
      case 'paymentpending':
        return SaleStatus.paymentPending;
      case 'completed':
      case 'paid':
        return SaleStatus.completed;
      case 'cancelled':
      case 'canceled':
        return SaleStatus.cancelled;
      case 'failed':
        return SaleStatus.failed;
      default:
        return SaleStatus.draft;
    }
  }

  String toDbString() {
    switch (this) {
      case SaleStatus.draft:
        return 'draft';
      case SaleStatus.paymentPending:
        return 'payment_pending';
      case SaleStatus.completed:
        return 'completed';
      case SaleStatus.cancelled:
        return 'cancelled';
      case SaleStatus.failed:
        return 'failed';
    }
  }

  String get displayNameAr {
    switch (this) {
      case SaleStatus.draft:
        return 'مسودة';
      case SaleStatus.paymentPending:
        return 'بانتظار الدفع';
      case SaleStatus.completed:
        return 'مكتملة ومدفوعة';
      case SaleStatus.cancelled:
        return 'ملغاة';
      case SaleStatus.failed:
        return 'فشلت';
    }
  }

  bool get isTerminal =>
      this == SaleStatus.completed ||
      this == SaleStatus.cancelled ||
      this == SaleStatus.failed;

  bool get canAcceptPayment =>
      this == SaleStatus.draft || this == SaleStatus.paymentPending;
}
