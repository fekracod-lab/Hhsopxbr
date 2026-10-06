import 'package:flutter/foundation.dart';
import '../enums/security_enums.dart';

/// نتيجة كشف التهديدات الأمنية (Threat Detection Result)
@immutable
class ThreatDetectionResult {
  final bool isThreatDetected;
  final SecurityEventType? detectedEventType;
  final ThreatSeverity severity;
  final String? targetSubjectId;
  final String reason;
  final bool shouldBlockRequest;
  final DateTime detectedAt;

  const ThreatDetectionResult({
    required this.isThreatDetected,
    this.detectedEventType,
    this.severity = ThreatSeverity.low,
    this.targetSubjectId,
    required this.reason,
    this.shouldBlockRequest = false,
    required this.detectedAt,
  });

  static ThreatDetectionResult safe({String reason = 'No threats detected'}) => ThreatDetectionResult(
    isThreatDetected: false,
    reason: reason,
    detectedAt: DateTime.now(),
  );

  static ThreatDetectionResult threat({
    required SecurityEventType eventType,
    required ThreatSeverity severity,
    required String reason,
    String? subjectId,
    bool block = true,
  }) => ThreatDetectionResult(
    isThreatDetected: true,
    detectedEventType: eventType,
    severity: severity,
    targetSubjectId: subjectId,
    reason: reason,
    shouldBlockRequest: block,
    detectedAt: DateTime.now(),
  );
}
