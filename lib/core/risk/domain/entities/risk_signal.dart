import 'package:flutter/foundation.dart';
import '../enums/risk_enums.dart';

/// إشارة خطر ذرية موثقة (Atomic Risk Signal)
@immutable
class RiskSignal {
  final String signalId;
  final RiskSignalType type;
  final RiskSource source;
  final String subjectId;
  final FraudCaseSeverity severity;
  final double confidence; // 0.0 - 1.0
  final int weight; // مساهمة النقطة في النتيجة الإجمالية
  final DateTime timestamp;
  final String metadataHash;
  final Map<String, dynamic> metadata;

  const RiskSignal({
    required this.signalId,
    required this.type,
    required this.source,
    required this.subjectId,
    required this.severity,
    this.confidence = 1.0,
    required this.weight,
    required this.timestamp,
    this.metadataHash = '',
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'signalId': signalId,
      'type': type.key,
      'source': source.key,
      'subjectId': subjectId,
      'severity': severity.key,
      'confidence': confidence,
      'weight': weight,
      'timestamp': timestamp.toIso8601String(),
      'metadataHash': metadataHash,
      'metadata': metadata,
    };
  }

  factory RiskSignal.fromMap(Map<String, dynamic> map, String docId) {
    return RiskSignal(
      signalId: docId,
      type: RiskSignalType.values.firstWhere(
        (t) => t.key == map['type']?.toString(),
        orElse: () => RiskSignalType.behavioralAnomaly,
      ),
      source: RiskSource.values.firstWhere(
        (s) => s.key == map['source']?.toString(),
        orElse: () => RiskSource.client,
      ),
      subjectId: map['subjectId']?.toString() ?? '',
      severity: FraudCaseSeverity.values.firstWhere(
        (s) => s.key == map['severity']?.toString(),
        orElse: () => FraudCaseSeverity.medium,
      ),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      weight: (map['weight'] as num?)?.toInt() ?? 10,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      metadataHash: map['metadataHash']?.toString() ?? '',
      metadata: map['metadata'] is Map ? Map<String, dynamic>.from(map['metadata'] as Map) : {},
    );
  }
}
