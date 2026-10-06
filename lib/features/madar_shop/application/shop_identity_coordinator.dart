// منسق الهوية والجلسات والصلاحيات (MADAR SHOP Identity Coordinator)
// Application Layer — Decoupled State & Orchestration

import '../domain/identity/entities/shop_session.dart';
import '../domain/identity/entities/shop_user.dart';
import '../domain/identity/rbac/shop_permission.dart';
import '../domain/identity/rbac/shop_role.dart';

class ShopIdentityCoordinator {
  ShopUser? _currentUser;
  ShopSession? _currentSession;

  ShopUser? get currentUser => _currentUser;
  ShopSession? get currentSession => _currentSession;

  bool get isAuthenticated => _currentUser != null && _currentSession != null && !_currentSession!.isExpired;

  /// تهيئة وتفعيل جلسة موظف جديدة
  void setSession({
    required ShopUser user,
    required ShopSession session,
  }) {
    _currentUser = user;
    _currentSession = session;
  }

  /// إنهاء الجلسة وتسجيل الخروج
  void clearSession() {
    _currentUser = null;
    _currentSession = null;
  }

  /// التحقق السريع من امتلاك المستخدم الحالي لصلاحية معينة
  bool hasPermission(ShopPermission permission) {
    if (!isAuthenticated) return false;
    return _currentUser!.hasPermission(permission);
  }

  /// التحقق من حق الكاشير / الموظف في إدارة الفرع الحالي
  bool canOperateOnActiveBranch(String branchId) {
    if (!isAuthenticated) return false;
    return _currentUser!.canAccessBranch(branchId);
  }

  /// التحقق من أن المستخدم يملك صلاحية مالك أو مدير
  bool get isManagementLevel {
    if (!isAuthenticated) return false;
    return _currentUser!.role == ShopRole.owner ||
        _currentUser!.role == ShopRole.generalManager ||
        _currentUser!.role == ShopRole.branchManager;
  }
}
