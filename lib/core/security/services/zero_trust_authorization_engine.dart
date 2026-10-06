import '../domain/entities/security_models.dart';
import '../entities/authorization_context.dart';
import '../entities/role_definition.dart';

/// محرك التفويض والتحقق القائم على انعدام الثقة (Zero-Trust Authorization Engine)
/// المبدأ: الحظر الافتراضي (Deny by default) والتحقق الإلزامي من الهوية، الدور، الصلاحية، ملكية المورد، وسياق الخطر.
class ZeroTrustAuthorizationEngine {
  final Map<MadarRole, RoleDefinition> roleDefinitions;

  ZeroTrustAuthorizationEngine({
    Map<MadarRole, RoleDefinition>? roleDefinitions,
  }) : roleDefinitions = roleDefinitions ?? RoleDefinition.defaultRoles;

  /// تقييم طلب الوصول وفق سياسة Zero-Trust
  /// يرجع `true` فقط وفقط إذا استوفى الطلب كافة الشروط، وإلا يرمي `SecurityViolationException`
  bool authorize(AuthorizationContext context) {
    // 1. التحقق من وجود هوية مستخدم موثقة
    if (context.subjectUserId.trim().isEmpty) {
      throw const SecurityViolationException(
        'Zero-Trust Denial: Unauthenticated anonymous request strictly rejected',
        type: SecurityViolationType.unauthorizedRoleEscalation,
        fieldName: 'subjectUserId',
      );
    }

    // 2. التحقق من صلاحية الجلسة
    if (!context.isSessionValid) {
      throw SecurityViolationException(
        'Zero-Trust Denial: Session is in invalid state [${context.sessionState.key}]',
        type: SecurityViolationType.bannedUserAction,
        fieldName: 'sessionState',
      );
    }

    // 3. التحقق من مستوى الخطر وسلوك الحساب
    if (!context.isRiskAcceptable) {
      throw SecurityViolationException(
        'Zero-Trust Denial: Operation blocked due to elevated risk score [${context.currentRiskScore}]',
        type: SecurityViolationType.rateLimitExceeded,
        fieldName: 'currentRiskScore',
      );
    }

    // 4. استرجاع مصفوفة صلاحيات الدور
    final roleDef = roleDefinitions[context.role];
    if (roleDef == null) {
      throw SecurityViolationException(
        'Zero-Trust Denial: Unrecognized role [${context.role.key}]',
        type: SecurityViolationType.unauthorizedRoleEscalation,
        fieldName: 'role',
      );
    }

    // 5. المدير العام والأعلى يملكان حق الوصول الشامل
    if (context.role == MadarRole.superAdmin || context.role == MadarRole.mainAdmin) {
      return true;
    }

    // 6. التحقق من الصلاحية الدقيقة (RBAC Capability Check)
    final hasPermission = roleDef.hasPermission(context.action);

    // 7. التحقق من ملكية المورد (ABAC Resource Ownership)
    // إذا كانت العملية تتطلب ملكية شخصية (مثل قراءة المحفظة أو طلب استرجاع للعميل)
    final isOwner = context.isResourceOwner;

    // إذا كانت الصلاحية موجودة والمورد يخص المستخدم أو كان إدارياً مصرحاً
    if (hasPermission && (isOwner || context.isAdmin || context.resourceOwnerId == null)) {
      return true;
    }

    // إذا فشل أي شرط -> الحظر الافتراضي الحاسم
    throw SecurityViolationException(
      'Zero-Trust Denial: Subject [${context.subjectUserId}] with role [${context.role.key}] lacks authorization for action [${context.action}] on resource [${context.resourceType}:${context.resourceId ?? "*"}] (Ownership: $isOwner)',
      type: SecurityViolationType.unauthorizedRoleEscalation,
      fieldName: 'action',
    );
  }

  /// التحقق السريع المباشر (Boolean Check بدون استثناء)
  bool isAuthorized(AuthorizationContext context) {
    try {
      return authorize(context);
    } catch (_) {
      return false;
    }
  }
}
