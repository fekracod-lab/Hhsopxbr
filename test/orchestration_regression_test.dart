import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/transaction_context.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/saga_execution.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/domain_event.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/consistency_violation.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/recovery_job.dart';
import 'package:dalal_alqaim/core/orchestration/domain/enums/orchestration_enums.dart';
import 'package:dalal_alqaim/core/orchestration/domain/repositories/i_transaction_repository.dart';
import 'helpers/orchestration_test_helper.dart';

class MockOrchRegressionRepo implements ITransactionRepository {
  final List<DomainEvent> events = [];

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
  Future<void> saveDomainEvent(DomainEvent event) async {
    events.add(event);
  }
  @override
  Future<void> saveConsistencyViolation(ConsistencyViolation violation) async {}
  @override
  Future<void> saveRecoveryJob(RecoveryJob job) async {}
}

void main() {
  group('Orchestration End-to-End Regression Tests (Taxi & Mersal Services)', () {
    test('1. Executes Taxi ride orchestration flow (Security -> Pricing -> Dispatch -> Notification)', () async {
      final repo = MockOrchRegressionRepo();
      final engine = createTestTransactionEngine(repository: repo);

      final result = await engine.executeOrderTransaction(
        customerId: 'cust_taxi_1',
        orderId: 'ride_taxi_999',
        serviceType: 'taxi',
        pickupLat: 33.3152,
        pickupLng: 44.3661,
        pickupAddress: 'الكرادة خارج',
        dropoffLat: 33.3500,
        dropoffLng: 44.4000,
        dropoffAddress: 'المنصور',
        distanceMeters: 8500.0,
        items: [], // Taxi rides don't have store items
        storeInventoryStock: {},
        paymentMethod: 'cash',
        idempotencyKey: 'idemp_taxi_reg_999',
      );

      expect(result.isSuccess, isTrue);
      expect(result.finalState, equals(TransactionState.completed));
      expect(result.metadata['totalFare'], isNotNull);
      expect(result.metadata['totalFare'], greaterThan(0));
      expect(repo.events.length, equals(1));
    });

    test('2. Executes Mersal parcel delivery orchestration flow', () async {
      final repo = MockOrchRegressionRepo();
      final engine = createTestTransactionEngine(repository: repo);

      final result = await engine.executeOrderTransaction(
        customerId: 'cust_mersal_1',
        orderId: 'pkg_mersal_777',
        serviceType: 'mersal',
        pickupLat: 33.3152,
        pickupLng: 44.3661,
        pickupAddress: 'مكتب الإرسال',
        dropoffLat: 33.3400,
        dropoffLng: 44.3800,
        dropoffAddress: 'مستلم الطرد',
        distanceMeters: 4500.0,
        items: [],
        storeInventoryStock: {},
        paymentMethod: 'cash',
        idempotencyKey: 'idemp_mersal_reg_777',
      );

      expect(result.isSuccess, isTrue);
      expect(result.finalState, equals(TransactionState.completed));
      expect(result.metadata['totalFare'], greaterThan(0));
    });
  });
}
