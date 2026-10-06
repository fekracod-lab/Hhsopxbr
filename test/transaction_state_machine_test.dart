import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/orchestration/domain/enums/orchestration_enums.dart';
import 'package:dalal_alqaim/core/orchestration/domain/services/transaction_state_machine.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

void main() {
  group('Transaction State Machine Legal Transitions Tests', () {
    test('1. Validates normal step-by-step transaction progression', () {
      expect(TransactionStateMachine.canTransition(TransactionState.created, TransactionState.validating), isTrue);
      expect(TransactionStateMachine.canTransition(TransactionState.validating, TransactionState.pricing), isTrue);
      expect(TransactionStateMachine.canTransition(TransactionState.pricing, TransactionState.reserving), isTrue);
      expect(TransactionStateMachine.canTransition(TransactionState.reserving, TransactionState.paymentAuthorizing), isTrue);
      expect(TransactionStateMachine.canTransition(TransactionState.paymentAuthorizing, TransactionState.orderCreating), isTrue);
      expect(TransactionStateMachine.canTransition(TransactionState.orderCreating, TransactionState.dispatching), isTrue);
      expect(TransactionStateMachine.canTransition(TransactionState.dispatching, TransactionState.notifying), isTrue);
      expect(TransactionStateMachine.canTransition(TransactionState.notifying, TransactionState.completed), isTrue);
    });

    test('2. Permits transition to Compensating upon intermediate failure', () {
      expect(TransactionStateMachine.canTransition(TransactionState.pricing, TransactionState.compensating), isTrue);
      expect(TransactionStateMachine.canTransition(TransactionState.reserving, TransactionState.compensating), isTrue);
      expect(TransactionStateMachine.canTransition(TransactionState.paymentAuthorizing, TransactionState.compensating), isTrue);
      expect(TransactionStateMachine.canTransition(TransactionState.dispatching, TransactionState.compensating), isTrue);
    });

    test('3. Rejects illegal and reverse transitions with SecurityViolationException', () {
      expect(
        () => TransactionStateMachine.assertValidTransition(
          TransactionState.completed,
          TransactionState.created, // Illegal restart from completed!
        ),
        throwsA(isA<SecurityViolationException>()),
      );

      expect(
        () => TransactionStateMachine.assertValidTransition(
          TransactionState.failed,
          TransactionState.completed, // Failed cannot become completed!
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });
  });
}
