import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/services/production_config_guard.dart';

void main() {
  group('Production Configuration Guard Dedicated Tests', () {
    const guard = ProductionConfigGuard();

    test('1. Blocks release if debugMode or localhost API endpoint is detected', () {
      final badConfig = {
        'environment': 'production',
        'debugMode': true, // Blocker!
        'apiEndpoint': 'http://localhost:8080/api', // Blocker!
        'firebaseProjectId': 'madar-prod',
        'appVersion': '1.0.0',
      };

      final (isSafe, blockers, _) = guard.auditProductionConfig(config: badConfig);
      expect(isSafe, isFalse);
      expect(blockers.length, equals(2));
      expect(blockers, contains('Debug mode is enabled in production configuration'));
      expect(blockers.any((b) => b.contains('localhost')), isTrue);
    });

    test('2. Blocks release if plaintext secrets or mock services are enabled', () {
      final insecureConfig = {
        'environment': 'production',
        'apiEndpoint': 'https://api.madar.iq',
        'firebaseProjectId': 'madar-prod',
        'appVersion': '1.0.0',
        'useMockServices': true, // Blocker!
        'secretKeyPlaintext': 'super_secret_123', // Blocker!
      };

      final (isSafe, blockers, _) = guard.auditProductionConfig(config: insecureConfig);
      expect(isSafe, isFalse);
      expect(blockers, contains('Mock services or repositories are enabled in production'));
      expect(blockers, contains('Hardcoded plaintext secret detected in configuration map'));
    });

    test('3. Approves verified, production-hardened release configuration', () {
      final validConfig = {
        'environment': 'production',
        'apiEndpoint': 'https://api.madar.iq',
        'firebaseProjectId': 'madar-production-cluster',
        'appVersion': '1.0.0+811',
        'enableVerboseLogging': false,
        'debugMode': false,
        'useMockServices': false,
        'chaosInjectionEnabled': false,
      };

      final (isSafe, blockers, warnings) = guard.auditProductionConfig(config: validConfig);
      expect(isSafe, isTrue);
      expect(blockers.isEmpty, isTrue);
      expect(warnings.isEmpty, isTrue);
    });
  });
}
