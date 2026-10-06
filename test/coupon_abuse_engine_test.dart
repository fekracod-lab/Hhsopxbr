import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/risk/domain/enums/risk_enums.dart';
import 'package:dalal_alqaim/core/risk/domain/services/coupon_abuse_engine.dart';

void main() {
  group('Coupon Abuse Engine Dedicated Tests', () {
    test('1. Normal single coupon redemption passes cleanly', () {
      final engine = CouponAbuseEngine();
      final sig = engine.evaluateCouponRedemption(
        subjectId: 'user_1',
        couponCode: 'MADAR50',
        deviceId: 'dev_1',
      );
      expect(sig, isNull);
    });

    test('2. Multi-account coupon exploitation on the same device triggers couponAbuse signal', () {
      final engine = CouponAbuseEngine();

      // Account 1 redeems
      engine.evaluateCouponRedemption(
        subjectId: 'user_1',
        couponCode: 'WELCOME2026',
        deviceId: 'shared_device',
      );

      // Account 2 on same device attempts same welcome coupon
      final sig = engine.evaluateCouponRedemption(
        subjectId: 'user_2',
        couponCode: 'WELCOME2026',
        deviceId: 'shared_device',
      );

      expect(sig, isNotNull);
      expect(sig!.type, equals(RiskSignalType.couponAbuse));
      expect(sig.weight, equals(30));
    });

    test('3. Excessive coupon redemption in 24 hours triggers rapid coupon abuse signal', () {
      final engine = CouponAbuseEngine();
      final now = DateTime.now();

      for (int i = 1; i <= 3; i++) {
        engine.evaluateCouponRedemption(
          subjectId: 'user_heavy',
          couponCode: 'PROMO_$i',
          deviceId: 'dev_$i',
          now: now,
        );
      }

      // 4th coupon in 24h
      final sig = engine.evaluateCouponRedemption(
        subjectId: 'user_heavy',
        couponCode: 'PROMO_4',
        deviceId: 'dev_4',
        now: now,
      );

      expect(sig, isNotNull);
      expect(sig!.type, equals(RiskSignalType.couponAbuse));
      expect(sig.weight, equals(20));
    });
  });
}
