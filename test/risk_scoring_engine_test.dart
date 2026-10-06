import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/risk/domain/entities/risk_score.dart';
import 'package:dalal_alqaim/core/risk/domain/enums/risk_enums.dart';
import 'package:dalal_alqaim/core/risk/domain/services/risk_scoring_engine.dart';

void main() {
  group('Risk Scoring Engine Dedicated Tests', () {
    test('1. Score 0..19 yields Trusted -> Allow', () {
      final score = RiskScore(
        rawScore: 10,
        normalizedScore: 10,
        riskLevel: RiskLevel.trusted,
        policyVersion: 'v1.0.0',
        calculatedAt: DateTime.now(),
      );

      final decision = RiskScoringEngine.evaluateDecision(score: score);
      expect(decision.decision, equals(RiskDecisionType.allow));
      expect(decision.allowed, isTrue);
      expect(decision.action, equals(RiskActionType.allow));
    });

    test('2. Score 40..59 yields Medium -> Challenge (Require OTP)', () {
      final score = RiskScore(
        rawScore: 50,
        normalizedScore: 50,
        riskLevel: RiskLevel.medium,
        policyVersion: 'v1.0.0',
        calculatedAt: DateTime.now(),
      );

      final decision = RiskScoringEngine.evaluateDecision(score: score);
      expect(decision.decision, equals(RiskDecisionType.challenge));
      expect(decision.allowed, isFalse);
      expect(decision.challengeRequired, isTrue);
      expect(decision.action, equals(RiskActionType.requireOtp));
    });

    test('3. Score 60..79 yields High -> Limit (Temporary Limit)', () {
      final score = RiskScore(
        rawScore: 70,
        normalizedScore: 70,
        riskLevel: RiskLevel.high,
        policyVersion: 'v1.0.0',
        calculatedAt: DateTime.now(),
      );

      final decision = RiskScoringEngine.evaluateDecision(score: score);
      expect(decision.decision, equals(RiskDecisionType.limit));
      expect(decision.allowed, isFalse);
      expect(decision.reviewRequired, isTrue);
      expect(decision.action, equals(RiskActionType.temporaryLimit));
    });

    test('4. Score 80..100 yields Critical -> Block (Block Operation)', () {
      final score = RiskScore(
        rawScore: 90,
        normalizedScore: 90,
        riskLevel: RiskLevel.critical,
        policyVersion: 'v1.0.0',
        calculatedAt: DateTime.now(),
      );

      final decision = RiskScoringEngine.evaluateDecision(score: score);
      expect(decision.decision, equals(RiskDecisionType.block));
      expect(decision.allowed, isFalse);
      expect(decision.action, equals(RiskActionType.blockOperation));
    });
  });
}
