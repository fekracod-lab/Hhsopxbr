import '../entities/service_health.dart';
import '../entities/system_health_report.dart';
import '../enums/observability_enums.dart';

/// محرك مراقبة صحة التبعيات والخدمات والتعافي التلقائي (Health Monitor Engine)
class HealthMonitorEngine {
  final Map<ServiceType, ServiceHealth> _serviceStatuses = {};

  HealthMonitorEngine() {
    _initializeDefaults();
  }

  void _initializeDefaults() {
    final now = DateTime.now();
    for (final service in ServiceType.values) {
      _serviceStatuses[service] = ServiceHealth(
        service: service,
        status: HealthStatus.healthy,
        latencyMs: 15,
        lastCheckedAt: now,
        details: 'Service operational and responding normally',
      );
    }
  }

  /// تسجيل نتيجة فحص صحة خدمة معينة
  ServiceHealth recordProbeResult({
    required ServiceType service,
    required bool isHealthy,
    required int latencyMs,
    String? details,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final current = _serviceStatuses[service] ??
        ServiceHealth(
          service: service,
          lastCheckedAt: currentTime,
        );

    ServiceHealth updated;

    if (isHealthy) {
      // تعافي الخدمة واستقرارها (Self-Healing / Recovery)
      updated = current.copyWith(
        status: HealthStatus.healthy,
        latencyMs: latencyMs,
        lastCheckedAt: currentTime,
        details: details ?? 'Service operational and healthy',
        consecutiveFailures: 0,
      );
    } else {
      final failures = current.consecutiveFailures + 1;
      final newStatus = failures >= 3
          ? HealthStatus.unhealthy
          : HealthStatus.degraded;

      updated = current.copyWith(
        status: newStatus,
        latencyMs: latencyMs,
        lastCheckedAt: currentTime,
        details: details ?? 'Probe failed ($failures consecutive failures)',
        consecutiveFailures: failures,
      );
    }

    _serviceStatuses[service] = updated;
    return updated;
  }

  /// إنشاء تقرير صحة شامل لمنظومة مدار
  SystemHealthReport generateReport({DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    var overall = HealthStatus.healthy;

    for (final health in _serviceStatuses.values) {
      if (health.status == HealthStatus.unhealthy) {
        overall = HealthStatus.unhealthy;
        break; // Unhealthy overrides all
      } else if (health.status == HealthStatus.degraded) {
        overall = HealthStatus.degraded;
      }
    }

    return SystemHealthReport(
      overallStatus: overall,
      services: Map<ServiceType, ServiceHealth>.from(_serviceStatuses),
      timestamp: currentTime,
    );
  }

  void reset() {
    _serviceStatuses.clear();
    _initializeDefaults();
  }
}
