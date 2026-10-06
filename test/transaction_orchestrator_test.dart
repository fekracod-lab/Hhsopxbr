import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/transaction_context.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/saga_execution.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/domain_event.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/consistency_violation.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/recovery_job.dart';
import 'package:dalal_alqaim/core/orchestration/domain/enums/orchestration_enums.dart';
import 'package:dalal_alqaim/core/orchestration/domain/repositories/i_transaction_repository.dart';
import 'package:dalal_alqaim/core/orders/domain/entities/order_item.dart';
import 'helpers/orchestration_test_helper.dart';

class MockTransactionRepository implements ITransactionRepository {
  final Map<String, TransactionContext> contexts = {};
  final Map<String, TransactionState> states = {};
  final Map<String, SagaExecution> sagas = {};
  final List<DomainEvent> events = [];

  @override
  Future<void> saveTransactionContext(TransactionContext context, TransactionState state) async {
    contexts[context.transactionId] = context;
    states[context.transactionId] = state;
  }

  @override
  Future<TransactionContext?> getTransactionContext(String transactionId) async => contexts[transactionId];

  @override
  Future<void> updateTransactionState(String transactionId, TransactionState state) async {
    states[transactionId] = state;
  }

  @override
  Future<void> saveSagaExecution(SagaExecution saga) async {
    sagas[saga.sagaId] = saga;
  }

  @override
  Future<SagaExecution?> getSagaExecution(String sagaId) async => sagas[sagaId];

  @override
  Future<void> saveDomainEvent(DomainEvent event) async {
    events.add(event);
  }

  @override
  Future<void> saveConsistencyViolation(ConsistencyViolation violation) async {}

  @override
  Future<void> saveRecoveryJob(RecoveryJob job) async {}
}

void main() {
  group('Madar Master Transaction Orchestrator End-to-End Tests', () {
    test('1. Executes full Food Order transaction successfully across all 6 Core Engines', () async {
      final mockRepo = MockTransactionRepository();
      final engine = createTestTransactionEngine(repository: mockRepo);

      final stock = {'item_burger_1': 20};
      final items = [
        const OrderItem(
          id: 'item_burger_1',
          name: 'برجر كلاسيك',
          price: 7000,
          quantity: 2,
        ),
      ];

      final result = await engine.executeOrderTransaction(
        customerId: 'customer_omar_1',
        orderId: 'ord_orch_100',
        serviceType: 'food',
        pickupLat: 33.3152,
        pickupLng: 44.3661,
        pickupAddress: 'مطعم القائم',
        dropoffLat: 33.3250,
        dropoffLng: 44.3750,
        dropoffAddress: 'شارع فلسطين',
        distanceMeters: 3500.0,
        items: items,
        storeInventoryStock: stock,
        paymentMethod: 'cash',
        idempotencyKey: 'idemp_orch_100',
      );

      expect(result.isSuccess, isTrue);
      expect(result.finalState, equals(TransactionState.completed));
      expect(result.sagaExecution?.status, equals(SagaStatus.completed));
      expect(mockRepo.states['tx-ord_orch_100'], equals(TransactionState.completed));
      expect(mockRepo.events.length, equals(1));
      expect(mockRepo.events.first.eventType, equals('order.created'));
      expect(stock['item_burger_1'], equals(18)); // 2 items reserved & locked atomically
    });

    test('2. Rejects duplicate request via central Idempotency Coordinator', () async {
      final mockRepo = MockTransactionRepository();
      final engine = createTestTransactionEngine(repository: mockRepo);

      final stock = {'item_pizza_1': 10};
      final items = [
        const OrderItem(
          id: 'item_pizza_1',
          name: 'بيتزا',
          price: 12000,
          quantity: 1,
        ),
      ];

      // Run 1: Original
      final res1 = await engine.executeOrderTransaction(
        customerId: 'cust_idemp_1',
        orderId: 'ord_idemp_200',
        serviceType: 'food',
        pickupLat: 33.3152,
        pickupLng: 44.3661,
        pickupAddress: 'مطعم',
        dropoffLat: 33.3250,
        dropoffLng: 44.3750,
        dropoffAddress: 'منزل',
        distanceMeters: 2000.0,
        items: items,
        storeInventoryStock: stock,
        paymentMethod: 'cash',
        idempotencyKey: 'idemp_duplicate_test_key',
      );
      expect(res1.isSuccess, isTrue);
      expect(stock['item_pizza_1'], equals(9));

      // Run 2: Exact Duplicate with same key -> Returns existing cached result without double deducting stock!
      final res2 = await engine.executeOrderTransaction(
        customerId: 'cust_idemp_1',
        orderId: 'ord_idemp_200',
        serviceType: 'food',
        pickupLat: 33.3152,
        pickupLng: 44.3661,
        pickupAddress: 'مطعم',
        dropoffLat: 33.3250,
        dropoffLng: 44.3750,
        dropoffAddress: 'منزل',
        distanceMeters: 2000.0,
        items: items,
        storeInventoryStock: stock,
        paymentMethod: 'cash',
        idempotencyKey: 'idemp_duplicate_test_key',
      );

      expect(res2.isSuccess, isTrue);
      expect(stock['item_pizza_1'], equals(9)); // Stock remains 9, not 8!
    });
  });
}
