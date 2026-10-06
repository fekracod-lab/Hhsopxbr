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

class MockConcurrencyRepo implements ITransactionRepository {
  @override
  Future<void> saveTransactionContext(TransactionContext context, TransactionState state) async {}
  @override
  Future<TransactionContext?> getTransactionContext(String transactionId) async => null;
  @override
  Future<void> updateTransactionState(String transactionId, TransactionState state) async {}
  @override
  Future<void> saveSagaExecution(SagaExecution saga) async {}
  @override
  Future<SagaExecution?> getSagaExecution(String sagaId) async => null;
  @override
  Future<void> saveDomainEvent(DomainEvent event) async {}
  @override
  Future<void> saveConsistencyViolation(ConsistencyViolation violation) async {}
  @override
  Future<void> saveRecoveryJob(RecoveryJob job) async {}
}

void main() {
  group('Orchestration Concurrency & Stock Invariants Tests', () {
    test('1. Finite stock concurrency: 20 simultaneous orders competing for 5 items', () async {
      final repo = MockConcurrencyRepo();
      final engine = createTestTransactionEngine(repository: repo);

      final stock = {'item_hot_sale': 5};
      final items = [
        const OrderItem(
          id: 'item_hot_sale',
          name: 'عرض حصري',
          price: 5000,
          quantity: 1,
        ),
      ];

      final futures = List.generate(20, (index) {
        return engine.executeOrderTransaction(
          customerId: 'cust_concurrent_$index',
          orderId: 'ord_conc_$index',
          serviceType: 'store',
          pickupLat: 33.3152,
          pickupLng: 44.3661,
          pickupAddress: 'المتجر',
          dropoffLat: 33.3250,
          dropoffLng: 44.3750,
          dropoffAddress: 'الزبون $index',
          distanceMeters: 1500.0,
          items: items,
          storeInventoryStock: stock,
          paymentMethod: 'cash',
          idempotencyKey: 'idemp_conc_order_$index',
        );
      });

      final results = await Future.wait(futures);

      final successes = results.where((r) => r.isSuccess).length;
      final failures = results.where((r) => !r.isSuccess).length;

      expect(successes, equals(5)); // Exactly 5 orders succeeded
      expect(failures, equals(15)); // Exactly 15 orders rejected due to stock depletion
      expect(stock['item_hot_sale'], equals(0)); // Stock is exactly 0, NEVER negative!
    });
  });
}
