import '../domain/entities/security_models.dart';

/// حارس منع تصعيد الصلاحيات والتلاعب بالهوية (Anti-Privilege Escalation Guard)
class AntiPrivilegeEscalationGuard {
  const AntiPrivilegeEscalationGuard();

  /// فحص محاولات تصعيد الصلاحيات وتغيير الأدوار من طرف العميل (Client-Side Role Mutation Attack)
  void assertLegalRoleMutation({
    required MadarRole actorRole,
    required String actorUserId,
    required MadarRole currentTargetRole,
    required MadarRole requestedNewRole,
    required String targetUserId,
  }) {
    // 1. لا يجوز لأي مستخدم عادي أو سائق أو تاجر تغيير دوره بنفسه
    if (actorUserId == targetUserId && !actorRole.isAdmin && requestedNewRole != currentTargetRole) {
      throw SecurityViolationException(
        'Privilege Escalation Blocked: Non-admin user [$actorUserId] attempted self-role mutation from [${currentTargetRole.key}] to [${requestedNewRole.key}]',
        type: SecurityViolationType.unauthorizedRoleEscalation,
        fieldName: 'role',
      );
    }

    // 2. ترقية الحسابات إلى SuperAdmin أو MainAdmin حصرية فقط لـ SuperAdmin
    if ((requestedNewRole == MadarRole.superAdmin || requestedNewRole == MadarRole.mainAdmin) &&
        actorRole != MadarRole.superAdmin) {
      throw SecurityViolationException(
        'Privilege Escalation Blocked: Only SuperAdmin can grant administrative tier [${requestedNewRole.key}]. Actor role: [${actorRole.key}]',
        type: SecurityViolationType.unauthorizedRoleEscalation,
        fieldName: 'role',
      );
    }

    // 3. منع الإداريين العاديين من ترقية مستخدمين إلى رتب أعلى منهم
    if (actorRole == MadarRole.admin && requestedNewRole.isAdmin && requestedNewRole != MadarRole.limitedAdmin && requestedNewRole != MadarRole.complaintsAdmin) {
      throw SecurityViolationException(
        'Privilege Escalation Blocked: Admin cannot grant equal or higher administrative privileges [${requestedNewRole.key}]',
        type: SecurityViolationType.unauthorizedRoleEscalation,
        fieldName: 'role',
      );
    }
  }

  /// فحص محاولات تزوير هوية المستخدم (UID Spoofing Attack)
  void assertIdentityIntegrity({
    required String authenticatedUid,
    required String requestPayloadUid,
    required MadarRole actorRole,
  }) {
    if (authenticatedUid.trim().isEmpty) {
      throw const SecurityViolationException(
        'Identity Violation: Unauthenticated request payload',
        type: SecurityViolationType.unauthorizedRoleEscalation,
        fieldName: 'uid',
      );
    }

    // إذا لم يكن إدارياً مصرحاً وحاول إرسال طلب باسم مستخدم آخر
    if (authenticatedUid != requestPayloadUid && !actorRole.isAdmin) {
      throw SecurityViolationException(
        'UID Spoofing Blocked: Authenticated user [$authenticatedUid] submitted mismatched subject UID [$requestPayloadUid]',
        type: SecurityViolationType.tamperedPayload,
        fieldName: 'uid',
      );
    }
  }
}
