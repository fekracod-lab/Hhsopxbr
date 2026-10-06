import '../entities/consistency_violation.dart';
import '../enums/orchestration_enums.dart';

/// محرك فحص وضمان اتساق البيانات عبر المنظومة (Consistency Engine)
class ConsistencyEngine {
  const ConsistencyEngine();

  /// فحص اتساق حالة الطلب وحالة الدفع
  static ConsistencyViolation? auditOrderPayment({
    required String orderId,
    required String orderStatus,
    required String paymentStatus,
  }) {
    if (orderStatus == 'completed' && paymentStatus == 'pending') {
      return ConsistencyViolation(
        violationId: 'viol-pay-$orderId-${DateTime.now().millisecondsSinceEpoch}',
        type: ConsistencyViolationType.completedOrderPendingPayment,
        severity: ViolationSeverity.critical,
        aggregateId: orderId,
        expectedState: 'paymentStatus == captured/settled',
        actualState: 'order is completed but payment is pending',
        recommendedAction: RecoveryAction.manualIntervention,
        detectedAt: DateTime.now(),
      );
    }
    return null;
  }

  /// فحص اتساق حالة الطلب وحجز المخزون
  static ConsistencyViolation? auditOrderReservation({
    required String orderId,
    required String orderStatus,
    required bool isReservationActive,
  }) {
    if (orderStatus == 'cancelled' && isReservationActive) {
      return ConsistencyViolation(
        violationId: 'viol-res-$orderId-${DateTime.now().millisecondsSinceEpoch}',
        type: ConsistencyViolationType.cancelledOrderActiveReservation,
        severity: ViolationSeverity.high,
        aggregateId: orderId,
        expectedState: 'reservation is released',
        actualState: 'order is cancelled but reservation remains active',
        recommendedAction: RecoveryAction.executeCompensation,
        detectedAt: DateTime.now(),
      );
    }
    return null;
  }

  /// فحص اتساق تعيين السائق
  static ConsistencyViolation? auditOrderDriverAssignment({
    required String orderId,
    required String orderStatus,
    required String? driverId,
  }) {
    if ((orderStatus == 'assigned' || orderStatus == 'delivering') && (driverId == null || driverId.isEmpty)) {
      return ConsistencyViolation(
        violationId: 'viol-drv-$orderId-${DateTime.now().millisecondsSinceEpoch}',
        type: ConsistencyViolationType.assignedOrderNoDriver,
        severity: ViolationSeverity.high,
        aggregateId: orderId,
        expectedState: 'valid driver assigned',
        actualState: 'order status is $orderStatus but driverId is empty',
        recommendedAction: RecoveryAction.retryStep,
        detectedAt: DateTime.now(),
      );
    }
    return null;
  }

  /// فحص حظر التعيين المزدوج للسائق (سائق واحد لأكثر من حد طاقته)
  static ConsistencyViolation? auditDriverCapacity({
    required String driverId,
    required int activeAssignedCount,
    required int maxCapacity,
  }) {
    if (activeAssignedCount > maxCapacity) {
      return ConsistencyViolation(
        violationId: 'viol-cap-$driverId-${DateTime.now().millisecondsSinceEpoch}',
        type: ConsistencyViolationType.duplicateDriverAssignment,
        severity: ViolationSeverity.critical,
        aggregateId: driverId,
        expectedState: 'activeOrders <= $maxCapacity',
        actualState: 'activeOrders == $activeAssignedCount',
        recommendedAction: RecoveryAction.manualIntervention,
        detectedAt: DateTime.now(),
      );
    }
    return null;
  }
}
