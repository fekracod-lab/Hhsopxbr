// حالات عملية الدفع في نقطة البيع (MADAR SHOP Payment Status Enum)
// Pure Dart — Zero UI Dependencies

enum PaymentStatus {
  pending,
  authorized,
  completed,
  failed,
  refunded;

  static PaymentStatus fromString(String? val) {
    if (val == null) return PaymentStatus.completed;
    switch (val.trim().toLowerCase()) {
      case 'pending':
        return PaymentStatus.pending;
      case 'authorized':
        return PaymentStatus.authorized;
      case 'completed':
      case 'paid':
        return PaymentStatus.completed;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      default:
        return PaymentStatus.completed;
    }
  }

  String toDbString() {
    switch (this) {
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.authorized:
        return 'authorized';
      case PaymentStatus.completed:
        return 'completed';
      case PaymentStatus.failed:
        return 'failed';
      case PaymentStatus.refunded:
        return 'refunded';
    }
  }
}
