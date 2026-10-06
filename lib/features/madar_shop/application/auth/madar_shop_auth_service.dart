// خدمة التحقق وبوابة المصادقة لمتجر مدار (MADAR SHOP Authentication Gate Service)
// Application Layer — Multi-Tier RBAC & Enterprise Security Gate

import '../../domain/identity/contracts/i_shop_identity_repository.dart';
import '../../domain/identity/entities/shop_session.dart';
import '../../domain/identity/entities/shop_user.dart';
import '../../domain/identity/rbac/shop_permission.dart';
import '../../domain/identity/rbac/shop_role.dart';
import '../shop_identity_coordinator.dart';

enum AuthDenialReason {
  notBusinessEmployee,
  noPosAccess,
  wrongBusiness,
  wrongBranch,
  invalidCredentials,
  sessionExpired,
  inactiveAccount,
  unauthorizedTerminal,
}

class AuthGateResult {
  final bool isAllowed;
  final ShopUser? user;
  final ShopSession? session;
  final AuthDenialReason? denialReason;
  final String? messageAr;

  const AuthGateResult._({
    required this.isAllowed,
    this.user,
    this.session,
    this.denialReason,
    this.messageAr,
  });

  factory AuthGateResult.allowed({
    required ShopUser user,
    required ShopSession session,
  }) {
    return AuthGateResult._(
      isAllowed: true,
      user: user,
      session: session,
    );
  }

  factory AuthGateResult.denied({
    required AuthDenialReason reason,
    required String messageAr,
  }) {
    return AuthGateResult._(
      isAllowed: false,
      denialReason: reason,
      messageAr: messageAr,
    );
  }
}

class MadarShopAuthService {
  final IShopIdentityRepository _identityRepo;
  final ShopIdentityCoordinator _identityCoordinator;

  // الأدوار المصرح لها بالدخول إلى بيئة المتجر
  static const Set<ShopRole> allowedShopRoles = {
    ShopRole.owner,
    ShopRole.generalManager,
    ShopRole.branchManager,
    ShopRole.cashier,
    ShopRole.inventoryClerk,
    ShopRole.accountant,
  };

  MadarShopAuthService({
    required IShopIdentityRepository identityRepo,
    required ShopIdentityCoordinator identityCoordinator,
  })  : _identityRepo = identityRepo,
        _identityCoordinator = identityCoordinator;

