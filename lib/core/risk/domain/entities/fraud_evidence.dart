import 'package:flutter/foundation.dart';
import '../enums/risk_enums.dart';

/// سجل دليل أمني جنائي غير قابل للتعديل (Immutable Fraud Evidence)
@immutable
class FraudEvidence {
  final String evidenceId;
  final String caseId;
  final EvidenceType type;
  final RiskSource source;
  final DateTime timestamp;
  final String payloadHash;
  final String correlationId;
  final Map<String, dynamic> evidenceData;

  const FraudEvidence({
    required this.evidenceId,
    required this.caseId,
    required this.type,
    required this.source,
    required this.timestamp,
    required this.payloadHash,
    required this.correlationId,
    this.evidenceData = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'evidenceId': evidenceId,
      'caseId': caseId,
      'type': type.key,
      'source': source.key,
      'timestamp': timestamp.toIso8601String(),
      'payloadHash': payloadHash,
      'correlationId': correlationId,
      'evidenceData': evidenceData,
    };
  }

  factory FraudEvidence.fromMap(Map<String, dynamic> map, String docId) {
    return FraudEvidence(
      evidenceId: docId,
      caseId: map['caseId']?.toString() ?? '',
      type: EvidenceType.values.firstWhere(
        (e) => e.key == map['type']?.toString(),
        orElse: () => EvidenceType.behaviorSnapshot,
      ),
      source: RiskSource.values.firstWhere(
        (s) => s.key == map['source']?.toString(),
        orElse: () => RiskSource.client,
      ),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      payloadHash: map['payloadHash']?.toString() ?? '',
      correlationId: map['correlationId']?.toString() ?? '',
      evidenceData: map['evidenceData'] is Map ? Map<String, dynamic>.from(map['evidenceData'] as Map) : {},
    );
  }
}
