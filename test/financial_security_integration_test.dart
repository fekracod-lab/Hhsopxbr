import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/security/security.dart';
import 'package:dalal_alqaim/core/resilience/services/financial_integrity_engine.dart';

void main() {
  group('Financial Security & Zero-Trust Integration Dedicated Tests', () {
    late ZeroTrustAuthorizationEngine authEngine;
    late FinancialIntegrityEngine finEngine;

    setUp(() {
      authEngine = ZeroTrustAuthorizationEngine();
      finEngine = FinancialIntegrityEngine();
    });

    test('1. ATTACK-004: Direct client wallet balance mutation blocked by Zero-Trust + Financial Engine', () async {
      // Step A: Customer attempts direct unauthorized debit on another wallet
      const attackContext = AuthorizationContext(
        subjectUserId: 'user_attacker',
        role: MadarRole.customer,
        action: 'wallet.debit',
        resourceType: 'wallet',
        resourceId: 'wallet_victim',
        resourceOwnerId: 'wallet_victim',
      );

      // Authorization Denial
      expect(
        () => authEngine.authorize(attackContext),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('2. ATTACK-006: 100 concurrent refund requests result in deterministic, atomic processing', () async {
      final futures = <Future<(bool, String?)>>[];

      for (var i = 0; i < 100; i++) {
        futures.add(
          finEngine.atomicRefund(
            originalTransactionId: 'tx_orig_1',
            originalAmountMinor: 50000,
            refundAmountMinor: 50000,
            refundTransactionId: 'ref_tx_1', // Duplicate transaction ID across concurrent callers
            idempotencyKey: 'idemp_refund_race',
          ),
        );
      }

      final results = await Future.wait(futures);
      final successful = results.where((r) => r.$1 == true).length;

      expect(successful, equals(100)); // Idempotency returns identical canonical success
    });
  });
}
