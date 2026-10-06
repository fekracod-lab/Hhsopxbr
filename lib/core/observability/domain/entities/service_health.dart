import 'package:flutter/foundation.dart';
import '../enums/observability_enums.dart';

/// تقرير صحة تبعية أو خدمة فردية (Service Health Record)
@immutable
class ServiceHealth {
  final ServiceType service;
  final HealthStatus status;
  final int latencyMs;
  final DateTime lastCheckedAt;
  final String details;
  final int consecutiveFailures;

  const ServiceHealth({
    required this.service,
    this.status = HealthStatus.healthy,
    this.latencyMs = 0,
    required this.lastCheckedAt,
    this.details = 'Operational',
    this.consecutiveFailures = 0,
  });

  ServiceHealth copyWith({
    ServiceType? service,
    HealthStatus? status,
    int? latencyMs,
    DateTime? lastCheckedAt,
    String? details,
    int? consecutiveFailures,
  }) {
    return ServiceHealth(
      service: service ?? this.service,
      status: status ?? this.status,
      latencyMs: latencyMs ?? this.latencyMs,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      details: details ?? this.details,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'service': service.key,
      'status': status.key,
      'latencyMs': latencyMs,
      'lastCheckedAt': lastCheckedAt.toIso8601String(),
      'details': details,
      'consecutiveFailures': consecutiveFailures,
    };
  }

  factory ServiceHealth.fromMap(Map<String, dynamic> map) {
    return ServiceHealth(
      service: ServiceType.fromString(map['service']?.toString()),
      status: HealthStatus.fromString(map['status']?.toString()),
      latencyMs: (map['latencyMs'] as num?)?.toInt() ?? 0,
      lastCheckedAt: map['lastCheckedAt'] != null
          ? DateTime.tryParse(map['lastCheckedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      details: map['details']?.toString() ?? 'Operational',
      consecutiveFailures: (map['consecutiveFailures'] as num?)?.toInt() ?? 0,
    );
  }
}
