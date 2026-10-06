import '../entities/retry_policy.dart';
import '../entities/retry_attempt.dart';
import 'circuit_breaker_engine.dart';

/// محرك إعادة المحاولات المنضبط هندسياً (Production-Grade Retry Engine)
class RetryEngine {
  final CircuitBreakerEngine? _circuitBreakerEngine;

  const RetryEngine({CircuitBreakerEngine? circuitBreakerEngine})
      : _circuitBreakerEngine = circuitBreakerEngine;

  /// تنفيذ عملية مع تطبيق سياسة حاول مرة ثانية والـ Backoff والـ Circuit Breaker
  Future<(T?, List<RetryAttempt>, String?)> executeWithRetry<T>({
    required String serviceKey,
    required Future<T> Function() operation,
    RetryPolicy policy = const RetryPolicy(),
    Future<void> Function(Duration delay)? customDelayer,
    DateTime? now,
  }) async {
    final attempts = <RetryAttempt>[];

    // 1. فحص قاطع الدائرة للخدمة (Circuit Breaker Pre-Check)
    if (_circuitBreakerEngine != null &&
        !_circuitBreakerEngine.isCallPermitted(serviceKey, now: now)) {
      final attempt = RetryAttempt(
        attemptNumber: 1,
        startedAt: now ?? DateTime.now(),
        completedAt: now ?? DateTime.now(),
        errorClassification: 'circuit_breaker_open',
        isSuccess: false,
      );
      attempts.add(attempt);
      return (null, attempts, 'Circuit breaker is OPEN for service: $serviceKey');
    }

    for (int attemptNum = 1; attemptNum <= policy.maxAttempts; attemptNum++) {
      final startTime = now ?? DateTime.now();

      try {
        final result = await operation();
        final endTime = now ?? DateTime.now();

        attempts.add(
          RetryAttempt(
            attemptNumber: attemptNum,
            startedAt: startTime,
            completedAt: endTime,
            durationMs: endTime.difference(startTime).inMilliseconds.abs(),
            isSuccess: true,
          ),
        );

        // إبلاغ قاطع الدائرة بالنجاح
        _circuitBreakerEngine?.recordSuccess(serviceKey, now: endTime);

        return (result, attempts, null);
      } catch (error) {
        final endTime = now ?? DateTime.now();
        final errorStr = error.toString().toLowerCase();
        final classification = _classifyError(errorStr);

        attempts.add(
          RetryAttempt(
            attemptNumber: attemptNum,
            startedAt: startTime,
            completedAt: endTime,
            durationMs: endTime.difference(startTime).inMilliseconds.abs(),
            errorClassification: classification,
            isSuccess: false,
          ),
        );

        // إبلاغ قاطع الدائرة بالفشل
        _circuitBreakerEngine?.recordFailure(serviceKey, now: endTime);

        // إذا كان الخطأ غير قابل لحاول مرة ثانية (Terminal Error)
        if (!policy.isRetryable(classification) || attemptNum == policy.maxAttempts) {
          return (null, attempts, error.toString());
        }

        // حساب وقت الانتظار وتطبيقه
        final delay = policy.computeDelay(attemptNum + 1);
        if (customDelayer != null) {
          await customDelayer(delay);
        } else {
          await Future.delayed(delay);
        }
      }
    }

    return (null, attempts, 'Max retry attempts (${policy.maxAttempts}) exhausted');
  }

  String _classifyError(String errorStr) {
    if (errorStr.contains('auth') || errorStr.contains('permission')) {
      return 'unauthenticated';
    }
    if (errorStr.contains('invalid') || errorStr.contains('argument')) {
      return 'invalid_argument';
    }
    if (errorStr.contains('block') || errorStr.contains('security')) {
      return 'blocked';
    }
    if (errorStr.contains('timeout')) {
      return 'timeout';
    }
    return 'network';
  }
}
