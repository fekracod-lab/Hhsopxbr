// أحداث نطاق محرك المخزون (MADAR SHOP Inventory Domain Events)
// Pure Dart — Zero UI Dependencies

import '../../../domain/inventory/entities/inventory_item.dart';
import '../../../domain/inventory/entities/inventory_ledger_entry.dart';

abstract class InventoryDomainEvent {
  final String eventId;
  final DateTime occurredAt;

  const InventoryDomainEvent({
    required this.eventId,
    required this.occurredAt,
  });
}

class InventoryMovementRecordedEvent extends InventoryDomainEvent {
  final InventoryItem item;
  final InventoryLedgerEntry ledgerEntry;

  const InventoryMovementRecordedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.item,
    required this.ledgerEntry,
  });
}

class InventoryLowStockEvent extends InventoryDomainEvent {
  final InventoryItem item;

  const InventoryLowStockEvent({
    required super.eventId,
    required super.occurredAt,
    required this.item,
  });
}

class InventoryOutOfStockEvent extends InventoryDomainEvent {
  final InventoryItem item;

  const InventoryOutOfStockEvent({
    required super.eventId,
    required super.occurredAt,
    required this.item,
  });
}

class InventoryReservedEvent extends InventoryDomainEvent {
  final InventoryItem item;
  final InventoryLedgerEntry ledgerEntry;

  const InventoryReservedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.item,
    required this.ledgerEntry,
  });
}

class InventoryReservationReleasedEvent extends InventoryDomainEvent {
  final InventoryItem item;
  final InventoryLedgerEntry ledgerEntry;

  const InventoryReservationReleasedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.item,
    required this.ledgerEntry,
  });
}

class InventoryConflictDetectedEvent extends InventoryDomainEvent {
  final String businessId;
  final String branchId;
  final String productId;
  final String? variantId;
  final int attemptedVersion;
  final int currentVersion;

  const InventoryConflictDetectedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.businessId,
    required this.branchId,
    required this.productId,
    this.variantId,
    required this.attemptedVersion,
    required this.currentVersion,
  });
}
