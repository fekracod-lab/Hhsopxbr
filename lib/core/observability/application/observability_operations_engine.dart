import '../domain/entities/operational_audit_record.dart';
import '../domain/entities/driver_live_operations_view.dart';
import '../domain/enums/observability_enums.dart';
import '../domain/services/distributed_tracing_engine.dart';
import '../domain/services/metrics_engine.dart';
import '../domain/services/health_monitor_engine.dart';
import '../domain/services/alerting_engine.dart';
import '../domain/services/incident_engine.dart';
import '../domain/services/audit_trail_engine.dart';
import '../domain/services/driver_operations_aggregator.dart';
import '../domain/repositories/i_observability_repository.dart';
import '../data/repositories/observability_repository.dart';

import 'package:dalal_alqaim/core/orchestration/domain/services/domain_event_bus.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/domain_event.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/driver_presence.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/driver_location.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/heartbeat_record.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/tracking_session.dart';
import 'package:dalal_alqaim/core/risk/domain/entities/risk_score.dart';

/// المحرك المركزي لمركز العمليات والمراقبة الموحدة (Observability & Admin Operations Engine)
class ObservabilityOperationsEngine {
  static ObservabilityOperationsEngine? _instance;
  static ObservabilityOperationsEngine get instance =>
      _instance ??= ObservabilityOperationsEngine();

  final IObservabilityRepository _repository;
  final DistributedTracingEngine _tracingEngine;
  final MetricsEngine _metricsEngine;
  final HealthMonitorEngine _healthMonitorEngine;
  final AlertingEngine _alertingEngine;
  final IncidentEngine _incidentEngine;
  final DomainEventBus _eventBus;

  ObservabilityOperationsEngine({
    IObservabilityRepository? repository,
    DistributedTracingEngine? tracingEngine,
    MetricsEngine? metricsEngine,
    HealthMonitorEngine? healthMonitorEngine,
    AlertingEngine? alertingEngine,
    IncidentEngine? incidentEngine,
    DomainEventBus? eventBus,
  }) : _repository = repository ?? ObservabilityRepository(),
        _tracingEngine = tracingEngine ?? DistributedTracingEngine(),
        _metricsEngine = metricsEngine ?? MetricsEngine(),
        _healthMonitorEngine = healthMonitorEngine ?? HealthMonitorEngine(),
        _alertingEngine = alertingEngine ?? AlertingEngine(),
        _incidentEngine = incidentEngine ?? IncidentEngine(),
        _eventBus = eventBus ?? DomainEventBus.instance {
    _subscribeToDomainEvents();
  }

  DistributedTracingEngine get tracingEngine => _tracingEngine;
  MetricsEngine get metricsEngine => _metricsEngine;
  HealthMonitorEngine get healthMonitorEngine => _healthMonitorEngine;
  AlertingEngine get alertingEngine => _alertingEngine;
  IncidentEngine get incidentEngine => _incidentEngine;

  void _subscribeToDomainEvents() {
    _eventBus.subscribe('OrderCreated', (event) async {
      _metricsEngine.recordOrderCreated(now: event.occurredAt);
    });

    _eventBus.subscribe('DriverPresenceUpdated', (event) async {
      final payload = event.payload;
      _metricsEngine.updateDriverCounts(
        online: (payload['online'] as num?)?.toInt() ?? 0,
        available: (payload['available'] as num?)?.toInt() ?? 0,
        busy: (payload['busy'] as num?)?.toInt() ?? 0,
      );
    });

    _eventBus.subscribe('RiskEvaluationCreated', (event) async {
      final payload = event.payload;
      final decision = payload['decision']?.toString();
      if (decision == 'block') {
        // Record block
      }
    });

    _eventBus.subscribe('IncidentCreated', (event) async {
      // Handled internally
    });
  }

  /// تنفيذ فحص دوري للمؤشرات والتحقق من التنبيهات وتصعيد الحوادث
  Future<void> runObservabilityTick({DateTime? now}) async {
    final currentTime = now ?? DateTime.now();

    // 1. توليد لقطة المؤشرات
    final snapshot = _metricsEngine.generateSnapshot(now: currentTime);
    await _repository.saveMetricsSnapshot(snapshot);

    // 2. فحص التنبيهات
    final triggeredAlerts = _alertingEngine.evaluateMetrics(snapshot, now: currentTime);
    for (final alert in triggeredAlerts) {
      await _repository.saveAlert(alert);

      // 3. تصعيد التنبيهات العالية والحرجة إلى حوادث تشغيلية
      if (alert.severity == AlertSeverity.high || alert.severity == AlertSeverity.critical) {
        final incident = _incidentEngine.escalateAlertToIncident(
          alert: alert,
          now: currentTime,
        );
        if (incident != null) {
          await _repository.saveIncident(incident);

          await _eventBus.publish(
            DomainEvent(
              eventId: 'evt-inc-${incident.incidentId}',
              eventType: 'IncidentCreated',
              aggregateId: incident.incidentId,
              aggregateType: 'Incident',
              transactionId: 'tx-obs',
              correlationId: 'corr-obs',
              occurredAt: currentTime,
              payload: incident.toMap(),
            ),
          );
        }
      }
    }

    // 4. حفظ تقرير الصحة
    final healthReport = _healthMonitorEngine.generateReport(now: currentTime);
    await _repository.saveHealthReport(healthReport);
  }

  /// تسجيل إجراء تدقيق إداري دائم ومشفر
  Future<OperationalAuditRecord> logAuditAction({
    required String actorId,
    required String actorRole,
    required AuditActionType action,
    required String targetEntityId,
    required String targetEntityType,
    required String reason,
    int riskScore = 0,
    required String traceId,
    Map<String, dynamic> beforeState = const {},
    Map<String, dynamic> afterState = const {},
    DateTime? now,
  }) async {
    final auditRecord = AuditTrailEngine.createAuditRecord(
      actorId: actorId,
      actorRole: actorRole,
      action: action,
      targetEntityId: targetEntityId,
      targetEntityType: targetEntityType,
      reason: reason,
      riskScore: riskScore,
      traceId: traceId,
      beforeState: beforeState,
      afterState: afterState,
      now: now,
    );

    await _repository.saveAuditRecord(auditRecord);

    await _eventBus.publish(
      DomainEvent(
        eventId: 'evt-audit-${auditRecord.auditId}',
        eventType: 'AuditRecordCreated',
        aggregateId: auditRecord.auditId,
        aggregateType: 'AuditLog',
        transactionId: 'tx-audit',
        correlationId: traceId,
        occurredAt: auditRecord.timestamp,
        payload: auditRecord.toMap(),
      ),
    );

    return auditRecord;
  }

  /// جلب الرؤية الموحدة لعمليات السائق الحية
  DriverLiveOperationsView getDriverLiveOperationsView({
    required String driverId,
    required DriverPresence presence,
    DriverLocation? location,
    HeartbeatRecord? latestHeartbeat,
    TrackingSession? activeTrackingSession,
    RiskScore? riskScore,
    List<String> activeOrderIds = const [],
    int activeIncidentsCount = 0,
    DateTime? now,
  }) {
    return DriverOperationsAggregator.aggregateDriverOperations(
      driverId: driverId,
      presence: presence,
      location: location,
      latestHeartbeat: latestHeartbeat,
      activeTrackingSession: activeTrackingSession,
      riskScore: riskScore,
      activeOrderIds: activeOrderIds,
      activeIncidentsCount: activeIncidentsCount,
      now: now,
    );
  }
}
