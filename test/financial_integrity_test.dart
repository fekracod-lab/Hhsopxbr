import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/services/financial_integrity_engine.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

void main() {
  group('Financial Integrity & Concurrency Safety Dedicated Tests', () {
    test('1. Enforces Zero-Negative Balance: blocks debit if balance is insufficient', () async {
      final engine = FinancialIntegrityEngine();
      engine.setInitialBalance('wallet_omar', 10000);

      // Debit 7000 -> OK (Balance = 3000)
      final (bal1, ok1, err1) = await engine.atomicWalletDebit(
        walletId: 'wallet_omar',
        amountMinor: 7000,
        transactionId: 'tx_1',
        idempotencyKey: 'idemp_1',
      );

      expect(ok1, isTrue);
      expect(bal1, equals(3000));
      expect(err1, isNull);

      // Attempt another debit of 7000 -> Blocked! Balance cannot become -4000
      final (bal2, ok2, err2) = await engine.atomicWalletDebit(
        walletId: 'wallet_omar',
        amountMinor: 7000,
        transactionId: 'tx_2',
        idempotencyKey: 'idemp_2',
      );

      expect(ok2, isFalse);
      expect(bal2, equals(3000)); // Unchanged!
      expect(err2, contains('Insufficient wallet balance'));
    });

    test('2. Prevents double debits via duplicate transaction IDs and idempotency', () async {
      final engine = FinancialIntegrityEngine();
      engine.setInitialBalance('wallet_123', 50000);

      // First debit
      final (bal1, ok1, _) = await engine.atomicWalletDebit(
        walletId: 'wallet_123',
        amountMinor: 10000,
        transactionId: 'tx_fixed_id',
        idempotencyKey: 'key_fixed_1',
      );

      expect(ok1, isTrue);
      expect(bal1, equals(40000));

      // Same transactionId with different idempotency key -> Replay attack blocked!
      await expectLater(
        engine.atomicWalletDebit(
          walletId: 'wallet_123',
          amountMinor: 10000,
          transactionId: 'tx_fixed_id',
          idempotencyKey: 'key_fixed_2',
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('3. Prevents excess refund amounts exceeding original transaction value', () async {
      final engine = FinancialIntegrityEngine();

      // Refund 6,000 out of 10,000 -> OK
      final (ok1, _) = await engine.atomicRefund(
        originalTransactionId: 'tx_orig_1',
        originalAmountMinor: 10000,
        refundAmountMinor: 6000,
        refundTransactionId: 'ref_1',
        idempotencyKey: 'idemp_ref_1',
      );
      expect(ok1, isTrue);

      // Attempt to refund another 5,000 (total 11,000 > 10,000) -> Blocked!
      final (ok2, err2) = await engine.atomicRefund(
        originalTransactionId: 'tx_orig_1',
        originalAmountMinor: 10000,
        refundAmountMinor: 5000,
        refundTransactionId: 'ref_2',
        idempotencyKey: 'idemp_ref_2',
      );
      expect(ok2, isFalse);
      expect(err2, contains('exceed original transaction'));
    });

    test('4. Enforces global coupon usage limits strictly', () async {
      final engine = FinancialIntegrityEngine();

      // Coupon limited to 2 uses
      final (ok1, _) = await engine.atomicCouponRedeem(
        couponCode: 'MADAR50',
        userId: 'u1',
        maxGlobalUses: 2,
        idempotencyKey: 'idemp_cp_1',
      );
      expect(ok1, isTrue);

      final (ok2, _) = await engine.atomicCouponRedeem(
        couponCode: 'MADAR50',
        userId: 'u2',
        maxGlobalUses: 2,
        idempotencyKey: 'idemp_cp_2',
      );
      expect(ok2, isTrue);

      // 3rd use -> Blocked!
      final (ok3, err3) = await engine.atomicCouponRedeem(
        couponCode: 'MADAR50',
        userId: 'u3',
        maxGlobalUses: 2,
        idempotencyKey: 'idemp_cp_3',
      );
      expect(ok3, isFalse);
      expect(err3, contains('limit (2) reached'));
    });
  });
}
