import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/observability/application/observability_operations_engine.dart';
import 'package:dalal_alqaim/core/observability/domain/enums/observability_enums.dart';
import 'package:dalal_alqaim/core/orchestration/domain/services/domain_event_bus.dart';
import 'helpers/observability_test_helper.dart';

void main() {
  group('Observability Operations Engine Application Facade Tests', () {
    late InMemoryObservabilityRepository repo;
    late DomainEventBus eventBus;
    late ObservabilityOperationsEngine engine;

    setUp(() {
      repo = InMemoryObservabilityRepository();
      eventBus = DomainEventBus();
      engine = ObservabilityOperationsEngine(
        repository: repo,
        eventBus: eventBus,
      );
    });

    test('1. Runs observability tick, saves metrics and publishes health report', () async {
      final now = DateTime.now();

      engine.metricsEngine.updateDriverCounts(online: 40, available: 25, busy: 15);
      engine.metricsEngine.recordOrderCreated(now: now);

      await engine.runObservabilityTick(now: now);

      expect(repo.metricsSnapshots.isNotEmpty, isTrue);
      expect(repo.latestHealthReport, isNotNull);
      expect(repo.latestHealthReport!.overallStatus, equals(HealthStatus.healthy));
    });

    test('2. Logs tamper-proof audit action and stores in repository with SHA-256', () async {
      final audit = await engine.logAuditAction(
        actorId: 'admin_security',
        actorRole: 'OpsLead',
        action: AuditActionType.blockDriver,
        targetEntityId: 'drv_hacker',
        targetEntityType: 'Driver',
        reason: 'GPS tampering detected by FakeLocationEngine',
        riskScore: 92,
        traceId: 'trace_audit_999',
      );

      expect(audit.actorId, equals('admin_security'));
      expect(audit.action, equals(AuditActionType.blockDriver));
      expect(audit.immutableHash.length, equals(64));
      expect(repo.auditLogs.length, equals(1));
    });

    test('3. Observability tick escalates critical financial anomaly into Incident and publishes DomainEvent', () async {
      final now = DateTime.now();

      // Trigger 6 failed transactions -> threshold breach
      for (int i = 0; i < 6; i++) {
        engine.metricsEngine.incrementFailedTransactions();
      }

      await engine.runObservabilityTick(now: now);

      expect(repo.alerts.isNotEmpty, isTrue);
      expect(repo.incidents.isNotEmpty, isTrue);
      final inc = repo.incidents.values.first;
      expect(inc.severity, equals(IncidentSeverity.critical));
      expect(inc.affectedService, equals(ServiceType.financialEngine));
    });
  });
}
