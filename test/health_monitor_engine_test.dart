import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/observability/domain/enums/observability_enums.dart';
import 'package:dalal_alqaim/core/observability/domain/services/health_monitor_engine.dart';

void main() {
  group('Health Monitor Engine Dedicated Tests', () {
    test('1. Initial state is all Healthy', () {
      final engine = HealthMonitorEngine();
      final report = engine.generateReport();
      expect(report.overallStatus, equals(HealthStatus.healthy));
      expect(report.services.values.every((s) => s.status == HealthStatus.healthy), isTrue);
    });

    test('2. Single probe failure causes Degraded; 3 failures cause Unhealthy', () {
      final engine = HealthMonitorEngine();

      // 1st failure -> Degraded
      final s1 = engine.recordProbeResult(
        service: ServiceType.notifications,
        isHealthy: false,
        latencyMs: 1200,
      );
      expect(s1.status, equals(HealthStatus.degraded));
      expect(engine.generateReport().overallStatus, equals(HealthStatus.degraded));

      // 2nd failure -> still Degraded
      engine.recordProbeResult(
        service: ServiceType.notifications,
        isHealthy: false,
        latencyMs: 1500,
      );

      // 3rd failure -> Unhealthy!
      final s3 = engine.recordProbeResult(
        service: ServiceType.notifications,
        isHealthy: false,
        latencyMs: 2500,
      );
      expect(s3.status, equals(HealthStatus.unhealthy));
      expect(engine.generateReport().overallStatus, equals(HealthStatus.unhealthy));
    });

    test('3. Successful probe after failures auto-recovers service to Healthy', () {
      final engine = HealthMonitorEngine();

      // Degrade service
      engine.recordProbeResult(
        service: ServiceType.firestore,
        isHealthy: false,
        latencyMs: 1000,
      );
      expect(engine.generateReport().overallStatus, equals(HealthStatus.degraded));

      // Successful recovery probe
      final recovered = engine.recordProbeResult(
        service: ServiceType.firestore,
        isHealthy: true,
        latencyMs: 25,
      );
      expect(recovered.status, equals(HealthStatus.healthy));
      expect(recovered.consecutiveFailures, equals(0));
      expect(engine.generateReport().overallStatus, equals(HealthStatus.healthy));
    });
  });
}
