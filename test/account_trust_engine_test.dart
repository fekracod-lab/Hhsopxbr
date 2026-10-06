import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/risk/domain/services/account_trust_engine.dart';

void main() {
  group('Account Trust Engine Dedicated Tests', () {
    test('1. New account with 0 history gets zero discount', () {
      final now = DateTime.now();
      final discount = AccountTrustEngine.computeTrustDiscount(
        accountCreatedAt: now,
        completedOrdersCount: 0,
        successfulPaymentsCount: 0,
        now: now,
      );
      expect(discount, equals(0));
    });

    test('2. Mature account (> 90 days) with 20+ completed orders gets max discount', () {
      final now = DateTime(2026, 8, 28, 12, 0, 0);
      final created = now.subtract(const Duration(days: 100));

      final discount = AccountTrustEngine.computeTrustDiscount(
        accountCreatedAt: created,
        completedOrdersCount: 25,
        successfulPaymentsCount: 25,
        now: now,
      );

      expect(discount, equals(20)); // 10 age + 10 history
    });
  });
}
