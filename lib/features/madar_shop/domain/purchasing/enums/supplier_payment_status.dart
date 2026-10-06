// حالة عملية سداد المورد (MADAR SHOP Supplier Payment Status)
// Pure Dart — Zero UI Dependencies

enum SupplierPaymentStatus {
  pending,
  completed,
  cancelled,
  failed;

  bool get isPending => this == SupplierPaymentStatus.pending;
  bool get isCompleted => this == SupplierPaymentStatus.completed;
  bool get isCancelled => this == SupplierPaymentStatus.cancelled;
  bool get isFailed => this == SupplierPaymentStatus.failed;

  static SupplierPaymentStatus fromString(String? value) {
    if (value == null) return SupplierPaymentStatus.pending;
    switch (value.trim().toLowerCase()) {
      case 'completed':
        return SupplierPaymentStatus.completed;
      case 'cancelled':
      case 'canceled':
        return SupplierPaymentStatus.cancelled;
      case 'failed':
        return SupplierPaymentStatus.failed;
      case 'pending':
      default:
        return SupplierPaymentStatus.pending;
    }
  }
}
