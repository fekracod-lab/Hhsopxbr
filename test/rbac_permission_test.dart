import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/security/security.dart';

void main() {
  group('RBAC & Granular Capability Matrix Dedicated Tests', () {
    late RbacPermissionEngine engine;

    setUp(() {
      engine = RbacPermissionEngine();
    });

    test('1. Validates Customer capability boundaries', () {
      expect(engine.hasPermission(MadarRole.customer, 'orders.create'), isTrue);
      expect(engine.hasPermission(MadarRole.customer, 'orders.read'), isTrue);
      expect(engine.hasPermission(MadarRole.customer, 'wallet.read'), isTrue);
      // Strictly disallowed:
      expect(engine.hasPermission(MadarRole.customer, 'drivers.assign'), isFalse);
      expect(engine.hasPermission(MadarRole.customer, 'admin.manage'), isFalse);
      expect(engine.hasPermission(MadarRole.customer, 'security.manage'), isFalse);
    });

    test('2. Validates Driver capability boundaries', () {
      expect(engine.hasPermission(MadarRole.driver, 'orders.read'), isTrue);
      expect(engine.hasPermission(MadarRole.driver, 'orders.update'), isTrue);
      expect(engine.hasPermission(MadarRole.driver, 'wallet.read'), isTrue);
      // Disallowed:
      expect(engine.hasPermission(MadarRole.driver, 'users.delete'), isFalse);
      expect(engine.hasPermission(MadarRole.driver, 'refund.approve'), isFalse);
    });

    test('3. Validates Role Hierarchy & Management Eligibility', () {
      // SuperAdmin can manage MainAdmin, Admin, Driver, Customer
      expect(engine.canActorManageTargetRole(actorRole: MadarRole.superAdmin, targetRole: MadarRole.admin), isTrue);
      expect(engine.canActorManageTargetRole(actorRole: MadarRole.superAdmin, targetRole: MadarRole.customer), isTrue);

      // Admin can manage Driver & Customer, but CANNOT manage SuperAdmin or MainAdmin
      expect(engine.canActorManageTargetRole(actorRole: MadarRole.admin, targetRole: MadarRole.driver), isTrue);
      expect(engine.canActorManageTargetRole(actorRole: MadarRole.admin, targetRole: MadarRole.superAdmin), isFalse);

      // Customer CANNOT manage Driver or Admin
      expect(engine.canActorManageTargetRole(actorRole: MadarRole.customer, targetRole: MadarRole.driver), isFalse);
    });
  });
}
