import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/transaction_context.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/saga_execution.dart';
import 'package:dalal_alqaim/core/orchestration/domain/enums/orchestration_enums.dart';
import 'package:dalal_alqaim/core/orchestration/domain/services/recovery_engine.dart';

void main() {
  group('Recovery Engine & Watchdog Dedicated Tests', () {
    test('1. Flags stuck active transaction exceeding timeout threshold', () {
      final oldCreatedAt = DateTime.now().subtract(const Duration(minutes: 15));
      final context = TransactionContext(
        transactionId: 'tx_stuck_1',
        operationId: 'op_1',
        idempotencyKey: 'key_1',
        actorId: 'usr_1',
        actorRole: 'customer',
        serviceType: 'food',
        orderId: 'ord_1',
        requestHash: 'hsh_1',
        correlationId: 'corr_1',
        createdAt: oldCreatedAt,
      );

      final isStuck = RecoveryEngine.isTransactionStuck(
        context: context,
        currentState: TransactionState.paymentAuthorizing,
      );

      expect(isStuck, isTrue);
    });

    test('2. Does not flag completed or terminal transactions as stuck', () {
      final oldCreatedAt = DateTime.now().subtract(const Duration(minutes: 60));
      final context = TransactionContext(
        transactionId: 'tx_done',
        operationId: 'op_2',
        idempotencyKey: 'key_2',
        actorId: 'usr_2',
        actorRole: 'customer',
        serviceType: 'taxi',
        orderId: 'ord_2',
        requestHash: 'hsh_2',
        correlationId: 'corr_2',
        createdAt: oldCreatedAt,
      );

      expect(
        RecoveryEngine.isTransactionStuck(context: context, currentState: TransactionState.completed),
        isFalse,
      );
      expect(
        RecoveryEngine.isTransactionStuck(context: context, currentState: TransactionState.failed),
        isFalse,
      );
    });

    test('3. Creates RecoveryJob from persisted saga execution', () {
      final saga = SagaExecution(
        sagaId: 'saga_rec_1',
        transactionId: 'tx_rec_1',
        completedSteps: const [SagaStepType.securityValidation, SagaStepType.inventoryReservation],
        status: SagaStatus.inProgress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final job = RecoveryEngine.createRecoveryJob(
        transactionId: 'tx_rec_1',
        saga: saga,
        currentState: TransactionState.paymentAuthorizing,
      );

      expect(job.transactionId, equals('tx_rec_1'));
      expect(job.sagaId, equals('saga_rec_1'));
      expect(job.state, equals(TransactionState.paymentAuthorizing));
      expect(job.attemptCount, equals(0));
    });
  });
}
