import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';
import '../enums/resilience_enums.dart';

/// آلة الحالات الصارمة للمعاملات والرحلات (Hardened Transaction State Machine)
class ResilienceTransactionStateMachine {
  const ResilienceTransactionStateMachine();

  /// التحقق الصارم من صحة انتقال حالة الرحلة ومنع أي تراجع أو انتقال غير قانوني
  static void validateRideTransition({
    required RideOperationalState from,
    required RideOperationalState to,
  }) {
    if (from == to) return; // No-op idempotent transition

    final allowedTransitions = <RideOperationalState, Set<RideOperationalState>>{
      RideOperationalState.requested: {
        RideOperationalState.matching,
        RideOperationalState.cancelled,
        RideOperationalState.expired,
      },
      RideOperationalState.matching: {
        RideOperationalState.driverAssigned,
        RideOperationalState.cancelled,
        RideOperationalState.failed,
        RideOperationalState.expired,
      },
      RideOperationalState.driverAssigned: {
        RideOperationalState.driverArriving,
        RideOperationalState.cancelled,
        RideOperationalState.failed,
      },
      RideOperationalState.driverArriving: {
        RideOperationalState.arrived,
        RideOperationalState.cancelled,
        RideOperationalState.failed,
      },
      RideOperationalState.arrived: {
        RideOperationalState.tripStarted,
        RideOperationalState.cancelled,
      },
      RideOperationalState.tripStarted: {
        RideOperationalState.tripCompleted,
        RideOperationalState.recoveryRequired,
      },
      RideOperationalState.tripCompleted: {
        RideOperationalState.settled,
      },
      RideOperationalState.recoveryRequired: {
        RideOperationalState.tripCompleted,
        RideOperationalState.cancelled,
        RideOperationalState.failed,
      },
      RideOperationalState.settled: {},
      RideOperationalState.cancelled: {},
      RideOperationalState.expired: {},
      RideOperationalState.failed: {},
    };

    final legalNextStates = allowedTransitions[from] ?? {};

    if (!legalNextStates.contains(to)) {
      throw SecurityViolationException(
        'Illegal state transition attempted for Ride from [${from.key}] to [${to.key}]. Terminal or reverse state mutations are strictly blocked.',
        type: SecurityViolationType.tamperedPayload,
        fieldName: 'operationalState',
      );
    }
  }

  /// التحقق هل الحالة نهائية لا تقبل أي تعديل
  static bool isTerminalState(RideOperationalState state) {
    return state == RideOperationalState.settled ||
        state == RideOperationalState.cancelled ||
        state == RideOperationalState.expired ||
        state == RideOperationalState.failed;
  }
}
