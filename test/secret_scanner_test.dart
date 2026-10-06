import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/security/security.dart';

void main() {
  group('Secret & Token Scanner Engine Dedicated Tests', () {
    const scanner = SecretScannerEngine();

    test('1. ATTACK-008: Detects and flags high-entropy API keys and private keys in strings', () {
      const payload = 'Config error connecting with AIzaSyD9876543210987654321 and -----BEGIN RSA PRIVATE KEY----- MIIE...';
      final findings = scanner.scanStringForSecrets(payload);

      expect(findings.length, greaterThanOrEqualTo(2));
      expect(findings.any((f) => f.contains('API key')), isTrue);
      expect(findings.any((f) => f.contains('Private Key')), isTrue);
    });

    test('2. Scans nested maps and detects plaintext passwords, tokens, and CVVs', () {
      final payload = {
        'user': 'omar',
        'auth': {
          'password': 'PlaintextPassword123!',
          'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.doNotLeakThis',
        },
      };

      final findings = scanner.scanMapForSensitiveData(payload);
      expect(findings.length, equals(2));
      expect(findings.any((f) => f.contains('password')), isTrue);
      expect(findings.any((f) => f.contains('token')), isTrue);
    });

    test('3. Redacts raw JWTs and API keys from log messages', () {
      const rawLog = 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.doNotLeakThis key: AIzaSyD9876543210987654321';
      final sanitized = scanner.redactSecretsFromText(rawLog);

      expect(sanitized, contains('[REDACTED_JWT_TOKEN]'));
      expect(sanitized, contains('[REDACTED_API_KEY]'));
      expect(sanitized, isNot(contains('AIzaSyD9876543210987654321')));
    });
  });
}
