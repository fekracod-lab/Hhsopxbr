import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/security/security.dart';

void main() {
  group('Automated Security Audit Engine Dedicated Tests', () {
    const auditEngine = SecurityAuditEngine();

    test('1. ATTACK-009: Detects critical blockers (debug mode, mock services, secrets) and yields SECURITY_BLOCKED', () {
      final audit = auditEngine.auditEnvironmentSecurity(
        isDebugMode: true,
        allowMockServices: true,
        isLocalhostEndpoint: true,
        plaintextSecretFindings: ['Found private key in config'],
        hasDenyByDefaultRules: false,
        hasStorageOwnershipRules: false,
      );

      expect(audit.status, equals(SecurityGateStatus.securityBlocked));
      expect(audit.hasCriticalBlockers, isTrue);
      expect(audit.criticalCount, greaterThanOrEqualTo(4));
    });

    test('2. Yields SECURITY_READY when all security criteria are verified with zero blockers', () {
      final audit = auditEngine.auditEnvironmentSecurity(
        isDebugMode: false,
        allowMockServices: false,
        isLocalhostEndpoint: false,
        plaintextSecretFindings: const [],
        hasDenyByDefaultRules: true,
        hasStorageOwnershipRules: true,
      );

      expect(audit.status, equals(SecurityGateStatus.securityReady));
      expect(audit.hasCriticalBlockers, isFalse);
      expect(audit.overallSecurityScore, equals(100.0));
    });
  });
}
