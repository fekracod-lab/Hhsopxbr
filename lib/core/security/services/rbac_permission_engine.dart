import '../domain/entities/security_models.dart';
import '../entities/permission.dart';
import '../entities/role_definition.dart';

/// محرك إدارة الأدوار والمصفوفة الصلاحيات (RBAC & Permission Matrix Engine)
class RbacPermissionEngine {
  final Map<MadarRole, RoleDefinition> _roles;

  RbacPermissionEngine({
    Map<MadarRole, RoleDefinition>? customRoles,
  }) : _roles = customRoles != null ? Map.from(customRoles) : Map.from(RoleDefinition.defaultRoles);

  Map<MadarRole, RoleDefinition> get roles => Map.unmodifiable(_roles);

  /// فحص هل يمتلك الدور صلاحية محددة
  bool hasPermission(MadarRole role, String permissionKey) {
    final roleDef = _roles[role];
    if (roleDef == null) return false;
    return roleDef.hasPermission(permissionKey);
  }

  /// الحصول على قائمة الصلاحيات الخاصة بدور معين
  Set<String> getPermissionsForRole(MadarRole role) {
    final roleDef = _roles[role];
    if (roleDef == null) return const {};
    if (role == MadarRole.superAdmin || role == MadarRole.mainAdmin) {
      return {for (var p in GranularPermission.all) p.key};
    }
    return Set.unmodifiable(roleDef.permissions);
  }

  /// هل يستطيع المستخدم صاحب الدور الحالي إدارة أو تعديل مستخدم بدور آخر؟
  bool canActorManageTargetRole({
    required MadarRole actorRole,
    required MadarRole targetRole,
  }) {
    // السوبر أدمن يدير الجميع
    if (actorRole == MadarRole.superAdmin) return true;
    if (actorRole == MadarRole.mainAdmin && targetRole != MadarRole.superAdmin) return true;

    final actorDef = _roles[actorRole];
    final targetDef = _roles[targetRole];

    if (actorDef == null || targetDef == null) return false;

    // التسلسل الهرمي الصارم: يمكن فقط لمن هو أعلى رتبة إدارة الرتب الأدنى
    return actorDef.hierarchyLevel > targetDef.hierarchyLevel;
  }
}
