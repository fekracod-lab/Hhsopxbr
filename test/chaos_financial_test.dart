import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/services/financial_integrity_engine.dart';

void main() {
  group('Chaos Scenario 014 & 016: Financial Race & Double-Spend Attacks', () {
    test('CHAOS-014: 100 concurrent debits on 10,000 balance of 7,000 each result in exactly 1 debit and final balance 3,000', () async {
      final engine = FinancialIntegrityEngine();
      engine.setInitialBalance('wallet_victim', 10000);

      final futures = List.generate(100, (i) {
        return engine.atomicWalletDebit(
          walletId: 'wallet_victim',
          amountMinor: 7000,
          transactionId: 'tx_attack_$i',
          idempotencyKey: 'idemp_attack_$i',
        );
      });

      final results = await Future.wait(futures);

      final successes = results.where((r) => r.$2 == true).toList();
      final failures = results.where((r) => r.$2 == false).toList();

      expect(successes.length, equals(1)); // Exactly 1 debit succeeded!
      expect(failures.length, equals(99));  // 99 debits were safely blocked!
      expect(engine.getBalance('wallet_victim'), equals(3000)); // Zero negative balance!
    });

    test('CHAOS-016: 50 concurrent redemptions on single-use coupon yield exactly 1 successful redemption', () async {
      final engine = FinancialIntegrityEngine();

      final futures = List.generate(50, (i) {
        return engine.atomicCouponRedeem(
          couponCode: 'FLASH100',
          userId: 'user_$i',
          maxGlobalUses: 1, // Single-use globally
          idempotencyKey: 'idemp_coupon_attack_$i',
        );
      });

      final results = await Future.wait(futures);

      final successes = results.where((r) => r.$1 == true).toList();
      final failures = results.where((r) => r.$1 == false).toList();

      expect(successes.length, equals(1));
      expect(failures.length, equals(49));
    });
  });
}
