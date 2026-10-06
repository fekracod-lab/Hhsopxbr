import '../domain/entities/security_models.dart';
import '../entities/authorization_context.dart';
import '../entities/security_event.dart';
import '../entities/security_readiness_result.dart';
import '../enums/security_enums.dart';
import '../repositories/i_security_repository.dart';
import '../repositories/security_repository.dart';
import '../services/anti_privilege_escalation_guard.dart';
import '../services/privacy_engine.dart';
import '../services/rate_limit_abuse_engine.dart';
import '../services/rbac_permission_engine.dart';
import '../services/secret_scanner_engine.dart';
import '../services/secure_storage_service.dart';
import '../services/security_audit_engine.dart';
import '../services/security_event_engine.dart';
import '../services/security_readiness_engine.dart';
import '../services/session_security_engine.dart';
import '../services/zero_trust_authorization_engine.dart';
import '../../orchestration/domain/services/domain_event_bus.dart';

/// محرك الأمان والخصوصية الإنتاجي المتكامل (MADAR Production Security Kernel Facade)
class ProductionSecurityEngine {
  final ZeroTrustAuthorizationEngine zeroTrustEngine;
  final RbacPermissionEngine rbacEngine;
  final AntiPrivilegeEscalationGuard escalationGuard;
  final SecretScannerEngine secretScanner;
  final SecureStorageService secureStorage;
  final PrivacyEngine privacyEngine;
  final SecurityEventEngine eventEngine;
  final RateLimitAbuseEngine rateLimitEngine;
  final SessionSecurityEngine sessionEngine;
  final SecurityAuditEngine auditEngine;
  final SecurityReadinessEngine readinessEngine;
  final ISecurityRepository repository;
  final DomainEventBus? eventBus;

  factory ProductionSecurityEngine({
    ZeroTrustAuthorizationEngine? zeroTrustEngine,
    RbacPermissionEngine? rbacEngine,
    AntiPrivilegeEscalationGuard? escalationGuard,
    SecretScannerEngine? secretScanner,
    SecureStorageService? secureStorage,
    PrivacyEngine? privacyEngine,
    SecurityEventEngine? eventEngine,
    RateLimitAbuseEngine? rateLimitEngine,
    SessionSecurityEngine? sessionEngine,
    SecurityAuditEngine? auditEngine,
    SecurityReadinessEngine? readinessEngine,
    ISecurityRepository? repository,
    DomainEventBus? eventBus,
  }) {
    final events = eventEngine ?? SecurityEventEngine(eventBus: eventBus);
    final repo = repository ?? SecurityRepository();

    return ProductionSecurityEngine._(
      zeroTrustEngine: zeroTrustEngine ?? ZeroTrustAuthorizationEngine(),
      rbacEngine: rbacEngine ?? RbacPermissionEngine(),
      escalationGuard: escalationGuard ?? const AntiPrivilegeEscalationGuard(),
      secretScanner: secretScanner ?? const SecretScannerEngine(),
      secureStorage: secureStorage ?? SecureStorageService(),
      privacyEngine: privacyEngine ?? const PrivacyEngine(),
      eventEngine: events,
      rateLimitEngine: rateLimitEngine ?? RateLimitAbuseEngine(),
      sessionEngine: sessionEngine ?? SessionSecurityEngine(),
      auditEngine: auditEngine ?? const SecurityAuditEngine(),
      readinessEngine: readinessEngine ?? const SecurityReadinessEngine(),
      repository: repo,
      eventBus: eventBus,
    );
  }

  const ProductionSecurityEngine._({
    required this.zeroTrustEngine,
    required this.rbacEngine,
    required this.escalationGuard,
    required this.secretScanner,
    required this.secureStorage,
    required this.privacyEngine,
    required this.eventEngine,
    required this.rateLimitEngine,
    required this.sessionEngine,
    required this.auditEngine,
    required this.readinessEngine,
    required this.repository,
    this.eventBus,
  });

