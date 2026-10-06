import '../domain/entities/security_models.dart';

/// محرك تحديد المعدل والحماية من إساءة الاستخدام وهجمات القوة الغاشمة (Rate Limiting & Abuse Engine)
class RateLimitAbuseEngine {
  final Map<String, List<DateTime>> _requestLogs = {};
  final Map<String, DateTime> _lockouts = {};

  RateLimitAbuseEngine();

  /// فحص هل تجاوز المستخدم أو العملية الحد المسموح به في نافذة زمنية منزلقة
  bool checkRateLimit({
    required String rateKey,
    required int maxAllowed,
    required Duration window,
    Duration lockoutDuration = const Duration(minutes: 15),
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();

    // 1. التحقق من وجود حظر نشط (Lockout)
    if (_lockouts.containsKey(rateKey)) {
      final lockedUntil = _lockouts[rateKey]!;
      if (currentTime.isBefore(lockedUntil)) {
        return false; // Still locked out!
      } else {
        _lockouts.remove(rateKey);
      }
    }

    // 2. تنظيف وتصفية الطلبات السابقة في النافذة المنزلقة
    final windowStart = currentTime.subtract(window);
    final timestamps = (_requestLogs[rateKey] ?? []).where((t) => !t.isBefore(windowStart)).toList();

    // 3. فحص بلوغ الحد الأقصى
    if (timestamps.length >= maxAllowed) {
      _lockouts[rateKey] = currentTime.add(lockoutDuration);
      return false; // Exceeded -> Block and apply lockout
    }

    // 4. تسجيل المحاولة الحالية
    timestamps.add(currentTime);
    _requestLogs[rateKey] = timestamps;
    return true; // Allowed
  }

  /// فحص مع رمي استثناء أمني عند التجاوز
  void assertRateLimit({
    required String rateKey,
    required int maxAllowed,
    required Duration window,
    Duration lockoutDuration = const Duration(minutes: 15),
    DateTime? now,
  }) {
    final allowed = checkRateLimit(
      rateKey: rateKey,
      maxAllowed: maxAllowed,
      window: window,
      lockoutDuration: lockoutDuration,
      now: now,
    );

    if (!allowed) {
      throw SecurityViolationException(
        'Rate limit exceeded for key [$rateKey]. Maximum $maxAllowed attempts allowed per ${window.inMinutes} minutes.',
        type: SecurityViolationType.rateLimitExceeded,
        fieldName: rateKey,
      );
    }
  }

  bool isLockedOut(String rateKey, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    if (!_lockouts.containsKey(rateKey)) return false;
    return currentTime.isBefore(_lockouts[rateKey]!);
  }

  void reset(String rateKey) {
    _requestLogs.remove(rateKey);
    _lockouts.remove(rateKey);
  }

  void clearAll() {
    _requestLogs.clear;
    _lockouts.clear();
  }
}
