import 'package:flutter/foundation.dart';
import '../enums/security_enums.dart';

/// نتيجة فحص وتدقيق أمني (Security Audit Finding Record)
@immutable
class SecurityAuditFinding {
  final String findingId;
  final SecurityGateCategory category;
  final ThreatSeverity severity;
  final String location;
  final String description;
  final String recommendation;
  final bool isBlocker;

  const SecurityAuditFinding({
    required this.findingId,
    required this.category,
    required this.severity,
    required this.location,
    required this.description,
    required this.recommendation,
    required this.isBlocker,
  });

  Map<String, dynamic> toMap() => {
    'findingId': findingId,
    'category': category.key,
    'severity': severity.key,
    'location': location,
    'description': description,
    'recommendation': recommendation,
    'isBlocker': isBlocker,
  };
}

/// تقرير التدقيق الأمني الإجمالي (Security Audit Result)
@immutable
class SecurityAuditResult {
  final String auditId;
  final DateTime auditedAt;
  final List<SecurityAuditFinding> findings;
  final double overallSecurityScore;
  final SecurityGateStatus status;

  const SecurityAuditResult({
    required this.auditId,
    required this.auditedAt,
    required this.findings,
    required this.overallSecurityScore,
    required this.status,
  });

  bool get hasCriticalBlockers => findings.any((f) => f.isBlocker || f.severity == ThreatSeverity.critical);
  int get criticalCount => findings.where((f) => f.severity == ThreatSeverity.critical).length;
  int get highCount => findings.where((f) => f.severity == ThreatSeverity.high).length;
}
