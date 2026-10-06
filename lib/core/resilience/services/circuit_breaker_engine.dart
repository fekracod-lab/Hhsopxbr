import '../entities/circuit_breaker_record.dart';
import '../enums/resilience_enums.dart';

/// محرك إدارة قواطع الدوائر للخدمات لمنع عواصف الأعطال (Circuit Breaker Engine)
class CircuitBreakerEngine {
  final Map<String, CircuitBreakerRecord> _breakers = {};
  final int defaultFailureThreshold;
  final Duration defaultRecoveryTimeout;

  CircuitBreakerEngine({
    this.defaultFailureThreshold = 5,
    this.defaultRecoveryTimeout = const Duration(seconds: 30),
  });

  Map<String, CircuitBreakerRecord> get breakers => Map.unmodifiable(_breakers);

  CircuitBreakerRecord getOrCreateRecord(String serviceKey, {DateTime? now}) {
    return _breakers.putIfAbsent(
      serviceKey,
      () => CircuitBreakerRecord(
        serviceKey: serviceKey,
        state: CircuitState.closed,
        failureThreshold: defaultFailureThreshold,
        recoveryTimeout: defaultRecoveryTimeout,
        lastStateChangedAt: now ?? DateTime.now(),
      ),
    );
  }

  /// التحقق هل مسموح بتنفيذ الطلب على الخدمة (Permission Check)
  bool isCallPermitted(String serviceKey, {DateTime? now}) {
    final record = getOrCreateRecord(serviceKey, now: now);
    final currentTime = now ?? DateTime.now();

    if (record.state == CircuitState.closed) {
      return true;
    }

    if (record.state == CircuitState.open) {
      final elapsed = currentTime.difference(record.lastStateChangedAt);
      if (elapsed >= record.recoveryTimeout) {
        // الانتقال إلى Half-Open لاختبار الخدمة بمحاولة استكشافية
        _breakers[serviceKey] = record.copyWith(
          state: CircuitState.halfOpen,
          lastStateChangedAt: currentTime,
        );
        return true;
      }
      return false; // لا يزال في فترة التهدئة
    }

    // Half-Open يسمح بمحاولة التحقق
    return true;
  }

  /// تسجيل نجاح العملية وتحديث حالة القاطع
  void recordSuccess(String serviceKey, {DateTime? now}) {
    final record = getOrCreateRecord(serviceKey, now: now);
    final currentTime = now ?? DateTime.now();

    if (record.state == CircuitState.halfOpen) {
      // تعافي الخدمة وإعادة إغلاق القاطع
      _breakers[serviceKey] = record.copyWith(
        state: CircuitState.closed,
        failureCount: 0,
        successCount: record.successCount + 1,
        lastStateChangedAt: currentTime,
      );
    } else {
      _breakers[serviceKey] = record.copyWith(
        failureCount: 0,
        successCount: record.successCount + 1,
      );
    }
  }

  /// تسجيل فشل العملية وفتح القاطع عند تجاوز العتبة
  void recordFailure(String serviceKey, {DateTime? now}) {
    final record = getOrCreateRecord(serviceKey, now: now);
    final currentTime = now ?? DateTime.now();
    final newFailures = record.failureCount + 1;

    if (record.state == CircuitState.halfOpen || newFailures >= record.failureThreshold) {
      _breakers[serviceKey] = record.copyWith(
        state: CircuitState.open,
        failureCount: newFailures,
        lastStateChangedAt: currentTime,
        lastFailureAt: currentTime,
      );
    } else {
      _breakers[serviceKey] = record.copyWith(
        failureCount: newFailures,
        lastFailureAt: currentTime,
      );
    }
  }

  void reset() {
    _breakers.clear();
  }
}
