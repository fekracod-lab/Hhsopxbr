import 'package:flutter/foundation.dart';
import '../enums/risk_enums.dart';

/// سياق تقييم المخاطر غير القابل للتعديل (Immutable Risk Context)
@immutable
class RiskContext {
  final String riskEvaluationId;
  final String? transactionId;
  final String operationId;
  final String correlationId;
  final String subjectId;
  final RiskSubjectType subjectType;
  final String idempotencyKey;
  final String policyVersion;
  final DateTime createdAt;

  const RiskContext({
    required this.riskEvaluationId,
    this.transactionId,
    required this.operationId,
    required this.correlationId,
    required this.subjectId,
    required this.subjectType,
    required this.idempotencyKey,
    this.policyVersion = 'v1.0.0',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'riskEvaluationId': riskEvaluationId,
      'transactionId': transactionId,
      'operationId': operationId,
      'correlationId': correlationId,
      'subjectId': subjectId,
      'subjectType': subjectType.key,
      'idempotencyKey': idempotencyKey,
      'policyVersion': policyVersion,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory RiskContext.fromMap(Map<String, dynamic> map, String docId) {
    return RiskContext(
      riskEvaluationId: docId,
      transactionId: map['transactionId']?.toString(),
      operationId: map['operationId']?.toString() ?? '',
      correlationId: map['correlationId']?.toString() ?? '',
      subjectId: map['subjectId']?.toString() ?? '',
      subjectType: RiskSubjectType.fromString(map['subjectType']?.toString()),
      idempotencyKey: map['idempotencyKey']?.toString() ?? '',
      policyVersion: map['policyVersion']?.toString() ?? 'v1.0.0',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
