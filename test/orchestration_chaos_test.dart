import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/transaction_context.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/saga_execution.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/domain_event.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/consistency_violation.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/recovery_job.dart';
import 'package:dalal_alqaim/core/orchestration/domain/enums/orchestration_enums.dart';
import 'package:dalal_alqaim/core/orchestration/domain/repositories/i_transaction_repository.dart';
import 'package:dalal_alqaim/core/orders/domain/entities/order_item.dart';
import 'package:dalal_alqaim/core/finance/application/financial_engine.dart';
import 'package:dalal_alqaim/core/finance/domain/entities/financial_transaction.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';
import 'helpers/orchestration_test_helper.dart';

class FailingPaymentFinancialEngine extends FinancialEngine {
  @override
  Future<FinancialTransaction> executeOrderPayment({
    required String orderId,
    required String orderSource,
    required String customerId,
    required int amount,
    String? idempotencyKey,
  }) async {
    throw const SecurityViolationException(
      'فشل خصم المحفظة بسبب عدم كفاية الرصيد',
      type: SecurityViolationType.unauthorizedFinancialMutation,
    );
  }
}

class MockChaosRepo implements ITransactionRepository {
  SagaExecution? savedSaga;
  TransactionState? finalState;

  @override
  Future<void> saveTransactionContext(TransactionContext context, TransactionState state) async {}
  @override
  Future<TransactionContext?> getTransactionContext(String transactionId) async => null;
  @override
  Future<void> updateTransactionState(String transactionId, TransactionState state) async {
    finalState = state;
  }
  @override
  Future<void> saveSagaExecution(SagaExecution saga) async {
    savedSaga = saga;
  }
  @override
  Future<SagaExecution?> getSagaExecution(String sagaId) async => savedSaga;
  @override
  Future<void> saveDomainEvent(DomainEvent event) async {}
  @override
  Future<void> saveConsistencyViolation(ConsistencyViolation violation) async {}
  @override
  Future<void> saveRecoveryJob(RecoveryJob job) async {}
}

void main() {
  group('Orchestration Chaos & Failure Recovery Tests', () {
    test('1. Payment failure triggers automatic Saga Compensation and releases reserved inventory', () async {
      final chaosRepo = MockChaosRepo();
      final failingFinance = FailingPaymentFinancialEngine();
      final engine = createTestTransactionEngine(
        repository: chaosRepo,
        financialEngine: failingFinance,
      );

      final stock = {'item_luxury_watch': 2};
      final items = [
        const OrderItem(
          id: 'item_luxury_watch',
          name: 'ساعة يد فاخرة',
          price: 250000,
          quantity: 1,
        ),
      ];

      final result = await engine.executeOrderTransaction(
        customerId: 'cust_broke_1',
        orderId: 'ord_chaos_payment_fail',
        serviceType: 'store',
        pickupLat: 33.3152,
        pickupLng: 44.3661,
        pickupAddress: 'متجر الساعات',
        dropoffLat: 33.3250,
        dropoffLng: 44.3750,
        dropoffAddress: 'عنوان الزبون',
        distanceMeters: 5000.0,
        items: items,
        storeInventoryStock: stock,
        paymentMethod: 'wallet', // Will fail in mock financial engine
        idempotencyKey: 'idemp_chaos_fail_1',
      );

      expect(result.isSuccess, isFalse);
      expect(result.failureType, equals(FailureType.paymentFailure));
      expect(result.sagaExecution?.status, equals(SagaStatus.compensated));

      // Invariant check: Reserved stock was cleanly returned back to available stock!
      expect(stock['item_luxury_watch'], equals(2));
    });
  });
}
