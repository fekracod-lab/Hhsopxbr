// أحداث نطاق المشتريات والموردين (MADAR SHOP Purchasing Domain Events)
// Pure Dart — Zero UI Dependencies

import '../../../domain/purchasing/entities/purchase_order.dart';
import '../../../domain/purchasing/entities/purchase_receipt.dart';
import '../../../domain/purchasing/entities/supplier_ledger_entry.dart';
import '../../../domain/purchasing/entities/supplier_payment.dart';

abstract class PurchasingDomainEvent {
  final String eventId;
  final DateTime occurredAt;

  const PurchasingDomainEvent({
    required this.eventId,
    required this.occurredAt,
  });
}

class PurchaseCreatedEvent extends PurchasingDomainEvent {
  final PurchaseOrder order;

  PurchaseCreatedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.order,
  });
}

class PurchaseSubmittedEvent extends PurchasingDomainEvent {
  final PurchaseOrder order;

  PurchaseSubmittedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.order,
  });
}

class PurchaseApprovedEvent extends PurchasingDomainEvent {
  final PurchaseOrder order;
  final String approvedBy;

  PurchaseApprovedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.order,
    required this.approvedBy,
  });
}

class PurchasePartiallyReceivedEvent extends PurchasingDomainEvent {
  final PurchaseOrder order;
  final PurchaseReceipt receipt;

  PurchasePartiallyReceivedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.order,
    required this.receipt,
  });
}

class PurchaseReceivedEvent extends PurchasingDomainEvent {
  final PurchaseOrder order;
  final PurchaseReceipt receipt;

  PurchaseReceivedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.order,
    required this.receipt,
  });
}

class PurchaseCancelledEvent extends PurchasingDomainEvent {
  final PurchaseOrder order;
  final String cancelledBy;
  final String? reason;

  PurchaseCancelledEvent({
    required super.eventId,
    required super.occurredAt,
    required this.order,
    required this.cancelledBy,
    this.reason,
  });
}

class SupplierPaymentCreatedEvent extends PurchasingDomainEvent {
  final SupplierPayment payment;

  SupplierPaymentCreatedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.payment,
  });
}

class SupplierPaymentCompletedEvent extends PurchasingDomainEvent {
  final SupplierPayment payment;
  final SupplierLedgerEntry ledgerEntry;

  SupplierPaymentCompletedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.payment,
    required this.ledgerEntry,
  });
}

class SupplierBalanceChangedEvent extends PurchasingDomainEvent {
  final String supplierId;
  final String businessId;
  final SupplierLedgerEntry ledgerEntry;

  SupplierBalanceChangedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.supplierId,
    required this.businessId,
    required this.ledgerEntry,
  });
}

class PurchaseConflictEvent extends PurchasingDomainEvent {
  final String businessId;
  final String purchaseOrderId;
  final String conflictDetails;

  PurchaseConflictEvent({
    required super.eventId,
    required super.occurredAt,
    required this.businessId,
    required this.purchaseOrderId,
    required this.conflictDetails,
  });
}

class DuplicateReceiveDetectedEvent extends PurchasingDomainEvent {
  final String businessId;
  final String purchaseOrderId;
  final String idempotencyKey;

  DuplicateReceiveDetectedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.businessId,
    required this.purchaseOrderId,
    required this.idempotencyKey,
  });
}
