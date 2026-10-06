// أمر الشراء في نظام مشتريات مدار (MADAR SHOP Purchase Order Entity)
// Pure Dart — Zero UI Dependencies

import '../../pos/value_objects/currency.dart';
import '../../pos/value_objects/money.dart';
import '../enums/purchase_order_status.dart';
import 'purchase_item.dart';

class PurchaseOrder {
  final String id;
  final String businessId;
  final String branchId;
  final String supplierId;
  final String orderNumber;
  final PurchaseOrderStatus status;
  final List<PurchaseItem> items;
  final Money subtotal;
  final Money discountTotal;
  final Money taxTotal;
  final Money grandTotal;
  final Currency currency;
  final String createdBy;
  final String? approvedBy;
  final String? cancelledBy;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final String idempotencyKey;
  final String? notes;

  PurchaseOrder({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.supplierId,
    required this.orderNumber,
    this.status = PurchaseOrderStatus.draft,
    required this.items,
    Money? subtotal,
    Money? discountTotal,
    Money? taxTotal,
    Money? grandTotal,
    Currency? currency,
    required this.createdBy,
    this.approvedBy,
    this.cancelledBy,
    this.cancellationReason,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    required this.idempotencyKey,
    this.notes,
  })  : currency = currency ?? (items.isNotEmpty ? items.first.unitCost.currency : Currency.iqd),
        subtotal = subtotal ??
            (items.isEmpty
                ? Money.zero(currency ?? Currency.iqd)
                : items.map((i) => i.lineSubtotal).reduce((a, b) => a + b)),
        discountTotal = discountTotal ??
            (items.isEmpty
                ? Money.zero(currency ?? Currency.iqd)
                : items.map((i) => i.discount).reduce((a, b) => a + b)),
        taxTotal = taxTotal ??
            (items.isEmpty
                ? Money.zero(currency ?? Currency.iqd)
                : items.map((i) => i.tax).reduce((a, b) => a + b)),
        grandTotal = grandTotal ??
            (items.isEmpty
                ? Money.zero(currency ?? Currency.iqd)
                : items.map((i) => i.lineTotal).reduce((a, b) => a + b));

  bool get isDraft => status == PurchaseOrderStatus.draft;
  bool get isSubmitted => status == PurchaseOrderStatus.submitted;
  bool get isApproved => status == PurchaseOrderStatus.approved;
  bool get isPartiallyReceived => status == PurchaseOrderStatus.partiallyReceived;
  bool get isReceived => status == PurchaseOrderStatus.received;
  bool get isClosed => status == PurchaseOrderStatus.closed;
  bool get isCancelled => status == PurchaseOrderStatus.cancelled;

  bool get areAllItemsFullyReceived {
    if (items.isEmpty) return false;
    return items.every((i) => i.isFullyReceived);
  }

  bool get hasAnyItemReceived {
    return items.any((i) => !i.quantityReceived.isZero);
  }

  PurchaseOrder copyWith({
    PurchaseOrderStatus? status,
    List<PurchaseItem>? items,
    Money? subtotal,
    Money? discountTotal,
    Money? taxTotal,
    Money? grandTotal,
    String? approvedBy,
    String? cancelledBy,
    String? cancellationReason,
    DateTime? updatedAt,
    int? version,
    String? notes,
  }) {
    return PurchaseOrder(
      id: id,
      businessId: businessId,
      branchId: branchId,
      supplierId: supplierId,
      orderNumber: orderNumber,
      status: status ?? this.status,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discountTotal: discountTotal ?? this.discountTotal,
      taxTotal: taxTotal ?? this.taxTotal,
      grandTotal: grandTotal ?? this.grandTotal,
      currency: currency,
      createdBy: createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      idempotencyKey: idempotencyKey,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseOrder &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          version == other.version;

  @override
  int get hashCode => id.hashCode ^ version.hashCode;

  @override
  String toString() =>
      'PurchaseOrder(id: $id, number: $orderNumber, status: $status, total: $grandTotal, v$version)';
}
