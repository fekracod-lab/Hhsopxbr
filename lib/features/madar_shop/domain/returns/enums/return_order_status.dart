// حالات أمر المرتجع للزبون (MADAR SHOP Customer Return Order Status)
// Pure Dart — Zero UI Dependencies

enum ReturnOrderStatus {
  /// طُلب من قبل الكاشير أو العميل وفي انتظار الموافقة
  requested,

  /// تمت الموافقة عليه من قبل المشرف أو المدير
  approved,

  /// استلمت البضاعة وفُحصت بالمخزن
  received,

  /// صُرف المبلغ أو اعتمد كرصيد دائن للعميل
  refunded,

  /// مكتمل بالكامل ونهائي
  completed,

  /// مرفوض من الإدارة
  rejected,

  /// ملغى قبل البدء
  cancelled;

  bool get isRequested => this == ReturnOrderStatus.requested;
  bool get isApproved => this == ReturnOrderStatus.approved;
  bool get isReceived => this == ReturnOrderStatus.received;
  bool get isRefunded => this == ReturnOrderStatus.refunded;
  bool get isCompleted => this == ReturnOrderStatus.completed;
  bool get isRejected => this == ReturnOrderStatus.rejected;
  bool get isCancelled => this == ReturnOrderStatus.cancelled;

  bool get isTerminal =>
      this == ReturnOrderStatus.completed ||
      this == ReturnOrderStatus.rejected ||
      this == ReturnOrderStatus.cancelled;

  bool get canApprove => this == ReturnOrderStatus.requested;
  bool get canReceive => this == ReturnOrderStatus.approved;
  bool get canRefund => this == ReturnOrderStatus.received;
  bool get canComplete => this == ReturnOrderStatus.refunded;
  bool get canCancel => this == ReturnOrderStatus.requested || this == ReturnOrderStatus.approved;

  static ReturnOrderStatus fromString(String? value) {
    if (value == null) return ReturnOrderStatus.requested;
    switch (value.trim().toLowerCase()) {
      case 'approved':
        return ReturnOrderStatus.approved;
      case 'received':
        return ReturnOrderStatus.received;
      case 'refunded':
        return ReturnOrderStatus.refunded;
      case 'completed':
        return ReturnOrderStatus.completed;
      case 'rejected':
        return ReturnOrderStatus.rejected;
      case 'cancelled':
      case 'canceled':
        return ReturnOrderStatus.cancelled;
      case 'requested':
      default:
        return ReturnOrderStatus.requested;
    }
  }
}
