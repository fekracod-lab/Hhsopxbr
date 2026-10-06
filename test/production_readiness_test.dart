import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/services/production_readiness_engine.dart';
import 'package:dalal_alqaim/core/resilience/enums/resilience_enums.dart';

void main() {
  group('Production Readiness Gate Dedicated Tests (12 Categories)', () {
    const engine = ProductionReadinessEngine();

    test('1. Yields PRODUCTION_READY when all 12 categories score 100% with zero blockers', () {
      final scores = {for (var c in ReadinessCategory.values) c: 100.0};
      final blockers = {for (var c in ReadinessCategory.values) c: <String>[]};
      final warnings = {for (var c in ReadinessCategory.values) c: <String>[]};

      final result = engine.evaluateSystemReadiness(
        categoryScores: scores,
        categoryBlockers: blockers,
        categoryWarnings: warnings,
      );

      expect(result.overallStatus, equals(ReadinessGateStatus.productionReady));
      expect(result.overallScore, equals(100.0));
      expect(result.blockingIssues.isEmpty, isTrue);
      expect(result.isProductionReady, isTrue);
      expect(result.categoryStatuses.length, equals(12));
    });

    test('2. Yields PRODUCTION_BLOCKED if any category has a single critical blocker', () {
      final scores = {for (var c in ReadinessCategory.values) c: 100.0};
      final blockers = <ReadinessCategory, List<String>>{
        ReadinessCategory.financialIntegrity: ['Negative balance vulnerability detected'],
      };
      final warnings = {for (var c in ReadinessCategory.values) c: <String>[]};

      final result = engine.evaluateSystemReadiness(
        categoryScores: scores,
        categoryBlockers: blockers,
        categoryWarnings: warnings,
      );

      expect(result.overallStatus, equals(ReadinessGateStatus.productionBlocked));
      expect(result.blockingIssues.length, equals(1));
      expect(result.isProductionReady, isFalse);
      expect(result.categoryStatuses[ReadinessCategory.financialIntegrity], equals(ReadinessGateStatus.productionBlocked));
    });

    test('3. Yields WARNING if category score is between 80% and 95% with non-critical warnings', () {
      final scores = {for (var c in ReadinessCategory.values) c: 92.0};
      final blockers = {for (var c in ReadinessCategory.values) c: <String>[]};
      final warnings = <ReadinessCategory, List<String>>{
        ReadinessCategory.configuration: ['Verbose logging enabled in release'],
      };

      final result = engine.evaluateSystemReadiness(
        categoryScores: scores,
        categoryBlockers: blockers,
        categoryWarnings: warnings,
      );

      expect(result.overallStatus, equals(ReadinessGateStatus.warning));
      expect(result.overallScore, equals(92.0));
      expect(result.warnings.length, equals(1));
      expect(result.blockingIssues.isEmpty, isTrue);
    });
  });
}
