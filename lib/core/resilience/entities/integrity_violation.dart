import 'package:flutter/foundation.dart';
import '../enums/resilience_enums.dart';

/// سجل اكتشاف خرق أو خلل في سلامة البيانات (Data Integrity Violation)
@immutable
class IntegrityViolation {
  final String violationId;
  final IntegrityViolationType type;
  final String entityId;
  final String entityType;
  final String details;
  final String severity; // 'warning', 'critical'
  final DateTime detectedAt;
  final bool fixed;

  const IntegrityViolation({
    required this.violationId,
    required this.type,
    required this.entityId,
    required this.entityType,
    required this.details,
    this.severity = 'critical',
    required this.detectedAt,
    this.fixed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'violationId': violationId,
      'type': type.key,
      'entityId': entityId,
      'entityType': entityType,
      'details': details,
      'severity': severity,
      'detectedAt': detectedAt.toIso8601String(),
      'fixed': fixed,
    };
  }

  factory IntegrityViolation.fromMap(Map<String, dynamic> map, String docId) {
    return IntegrityViolation(
      violationId: docId,
      type: IntegrityViolationType.fromString(map['type']?.toString()),
      entityId: map['entityId']?.toString() ?? '',
      entityType: map['entityType']?.toString() ?? '',
      details: map['details']?.toString() ?? '',
      severity: map['severity']?.toString() ?? 'critical',
      detectedAt: map['detectedAt'] != null
          ? DateTime.tryParse(map['detectedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      fixed: map['fixed'] == true,
    );
  }
}
