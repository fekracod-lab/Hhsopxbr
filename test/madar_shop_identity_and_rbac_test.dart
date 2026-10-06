// اختبارات الهوية والصلاحيات وعقود نبضات القلب لمنظومة MADAR SHOP
// Unit & Domain Tests — Zero Mocks

import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/madar_shop/madar_shop.dart';

void main() {
  group('MADAR SHOP Phase S1 — Identity & RBAC & Heartbeat Lease Tests', () {
    test('1. Owner role has all permissions without restriction', () {
      final hasAll = ShopPermissionMatrix.hasAllPermissions(
        role: ShopRole.owner,
        permissions: ShopPermission.values,
      );
      expect(hasAll, isTrue);
    });

    test('2. Cashier has sales permissions but cannot edit cost price or delete products', () {
      expect(
        ShopPermissionMatrix.hasPermission(
          role: ShopRole.cashier,
          permission: ShopPermission.createSalesOrder,
        ),
        isTrue,
      );
      expect(
        ShopPermissionMatrix.hasPermission(
          role: ShopRole.cashier,
          permission: ShopPermission.accessPos,
        ),
        isTrue,
      );
      expect(
        ShopPermissionMatrix.hasPermission(
          role: ShopRole.cashier,
          permission: ShopPermission.editCostPrice,
        ),
        isFalse,
      );
      expect(
        ShopPermissionMatrix.hasPermission(
          role: ShopRole.cashier,
          permission: ShopPermission.deleteProduct,
        ),
        isFalse,
      );
      expect(
        ShopPermissionMatrix.hasPermission(
          role: ShopRole.cashier,
          permission: ShopPermission.viewFinancialLedger,
        ),
        isFalse,
      );
    });

    test('3. Inventory clerk can adjust stock but cannot access POS checkout', () {
      expect(
        ShopPermissionMatrix.hasPermission(
          role: ShopRole.inventoryClerk,
          permission: ShopPermission.adjustInventoryStock,
        ),
        isTrue,
      );
      expect(
        ShopPermissionMatrix.hasPermission(
          role: ShopRole.inventoryClerk,
          permission: ShopPermission.accessPos,
        ),
        isFalse,
      );
    });

    test('4. ShopUser branch access rules work correctly', () {
      final cashier = ShopUser(
        userId: 'U-001',
        businessId: 'BIZ-01',
        fullName: 'أحمد الكاشير',
        phone: '07700000000',
        email: 'ahmed@madar.iq',
        role: ShopRole.cashier,
        assignedBranchIds: const ['BRANCH-QAIM-01'],
        createdAt: DateTime.now(),
      );

      expect(cashier.canAccessBranch('BRANCH-QAIM-01'), isTrue);
      expect(cashier.canAccessBranch('BRANCH-BAGHDAD-02'), isFalse);

      final owner = ShopUser(
        userId: 'U-002',
        businessId: 'BIZ-01',
        fullName: 'المالك العام',
        phone: '07700000001',
        email: 'owner@madar.iq',
        role: ShopRole.owner,
        assignedBranchIds: const [], // Owner has access to all branches
        createdAt: DateTime.now(),
      );

      expect(owner.canAccessBranch('BRANCH-QAIM-01'), isTrue);
      expect(owner.canAccessBranch('BRANCH-BAGHDAD-02'), isTrue);
    });

    test('5. ShopAvailabilityState orthogonal availability and operational load calculations', () {
      final normalState = ShopAvailabilityState(
        branchId: 'BR-01',
        availability: ShopAvailability.open,
        operationalLoad: ShopOperationalLoad.normal,
        basePrepTimeMinutes: 20,
        busyLoadBufferMinutes: 15,
        highLoadBufferMinutes: 30,
        updatedAt: DateTime.now(),
        updatedByUserId: 'U-001',
      );

      expect(normalState.isReadyToReceiveOrders, isTrue);
      expect(normalState.effectivePrepTimeMinutes, 20);

      // Busy load test (+15 min)
      final busyState = normalState.copyWith(
        operationalLoad: ShopOperationalLoad.busy,
      );
      expect(busyState.isReadyToReceiveOrders, isTrue);
      expect(busyState.effectivePrepTimeMinutes, 35); // 20 + 15

      // High peak load test (+30 min)
      final highState = normalState.copyWith(
        operationalLoad: ShopOperationalLoad.high,
      );
      expect(highState.effectivePrepTimeMinutes, 50); // 20 + 30

      // AutoClosed or Closed test
      final autoClosedState = normalState.copyWith(
        availability: ShopAvailability.autoClosed,
      );
      expect(autoClosedState.isReadyToReceiveOrders, isFalse);
    });

    test('6. Session Heartbeat Lease and Stale Detection', () {
      final startTime = DateTime.now();
      final session = ShopSession(
        sessionId: 'SESS-101',
        installationId: 'INSTALL-WIN-X86-99',
        terminalId: 'POS-WIN-01',
        userId: 'U-001',
        businessId: 'BIZ-01',
        activeBranchId: 'BR-01',
        startedAt: startTime,
        lastHeartbeatAt: startTime,
        expiresAt: startTime.add(const Duration(minutes: 5)),
      );

      expect(session.isExpired, isFalse);
      expect(session.isHeartbeatOverdue(tolerance: const Duration(seconds: 90), now: startTime.add(const Duration(seconds: 30))), isFalse);
      expect(session.isHeartbeatOverdue(tolerance: const Duration(seconds: 90), now: startTime.add(const Duration(seconds: 120))), isTrue);

      // Record new heartbeat
      final updatedSession = session.recordHeartbeat(
        heartbeatTime: startTime.add(const Duration(minutes: 1)),
        leaseExtension: const Duration(minutes: 5),
      );
      expect(updatedSession.lastHeartbeatAt, startTime.add(const Duration(minutes: 1)));
      expect(updatedSession.expiresAt, startTime.add(const Duration(minutes: 6)));
    });

    test('7. ShopIdentityCoordinator session management and authorization', () {
      final coordinator = ShopIdentityCoordinator();
      expect(coordinator.isAuthenticated, isFalse);

      final user = ShopUser(
        userId: 'U-001',
        businessId: 'BIZ-01',
        fullName: 'مدير المتجر',
        phone: '07700000000',
        email: 'manager@madar.iq',
        role: ShopRole.branchManager,
        assignedBranchIds: const ['BR-01'],
        createdAt: DateTime.now(),
      );

      final session = ShopSession(
        sessionId: 'SESS-101',
        installationId: 'INST-01',
        terminalId: 'POS-WIN-01',
        userId: 'U-001',
        businessId: 'BIZ-01',
        activeBranchId: 'BR-01',
        startedAt: DateTime.now(),
        lastHeartbeatAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      coordinator.setSession(user: user, session: session);
      expect(coordinator.isAuthenticated, isTrue);
      expect(coordinator.isManagementLevel, isTrue);
      expect(coordinator.canOperateOnActiveBranch('BR-01'), isTrue);
      expect(coordinator.hasPermission(ShopPermission.accessPos), isTrue);

      coordinator.clearSession();
      expect(coordinator.isAuthenticated, isFalse);
    });
  });
}
