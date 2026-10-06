import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/security/security.dart';
import 'package:dalal_alqaim/core/resilience/services/financial_integrity_engine.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/domain_event.dart';
import 'package:dalal_alqaim/core/orchestration/domain/services/domain_event_bus.dart';
import 'helpers/security_test_helper.dart';

void main() {
  group('Phase 8.12 Production Security Reality Check & Trust Boundary Suite', () {
    late ProductionSecurityEngine facade;
    late InMemorySecurityRepository repository;
    late FinancialIntegrityEngine financialEngine;

    setUp(() {
      repository = InMemorySecurityRepository();
      facade = ProductionSecurityEngine(repository: repository);
      financialEngine = FinancialIntegrityEngine();
    });

    test('1. TRUST BOUNDARY: Server and Kernel deny unauthenticated & expired requests before reaching business logic', () {
      // Unauthenticated context
      const unauthContext = AuthorizationContext(
        subjectUserId: '',
        role: MadarRole.customer,
        action: 'orders.create',
        resourceType: 'orders',
        sessionState: SecuritySessionState.expired,
      );

      expect(
        () => facade.authorizeRequest(unauthContext),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('2. CROSS-TENANT ISOLATION: Customer A cannot access Customer B orders/rides', () {
      const crossContext = AuthorizationContext(
        subjectUserId: 'customer_alice',
        role: MadarRole.customer,
        action: 'orders.read',
        resourceType: 'orders',
        resourceId: 'ord_bob_99',
        resourceOwnerId: 'customer_bob',
      );

      expect(
        () => facade.authorizeRequest(crossContext),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('3. FINANCIAL ATOMICITY & RACE CONDITION: Concurrent debit and refund preserve Zero Negative Balance', () async {
      financialEngine.setInitialBalance('wallet_omar', 50000);

      // Concurrent debits totaling 80,000 against 50,000 balance
      final futureA = financialEngine.atomicWalletDebit(
        walletId: 'wallet_omar',
        amountMinor: 40000,
        transactionId: 'tx_conc_a',
        idempotencyKey: 'idemp_conc_a',
      );

      final futureB = financialEngine.atomicWalletDebit(
        walletId: 'wallet_omar',
        amountMinor: 40000,
        transactionId: 'tx_conc_b',
        idempotencyKey: 'idemp_conc_b',
      );

      final results = await Future.wait([futureA, futureB]);
      final successCount = results.where((r) => r.$2 == true).length;
      final failCount = results.where((r) => r.$2 == false).length;

      expect(successCount, equals(1));
      expect(failCount, equals(1));
      expect(financialEngine.getBalance('wallet_omar'), equals(10000)); // Exactly 50,000 - 40,000
    });

    test('4. PII & SECRET LEAKAGE PREVENTION: Recursively scrubs tokens and phones in event payloads', () async {
      final dirtyPayload = {
        'jwtToken': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.secret',
        'customerPhone': '07801234567',
        'customerEmail': 'test@madar.iq',
        'password': 'RawPassword123!',
        'amount': 25000,
      };

      final sanitized = facade.privacyEngine.sanitizeMap(dirtyPayload);

      expect(sanitized['jwtToken'], equals('[REDACTED_HIGHLY_SENSITIVE]'));
      expect(sanitized['password'], equals('[REDACTED_HIGHLY_SENSITIVE]'));
      expect(sanitized['customerPhone'], equals('078****4567'));
      expect(sanitized['customerEmail'], equals('t***t@madar.iq'));
      expect(sanitized['amount'], equals(25000));
    });

    test('5. AUDIT IMMUTABILITY & DOMAIN EVENT BUS: Critical security violations propagate domain events', () async {
      DomainEvent? capturedEvent;
      final bus = DomainEventBus();
      final customFacade = ProductionSecurityEngine(repository: repository, eventBus: bus);

      bus.subscribe('security.privilege_escalation_attempt', (event) {
        capturedEvent = event;
      });

      await customFacade.logSecurityViolation(
        eventType: SecurityEventType.privilegeEscalationAttempt,
        severity: ThreatSeverity.critical,
        actorUserId: 'attacker_101',
        description: 'Attempted to force role promotion to superAdmin',
      );

      await Future.delayed(const Duration(milliseconds: 10));
      expect(capturedEvent, isNotNull);
      expect(capturedEvent!.payload['actorUserId'], equals('attacker_101'));
      expect(capturedEvent!.payload['severity'], equals('critical'));
    });

    test('6. FULL PRODUCTION SECURITY GATE (14 CATEGORIES): Evaluates and certifies production security readiness', () async {
      final scores = {for (var c in SecurityGateCategory.values) c: 100.0};
      final blockers = {for (var c in SecurityGateCategory.values) c: <String>[]};

      final result = await facade.runSecurityReadinessAudit(
        categoryScores: scores,
        categoryBlockers: blockers,
      );

      expect(result.gateStatus, equals(SecurityGateStatus.securityReady));
      expect(result.isProductionSecurityReady, isTrue);
      expect(result.overallSecurityScore, equals(100.0));
      expect(result.categoryScores.length, equals(14));
    });
  });
}
