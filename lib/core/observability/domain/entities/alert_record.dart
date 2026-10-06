import 'package:flutter/foundation.dart';
import '../enums/observability_enums.dart';

/// سجل التنبيه التشغيلي الذكي (Alert Record)
@immutable
class AlertRecord {
  final String alertId;
  final String name;
  final AlertSeverity severity;
  final AlertStatus status;
  final String metricName;
  final double threshold;
  final double actualValue;
  final ServiceType service;
  final String message;
  final DateTime triggeredAt;
  final DateTime? resolvedAt;
  final String? acknowledgedBy;

  const AlertRecord({
    required this.alertId,
    required this.name,
    required this.severity,
    this.status = AlertStatus.active,
    required this.metricName,
    required this.threshold,
    required this.actualValue,
    required this.service,
    required this.message,
    required this.triggeredAt,
    this.resolvedAt,
    this.acknowledgedBy,
  });

  AlertRecord copyWith({
    String? alertId,
    String? name,
    AlertSeverity? severity,
    AlertStatus? status,
    String? metricName,
    double? threshold,
    double? actualValue,
    ServiceType? service,
    String? message,
    DateTime? triggeredAt,
    DateTime? resolvedAt,
    String? acknowledgedBy,
  }) {
    return AlertRecord(
      alertId: alertId ?? this.alertId,
      name: name ?? this.name,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      metricName: metricName ?? this.metricName,
      threshold: threshold ?? this.threshold,
      actualValue: actualValue ?? this.actualValue,
      service: service ?? this.service,
      message: message ?? this.message,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alertId': alertId,
      'name': name,
      'severity': severity.key,
      'status': status.key,
      'metricName': metricName,
      'threshold': threshold,
      'actualValue': actualValue,
      'service': service.key,
      'message': message,
      'triggeredAt': triggeredAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'acknowledgedBy': acknowledgedBy,
    };
  }

  factory AlertRecord.fromMap(Map<String, dynamic> map, String docId) {
    return AlertRecord(
      alertId: docId,
      name: map['name']?.toString() ?? '',
      severity: AlertSeverity.fromString(map['severity']?.toString()),
      status: AlertStatus.fromString(map['status']?.toString()),
      metricName: map['metricName']?.toString() ?? '',
      threshold: (map['threshold'] as num?)?.toDouble() ?? 0.0,
      actualValue: (map['actualValue'] as num?)?.toDouble() ?? 0.0,
      service: ServiceType.fromString(map['service']?.toString()),
      message: map['message']?.toString() ?? '',
      triggeredAt: map['triggeredAt'] != null
          ? DateTime.tryParse(map['triggeredAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      resolvedAt: map['resolvedAt'] != null
          ? DateTime.tryParse(map['resolvedAt'].toString())
          : null,
      acknowledgedBy: map['acknowledgedBy']?.toString(),
    );
  }
}
