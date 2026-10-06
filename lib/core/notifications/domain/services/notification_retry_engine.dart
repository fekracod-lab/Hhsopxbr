import 'dart:math' as math;

/// محرك إدارة إعادة المحاولات والتراجع الأسي (Notification Retry Engine)
class NotificationRetryEngine {
  const NotificationRetryEngine();

  /// هل يمكن حاول مرة ثانية؟
  static bool canRetry(int currentRetryCount, int maxRetries) {
    return currentRetryCount < maxRetries;
  }

  /// احتساب مدة التراجع الأسي (Exponential Backoff Duration)
  static Duration computeBackoff({
    required int retryCount,
    int baseBackoffSeconds = 10,
    int maxBackoffSeconds = 300,
  }) {
    final factor = math.pow(2, retryCount).toInt();
    final delay = baseBackoffSeconds * factor;
    final clamped = math.min(maxBackoffSeconds, delay);
    return Duration(seconds: clamped);
  }
}
