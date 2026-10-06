import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/domain_event.dart';
import 'package:dalal_alqaim/core/orchestration/domain/services/domain_event_bus.dart';

void main() {
  group('Domain Event Bus & Deduplication Tests', () {
    test('1. Dispatches event to matching topic subscribers', () async {
      final bus = DomainEventBus();
      DomainEvent? receivedEvent;

      bus.subscribe('payment.captured', (event) {
        receivedEvent = event;
      });

      final event = DomainEvent(
        eventId: 'evt_pay_1',
        eventType: 'payment.captured',
        aggregateId: 'ord_1',
        aggregateType: 'Order',
        transactionId: 'tx_1',
        correlationId: 'corr_1',
        occurredAt: DateTime.now(),
        payload: {'amount': 10000},
      );

      await bus.publish(event);

      expect(receivedEvent, isNotNull);
      expect(receivedEvent?.eventId, equals('evt_pay_1'));
      expect(receivedEvent?.payload['amount'], equals(10000));
    });

    test('2. Ensures Event Idempotency — ignores duplicate event IDs', () async {
      final bus = DomainEventBus();
      int callCount = 0;

      bus.subscribe('order.created', (_) {
        callCount++;
      });

      final event = DomainEvent(
        eventId: 'evt_same_id',
        eventType: 'order.created',
        aggregateId: 'ord_2',
        aggregateType: 'Order',
        transactionId: 'tx_2',
        correlationId: 'corr_2',
        occurredAt: DateTime.now(),
      );

      await bus.publish(event);
      await bus.publish(event); // Duplicate
      await bus.publish(event); // Triplicate

      expect(callCount, equals(1)); // Executed exactly once!
    });
  });
}
