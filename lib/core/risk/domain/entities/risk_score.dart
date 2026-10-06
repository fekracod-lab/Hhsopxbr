import 'package:flutter/foundation.dart';
import '../enums/risk_enums.dart';

/// درجة الخطورة المحسوبة حتمياً (Deterministic Risk Score)
@immutable
class RiskScore {
  final int rawScore;
  final int normalizedScore; // 0 .. 100
  final RiskLevel riskLevel;
  final double confidence; // 0.0 .. 1.0
  final String policyVersion;
  final DateTime calculatedAt;

  const RiskScore({
    required this.rawScore,
    required this.normalizedScore,
    required this.riskLevel,
    this.confidence = 1.0,
    required this.policyVersion,
    required this.calculatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'rawScore': rawScore,
      'normalizedScore': normalizedScore,
      'riskLevel': riskLevel.key,
      'confidence': confidence,
      'policyVersion': policyVersion,
      'calculatedAt': calculatedAt.toIso8601String(),
    };
  }

  factory RiskScore.fromMap(Map<String, dynamic> map) {
    final norm = (map['normalizedScore'] as num?)?.toInt() ?? 0;
    return RiskScore(
      rawScore: (map['rawScore'] as num?)?.toInt() ?? norm,
      normalizedScore: norm.clamp(0, 100),
      riskLevel: RiskLevel.fromString(map['riskLevel']?.toString()),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      policyVersion: map['policyVersion']?.toString() ?? 'v1.0.0',
      calculatedAt: map['calculatedAt'] != null
          ? DateTime.tryParse(map['calculatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
