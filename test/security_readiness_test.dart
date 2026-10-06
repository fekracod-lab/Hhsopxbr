import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/security/security.dart';

void main() {
  group('Production Security Readiness Gate Dedicated Tests (14 Categories)', () {
    const readinessEngine = SecurityReadinessEngine();

    test('1. Yields SECURITY_READY when all 14 categories score 100% with zero blockers', () {
      final scores = {for (var c in SecurityGateCategory.values) c: 100.0};
      final blockers = {for (var c in SecurityGateCategory.values) c: <String>[]};

      final result = readinessEngine.evaluateSecurityGate(
        categoryScores: scores,
        categoryBlockers: blockers,
      );

      expect(result.gateStatus, equals(SecurityGateStatus.securityReady));
      expect(result.isProductionSecurityReady, isTrue);
      expect(result.overallSecurityScore, equals(100.0));
    });

    test('2. Yields SECURITY_BLOCKED if any category has a critical blocker', () {
      final scores = {for (var c in SecurityGateCategory.values) c: 100.0};
      final blockers = {
        for (var c in SecurityGateCategory.values) c: <String>[],
      };
      blockers[SecurityGateCategory.secretProtection] = ['Hardcoded API key detected in release configuration'];

      final result = readinessEngine.evaluateSecurityGate(
        categoryScores: scores,
        categoryBlockers: blockers,
      );

      expect(result.gateStatus, equals(SecurityGateStatus.securityBlocked));
      expect(result.hasCriticalBlockers, isTrue);
    });

    test('3. Yields SECURITY_WARNING when score is between 70% and 95% with non-blocking warnings', () {
      final scores = {for (var c in SecurityGateCategory.values) c: 100.0};
      scores[SecurityGateCategory.storageSecurity] = 85.0; // Non-blocking warning

      final blockers = {for (var c in SecurityGateCategory.values) c: <String>[]};
      final warnings = {
        SecurityGateCategory.storageSecurity: ['Consider enforcing 5MB max upload file size restriction on avatars'],
      };

      final result = readinessEngine.evaluateSecurityGate(
        categoryScores: scores,
        categoryBlockers: blockers,
        categoryWarnings: warnings,
      );

      expect(result.gateStatus, equals(SecurityGateStatus.securityWarning));
    });
  });
}
