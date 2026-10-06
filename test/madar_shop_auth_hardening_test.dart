// حزمة اختبارات التحصين الأمني للمصادقة وجلسات العمل (MADAR SYSTEM S8 Auth Hardening Suite)
// 11 Mandatory Tests: Zero Hardcoded Credentials + RBAC Guard + Session Invalidation + Isolation

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/madar_shop/madar_shop.dart';

void main() {
  const bizId = 'BIZ-01';
  const branchId = 'BR-01';
  const terminalId = 'POS-WIN-01';
  const installId = 'INST-WIN-01';

  late MemoryShopIdentityRepository identityRepo;
  late ShopIdentityCoordinator identityCoordinator;
  late MadarShopAuthService authService;

  setUp(() {
    identityRepo = MemoryShopIdentityRepository();
    identityCoordinator = ShopIdentityCoordinator();
    authService = MadarShopAuthService(
      identityRepo: identityRepo,
      identityCoordinator: identityCoordinator,
    );

    // Business setup
    identityRepo.seedBusiness(
      business: ShopBusiness(
        businessId: bizId,
        tradeName: 'Madar Supermarket',
        legalName: 'Madar LLC',
        phone: '07701112233',
        email: 'info@madar.iq',
        defaultCurrency: 'IQD',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      branches: [
        ShopBranch(
          branchId: branchId,
          businessId: bizId,
          name: 'Main Branch',
          code: 'BR-01',
          address: 'Baghdad, Karrada',
          phone: '07701112233',
          isMainBranch: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
    );

    // 1. Customer User
    identityRepo.seedUser(
      user: ShopUser(
        userId: 'usr_cust_01',
        businessId: bizId,
        fullName: 'Customer Test',
        phone: '07700000001',
        email: 'customer@madar.iq',
        role: ShopRole.custom,      // Non-shop role (simulates customer/external user)
        isActive: true,
        assignedBranchIds: const [branchId],
        createdAt: DateTime.now(),
      ),
      loginIdentifier: 'customer@madar.iq',
      secret: 'secure_pass_1',
    );

    // 2. Normal / Delivery User (non-shop role)
    identityRepo.seedUser(
      user: ShopUser(
        userId: 'usr_normal_01',
        businessId: bizId,
        fullName: 'Delivery Driver',
        phone: '07700000002',
        email: 'driver@madar.iq',
        role: ShopRole.custom,      // Non-shop role (simulates delivery / external user)
        isActive: true,
        assignedBranchIds: const [branchId],
        createdAt: DateTime.now(),
      ),
      loginIdentifier: 'driver@madar.iq',
      secret: 'secure_pass_2',
    );

    // 3. Authenticated user without business membership
    identityRepo.seedUser(
      user: ShopUser(
        userId: 'usr_no_biz_01',
        businessId: '', // No business association
        fullName: 'No Business User',
        phone: '07700000003',
        email: 'nobiz@madar.iq',
        role: ShopRole.cashier,
        isActive: true,
        assignedBranchIds: const [branchId],
        createdAt: DateTime.now(),
      ),
      loginIdentifier: 'nobiz@madar.iq',
      secret: 'secure_pass_3',
    );

    // 4. Valid Shop Cashier (Business employee)
    identityRepo.seedUser(
      user: ShopUser(
        userId: 'usr_cashier_01',
        businessId: bizId,
        fullName: 'Ahmad Cashier',
        phone: '07700000004',
        email: 'cashier@madar.iq',
        role: ShopRole.cashier,
        isActive: true,
        assignedBranchIds: const [branchId],
        createdAt: DateTime.now(),
      ),
      loginIdentifier: 'cashier@madar.iq',
      secret: 'secure_pass_4',
    );

    // 5. Employee assigned to different branch
    identityRepo.seedUser(
      user: ShopUser(
        userId: 'usr_wrong_branch_01',
        businessId: bizId,
        fullName: 'Branch 2 Cashier',
        phone: '07700000005',
        email: 'otherbranch@madar.iq',
        role: ShopRole.cashier,
        isActive: true,
        assignedBranchIds: const ['BR-02'], // Only BR-02
        createdAt: DateTime.now(),
      ),
      loginIdentifier: 'otherbranch@madar.iq',
      secret: 'secure_pass_5',
    );

    // 6. Employee assigned to different business
    identityRepo.seedUser(
      user: ShopUser(
        userId: 'usr_wrong_biz_01',
        businessId: 'BIZ-OTHER',
        fullName: 'Competitor Employee',
        phone: '07700000006',
        email: 'wrongbiz@madar.iq',
        role: ShopRole.cashier,
        isActive: true,
        assignedBranchIds: const [branchId],
        createdAt: DateTime.now(),
      ),
      loginIdentifier: 'wrongbiz@madar.iq',
      secret: 'secure_pass_6',
    );

    // 7. Inventory Clerk without POS permission
    identityRepo.seedUser(
      user: ShopUser(
        userId: 'usr_no_pos_01',
        businessId: bizId,
        fullName: 'Inventory Clerk No POS',
        phone: '07700000007',
        email: 'clerk@madar.iq',
        role: ShopRole.inventoryClerk, // Default permissions do not include accessPos
        isActive: true,
        assignedBranchIds: const [branchId],
        createdAt: DateTime.now(),
      ),
      loginIdentifier: 'clerk@madar.iq',
      secret: 'secure_pass_7',
    );
  });

  group('MADAR SYSTEM — S8 Auth Hardening Verification', () {
    test('1. Customer account => DENIED even if authentication succeeds', () async {
      final result = await authService.loginAndOpenSession(
        loginIdentifier: 'customer@madar.iq',
        secret: 'secure_pass_1',
        businessId: bizId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
        requirePosAccess: true,
      );

      expect(result.isAllowed, isFalse);
      expect(result.denialReason, equals(AuthDenialReason.notBusinessEmployee));
      expect(identityCoordinator.isAuthenticated, isFalse);
    });

    test('2. Normal non-shop user => DENIED', () async {
      final result = await authService.loginAndOpenSession(
        loginIdentifier: 'driver@madar.iq',
        secret: 'secure_pass_2',
        businessId: bizId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
        requirePosAccess: true,
      );

      expect(result.isAllowed, isFalse);
      expect(result.denialReason, equals(AuthDenialReason.notBusinessEmployee));
      expect(identityCoordinator.isAuthenticated, isFalse);
    });

    test('3. Authenticated user but no business membership => DENIED', () async {
      final result = await authService.loginAndOpenSession(
        loginIdentifier: 'nobiz@madar.iq',
        secret: 'secure_pass_3',
        businessId: bizId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
        requirePosAccess: true,
      );

      expect(result.isAllowed, isFalse);
      expect(result.denialReason, equals(AuthDenialReason.wrongBusiness));
      expect(identityCoordinator.isAuthenticated, isFalse);
    });

    test('4. Legitimate shop business employee => ALLOWED & session active', () async {
      final result = await authService.loginAndOpenSession(
        loginIdentifier: 'cashier@madar.iq',
        secret: 'secure_pass_4',
        businessId: bizId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
        requirePosAccess: true,
      );

      expect(result.isAllowed, isTrue);
      expect(result.user, isNotNull);
      expect(result.session, isNotNull);
      expect(identityCoordinator.isAuthenticated, isTrue);
      expect(identityCoordinator.currentUser?.userId, equals('usr_cashier_01'));
      expect(identityCoordinator.currentSession?.terminalId, equals(terminalId));
    });

    test('5. Wrong branch authorization => DENIED', () async {
      final result = await authService.loginAndOpenSession(
        loginIdentifier: 'otherbranch@madar.iq',
        secret: 'secure_pass_5',
        businessId: bizId,
        branchId: branchId, // Attempting BR-01 while assigned only to BR-02
        terminalId: terminalId,
        installationId: installId,
        requirePosAccess: true,
      );

      expect(result.isAllowed, isFalse);
      expect(result.denialReason, equals(AuthDenialReason.wrongBranch));
      expect(identityCoordinator.isAuthenticated, isFalse);
    });

    test('6. Wrong business binding => DENIED', () async {
      final result = await authService.loginAndOpenSession(
        loginIdentifier: 'wrongbiz@madar.iq',
        secret: 'secure_pass_6',
        businessId: bizId, // Attempting BIZ-01 while member of BIZ-OTHER
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
        requirePosAccess: true,
      );

      expect(result.isAllowed, isFalse);
      expect(result.denialReason, equals(AuthDenialReason.wrongBusiness));
      expect(identityCoordinator.isAuthenticated, isFalse);
    });

    test('7. Missing POS permission => DENIED from POS shell', () async {
      final result = await authService.loginAndOpenSession(
        loginIdentifier: 'clerk@madar.iq',
        secret: 'secure_pass_7',
        businessId: bizId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
        requirePosAccess: true,
      );

      expect(result.isAllowed, isFalse);
      expect(result.denialReason, equals(AuthDenialReason.noPosAccess));
      expect(identityCoordinator.isAuthenticated, isFalse);
    });

    test('8. Expired session => DENIED upon session validation', () async {
      // First login successfully
      final login = await authService.loginAndOpenSession(
        loginIdentifier: 'cashier@madar.iq',
        secret: 'secure_pass_4',
        businessId: bizId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
      );
      expect(login.isAllowed, isTrue);

      // Artificially simulate expired session in coordinator
      final expiredSession = identityCoordinator.currentSession!.copyWith(
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      identityCoordinator.setSession(
        user: identityCoordinator.currentUser!,
        session: expiredSession,
      );

      // Validate session
      final validation = await authService.validateCurrentSession(
        businessId: bizId,
        branchId: branchId,
      );

      expect(validation.isAllowed, isFalse);
      expect(validation.denialReason, equals(AuthDenialReason.sessionExpired));
    });

    test('9. Logout => session terminated and coordinator cleared', () async {
      await authService.loginAndOpenSession(
        loginIdentifier: 'cashier@madar.iq',
        secret: 'secure_pass_4',
        businessId: bizId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
      );
      expect(identityCoordinator.isAuthenticated, isTrue);

      await authService.logout();

      expect(identityCoordinator.isAuthenticated, isFalse);
      expect(identityCoordinator.currentUser, isNull);
      expect(identityCoordinator.currentSession, isNull);
    });

    test('10. Account switching => previous role and permissions cleared', () async {
      // 1. Manager with management privileges
      identityRepo.seedUser(
        user: ShopUser(
          userId: 'usr_mgr_01',
          businessId: bizId,
          fullName: 'Manager User',
          phone: '07700000088',
          email: 'manager@madar.iq',
          role: ShopRole.branchManager,
          isActive: true,
          assignedBranchIds: const [branchId],
          createdAt: DateTime.now(),
        ),
        loginIdentifier: 'manager@madar.iq',
        secret: 'secure_pass_mgr',
      );

      await authService.loginAndOpenSession(
        loginIdentifier: 'manager@madar.iq',
        secret: 'secure_pass_mgr',
        businessId: bizId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
      );

      expect(identityCoordinator.currentUser?.role, equals(ShopRole.branchManager));
      expect(identityCoordinator.isManagementLevel, isTrue);

      // 2. Switch account to Cashier (non-management)
      await authService.logout();
      expect(identityCoordinator.isAuthenticated, isFalse);
      expect(identityCoordinator.isManagementLevel, isFalse);

      await authService.loginAndOpenSession(
        loginIdentifier: 'cashier@madar.iq',
        secret: 'secure_pass_4',
        businessId: bizId,
        branchId: branchId,
        terminalId: terminalId,
        installationId: installId,
      );

      expect(identityCoordinator.currentUser?.role, equals(ShopRole.cashier));
      expect(identityCoordinator.isManagementLevel, isFalse);
      expect(identityCoordinator.hasPermission(ShopPermission.accessPos), isTrue);
    });

    test('11. Static Security Scan: No default hardcoded credentials in production code', () {
      final productionDir = Directory('lib/features/madar_shop');
      expect(productionDir.existsSync(), isTrue);

      final dartFiles = productionDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final prohibitedPatterns = [
        RegExp(r'123456'),
        RegExp("cashier.*123456"),
        RegExp("admin.*123456"),
        RegExp("manager.*123456"),
        RegExp(r'createWithDefaults'),
        RegExp(r'seedDefaultAccounts'),
      ];

      for (final file in dartFiles) {
        // Exclude customer demo phone numbers in dialog UI widgets
        if (file.path.contains('pos_customer_dialog.dart')) continue;

        final content = file.readAsStringSync();
        for (final pattern in prohibitedPatterns) {
          final matches = pattern.allMatches(content);
          expect(
            matches.isEmpty,
            isTrue,
            reason: 'File ${file.path} contains forbidden hardcoded pattern ${pattern.pattern}',
          );
        }
      }
    });
  });
}
