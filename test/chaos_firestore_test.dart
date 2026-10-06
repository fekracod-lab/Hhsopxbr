import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/entities/failure_injection.dart';
import 'package:dalal_alqaim/core/resilience/entities/chaos_scenario.dart';
import 'package:dalal_alqaim/core/resilience/enums/resilience_enums.dart';
import 'package:dalal_alqaim/core/resilience/services/failure_injection_engine.dart';
import 'package:dalal_alqaim/core/resilience/services/chaos_engine.dart';
import 'package:dalal_alqaim/core/resilience/services/retry_engine.dart';
import 'package:dalal_alqaim/core/resilience/services/circuit_breaker_engine.dart';

void main() {
  group('Chaos Scenario 003 & 004: Firestore Database Failure & Timeout Tests', () {
    test('CHAOS-003: Firestore 503 unavailability opens circuit breaker and recovers after cooldown', () async {
      final failureInjection = FailureInjectionEngine();
      final breaker = CircuitBreakerEngine(defaultFailureThreshold: 2, defaultRecoveryTimeout: const Duration(milliseconds: 50));
      final retry = RetryEngine(circuitBreakerEngine: breaker);
      final chaosEngine = ChaosEngine(failureInjectionEngine: failureInjection);

      final scenario = ChaosScenario(
        scenarioId: 'CHAOS-003',
        name: 'Firestore Database Outage',
        description: 'Simulates complete 503 service outage on cloud database',
        injections: [
          const FailureInjection(
            injectionId: 'inj_db_503',
            type: FailureInjectionType.firestoreUnavailable,
            targetService: 'firestore_core',
            probability: 1.0,
          ),
        ],
        assertions: [
          'CIRCUIT_BREAKER_OPENED',
          'AUTO_RECOVERED_AFTER_RESTORE',
        ],
      );

      final (passed, passedAssertions, failedAssertions) = await chaosEngine.executeScenario(
        scenario: scenario,
        workload: () async {
          // Attempt 1: fails
          await retry.executeWithRetry(
            serviceKey: 'firestore_core',
            customDelayer: (_) async {},
            operation: () async {
              await failureInjection.evaluateAndInject('firestore_core');
              return 'OK';
            },
          );

          // Attempt 2: fails -> trips breaker to OPEN
          await retry.executeWithRetry(
            serviceKey: 'firestore_core',
            customDelayer: (_) async {},
            operation: () async {
              await failureInjection.evaluateAndInject('firestore_core');
              return 'OK';
            },
          );
        },
        assertionVerifier: (assertion) async {
          if (assertion == 'CIRCUIT_BREAKER_OPENED') {
            return breaker.getOrCreateRecord('firestore_core').state == CircuitState.open;
          }
          if (assertion == 'AUTO_RECOVERED_AFTER_RESTORE') {
            await Future.delayed(const Duration(milliseconds: 60)); // Wait for cooldown
            final (res, _, _) = await retry.executeWithRetry(
              serviceKey: 'firestore_core',
              operation: () async => 'DB_RESTORED_SUCCESS',
            );
            return res == 'DB_RESTORED_SUCCESS' &&
                breaker.getOrCreateRecord('firestore_core').state == CircuitState.closed;
          }
          return false;
        },
      );

      expect(passed, isTrue);
      expect(passedAssertions.length, equals(2));
      expect(failedAssertions.isEmpty, isTrue);
    });
  });
}
