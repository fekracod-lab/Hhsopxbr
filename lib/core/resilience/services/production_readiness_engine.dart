import '../entities/production_readiness_result.dart';
import '../enums/resilience_enums.dart';

/// محرك تقييم بوابة الجاهزية الإنتاجية الشاملة (Production Readiness Gate Engine)
class ProductionReadinessEngine {
  const ProductionReadinessEngine();

  /// إجراء تقييم تدقيقي شامل للفئات الـ 12 وإصدار تقرير الجاهزية
  ProductionReadinessResult evaluateSystemReadiness({
    required Map<ReadinessCategory, double> categoryScores,
    required Map<ReadinessCategory, List<String>> categoryBlockers,
    required Map<ReadinessCategory, List<String>> categoryWarnings,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final allBlockers = <String>[];
    final allWarnings = <String>[];
    final computedStatuses = <ReadinessCategory, ReadinessGateStatus>{};

    double totalScore = 0.0;
    int evaluatedCategoriesCount = 0;

    for (final category in ReadinessCategory.values) {
      final score = categoryScores[category] ?? 100.0;
      final blockers = categoryBlockers[category] ?? [];
      final warnings = categoryWarnings[category] ?? [];

      allBlockers.addAll(blockers);
      allWarnings.addAll(warnings);

      totalScore += score;
      evaluatedCategoriesCount++;

      if (blockers.isNotEmpty || score < 80.0) {
        computedStatuses[category] = ReadinessGateStatus.productionBlocked;
      } else if (warnings.isNotEmpty || score < 95.0) {
        computedStatuses[category] = ReadinessGateStatus.warning;
      } else {
        computedStatuses[category] = ReadinessGateStatus.productionReady;
      }
    }

    final overallScore = evaluatedCategoriesCount > 0
        ? (totalScore / evaluatedCategoriesCount)
        : 0.0;

    final overallStatus = allBlockers.isEmpty && overallScore >= 95.0
        ? ReadinessGateStatus.productionReady
        : (allBlockers.isNotEmpty
            ? ReadinessGateStatus.productionBlocked
            : ReadinessGateStatus.warning);

    return ProductionReadinessResult(
      overallStatus: overallStatus,
      overallScore: double.parse(overallScore.toStringAsFixed(1)),
      categoryScores: categoryScores,
      categoryStatuses: computedStatuses,
      blockingIssues: allBlockers,
      warnings: allWarnings,
      evaluatedAt: timestamp,
    );
  }
}
