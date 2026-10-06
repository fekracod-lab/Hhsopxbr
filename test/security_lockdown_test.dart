import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/services/security_lockdown_engine.dart';

void main() {
  group('Security Lockdown & PII Sanitization Dedicated Tests', () {
    const engine = SecurityLockdownEngine();

    test('1. Redacts passwords, tokens, OTPs, CVVs and sensitive keys from nested payload maps', () {
      final sensitiveData = {
        'userId': 'user_123',
        'email': 'driver@madar.iq',
        'password': 'PlaintextPassword123!',
        'accessToken': 'eyJh...jwt_token',
        'otpCode': '994821',
        'payment': {
          'cardNumber': '4111222233334444',
          'cvv': '987',
          'amount': 25000,
        },
      };

      final sanitized = engine.sanitizePayload(sensitiveData);

      expect(sanitized['userId'], equals('user_123'));
      expect(sanitized['email'], equals('driver@madar.iq'));
      expect(sanitized['password'], equals('[REDACTED_BY_SECURITY_LOCKDOWN]'));
      expect(sanitized['accessToken'], equals('[REDACTED_BY_SECURITY_LOCKDOWN]'));
      expect(sanitized['otpCode'], equals('[REDACTED_BY_SECURITY_LOCKDOWN]'));

      final payment = sanitized['payment'] as Map;
      expect(payment['cardNumber'], equals('[REDACTED_BY_SECURITY_LOCKDOWN]'));
      expect(payment['cvv'], equals('[REDACTED_BY_SECURITY_LOCKDOWN]'));
      expect(payment['amount'], equals(25000));
    });

    test('2. Redacts authorization bearer tokens and OTPs from raw log string messages', () {
      final rawLog = 'User login failed with Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9 and otp=123456';
      final sanitized = engine.sanitizeLogMessage(rawLog);

      expect(sanitized, contains('Bearer [REDACTED_TOKEN]'));
      expect(sanitized, contains('otp: [REDACTED_OTP]'));
      expect(sanitized.contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'), isFalse);
      expect(sanitized.contains('123456'), isFalse);
    });
  });
}
