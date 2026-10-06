// أحداث نطاق المرتجعات واسترداد الأموال (MADAR SHOP Returns Domain Events)
// Pure Dart — Zero UI Dependencies

import '../../../domain/returns/entities/refund.dart';
import '../../../domain/returns/entities/return_order.dart';
import '../../../domain/returns/entities/supplier_return.dart';

abstract class ReturnsDomainEvent {
  final String eventId;
  final DateTime occurredAt;

  const ReturnsDomainEvent({
    required this.eventId,
    required this.occurredAt,
  });
}

class ReturnCreatedEvent extends ReturnsDomainEvent {
  final ReturnOrder order;
  final String actorId;

  const ReturnCreatedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.order,
    required this.actorId,
  });
}

class ReturnApprovedEvent extends ReturnsDomainEvent {
  final ReturnOrder order;
  final String approvedBy;

  const ReturnApprovedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.order,
    required this.approvedBy,
  });
}

class ReturnReceivedEvent extends ReturnsDomainEvent {
  final ReturnOrder order;
  final String receivedBy;

  const ReturnReceivedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.order,
    required this.receivedBy,
  });
}

class RefundCompletedEvent extends ReturnsDomainEvent {
  final Refund refund;
  final ReturnOrder order;

  const RefundCompletedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.refund,
    required this.order,
  });
}

class ReturnCancelledEvent extends ReturnsDomainEvent {
  final ReturnOrder order;
  final String cancelledBy;
  final String reason;

  const ReturnCancelledEvent({
    required super.eventId,
    required super.occurredAt,
    required this.order,
    required this.cancelledBy,
    required this.reason,
  });
}

class SupplierReturnCreatedEvent extends ReturnsDomainEvent {
  final SupplierReturn supplierReturn;
  final String actorId;

  const SupplierReturnCreatedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.supplierReturn,
    required this.actorId,
  });
}

class SupplierReturnCompletedEvent extends ReturnsDomainEvent {
  final SupplierReturn supplierReturn;
  final String actorId;

  const SupplierReturnCompletedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.supplierReturn,
    required this.actorId,
  });
}

class DuplicateReturnDetectedEvent extends ReturnsDomainEvent {
  final String idempotencyKey;
  final String referenceId;

  const DuplicateReturnDetectedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.idempotencyKey,
    required this.referenceId,
  });
}
