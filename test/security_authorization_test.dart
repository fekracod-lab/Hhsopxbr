import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/security/security.dart';

void main() {
  group('Zero-Trust Authorization Engine Dedicated Tests', () {
    late ZeroTrustAuthorizationEngine engine;

    setUp(() {
      engine = ZeroTrustAuthorizationEngine();
    });

    test('1. Authorizes valid owner accessing personal order resource', () {
      const context = AuthorizationContext(
        subjectUserId: 'user_omar',
        role: MadarRole.customer,
        action: 'orders.read',
        resourceType: 'orders',
        resourceId: 'ord_123',
        resourceOwnerId: 'user_omar',
        sessionState: SecuritySessionState.active,
      );

      final isAllowed = engine.authorize(context);
      expect(isAllowed, isTrue);
    });

    test('2. Denies non-owner customer attempting to access another user order (Zero-Trust Deny-by-Default)', () {
      const context = AuthorizationContext(
        subjectUserId: 'user_attacker',
        role: MadarRole.customer,
        action: 'orders.read',
        resourceType: 'orders',
        resourceId: 'ord_123',
        resourceOwnerId: 'user_victim',
        sessionState: SecuritySessionState.active,
      );

      expect(
        () => engine.authorize(context),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('3. Allows SuperAdmin and MainAdmin universal access regardless of ownership', () {
      const superAdminCtx = AuthorizationContext(
        subjectUserId: 'super_admin_1',
        role: MadarRole.superAdmin,
        action: 'users.delete',
        resourceType: 'users',
        resourceId: 'user_any',
        resourceOwnerId: 'user_victim',
      );

      expect(engine.authorize(superAdminCtx), isTrue);
    });

    test('4. Rejects request with expired or revoked session state', () {
      const revokedContext = AuthorizationContext(
        subjectUserId: 'user_omar',
        role: MadarRole.customer,
        action: 'orders.read',
        resourceType: 'orders',
        resourceOwnerId: 'user_omar',
        sessionState: SecuritySessionState.revoked,
      );

      expect(
        () => engine.authorize(revokedContext),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('5. Rejects request when current risk score is elevated (Risk Score >= 80)', () {
      const highRiskContext = AuthorizationContext(
        subjectUserId: 'user_omar',
        role: MadarRole.customer,
        action: 'orders.read',
        resourceType: 'orders',
        resourceOwnerId: 'user_omar',
        currentRiskScore: 92.5,
      );

      expect(
        () => engine.authorize(highRiskContext),
        throwsA(isA<SecurityViolationException>()),
      );
    });
  });
}
