// حالات إرجاع البضاعة إلى المورد (MADAR SHOP Supplier Return Status Enum)
// Pure Dart — Zero UI Dependencies

enum SupplierReturnStatus {
  /// مسودة طلب الإرجاع
  draft,

  /// معتمد وجاهز للتسليم والشحن
  approved,

  /// صُرف من المخزن وأعيد للمورد وصدر به إشعار دائن
  completed,

  /// ملغى
  cancelled;

  bool get isDraft => this == SupplierReturnStatus.draft;
  bool get isApproved => this == SupplierReturnStatus.approved;
  bool get isCompleted => this == SupplierReturnStatus.completed;
  bool get isCancelled => this == SupplierReturnStatus.cancelled;

  static SupplierReturnStatus fromString(String? val) {
    if (val == null) return SupplierReturnStatus.draft;
    switch (val.trim().toLowerCase()) {
      case 'approved':
        return SupplierReturnStatus.approved;
      case 'completed':
        return SupplierReturnStatus.completed;
      case 'cancelled':
      case 'canceled':
        return SupplierReturnStatus.cancelled;
      case 'draft':
      default:
        return SupplierReturnStatus.draft;
    }
  }
}
