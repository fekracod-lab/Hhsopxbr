import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/saga_execution.dart';
import 'package:dalal_alqaim/core/orchestration/domain/enums/orchestration_enums.dart';
import 'package:dalal_alqaim/core/orchestration/domain/services/compensation_engine.dart';

void main() {
  group('Saga Orchestration & Compensation Engine Dedicated Tests', () {
    test('1. Plans compensations in strict reverse LIFO order', () {
      final saga = SagaExecution(
        sagaId: 'saga_1',
        transactionId: 'tx_1',
        completedSteps: const [
          SagaStepType.securityValidation,
          SagaStepType.fareCalculation,
          SagaStepType.inventoryReservation,
          SagaStepType.paymentAuthorization,
          SagaStepType.orderCreation,
          SagaStepType.driverDispatch,
        ],
        status: SagaStatus.inProgress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final plan = CompensationEngine.planCompensations(
        saga: saga,
        orderId: 'ord_123',
        driverId: 'drv_99',
        paymentAmount: 25000,
      );

      expect(plan.length, equals(4));
      // Reverse order: Driver -> Order -> Payment -> Inventory
      expect(plan[0].stepType, equals(SagaStepType.driverDispatch));
      expect(plan[1].stepType, equals(SagaStepType.orderCreation));
      expect(plan[2].stepType, equals(SagaStepType.paymentAuthorization));
      expect(plan[3].stepType, equals(SagaStepType.inventoryReservation));
    });

    test('2. Skips compensation planning for read-only / stateless steps', () {
      final saga = SagaExecution(
        sagaId: 'saga_2',
        transactionId: 'tx_2',
        completedSteps: const [
          SagaStepType.securityValidation,
          SagaStepType.fareCalculation,
        ],
        status: SagaStatus.inProgress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final plan = CompensationEngine.planCompensations(
        saga: saga,
        orderId: 'ord_empty',
      );

      expect(plan, isEmpty); // Security and Pricing calculation don't need reverse mutations
    });
  });
}
