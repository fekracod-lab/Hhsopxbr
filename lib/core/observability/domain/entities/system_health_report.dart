import 'package:flutter/foundation.dart';
import '../enums/observability_enums.dart';
import 'service_health.dart';

/// التقرير الشامل لصحة منظومة مدار بكافة خدماتها (System Health Report)
@immutable
class SystemHealthReport {
  final HealthStatus overallStatus;
  final Map<ServiceType, ServiceHealth> services;
  final DateTime timestamp;

  const SystemHealthReport({
    required this.overallStatus,
    required this.services,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'overallStatus': overallStatus.key,
      'services': services.map((k, v) => MapEntry(k.key, v.toMap())),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SystemHealthReport.fromMap(Map<String, dynamic> map) {
    final srvMap = map['services'] is Map ? Map<String, dynamic>.from(map['services'] as Map) : <String, dynamic>{};
    final parsedServices = <ServiceType, ServiceHealth>{};

    srvMap.forEach((k, v) {
      if (v is Map) {
        final sh = ServiceHealth.fromMap(Map<String, dynamic>.from(v));
        parsedServices[sh.service] = sh;
      }
    });

    return SystemHealthReport(
      overallStatus: HealthStatus.fromString(map['overallStatus']?.toString()),
      services: parsedServices,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
