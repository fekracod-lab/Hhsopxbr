import '../../domain/entities/trace_span.dart';
import '../../domain/entities/system_metrics_snapshot.dart';
import '../../domain/entities/system_health_report.dart';
import '../../domain/entities/alert_record.dart';
import '../../domain/entities/incident_record.dart';
import '../../domain/entities/operational_audit_record.dart';
import '../../domain/repositories/i_observability_repository.dart';
import '../datasources/observability_remote_datasource.dart';

/// تطبيق مستودع المراقبة والعمليات (ObservabilityRepository)
class ObservabilityRepository implements IObservabilityRepository {
  final ObservabilityRemoteDatasource _remoteDatasource;

  ObservabilityRepository({ObservabilityRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? ObservabilityRemoteDatasource();

  @override
  Future<void> saveSpan(TraceSpan span) {
    return _remoteDatasource.saveSpan(span);
  }

  @override
  Future<List<TraceSpan>> getSpansByTraceId(String traceId) {
    return _remoteDatasource.getSpansByTraceId(traceId);
  }

  @override
  Future<void> saveMetricsSnapshot(SystemMetricsSnapshot snapshot) {
    return _remoteDatasource.saveMetricsSnapshot(snapshot);
  }

  @override
  Future<SystemMetricsSnapshot?> getLatestMetricsSnapshot() {
    return _remoteDatasource.getLatestMetricsSnapshot();
  }

  @override
  Future<void> saveHealthReport(SystemHealthReport report) {
    return _remoteDatasource.saveHealthReport(report);
  }

  @override
  Future<SystemHealthReport?> getLatestHealthReport() {
    return _remoteDatasource.getLatestHealthReport();
  }

  @override
  Future<void> saveAlert(AlertRecord alert) {
    return _remoteDatasource.saveAlert(alert);
  }

  @override
  Future<List<AlertRecord>> getActiveAlerts() {
    return _remoteDatasource.getActiveAlerts();
  }

  @override
  Future<void> saveIncident(IncidentRecord incident) {
    return _remoteDatasource.saveIncident(incident);
  }

  @override
  Future<IncidentRecord?> getIncident(String incidentId) {
    return _remoteDatasource.getIncident(incidentId);
  }

  @override
  Future<List<IncidentRecord>> getActiveIncidents() {
    return _remoteDatasource.getActiveIncidents();
  }

  @override
  Future<void> saveAuditRecord(OperationalAuditRecord auditRecord) {
    return _remoteDatasource.saveAuditRecord(auditRecord);
  }

  @override
  Future<List<OperationalAuditRecord>> getAuditLogsByEntity(String targetEntityId) {
    return _remoteDatasource.getAuditLogsByEntity(targetEntityId);
  }
}
