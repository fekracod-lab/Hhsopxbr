import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/services/circuit_breaker_engine.dart';
import 'package:dalal_alqaim/core/resilience/enums/resilience_enums.dart';

void main() {
  group('Circuit Breaker Engine Dedicated Tests', () {
    test('1. Initial state is CLOSED and permits calls', () {
      final engine = CircuitBreakerEngine(defaultFailureThreshold: 3);
      expect(engine.isCallPermitted('notification_service'), isTrue);

      final record = engine.getOrCreateRecord('notification_service');
      expect(record.state, equals(CircuitState.closed));
      expect(record.failureCount, equals(0));
    });

    test('2. Reaching failure threshold transitions state to OPEN and blocks calls', () {
      final now = DateTime(2026, 8, 29, 10, 0, 0);
      final engine = CircuitBreakerEngine(defaultFailureThreshold: 3);

      engine.recordFailure('sms_service', now: now);
      engine.recordFailure('sms_service', now: now);
      expect(engine.isCallPermitted('sms_service', now: now), isTrue); // 2 failures < 3

      engine.recordFailure('sms_service', now: now); // 3rd failure -> OPEN
      final record = engine.getOrCreateRecord('sms_service');
      expect(record.state, equals(CircuitState.open));
      expect(engine.isCallPermitted('sms_service', now: now), isFalse); // Blocked
    });

    test('3. Transitions to HALF_OPEN after recovery timeout expires to permit single probe', () {
      final startTime = DateTime(2026, 8, 29, 10, 0, 0);
      final engine = CircuitBreakerEngine(
        defaultFailureThreshold: 2,
        defaultRecoveryTimeout: const Duration(seconds: 30),
      );

      engine.recordFailure('maps_api', now: startTime);
      engine.recordFailure('maps_api', now: startTime);
      expect(engine.getOrCreateRecord('maps_api').state, equals(CircuitState.open));

      // After 10s: still in cooldown
      expect(engine.isCallPermitted('maps_api', now: startTime.add(const Duration(seconds: 10))), isFalse);

      // After 35s: cooldown expired -> transitions to HALF_OPEN
      final afterCooldown = startTime.add(const Duration(seconds: 35));
      expect(engine.isCallPermitted('maps_api', now: afterCooldown), isTrue);
      expect(engine.getOrCreateRecord('maps_api').state, equals(CircuitState.halfOpen));
    });

    test('4. Successful probe in HALF_OPEN resets breaker to CLOSED', () {
      final startTime = DateTime(2026, 8, 29, 10, 0, 0);
      final engine = CircuitBreakerEngine(
        defaultFailureThreshold: 2,
        defaultRecoveryTimeout: const Duration(seconds: 10),
      );

      engine.recordFailure('payment_api', now: startTime);
      engine.recordFailure('payment_api', now: startTime);

      // Advance past timeout -> half-open
      final probeTime = startTime.add(const Duration(seconds: 15));
      engine.isCallPermitted('payment_api', now: probeTime);

      // Record success
      engine.recordSuccess('payment_api', now: probeTime);
      final record = engine.getOrCreateRecord('payment_api');
      expect(record.state, equals(CircuitState.closed));
      expect(record.failureCount, equals(0));
    });

    test('5. Failed probe in HALF_OPEN immediately re-opens breaker', () {
      final startTime = DateTime(2026, 8, 29, 10, 0, 0);
      final engine = CircuitBreakerEngine(
        defaultFailureThreshold: 2,
        defaultRecoveryTimeout: const Duration(seconds: 10),
      );

      engine.recordFailure('inventory_api', now: startTime);
      engine.recordFailure('inventory_api', now: startTime);

      // Advance past timeout -> half-open
      final probeTime = startTime.add(const Duration(seconds: 15));
      engine.isCallPermitted('inventory_api', now: probeTime);

      // Record failure during probe
      engine.recordFailure('inventory_api', now: probeTime);
      final record = engine.getOrCreateRecord('inventory_api');
      expect(record.state, equals(CircuitState.open));
    });
  });
}
