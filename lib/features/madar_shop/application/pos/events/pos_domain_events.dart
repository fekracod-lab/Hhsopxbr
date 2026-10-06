// أحداث نطاق محرك نقطة البيع (MADAR SHOP POS Domain Events)
// Pure Dart — Zero UI Dependencies

import '../../../domain/pos/entities/customer_ledger_entry.dart';
import '../../../domain/pos/entities/inventory_movement_intent.dart';
import '../../../domain/pos/entities/payment.dart';
import '../../../domain/pos/entities/receipt_snapshot.dart';
import '../../../domain/pos/entities/sale.dart';

abstract class PosDomainEvent {
  final String eventId;
  final DateTime occurredAt;

  const PosDomainEvent({
    required this.eventId,
    required this.occurredAt,
  });
}

class SaleCompletedEvent extends PosDomainEvent {
  final Sale sale;

  const SaleCompletedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.sale,
  });
}

class PaymentCompletedEvent extends PosDomainEvent {
  final String saleId;
  final Payment payment;

  const PaymentCompletedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.saleId,
    required this.payment,
  });
}

class CreditCreatedEvent extends PosDomainEvent {
  final CustomerLedgerEntry ledgerEntry;

  const CreditCreatedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.ledgerEntry,
  });
}

class InventoryMovementRequestedEvent extends PosDomainEvent {
  final List<InventoryMovementIntent> movementIntents;

  const InventoryMovementRequestedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.movementIntents,
  });
}

class ReceiptReadyEvent extends PosDomainEvent {
  final ReceiptSnapshot receiptSnapshot;

  const ReceiptReadyEvent({
    required super.eventId,
    required super.occurredAt,
    required this.receiptSnapshot,
  });
}

/// موزع أحداث النطاق الداخلي (In-Process Domain Event Bus)
abstract class IPosEventBus {
  void publish(PosDomainEvent event);
}

class DefaultPosEventBus implements IPosEventBus {
  final List<void Function(PosDomainEvent)> _listeners = [];

  void subscribe(void Function(PosDomainEvent) listener) {
    _listeners.add(listener);
  }

  @override
  void publish(PosDomainEvent event) {
    for (final listener in _listeners) {
      try {
        listener(event);
      } catch (_) {
        // حماية تدفق الحدث من انهيار المستمعين الخارجيين
      }
    }
  }
}
