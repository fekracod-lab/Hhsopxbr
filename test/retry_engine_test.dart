import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/entities/retry_policy.dart';
import 'package:dalal_alqaim/core/resilience/services/retry_engine.dart';
import 'package:dalal_alqaim/core/resilience/services/circuit_breaker_engine.dart';

void main() {
  group('Retry Engine Dedicated Tests', () {
    test('1. Computes deterministic exponential backoff with custom jitter factor', () {
      final policy = RetryPolicy(
        initialDelay: const Duration(milliseconds: 100),
        maxDelay: const Duration(seconds: 2),
        exponentialFactor: 2.0,
        customJitterGenerator: () => 0.5,
      );

      final delay1 = policy.computeDelay(1);
      final delay2 = policy.computeDelay(2);
      final delay3 = policy.computeDelay(3);

      expect(delay1.inMilliseconds, equals(100)); // initial
      expect(delay2.inMilliseconds, equals(100)); // 200 * 0.5 = 100
      expect(delay3.inMilliseconds, equals(200)); // 400 * 0.5 = 200
    });

    test('2. Retries transient failures up to max attempts and succeeds upon recovery', () async {
      final retryEngine = RetryEngine();
      int executionCount = 0;

      final (result, attempts, error) = await retryEngine.executeWithRetry<String>(
        serviceKey: 'firestore_orders',
        policy: const RetryPolicy(maxAttempts: 3),
        customDelayer: (_) async {}, // instant delay for test speed
        operation: () async {
          executionCount++;
          if (executionCount < 3) {
            throw Exception('Transient network timeout');
          }
          return 'ORDER_PLACED_SUCCESS';
        },
      );

      expect(result, equals('ORDER_PLACED_SUCCESS'));
      expect(attempts.length, equals(3));
      expect(attempts[0].isSuccess, isFalse);
      expect(attempts[1].isSuccess, isFalse);
      expect(attempts[2].isSuccess, isTrue);
      expect(error, isNull);
    });

    test('3. Fast-fails immediately on non-retryable security/auth errors without wasteful retries', () async {
      final retryEngine = RetryEngine();
      int executionCount = 0;

      final (result, attempts, error) = await retryEngine.executeWithRetry<String>(
        serviceKey: 'auth_service',
        policy: const RetryPolicy(maxAttempts: 5),
        customDelayer: (_) async {},
        operation: () async {
          executionCount++;
          throw Exception('unauthenticated: Invalid token or expired session');
        },
      );

      expect(result, isNull);
      expect(executionCount, equals(1)); // Stopped immediately at attempt 1
      expect(attempts.length, equals(1));
      expect(attempts.first.errorClassification, equals('unauthenticated'));
      expect(error, contains('unauthenticated'));
    });

    test('4. Fast-fails when circuit breaker is OPEN for the target service', () async {
      final breakerEngine = CircuitBreakerEngine(defaultFailureThreshold: 2);
      final retryEngine = RetryEngine(circuitBreakerEngine: breakerEngine);

      // Force breaker to open with 2 failures
      breakerEngine.recordFailure('payment_gateway');
      breakerEngine.recordFailure('payment_gateway');

      final (result, attempts, error) = await retryEngine.executeWithRetry<String>(
        serviceKey: 'payment_gateway',
        operation: () async => 'SHOULD_NOT_EXECUTE',
      );

      expect(result, isNull);
      expect(attempts.first.errorClassification, equals('circuit_breaker_open'));
      expect(error, contains('Circuit breaker is OPEN'));
    });
  });
}
