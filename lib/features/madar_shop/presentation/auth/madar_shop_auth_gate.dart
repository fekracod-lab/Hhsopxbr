// بوابة التحقق الأمنية لنظام متجر مدار (MADAR SHOP Authentication Gate)
// Presentation Layer — Gatekeeper guarding the POS shell from unauthorized users

import 'package:flutter/material.dart';

import '../../application/auth/madar_shop_auth_service.dart';
import '../../application/shop_identity_coordinator.dart';
import '../../data/identity/repositories/firebase_shop_identity_repository.dart';
import '../../domain/identity/entities/shop_session.dart';
import '../../domain/identity/entities/shop_user.dart';
import '../../domain/identity/rbac/shop_permission.dart';
import '../pos/controllers/windows_pos_controller.dart';
import '../pos/pages/windows_pos_page.dart';
import '../pos/utils/production_pos_factory.dart';
import 'access_denied_page.dart';
import 'madar_shop_login_page.dart';

class MadarShopAuthGate extends StatefulWidget {
  final MadarShopAuthService? authService;
  final ShopIdentityCoordinator? identityCoordinator;
  final Widget Function(BuildContext context, ShopUser user, ShopSession session)? builder;
  final String defaultBusinessId;
  final String defaultBranchId;
  final String defaultTerminalId;

  const MadarShopAuthGate({
    super.key,
    this.authService,
    this.identityCoordinator,
    this.builder,
    this.defaultBusinessId = 'BIZ-01',
    this.defaultBranchId = 'BR-01',
    this.defaultTerminalId = 'POS-WIN-01',
  });

  @override
  State<MadarShopAuthGate> createState() => _MadarShopAuthGateState();
}

class _MadarShopAuthGateState extends State<MadarShopAuthGate> {
  late final ShopIdentityCoordinator _identityCoordinator;
  late final MadarShopAuthService _authService;
  Future<WindowsPosController>? _posControllerFuture;

  @override
  void initState() {
    super.initState();
    _identityCoordinator = widget.identityCoordinator ?? ShopIdentityCoordinator();
    _authService = widget.authService ??
        MadarShopAuthService(
          identityRepo: FirebaseShopIdentityRepository(),
          identityCoordinator: _identityCoordinator,
        );
  }

  @override
  Widget build(BuildContext context) {
    // 1. فحص ما إذا كان المستخدم مسجلاً ومملكاً لجلسة سارية
    if (!_identityCoordinator.isAuthenticated) {
      _posControllerFuture = null; // إعادة تعيين المتحكم عند الخروج
      return MadarShopLoginPage(
        authService: _authService,
        initialBusinessId: widget.defaultBusinessId,
        initialBranchId: widget.defaultBranchId,
        initialTerminalId: widget.defaultTerminalId,
        onLoginSuccess: (user, session) {
          setState(() {});
        },
      );
    }

    final user = _identityCoordinator.currentUser!;
    final session = _identityCoordinator.currentSession!;

    // 2. التحقق من أن الحساب تابع لموظفي المتجر (وليس زبون عادي)
    if (!MadarShopAuthService.allowedShopRoles.contains(user.role)) {
      return AccessDeniedPage(
        title: 'حساب غير مصرح به',
        message: 'هذا الحساب غير مرتبط بحساب متجر مصرح به.',
        roleDisplayName: user.role.displayNameAr,
        onSwitchAccount: () async {
          await _authService.logout();
          if (mounted) setState(() {});
        },
      );
    }

    // 3. التحقق من صلاحية الوصول لنقطة البيع (POS Access)
    if (!user.hasPermission(ShopPermission.accessPos)) {
      return AccessDeniedPage(
        title: 'صلاحية غير كافية',
        message: 'ليس لديك صلاحية استخدام نقطة البيع.',
        roleDisplayName: user.role.displayNameAr,
        onSwitchAccount: () async {
          await _authService.logout();
          if (mounted) setState(() {});
        },
      );
    }

    // 4. مصرح له بالكامل — الدخول إلى شاشة الـ POS
    if (widget.builder != null) {
      return widget.builder!(context, user, session);
    }

    _posControllerFuture ??= ProductionPosFactory.createController(
      identityCoordinator: _identityCoordinator,
    );

    return FutureBuilder<WindowsPosController>(
      future: _posControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F1117),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF1E88E5)),
                  SizedBox(height: 16),
                  Text(
                    'جاري تهيئة نقطة البيع...',
                    style: TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Text(
                'تعذر تحميل نقطة البيع: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent, fontFamily: 'Cairo'),
              ),
            ),
          );
        }

        return WindowsPosPage(
          controller: snapshot.data!,
          onLogout: () async {
            await _authService.logout();
            if (mounted) setState(() {});
          },
        );
      },
    );
  }
}
