import '../entities/risk_score.dart';
import '../entities/risk_decision.dart';
import '../entities/risk_policy.dart';
import '../enums/risk_enums.dart';

/// محرك اتخاذ قرارات المخاطر الحتمية وفق السياسة (Deterministic Risk Scoring & Decision Engine)
class RiskScoringEngine {
  const RiskScoringEngine();

  /// توليد القرار الأمني الحتمي بناءً على درجة الخطورة والسياسة المعتمدة
  static RiskDecision evaluateDecision({
    required RiskScore score,
    RiskPolicy? policy,
  }) {
    final thresholds = policy?.riskThresholds ?? const {
      'critical': 80,
      'high': 60,
      'medium': 40,
      'low': 20,
    };

    final s = score.normalizedScore;

    if (s >= (thresholds['critical'] ?? 80)) {
      return RiskDecision(
        decision: RiskDecisionType.block,
        riskLevel: RiskLevel.critical,
        score: score,
        confidence: score.confidence,
        allowed: false,
        challengeRequired: false,
        reviewRequired: true,
        action: RiskActionType.blockOperation,
        policyVersion: score.policyVersion,
      );
    }

    if (s >= (thresholds['high'] ?? 60)) {
      return RiskDecision(
        decision: RiskDecisionType.limit,
        riskLevel: RiskLevel.high,
        score: score,
        confidence: score.confidence,
        allowed: false,
        challengeRequired: false,
        reviewRequired: true,
        action: RiskActionType.temporaryLimit,
        policyVersion: score.policyVersion,
      );
    }

    if (s >= (thresholds['medium'] ?? 40)) {
      return RiskDecision(
        decision: RiskDecisionType.challenge,
        riskLevel: RiskLevel.medium,
        score: score,
        confidence: score.confidence,
        allowed: false,
        challengeRequired: true,
        reviewRequired: false,
        action: RiskActionType.requireOtp,
        policyVersion: score.policyVersion,
      );
    }

    return RiskDecision(
      decision: RiskDecisionType.allow,
      riskLevel: s >= (thresholds['low'] ?? 20) ? RiskLevel.low : RiskLevel.trusted,
      score: score,
      confidence: score.confidence,
      allowed: true,
      challengeRequired: false,
      reviewRequired: false,
      action: RiskActionType.allow,
      policyVersion: score.policyVersion,
    );
  }
}
