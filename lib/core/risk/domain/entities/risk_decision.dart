import 'package:flutter/foundation.dart';
import '../enums/risk_enums.dart';
import 'risk_score.dart';

/// القرار النهائي لتقييم المخاطر (Risk Decision Result)
@immutable
class RiskDecision {
  final RiskDecisionType decision;
  final RiskLevel riskLevel;
  final RiskScore score;
  final double confidence;
  final bool allowed;
  final bool challengeRequired;
  final bool reviewRequired;
  final RiskActionType action;
  final String policyVersion;

  const RiskDecision({
    required this.decision,
    required this.riskLevel,
    required this.score,
    required this.confidence,
    required this.allowed,
    this.challengeRequired = false,
    this.reviewRequired = false,
    required this.action,
    required this.policyVersion,
  });

  Map<String, dynamic> toMap() {
    return {
      'decision': decision.key,
      'riskLevel': riskLevel.key,
      'score': score.toMap(),
      'confidence': confidence,
      'allowed': allowed,
      'challengeRequired': challengeRequired,
      'reviewRequired': reviewRequired,
      'action': action.key,
      'policyVersion': policyVersion,
    };
  }

  factory RiskDecision.fromMap(Map<String, dynamic> map) {
    final scoreMap = map['score'] is Map ? Map<String, dynamic>.from(map['score'] as Map) : <String, dynamic>{};
    return RiskDecision(
      decision: RiskDecisionType.fromString(map['decision']?.toString()),
      riskLevel: RiskLevel.fromString(map['riskLevel']?.toString()),
      score: RiskScore.fromMap(scoreMap),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      allowed: map['allowed'] == true,
      challengeRequired: map['challengeRequired'] == true,
      reviewRequired: map['reviewRequired'] == true,
      action: RiskActionType.values.firstWhere(
        (a) => a.key == map['action']?.toString(),
        orElse: () => RiskActionType.allow,
      ),
      policyVersion: map['policyVersion']?.toString() ?? 'v1.0.0',
    );
  }
}