  /// فحص وتفويض الطلب وفق سياسة Zero-Trust وتسجيل الأحداث المخالفة تلقائياً
  bool authorizeRequest(AuthorizationContext context) {
    try {
      return zeroTrustEngine.authorize(context);
    } catch (e) {
      // تسجيل الحدث الأمني فوراً في سجل الأحداث والمستودع
      eventEngine.recordSecurityEvent(
        eventType: SecurityEventType.permissionDenied,
        severity: ThreatSeverity.high,
        actorUserId: context.subjectUserId,
        description: e.toString(),
        resource: '${context.resourceType}:${context.resourceId ?? "*"}',
      );
      rethrow;
    }
  }

  /// فحص محاولة تصعيد الصلاحيات
  void assertLegalRoleMutation({
    required MadarRole actorRole,
    required String actorUserId,
    required MadarRole currentTargetRole,
    required MadarRole requestedNewRole,
    required String targetUserId,
  }) {
    try {
      escalationGuard.assertLegalRoleMutation(
        actorRole: actorRole,
        actorUserId: actorUserId,
        currentTargetRole: currentTargetRole,
        requestedNewRole: requestedNewRole,
        targetUserId: targetUserId,
      );
    } catch (e) {
      eventEngine.recordSecurityEvent(
        eventType: SecurityEventType.privilegeEscalationAttempt,
        severity: ThreatSeverity.critical,
        actorUserId: actorUserId,
        description: e.toString(),
        resource: 'users:$targetUserId:role',
      );
      rethrow;
    }
  }

  /// فحص تزوير الهوية UID Spoofing
  void assertIdentityIntegrity({
    required String authenticatedUid,
    required String requestPayloadUid,
    required MadarRole actorRole,
  }) {
    try {
      escalationGuard.assertIdentityIntegrity(
        authenticatedUid: authenticatedUid,
        requestPayloadUid: requestPayloadUid,
        actorRole: actorRole,
      );
    } catch (e) {
      eventEngine.recordSecurityEvent(
        eventType: SecurityEventType.unauthorizedAccess,
        severity: ThreatSeverity.high,
        actorUserId: authenticatedUid,
        description: e.toString(),
        resource: 'users:$requestPayloadUid',
      );
      rethrow;
    }
  }

  /// فحص تحديد المعدل ومنع الإغراق
  void assertRateLimit({
    required String rateKey,
    required int maxAllowed,
    required Duration window,
    Duration lockoutDuration = const Duration(minutes: 15),
    DateTime? now,
  }) {
    try {
      rateLimitEngine.assertRateLimit(
        rateKey: rateKey,
        maxAllowed: maxAllowed,
        window: window,
        lockoutDuration: lockoutDuration,
        now: now,
      );
    } catch (e) {
      eventEngine.recordSecurityEvent(
        eventType: SecurityEventType.rateLimitExceeded,
        severity: ThreatSeverity.medium,
        actorUserId: rateKey,
        description: e.toString(),
        resource: rateKey,
      );
      rethrow;
    }
  }

  /// تسجيل وحفظ حدث أمني
  Future<SecurityEventRecord> logSecurityViolation({
    required SecurityEventType eventType,
    required ThreatSeverity severity,
    required String actorUserId,
    required String description,
    String? resource,
    String? traceId,
    String? correlationId,
    Map<String, dynamic> metadata = const {},
    DateTime? now,
  }) async {
    final event = await eventEngine.recordSecurityEvent(
      eventType: eventType,
      severity: severity,
      actorUserId: actorUserId,
      description: description,
      resource: resource,
      traceId: traceId,
      correlationId: correlationId,
      metadata: metadata,
      now: now,
    );
    await repository.saveSecurityEvent(event);
    return event;
  }

  /// تنفيذ تدقيق الجاهزية الأمنية لـ 14 فئة وحفظ النتيجة
  Future<SecurityReadinessResult> runSecurityReadinessAudit({
    required Map<SecurityGateCategory, double> categoryScores,
    required Map<SecurityGateCategory, List<String>> categoryBlockers,
    Map<SecurityGateCategory, List<String>> categoryWarnings = const {},
    DateTime? now,
  }) async {
    final result = readinessEngine.evaluateSecurityGate(
      categoryScores: categoryScores,
      categoryBlockers: categoryBlockers,
      categoryWarnings: categoryWarnings,
      now: now,
    );

    await repository.saveReadinessAudit(result);
    return result;
  }
}
