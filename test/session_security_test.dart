import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/security/security.dart';

void main() {
  group('Session Security & Step-Up Re-Authentication Dedicated Tests', () {
    late SessionSecurityEngine engine;

    setUp(() {
      engine = SessionSecurityEngine(
        sessionTtl: const Duration(hours: 24),
        sensitiveOperationMaxAge: const Duration(minutes: 10),
      );
    });

    test('1. Validates active registered sessions', () {
      final now = DateTime(2026, 8, 29, 12, 0, 0);
      engine.registerSession('sess_100', now: now);

      expect(engine.validateSession('sess_100', now: now.add(const Duration(hours: 1))), equals(SecuritySessionState.active));
    });

    test('2. Marks session expired when exceeding TTL', () {
      final now = DateTime(2026, 8, 29, 12, 0, 0);
      engine.registerSession('sess_100', now: now);

      expect(engine.validateSession('sess_100', now: now.add(const Duration(hours: 25))), equals(SecuritySessionState.expired));
    });

    test('3. Revokes sessions immediately on forced logout', () {
      final now = DateTime(2026, 8, 29, 12, 0, 0);
      engine.registerSession('sess_100', now: now);
      engine.revokeSession('sess_100');

      expect(engine.validateSession('sess_100', now: now), equals(SecuritySessionState.revoked));
    });

    test('4. Enforces step-up re-authentication for sensitive actions when age exceeds 10 minutes', () {
      final now = DateTime(2026, 8, 29, 12, 0, 0);
      engine.registerSession('sess_100', now: now);

      // Sensitive action within 5 min of re-auth -> No re-auth required
      expect(
        engine.requiresReAuthentication(
          sessionId: 'sess_100',
          isSensitiveOperation: true,
          lastReAuthTime: now,
          now: now.add(const Duration(minutes: 5)),
        ),
        isFalse,
      );

      // Sensitive action 15 min after re-auth -> Re-auth required!
      expect(
        engine.requiresReAuthentication(
          sessionId: 'sess_100',
          isSensitiveOperation: true,
          lastReAuthTime: now,
          now: now.add(const Duration(minutes: 15)),
        ),
        isTrue,
      );
    });
  });
}
