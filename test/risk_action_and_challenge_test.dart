import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/risk/domain/entities/risk_decision.dart';
import 'package:dalal_alqaim/core/risk/domain/entities/risk_score.dart';
import 'package:dalal_alqaim/core/risk/domain/enums/risk_enums.dart';
import 'package:dalal_alqaim/core/risk/domain/services/risk_action_engine.dart';
import 'package:dalal_alqaim/core/risk/domain/services/challenge_engine.dart';

void main() {
  group('Risk Action & Challenge Engine Dedicated Tests', () {
    test('1. Action engine accurately detects block and challenge states', () {
      final score = RiskScore(
        rawScore: 85,
        normalizedScore: 85,
        riskLevel: RiskLevel.critical,
        policyVersion: 'v1.0.0',
        calculatedAt: DateTime.now(),
      );

      final blockDecision = RiskDecision(
        decision: RiskDecisionType.block,
        riskLevel: RiskLevel.critical,
        score: score,
        confidence: 1.0,
        allowed: false,
        action: RiskActionType.blockOperation,
        policyVersion: 'v1.0.0',
      );

      expect(RiskActionEngine.shouldBlockOperation(blockDecision), isTrue);
      expect(RiskActionEngine.requiresChallenge(blockDecision), isFalse);

      final challengeDecision = RiskDecision(
        decision: RiskDecisionType.challenge,
        riskLevel: RiskLevel.medium,
        score: score,
        confidence: 1.0,
        allowed: false,
        challengeRequired: true,
        action: RiskActionType.requireOtp,
        policyVersion: 'v1.0.0',
      );

      expect(RiskActionEngine.shouldBlockOperation(challengeDecision), isFalse);
      expect(RiskActionEngine.requiresChallenge(challengeDecision), isTrue);
    });

    test('2. Challenge engine creates and single-use consumes verification codes', () {
      final challengeEngine = ChallengeEngine();

      final challengeId = challengeEngine.createChallenge(
        subjectId: 'user_otp',
        type: ChallengeType.otp,
        verificationCode: '482910',
      );

      // Wrong code -> fails & remains active
      expect(
        challengeEngine.verifyChallenge(challengeId: challengeId, providedCode: '111111'),
        isFalse,
      );

      // Correct code -> succeeds and consumes
      expect(
        challengeEngine.verifyChallenge(challengeId: challengeId, providedCode: '482910'),
        isTrue,
      );

      // Replay attempt of consumed challenge -> fails!
      expect(
        challengeEngine.verifyChallenge(challengeId: challengeId, providedCode: '482910'),
        isFalse,
      );
    });
  });
}
