import '../entities/compensation_action.dart';
import '../entities/saga_execution.dart';
import '../enums/orchestration_enums.dart';

/// محرك تنفيذ التعويضات العكسية للملحمة الموزعة (Saga Compensation Engine)
class CompensationEngine {
  const CompensationEngine();

  /// توليد خطة التعويض العكسية للخطوات المكتملة
  static List<CompensationAction> planCompensations({
    required SagaExecution saga,
    required String orderId,
    String? driverId,
    int? paymentAmount,
  }) {
    final actions = <CompensationAction>[];

    // تنفيذ التعويض بترتيب عكسي صارم (LIFO - Last In First Out)
    for (final step in saga.completedSteps.reversed) {
      switch (step) {
        case SagaStepType.financialSettlement:
        case SagaStepType.paymentAuthorization:
          actions.add(CompensationAction(
            stepType: step,
            targetEntityId: orderId,
            actionDescription: 'إلغاء حجز أو استرداد المبلغ المالي (${paymentAmount ?? 0} د.ع)',
            payload: {'amount': paymentAmount ?? 0},
          ));
          break;

        case SagaStepType.driverDispatch:
          actions.add(CompensationAction(
            stepType: step,
            targetEntityId: driverId ?? '',
            actionDescription: 'إلغاء تعيين وتحرير الكابتن',
            payload: {'driverId': driverId ?? ''},
          ));
          break;

        case SagaStepType.orderCreation:
          actions.add(CompensationAction(
            stepType: step,
            targetEntityId: orderId,
            actionDescription: 'تحديث حالة الطلب إلى ملغي (Cancelled)',
          ));
          break;

        case SagaStepType.inventoryReservation:
          actions.add(CompensationAction(
            stepType: step,
            targetEntityId: orderId,
            actionDescription: 'تحرير حجز المخزون وإعادة الكميات للمتجر',
          ));
          break;

        case SagaStepType.securityValidation:
        case SagaStepType.fareCalculation:
        case SagaStepType.notificationDispatch:
          // خطوات غير محتاجة لتعويض مالي أو عيني
          break;
      }
    }

    return actions;
  }
}
