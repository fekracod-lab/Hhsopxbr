import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/security/security.dart';
import 'package:dalal_alqaim/core/resilience/services/financial_integrity_engine.dart';
import 'helpers/security_test_helper.dart';

void main() {
  group('Adversarial Security Attack Simulations (ATTACK-001 to ATTACK-010)', () {
    late ProductionSecurityEngine facade;
    late InMemorySecurityRepository repository;
    late FinancialIntegrityEngine financialEngine;

    setUp(() {
      repository = InMemorySecurityRepository();
      facade = ProductionSecurityEngine(repository: repository);
      financialEngine = FinancialIntegrityEngine();
    });

    test('ATTACK-001: Customer attempts to self-modify role to ADMIN -> BLOCKED & Logged', () {
      expect(
        () => facade.assertLegalRoleMutation(
          actorRole: MadarRole.customer,
          actorUserId: 'customer_attacker',
          currentTargetRole: MadarRole.customer,
          requestedNewRole: MadarRole.admin,
          targetUserId: 'customer_attacker',
        ),
        throwsA(isA<SecurityViolationException>()),
      );
      expect(facade.eventEngine.events.any((e) => e.eventType == SecurityEventType.privilegeEscalationAttempt), isTrue);
    });

    test('ATTACK-002: Driver attempts to read another driver private documents -> BLOCKED', () {
      const driverContext = AuthorizationContext(
        subjectUserId: 'driver_a',
        role: MadarRole.driver,
        action: 'drivers.read',
        resourceType: 'drivers',
        resourceId: 'driver_b',
        resourceOwnerId: 'driver_b',
      );

      expect(
        () => facade.authorizeRequest(driverContext),
        throwsA(isA<SecurityViolationException>()),
      );
      expect(facade.eventEngine.events.any((e) => e.eventType == SecurityEventType.permissionDenied), isTrue);
    });

    test('ATTACK-003: Non-authorized entity attempts merchant price modification -> BLOCKED', () {
      const customerContext = AuthorizationContext(
        subjectUserId: 'customer_1',
        role: MadarRole.customer,
        action: 'merchant.manage',
        resourceType: 'merchant',
        resourceId: 'store_99',
      );

      expect(
        () => facade.authorizeRequest(customerContext),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('ATTACK-004: Customer attempts direct wallet balance overdraft -> BLOCKED', () async {
      financialEngine.setInitialBalance('wallet_victim', 10000);

      final (_, success, error) = await financialEngine.atomicWalletDebit(
        walletId: 'wallet_victim',
        amountMinor: 50000,
        transactionId: 'tx_attack_4',
        idempotencyKey: 'key_attack_4',
      );

      expect(success, isFalse);
      expect(error, contains('Insufficient wallet balance'));
    });

    test('ATTACK-005: User submits mismatched UID in request payload (UID Spoofing) -> BLOCKED', () {
      expect(
        () => facade.assertIdentityIntegrity(
          authenticatedUid: 'usr_real_alice',
          requestPayloadUid: 'usr_spoofed_bob',
          actorRole: MadarRole.customer,
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('ATTACK-007: Rapid OTP Brute-Force sequence -> RATE LIMITED & LOCKED OUT', () {
      final now = DateTime(2026, 8, 29, 12, 0, 0);
      const rateKey = 'otp_target_user';

      // 3 attempts succeed within rate limit
      for (var i = 0; i < 3; i++) {
        facade.assertRateLimit(rateKey: rateKey, maxAllowed: 3, window: const Duration(minutes: 5), now: now);
      }

      // 4th attempt -> Throws SecurityViolationException & Logs Event
      expect(
        () => facade.assertRateLimit(rateKey: rateKey, maxAllowed: 3, window: const Duration(minutes: 5), now: now),
        throwsA(isA<SecurityViolationException>()),
      );
      expect(facade.eventEngine.events.any((e) => e.eventType == SecurityEventType.rateLimitExceeded), isTrue);
    });

    test('ATTACK-008: Plaintext passwords or secrets appearing in logs -> AUTOMATICALLY REDACTED', () {
      final payload = {
        'jwt': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.secret',
        'password': 'RawPassword!',
        'userPhone': '07801234567',
      };

      final sanitized = facade.privacyEngine.sanitizeMap(payload);
      expect(sanitized['password'], equals('[REDACTED_HIGHLY_SENSITIVE]'));
      expect(sanitized['userPhone'], equals('078****4567'));
    });

    test('ATTACK-010: Unauthorized user attempts administrative management -> DENIED & AUDITED', () {
      const ctx = AuthorizationContext(
        subjectUserId: 'random_user',
        role: MadarRole.customer,
        action: 'security.manage',
        resourceType: 'system_security',
      );

      expect(
        () => facade.authorizeRequest(ctx),
        throwsA(isA<SecurityViolationException>()),
      );
      expect(facade.eventEngine.events.length, greaterThanOrEqualTo(1));
    });
  });
}
