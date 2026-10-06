// حالات دورة حياة أمر الشراء (MADAR SHOP Purchase Order Status)
// Pure Dart — Zero UI Dependencies

enum PurchaseOrderStatus {
  draft,
  submitted,
  approved,
  partiallyReceived,
  received,
  closed,
  cancelled;

  bool get isDraft => this == PurchaseOrderStatus.draft;
  bool get isSubmitted => this == PurchaseOrderStatus.submitted;
  bool get isApproved => this == PurchaseOrderStatus.approved;
  bool get isPartiallyReceived => this == PurchaseOrderStatus.partiallyReceived;
  bool get isReceived => this == PurchaseOrderStatus.received;
  bool get isClosed => this == PurchaseOrderStatus.closed;
  bool get isCancelled => this == PurchaseOrderStatus.cancelled;

  bool get isTerminal => this == PurchaseOrderStatus.closed || this == PurchaseOrderStatus.cancelled;

  bool get canReceive =>
      this == PurchaseOrderStatus.approved || this == PurchaseOrderStatus.partiallyReceived;

  static PurchaseOrderStatus fromString(String? value) {
    if (value == null) return PurchaseOrderStatus.draft;
    switch (value.trim().toLowerCase()) {
      case 'submitted':
        return PurchaseOrderStatus.submitted;
      case 'approved':
        return PurchaseOrderStatus.approved;
      case 'partiallyreceived':
      case 'partially_received':
        return PurchaseOrderStatus.partiallyReceived;
      case 'received':
        return PurchaseOrderStatus.received;
      case 'closed':
        return PurchaseOrderStatus.closed;
      case 'cancelled':
      case 'canceled':
        return PurchaseOrderStatus.cancelled;
      case 'draft':
      default:
        return PurchaseOrderStatus.draft;
    }
  }
}
