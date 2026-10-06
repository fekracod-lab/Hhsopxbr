import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/security/security.dart';

void main() {
  group('Rate Limiting & Abuse Protection Dedicated Tests', () {
    late RateLimitAbuseEngine engine;

    setUp(() {
      engine = RateLimitAbuseEngine();
    });

    test('1. ATTACK-007: Allows requests within window threshold, then blocks on excess', () {
      final now = DateTime(2026, 8, 29, 12, 0, 0);

      // Max 3 OTP attempts per 5 minutes
      expect(engine.checkRateLimit(rateKey: 'otp_07801234567', maxAllowed: 3, window: const Duration(minutes: 5), now: now), isTrue);
      expect(engine.checkRateLimit(rateKey: 'otp_07801234567', maxAllowed: 3, window: const Duration(minutes: 5), now: now.add(const Duration(seconds: 10))), isTrue);
      expect(engine.checkRateLimit(rateKey: 'otp_07801234567', maxAllowed: 3, window: const Duration(minutes: 5), now: now.add(const Duration(seconds: 20))), isTrue);

      // 4th attempt -> Strictly BLOCKED!
      expect(engine.checkRateLimit(rateKey: 'otp_07801234567', maxAllowed: 3, window: const Duration(minutes: 5), now: now.add(const Duration(seconds: 30))), isFalse);
    });

    test('2. Enforces temporary lockout duration after rate limit breach', () {
      final now = DateTime(2026, 8, 29, 12, 0, 0);

      // Exceed threshold
      for (var i = 0; i < 3; i++) {
        engine.checkRateLimit(rateKey: 'login_attacker', maxAllowed: 3, window: const Duration(minutes: 5), lockoutDuration: const Duration(minutes: 15), now: now);
      }
      engine.checkRateLimit(rateKey: 'login_attacker', maxAllowed: 3, window: const Duration(minutes: 5), lockoutDuration: const Duration(minutes: 15), now: now);

      expect(engine.isLockedOut('login_attacker', now: now.add(const Duration(minutes: 5))), isTrue);

      // After 16 minutes (lockout expired) -> allowed again
      expect(engine.isLockedOut('login_attacker', now: now.add(const Duration(minutes: 16))), isFalse);
    });
  });
}
