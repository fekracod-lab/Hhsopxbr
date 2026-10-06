import 'package:flutter/foundation.dart';
import '../enums/security_enums.dart';

/// نتيجة بوابة الجاهزية الأمنية الشاملة (Production Security Readiness Result)
@immutable
class SecurityReadinessResult {
  final String auditId;
  final DateTime auditedAt;
  final SecurityGateStatus gateStatus;
  final double overallSecurityScore;
  final Map<SecurityGateCategory, double> categoryScores;
  final Map<SecurityGateCategory, List<String>> categoryBlockers;
  final Map<SecurityGateCategory, List<String>> categoryWarnings;

  const SecurityReadinessResult({
    required this.auditId,
    required this.auditedAt,
    required this.gateStatus,
    required this.overallSecurityScore,
    required this.categoryScores,
    this.categoryBlockers = const {},
    this.categoryWarnings = const {},
  });

  bool get isProductionSecurityReady => gateStatus == SecurityGateStatus.securityReady;
  bool get hasCriticalBlockers => categoryBlockers.values.any((list) => list.isNotEmpty);

  Map<String, dynamic> toMap() => {
    'auditId': auditId,
    'auditedAt': auditedAt.toIso8601String(),
    'gateStatus': gateStatus.key,
    'overallSecurityScore': overallSecurityScore,
    'categoryScores': categoryScores.map((k, v) => MapEntry(k.key, v)),
    'categoryBlockers': categoryBlockers.map((k, v) => MapEntry(k.key, v)),
    'categoryWarnings': categoryWarnings.map((k, v) => MapEntry(k.key, v)),
  };
}
