import '../domain/entities/security_models.dart';
import '../enums/security_enums.dart';

/// محرك أمان الجلسات وإعادة المصادقة للعمليات الحساسة (Session Security & Re-Auth Engine)
class SessionSecurityEngine {
  final Map<String, (DateTime createdAt, DateTime lastActiveAt, bool isRevoked)> _sessions = {};
  final Duration sessionTtl;
  final Duration sensitiveOperationMaxAge;

  SessionSecurityEngine({
    this.sessionTtl = const Duration(hours: 24),
    this.sensitiveOperationMaxAge = const Duration(minutes: 10),
  });

  /// تسجيل جلسة جديدة
  void registerSession(String sessionId, {DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    _sessions[sessionId] = (timestamp, timestamp, false);
  }

  /// إلغاء جلسة أمنية فوراً (Forced Logout / Revocation)
  void revokeSession(String sessionId) {
    if (_sessions.containsKey(sessionId)) {
      final (created, lastActive, _) = _sessions[sessionId]!;
      _sessions[sessionId] = (created, lastActive, true);
    }
  }

  /// فحص صلاحية الجلسة
  SecuritySessionState validateSession(String sessionId, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final session = _sessions[sessionId];

    if (session == null) return SecuritySessionState.revoked;

    final (created, lastActive, isRevoked) = session;

    if (isRevoked) return SecuritySessionState.revoked;

    if (currentTime.difference(created) > sessionTtl) {
      return SecuritySessionState.expired;
    }

    return SecuritySessionState.active;
  }

  /// فحص هل تتطلب العملية المالية أو الإدارية الحساسة إعادة تأكيد هوية/كلمة مرور (Step-Up / Re-Authentication)
  bool requiresReAuthentication({
    required String sessionId,
    required bool isSensitiveOperation,
    DateTime? lastReAuthTime,
    DateTime? now,
  }) {
    if (!isSensitiveOperation) return false;
    final currentTime = now ?? DateTime.now();

    if (lastReAuthTime == null) return true;

    return currentTime.difference(lastReAuthTime) > sensitiveOperationMaxAge;
  }

  /// التحقق مع فرض قيود الأمان
  void assertValidSession(String sessionId, {DateTime? now}) {
    final state = validateSession(sessionId, now: now);
    if (state != SecuritySessionState.active) {
      throw SecurityViolationException(
        'Session security violation: session is [${state.key}]',
        type: SecurityViolationType.bannedUserAction,
        fieldName: 'sessionId',
      );
    }
  }
}
