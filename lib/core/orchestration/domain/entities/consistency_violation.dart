import 'package:flutter/foundation.dart';
import '../enums/orchestration_enums.dart';

/// سجل رصد التناقض وانتهاك الاتساق (Consistency Violation Record)
@immutable
class ConsistencyViolation {
  final String violationId;
  final ConsistencyViolationType type;
  final ViolationSeverity severity;
  final String aggregateId;
  final String expectedState;
  final String actualState;
  final RecoveryAction recommendedAction;
  final DateTime detectedAt;
  final DateTime? resolvedAt;
  final bool isResolved;
  final String? resolutionDetails;

  const ConsistencyViolation({
    required this.violationId,
    required this.type,
    required this.severity,
    required this.aggregateId,
    required this.expectedState,
    required this.actualState,
    required this.recommendedAction,
    required this.detectedAt,
    this.resolvedAt,
    this.isResolved = false,
    this.resolutionDetails,
  });

  ConsistencyViolation copyWith({
    String? violationId,
    ConsistencyViolationType? type,
    ViolationSeverity? severity,
    String? aggregateId,
    String? expectedState,
    String? actualState,
    RecoveryAction? recommendedAction,
    DateTime? detectedAt,
    DateTime? resolvedAt,
    bool? isResolved,
    String? resolutionDetails,
  }) {
    return ConsistencyViolation(
      violationId: violationId ?? this.violationId,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      aggregateId: aggregateId ?? this.aggregateId,
      expectedState: expectedState ?? this.expectedState,
      actualState: actualState ?? this.actualState,
      recommendedAction: recommendedAction ?? this.recommendedAction,
      detectedAt: detectedAt ?? this.detectedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      isResolved: isResolved ?? this.isResolved,
      resolutionDetails: resolutionDetails ?? this.resolutionDetails,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'violationId': violationId,
      'type': type.key,
      'severity': severity.key,
      'aggregateId': aggregateId,
      'expectedState': expectedState,
      'actualState': actualState,
      'recommendedAction': recommendedAction.key,
      'detectedAt': detectedAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'isResolved': isResolved,
      'resolutionDetails': resolutionDetails,
    };
  }

  factory ConsistencyViolation.fromMap(Map<String, dynamic> map, String docId) {
    return ConsistencyViolation(
      violationId: docId,
      type: ConsistencyViolationType.values.firstWhere(
        (t) => t.key == map['type']?.toString(),
        orElse: () => ConsistencyViolationType.completedOrderPendingPayment,
      ),
      severity: ViolationSeverity.values.firstWhere(
        (s) => s.key == map['severity']?.toString(),
        orElse: () => ViolationSeverity.medium,
      ),
      aggregateId: map['aggregateId']?.toString() ?? '',
      expectedState: map['expectedState']?.toString() ?? '',
      actualState: map['actualState']?.toString() ?? '',
      recommendedAction: RecoveryAction.values.firstWhere(
        (r) => r.key == map['recommendedAction']?.toString(),
        orElse: () => RecoveryAction.manualIntervention,
      ),
      detectedAt: map['detectedAt'] != null
          ? DateTime.tryParse(map['detectedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      resolvedAt: map['resolvedAt'] != null ? DateTime.tryParse(map['resolvedAt'].toString()) : null,
      isResolved: map['isResolved'] == true,
      resolutionDetails: map['resolutionDetails']?.toString(),
    );
  }
}
