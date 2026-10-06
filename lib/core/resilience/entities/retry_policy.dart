import 'package:flutter/foundation.dart';

/// دالة توليد التشتت الزمني (Jitter Generator Abstraction) للاختبار الحتمي
typedef JitterGenerator = double Function();

/// سياسة إعادة المحاولات المنضبطة (Deterministic Retry Policy)
@immutable
class RetryPolicy {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double exponentialFactor;
  final bool useJitter;
  final Set<String> retryableErrors;
  final Set<String> nonRetryableErrors;
  final Duration timeout;
  final JitterGenerator? customJitterGenerator;

  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 100),
    this.maxDelay = const Duration(seconds: 5),
    this.exponentialFactor = 2.0,
    this.useJitter = true,
    this.retryableErrors = const {'network', 'timeout', 'unavailable', 'transient'},
    this.nonRetryableErrors = const {'unauthenticated', 'invalid_argument', 'blocked', 'permission_denied'},
    this.timeout = const Duration(seconds: 10),
    this.customJitterGenerator,
  });

  /// حساب فترة التأخير للمحاولة مع الـ Exponential Backoff والـ Jitter
  Duration computeDelay(int attempt) {
    if (attempt <= 1) return initialDelay;

    final baseDelayMs = initialDelay.inMilliseconds *
        (exponentialFactor > 1 ? (1 << (attempt - 1)) : 1);
    final cappedDelayMs = baseDelayMs > maxDelay.inMilliseconds
        ? maxDelay.inMilliseconds
        : baseDelayMs;

    if (!useJitter) {
      return Duration(milliseconds: cappedDelayMs);
    }

    // Full Jitter: Uniform random between 0 and capped delay
    final jitterFactor = customJitterGenerator != null
        ? customJitterGenerator!()
        : 0.5; // Default deterministic midpoint if none passed

    final finalDelayMs = (cappedDelayMs * jitterFactor.clamp(0.0, 1.0)).round();
    return Duration(milliseconds: finalDelayMs.clamp(initialDelay.inMilliseconds, maxDelay.inMilliseconds));
  }

  bool isRetryable(String errorClassification) {
    if (nonRetryableErrors.contains(errorClassification.toLowerCase())) {
      return false;
    }
    return retryableErrors.contains(errorClassification.toLowerCase()) || retryableErrors.isEmpty;
  }
}
