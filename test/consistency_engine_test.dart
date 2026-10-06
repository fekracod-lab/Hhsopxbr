import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/orchestration/domain/enums/orchestration_enums.dart';
import 'package:dalal_alqaim/core/orchestration/domain/services/consistency_engine.dart';

void main() {
  group('Consistency Engine & Impossible State Detection Tests', () {
    test('1. Detects completed order with pending payment as CRITICAL violation', () {
      final violation = ConsistencyEngine.auditOrderPayment(
        orderId: 'ord_bad_1',
        orderStatus: 'completed',
        paymentStatus: 'pending',
      );

      expect(violation, isNotNull);
      expect(violation?.type, equals(ConsistencyViolationType.completedOrderPendingPayment));
      expect(violation?.severity, equals(ViolationSeverity.critical));
    });

    test('2. Detects cancelled order with active inventory reservation', () {
      final violation = ConsistencyEngine.auditOrderReservation(
        orderId: 'ord_bad_2',
        orderStatus: 'cancelled',
        isReservationActive: true,
      );

      expect(violation, isNotNull);
      expect(violation?.type, equals(ConsistencyViolationType.cancelledOrderActiveReservation));
      expect(violation?.recommendedAction, equals(RecoveryAction.executeCompensation));
    });

    test('3. Detects assigned/delivering order with empty driverId', () {
      final violation = ConsistencyEngine.auditOrderDriverAssignment(
        orderId: 'ord_bad_3',
        orderStatus: 'delivering',
        driverId: '',
      );

      expect(violation, isNotNull);
      expect(violation?.type, equals(ConsistencyViolationType.assignedOrderNoDriver));
    });

    test('4. Detects driver exceeding maximum allowed order capacity', () {
      final violation = ConsistencyEngine.auditDriverCapacity(
        driverId: 'drv_overload',
        activeAssignedCount: 3,
        maxCapacity: 1,
      );

      expect(violation, isNotNull);
      expect(violation?.type, equals(ConsistencyViolationType.duplicateDriverAssignment));
      expect(violation?.severity, equals(ViolationSeverity.critical));
    });
  });
}
