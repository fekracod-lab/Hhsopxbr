import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'crash_reporter.dart';

/// خدمة الرصد وتتبع الأخطاء المركزية لمنصة مدار (Madar Unified Observability Logger)
class AppLogger {
  AppLogger._();

  static bool _isInitialized = false;

  /// تهيئة الخدمة
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      await CrashReporter.init();
      _isInitialized = true;
      debugPrint(' [AppLogger] Observability initialized successfully');
    } catch (e) {
      debugPrint(' [AppLogger] Init error: $e');
    }
  }

  /// تعيين هوية المستخدم ودوره لربطها بالتقارير
  static Future<void> setUserContext({
    required String userId,
    String? role,
    String? phone,
    String? region,
  }) async {
    if (kIsWeb) return;
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setUserIdentifier(userId);
      if (role != null) await crashlytics.setCustomKey('user_role', role);
      if (phone != null) await crashlytics.setCustomKey('user_phone', CrashReporter.sanitize(phone));
      if (region != null) await crashlytics.setCustomKey('user_region', region);
    } catch (e) {
      debugPrint(' [AppLogger] Failed to set user context: $e');
    }
  }

  /// مسح هوية المستخدم عند تسجيل الخروج
  static Future<void> clearUserContext() async {
    if (kIsWeb) return;
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setUserIdentifier('');
      await crashlytics.setCustomKey('user_role', 'guest');
    } catch (e) {
      debugPrint(' [AppLogger] Failed to clear user context: $e');
    }
  }

  /// مستويات السجلات الموحدة (Unified Log Levels)
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint(' [DEBUG]${tag != null ? " [$tag]" : ""}: $message');
    }
  }

  static void info(String message, {String? tag}) {
    debugPrint('ℹ [INFO]${tag != null ? " [$tag]" : ""}: $message');
    if (!kIsWeb) {
      try {
        FirebaseCrashlytics.instance.log('[INFO] $message');
      } catch (_) {}
    }
  }

  static void warning(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    debugPrint(' [WARN]${tag != null ? " [$tag]" : ""}: $message');
    if (!kIsWeb) {
      try {
        FirebaseCrashlytics.instance.log('[WARN] $message');
        if (error != null) {
          CrashReporter.recordError(error, stackTrace, reason: message, fatal: false);
        }
      } catch (_) {}
    }
  }

  static void error(
    String message, {
    String? tag,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    debugPrint(' [ERROR]${tag != null ? " [$tag]" : ""}: $message');
    if (stackTrace != null && kDebugMode) {
      debugPrint(stackTrace.toString());
    }
    CrashReporter.recordError(
      error ?? Exception(message),
      stackTrace,
      reason: message,
      fatal: false,
    );
  }

  static void fatal(
    String message, {
    String? tag,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    debugPrint(' [FATAL]${tag != null ? " [$tag]" : ""}: $message');
    CrashReporter.recordError(
      error ?? Exception(message),
      stackTrace,
      reason: message,
      fatal: true,
    );
  }

  /// للتوافق مع الإصدارات السابقة (Backward Compatibility)
  static void log(String message) => info(message);

  static Future<void> recordError(
    dynamic error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    if (fatal) {
      AppLogger.fatal(reason ?? error.toString(), error: error, stackTrace: stackTrace);
    } else {
      AppLogger.error(reason ?? error.toString(), error: error, stackTrace: stackTrace);
    }
  }

  static void recordFlutterFatalError(FlutterErrorDetails details) {
    CrashReporter.recordFlutterFatalError(details);
  }
}
