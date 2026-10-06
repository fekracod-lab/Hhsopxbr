import '../entities/security_readiness_result.dart';
import '../enums/security_enums.dart';

/// محرك تقييم بوابة الجاهزية الأمنية لـ 14 فئة (Production Security Readiness Gate Engine)
class SecurityReadinessEngine {
  const SecurityReadinessEngine();

  /// تدقيق وتقييم الفئات الـ 14
  SecurityReadinessResult evaluateSecurityGate({
    required Map<SecurityGateCategory, double> categoryScores,
    required Map<SecurityGateCategory, List<String>> categoryBlockers,
    Map<SecurityGateCategory, List<String>> categoryWarnings = const {},
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final allCategories = SecurityGateCategory.values;

    var totalScore = 0.0;
    var hasAnyBlocker = false;
    var hasAnyWarning = false;

    final resolvedScores = <SecurityGateCategory, double>{};
    final resolvedBlockers = <SecurityGateCategory, List<String>>{};
    final resolvedWarnings = <SecurityGateCategory, List<String>>{};

    for (final cat in allCategories) {
      final score = categoryScores[cat] ?? 0.0;
      final blockers = categoryBlockers[cat] ?? const [];
      final warnings = categoryWarnings[cat] ?? const [];

      resolvedScores[cat] = score;
      resolvedBlockers[cat] = List.unmodifiable(blockers);
      resolvedWarnings[cat] = List.unmodifiable(warnings);

      totalScore += score;

      if (blockers.isNotEmpty || score < 70.0) {
        hasAnyBlocker = true;
      } else if (warnings.isNotEmpty || score < 95.0) {
        hasAnyWarning = true;
      }
    }

    final avgScore = totalScore / allCategories.length;

    SecurityGateStatus status;
    if (hasAnyBlocker) {
      status = SecurityGateStatus.securityBlocked;
    } else if (hasAnyWarning || avgScore < 95.0) {
      status = SecurityGateStatus.securityWarning;
    } else {
      status = SecurityGateStatus.securityReady;
    }

    return SecurityReadinessResult(
      auditId: 'sec_gate_${timestamp.millisecondsSinceEpoch}',
      auditedAt: timestamp,
      gateStatus: status,
      overallSecurityScore: avgScore,
      categoryScores: resolvedScores,
      categoryBlockers: resolvedBlockers,
      categoryWarnings: resolvedWarnings,
    );
  }
}
