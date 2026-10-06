import 'package:flutter/foundation.dart';
import '../enums/risk_enums.dart';
import 'risk_context.dart';
import 'risk_signal.dart';
import 'risk_score.dart';
import 'risk_decision.dart';

/// سجل نتيجة تقييم المخاطر الكامل والموثق (Risk Evaluation Record)
@immutable
class RiskEvaluation {
  final String evaluationId;
  final RiskContext context;
  final String featuresHash;
  final List<RiskSignal> signals;
  final RiskScore score;
  final RiskDecision decision;
  final String policyVersion;
  final int durationMs;
  final RiskEvaluationStatus status;
  final DateTime createdAt;

  const RiskEvaluation({
    required this.evaluationId,
    required this.context,
    required this.featuresHash,
    this.signals = const [],
    required this.score,
    required this.decision,
    required this.policyVersion,
    this.durationMs = 0,
    this.status = RiskEvaluationStatus.completed,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'evaluationId': evaluationId,
      'context': context.toMap(),
      'featuresHash': featuresHash,
      'signals': signals.map((s) => s.toMap()).toList(),
      'score': score.toMap(),
      'decision': decision.toMap(),
      'policyVersion': policyVersion,
      'durationMs': durationMs,
      'status': status.key,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory RiskEvaluation.fromMap(Map<String, dynamic> map, String docId) {
    final ctxMap = map['context'] is Map ? Map<String, dynamic>.from(map['context'] as Map) : <String, dynamic>{};
    final scoreMap = map['score'] is Map ? Map<String, dynamic>.from(map['score'] as Map) : <String, dynamic>{};
    final decMap = map['decision'] is Map ? Map<String, dynamic>.from(map['decision'] as Map) : <String, dynamic>{};
    final sigList = (map['signals'] as List?)
            ?.map((e) => RiskSignal.fromMap(Map<String, dynamic>.from(e as Map), e['signalId']?.toString() ?? ''))
            .toList() ??
        [];

    return RiskEvaluation(
      evaluationId: docId,
      context: RiskContext.fromMap(ctxMap, ctxMap['riskEvaluationId']?.toString() ?? docId),
      featuresHash: map['featuresHash']?.toString() ?? '',
      signals: sigList,
      score: RiskScore.fromMap(scoreMap),
      decision: RiskDecision.fromMap(decMap),
      policyVersion: map['policyVersion']?.toString() ?? 'v1.0.0',
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      status: RiskEvaluationStatus.values.firstWhere(
        (s) => s.key == map['status']?.toString(),
        orElse: () => RiskEvaluationStatus.completed,
      ),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
