import 'package:flutter/foundation.dart';
import '../enums/risk_enums.dart';

/// ملف وقضية احتيال تشغيلية وإدارية (Fraud Case Entity)
@immutable
class FraudCase {
  final String caseId;
  final String subjectId;
  final RiskSubjectType subjectType;
  final FraudCaseSeverity severity;
  final FraudCaseStatus status;
  final int riskScore;
  final List<String> signalIds;
  final List<String> evidenceReferences;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? assignedTo;
  final String? resolution;

  const FraudCase({
    required this.caseId,
    required this.subjectId,
    required this.subjectType,
    required this.severity,
    this.status = FraudCaseStatus.open,
    required this.riskScore,
    this.signalIds = const [],
    this.evidenceReferences = const [],
    required this.createdAt,
    required this.updatedAt,
    this.assignedTo,
    this.resolution,
  });

  FraudCase copyWith({
    String? caseId,
    String? subjectId,
    RiskSubjectType? subjectType,
    FraudCaseSeverity? severity,
    FraudCaseStatus? status,
    int? riskScore,
    List<String>? signalIds,
    List<String>? evidenceReferences,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? assignedTo,
    String? resolution,
  }) {
    return FraudCase(
      caseId: caseId ?? this.caseId,
      subjectId: subjectId ?? this.subjectId,
      subjectType: subjectType ?? this.subjectType,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      riskScore: riskScore ?? this.riskScore,
      signalIds: signalIds ?? this.signalIds,
      evidenceReferences: evidenceReferences ?? this.evidenceReferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedTo: assignedTo ?? this.assignedTo,
      resolution: resolution ?? this.resolution,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'caseId': caseId,
      'subjectId': subjectId,
      'subjectType': subjectType.key,
      'severity': severity.key,
      'status': status.key,
      'riskScore': riskScore,
      'signalIds': signalIds,
      'evidenceReferences': evidenceReferences,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'assignedTo': assignedTo,
      'resolution': resolution,
    };
  }

  factory FraudCase.fromMap(Map<String, dynamic> map, String docId) {
    return FraudCase(
      caseId: docId,
      subjectId: map['subjectId']?.toString() ?? '',
      subjectType: RiskSubjectType.fromString(map['subjectType']?.toString()),
      severity: FraudCaseSeverity.values.firstWhere(
        (s) => s.key == map['severity']?.toString(),
        orElse: () => FraudCaseSeverity.medium,
      ),
      status: FraudCaseStatus.fromString(map['status']?.toString()),
      riskScore: (map['riskScore'] as num?)?.toInt() ?? 0,
      signalIds: (map['signalIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      evidenceReferences: (map['evidenceReferences'] as List?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      assignedTo: map['assignedTo']?.toString(),
      resolution: map['resolution']?.toString(),
    );
  }
}
