// حالات تنفيذ استرداد الأموال (MADAR SHOP Refund Status Enum)
// Pure Dart — Zero UI Dependencies

enum RefundStatus {
  /// قيد الانتظار
  pending,

  /// جاري التنفيذ
  processing,

  /// اكتمل الاسترداد وسُجلت القيود المالية
  completed,

  /// فشل الاسترداد
  failed,

  /// ملغى
  cancelled;

  bool get isPending => this == RefundStatus.pending;
  bool get isProcessing => this == RefundStatus.processing;
  bool get isCompleted => this == RefundStatus.completed;
  bool get isFailed => this == RefundStatus.failed;
  bool get isCancelled => this == RefundStatus.cancelled;

  static RefundStatus fromString(String? val) {
    if (val == null) return RefundStatus.pending;
    switch (val.trim().toLowerCase()) {
      case 'processing':
        return RefundStatus.processing;
      case 'completed':
        return RefundStatus.completed;
      case 'failed':
        return RefundStatus.failed;
      case 'cancelled':
      case 'canceled':
        return RefundStatus.cancelled;
      case 'pending':
      default:
        return RefundStatus.pending;
    }
  }
}
