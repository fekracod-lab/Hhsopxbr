import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/enums/resilience_enums.dart';
import 'package:dalal_alqaim/core/resilience/services/transaction_state_machine.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

void main() {
  group('Hardened Transaction State Machine Dedicated Tests', () {
    test('1. Validates complete legal lifecycle of Ride without exception', () {
      expect(
        () => ResilienceTransactionStateMachine.validateRideTransition(
          from: RideOperationalState.requested,
          to: RideOperationalState.matching,
        ),
        returnsNormally,
      );

      expect(
        () => ResilienceTransactionStateMachine.validateRideTransition(
          from: RideOperationalState.matching,
          to: RideOperationalState.driverAssigned,
        ),
        returnsNormally,
      );

      expect(
        () => ResilienceTransactionStateMachine.validateRideTransition(
          from: RideOperationalState.driverAssigned,
          to: RideOperationalState.driverArriving,
        ),
        returnsNormally,
      );

      expect(
        () => ResilienceTransactionStateMachine.validateRideTransition(
          from: RideOperationalState.driverArriving,
          to: RideOperationalState.arrived,
        ),
        returnsNormally,
      );

      expect(
        () => ResilienceTransactionStateMachine.validateRideTransition(
          from: RideOperationalState.arrived,
          to: RideOperationalState.tripStarted,
        ),
        returnsNormally,
      );

      expect(
        () => ResilienceTransactionStateMachine.validateRideTransition(
          from: RideOperationalState.tripStarted,
          to: RideOperationalState.tripCompleted,
        ),
        returnsNormally,
      );

      expect(
        () => ResilienceTransactionStateMachine.validateRideTransition(
          from: RideOperationalState.tripCompleted,
          to: RideOperationalState.settled,
        ),
        returnsNormally,
      );
    });

    test('2. Rejects reverse or illegal transitions with SecurityViolationException', () {
      // settled -> tripStarted
      expect(
        () => ResilienceTransactionStateMachine.validateRideTransition(
          from: RideOperationalState.settled,
          to: RideOperationalState.tripStarted,
        ),
        throwsA(isA<SecurityViolationException>()),
      );

      // tripCompleted -> matching
      expect(
        () => ResilienceTransactionStateMachine.validateRideTransition(
          from: RideOperationalState.tripCompleted,
          to: RideOperationalState.matching,
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('3. Rejects transitions out of terminal cancelled/expired/failed states', () {
      expect(
        () => ResilienceTransactionStateMachine.validateRideTransition(
          from: RideOperationalState.cancelled,
          to: RideOperationalState.tripStarted,
        ),
        throwsA(isA<SecurityViolationException>()),
      );

      expect(
        () => ResilienceTransactionStateMachine.validateRideTransition(
          from: RideOperationalState.expired,
          to: RideOperationalState.driverAssigned,
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });
  });
}
