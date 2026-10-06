import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/security/security.dart';

void main() {
  group('Secure Storage Service Dedicated Tests', () {
    late SecureStorageService storage;

    setUp(() {
      storage = SecureStorageService(masterSecretKey: 'TEST_SECRET_KEY_1234567890');
    });

    test('1. Encrypts and decrypts sensitive values securely with HMAC validation', () async {
      await storage.writeSecure(key: 'user_auth_token', value: 'secret_jwt_session_token_xyz');

      final decrypted = await storage.readSecure('user_auth_token');
      expect(decrypted, equals('secret_jwt_session_token_xyz'));
    });

    test('2. Returns null when reading non-existent key', () async {
      final val = await storage.readSecure('non_existent_key');
      expect(val, isNull);
    });

    test('3. Deletes keys securely and purges on deleteAll', () async {
      await storage.writeSecure(key: 'key1', value: 'val1');
      await storage.writeSecure(key: 'key2', value: 'val2');

      await storage.deleteSecure('key1');
      expect(await storage.readSecure('key1'), isNull);
      expect(await storage.readSecure('key2'), equals('val2'));

      await storage.deleteAll();
      expect(await storage.readSecure('key2'), isNull);
    });
  });
}