  /// تنفيذ عملية تسجيل الدخول وفتح الجلسة بعد الفحص الصارم للصلاحيات
  Future<AuthGateResult> loginAndOpenSession({
    required String loginIdentifier,
    required String secret,
    required String businessId,
    required String branchId,
    required String terminalId,
    required String installationId,
    bool requirePosAccess = true,
  }) async {
    // 1. التحقق من صحة بيانات الدخول
    final user = await _identityRepo.getUserByCredentials(
      loginIdentifier: loginIdentifier,
      secret: secret,
    );

    if (user == null) {
      return AuthGateResult.denied(
        reason: AuthDenialReason.invalidCredentials,
        messageAr: 'بيانات الدخول غير صحيحة أو الحساب غير موجود.',
      );
    }

    // 2. التحقق من أن الحساب نشط
    if (!user.isActive) {
      return AuthGateResult.denied(
        reason: AuthDenialReason.inactiveAccount,
        messageAr: 'هذا الحساب معطل أو تم تجميده؛ يرجى مراجعة إدارة المتجر.',
      );
    }

    // 3. التحقق من هوية الموظف (Business/Shop Employee وليس زبون عادي)
    if (!allowedShopRoles.contains(user.role)) {
      return AuthGateResult.denied(
        reason: AuthDenialReason.notBusinessEmployee,
        messageAr: 'هذا الحساب غير مرتبط بحساب متجر مصرح به.',
      );
    }

    // 4. التحقق من تطابق النشاط التجاري
    if (user.businessId != businessId) {
      return AuthGateResult.denied(
        reason: AuthDenialReason.wrongBusiness,
        messageAr: 'المستخدم غير مرتبط بهذا المتجر.',
      );
    }

    // 5. التحقق من صلاحية الوصول للفرع المحدد
    if (!user.canAccessBranch(branchId)) {
      return AuthGateResult.denied(
        reason: AuthDenialReason.wrongBranch,
        messageAr: 'ليس لديك صلاحية الوصول إلى هذا الفرع.',
      );
    }

    // 6. التحقق من صلاحية استخدام نقطة البيع (إذا كان الدخول مخصصاً لـ POS)
    if (requirePosAccess && !user.hasPermission(ShopPermission.accessPos)) {
      return AuthGateResult.denied(
        reason: AuthDenialReason.noPosAccess,
        messageAr: 'ليس لديك صلاحية استخدام نقطة البيع.',
      );
    }

    // 7. إنشاء جلسة عمل جديدة
    final now = DateTime.now();
    final session = ShopSession(
      sessionId: 'SESS-${now.millisecondsSinceEpoch}-${user.userId}',
      installationId: installationId,
      terminalId: terminalId,
      userId: user.userId,
      businessId: businessId,
      activeBranchId: branchId,
      startedAt: now,
      lastHeartbeatAt: now,
      expiresAt: now.add(const Duration(hours: 12)),
      status: ShopSessionStatus.active,
    );

    await _identityRepo.saveSession(session);

    // 8. تفعيل الجلسة في منسق الهوية
    _identityCoordinator.setSession(user: user, session: session);

    return AuthGateResult.allowed(
      user: user,
      session: session,
    );
  }

  /// التحقق من صلاحية جلسة حالية
  Future<AuthGateResult> validateCurrentSession({
    required String businessId,
    required String branchId,
    bool requirePosAccess = true,
  }) async {
    final user = _identityCoordinator.currentUser;
    final session = _identityCoordinator.currentSession;

    if (user == null || session == null) {
      return AuthGateResult.denied(
        reason: AuthDenialReason.invalidCredentials,
        messageAr: 'لم يتم العثور على جلسة مسجلة.',
      );
    }

    if (session.isExpired || session.status == ShopSessionStatus.terminated) {
      return AuthGateResult.denied(
        reason: AuthDenialReason.sessionExpired,
        messageAr: 'جلسة العمل منتهية الصلاحية؛ يرجى تسجيل الدخول مجدداً.',
      );
    }

    if (!allowedShopRoles.contains(user.role)) {
      return AuthGateResult.denied(
        reason: AuthDenialReason.notBusinessEmployee,
        messageAr: 'هذا الحساب غير مرتبط بحساب متجر مصرح به.',
      );
    }

    if (session.businessId != businessId || user.businessId != businessId) {
      return AuthGateResult.denied(
        reason: AuthDenialReason.wrongBusiness,
        messageAr: 'المستخدم غير مرتبط بهذا المتجر.',
      );
    }

    if (session.activeBranchId != branchId || !user.canAccessBranch(branchId)) {
      return AuthGateResult.denied(
        reason: AuthDenialReason.wrongBranch,
        messageAr: 'ليس لديك صلاحية الوصول إلى هذا الفرع.',
      );
    }

    if (requirePosAccess && !user.hasPermission(ShopPermission.accessPos)) {
      return AuthGateResult.denied(
        reason: AuthDenialReason.noPosAccess,
        messageAr: 'ليس لديك صلاحية استخدام نقطة البيع.',
      );
    }

    return AuthGateResult.allowed(
      user: user,
      session: session,
    );
  }

  /// تسجيل الخروج وإغلاق الجلسة
  Future<void> logout() async {
    final currentSession = _identityCoordinator.currentSession;
    if (currentSession != null) {
      await _identityRepo.terminateSession(currentSession.sessionId);
    }
    _identityCoordinator.clearSession();
  }
}
