import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/risk/domain/enums/risk_enums.dart';
import 'package:dalal_alqaim/core/risk/domain/services/wallet_abuse_engine.dart';

void main() {
  group('Wallet Abuse Engine Dedicated Tests', () {
    test('1. Repeated failed payment attempts trigger repeatedFailedPayments signal', () {
      final engine = WalletAbuseEngine();
      final now = DateTime.now();

      for (int i = 0; i < 4; i++) {
        final sig = engine.recordFailedPayment(
          subjectId: 'user_wallet_1',
          threshold: 5,
          now: now.add(Duration(minutes: i)),
        );
        expect(sig, isNull);
      }

      // 5th failed payment
      final sig5 = engine.recordFailedPayment(
        subjectId: 'user_wallet_1',
        threshold: 5,
        now: now.add(const Duration(minutes: 5)),
      );

      expect(sig5, isNotNull);
      expect(sig5!.type, equals(RiskSignalType.repeatedFailedPayments));
      expect(sig5.weight, equals(30));
    });

    test('2. Rapid wallet debit/refund mutation cycles trigger walletRapidMutation signal', () {
      final engine = WalletAbuseEngine();
      final now = DateTime.now();

      for (int i = 0; i < 10; i++) {
        final sig = engine.recordWalletMutation(
          subjectId: 'user_rapid_wallet',
          threshold: 10,
          now: now.add(Duration(minutes: i * 2)),
        );
        expect(sig, isNull);
      }

      // 11th mutation in 1h
      final sig11 = engine.recordWalletMutation(
        subjectId: 'user_rapid_wallet',
        threshold: 10,
        now: now.add(const Duration(minutes: 25)),
      );

      expect(sig11, isNotNull);
      expect(sig11!.type, equals(RiskSignalType.walletRapidMutation));
      expect(sig11.weight, equals(20));
    });
  });
}
