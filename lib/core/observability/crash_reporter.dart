import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// حارس التقاط وتوثيق الانهيارات البرمجية لمنصة مدار مع حماية الخصوصية (PII Sanitization)
class CrashReporter {
  CrashReporter._();

  static bool _isInitialized = false;

  /// تهيئة Crashlytics
  static Future<void> init() async {
    if (_isInitialized || kIsWeb) return;

    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
      _isInitialized = true;
    } catch (e) {
      debugPrint(' [CrashReporter] Init warning: $e');
    }
  }

  /// تنظيف النصوص والرسائل من البيانات الحساسة (PII Sanitizer)
  static String sanitize(String message) {
    var sanitized = message;
    // حماية كلمات المرور
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(password|pass|pin|secret)=[^&\s,]+', caseSensitive: false),
      (m) => '${m.group(1)}=[REDACTED]',
    );
    // حماية رموز OTP والتوكنات
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(otp|code|token|jwt)=[^&\s,]+', caseSensitive: false),
      (m) => '${m.group(1)}=[REDACTED]',
    );
    // حماية بطاقات الائتمان
    sanitized = sanitized.replaceAll(RegExp(r'\b(?:\d[ -]*?){13,16}\b'), '[CARD_REDACTED]');
    return sanitized;
  }

  /// تسجيل خطأ غير مميت في Crashlytics
  static Future<void> recordError(
    dynamic error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    if (kIsWeb) return;

    try {
      final cleanReason = reason != null ? sanitize(reason) : null;
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: cleanReason,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint(' [CrashReporter] Failed to send to Crashlytics: $e');
    }
  }

  /// تسجيل خطأ فلاتر المميت
  static void recordFlutterFatalError(FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (!kIsWeb) {
      try {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      } catch (_) {}
    }
  }
}
