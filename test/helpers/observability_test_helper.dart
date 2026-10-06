import 'package:dalal_alqaim/core/observability/domain/entities/trace_span.dart';
import 'package:dalal_alqaim/core/observability/domain/entities/system_metrics_snapshot.dart';
import 'package:dalal_alqaim/core/observability/domain/entities/system_health_report.dart';
import 'package:dalal_alqaim/core/observability/domain/entities/alert_record.dart';
import 'package:dalal_alqaim/core/observability/domain/entities/incident_record.dart';
import 'package:dalal_alqaim/core/observability/domain/entities/operational_audit_record.dart';
import 'package:dalal_alqaim/core/observability/domain/repositories/i_observability_repository.dart';

/// 🧪 مستودع ذاكرة افتراضي لاختبارات مركز العمليات والمراقبة الموحدة
class InMemoryObservabilityRepository implements IObservabilityRepository {
  final Map<String, TraceSpan> spans = {};
  final List<SystemMetricsSnapshot> metricsSnapshots = [];
  SystemHealthReport? latestHealthReport;
  final Map<String, AlertRecord> alerts = {};
  final Map<String, IncidentRecord> incidents = {};
  final List<OperationalAuditRecord> auditLogs = [];

  @override
  Future<void> saveSpan(TraceSpan span) async {
    spans[span.spanId] = span;
  }

  @override
  Future<List<TraceSpan>> getSpansByTraceId(String traceId) async {
    return spans.values.where((s) => s.traceId == traceId).toList();
  }

  @override
  Future<void> saveMetricsSnapshot(SystemMetricsSnapshot snapshot) async {
    metricsSnapshots.add(snapshot);
  }

  @override
  Future<SystemMetricsSnapshot?> getLatestMetricsSnapshot() async {
    return metricsSnapshots.isNotEmpty ? metricsSnapshots.last : null;
  }

  @override
  Future<void> saveHealthReport(SystemHealthReport report) async {
    latestHealthReport = report;
  }

  @override
  Future<SystemHealthReport?> getLatestHealthReport() async {
    return latestHealthReport;
  }

  @override
  Future<void> saveAlert(AlertRecord alert) async {
    alerts[alert.alertId] = alert;
  }

  @override
  Future<List<AlertRecord>> getActiveAlerts() async {
    return alerts.values.where((a) => a.status.key == 'active').toList();
  }

  @override
  Future<void> saveIncident(IncidentRecord incident) async {
    incidents[incident.incidentId] = incident;
  }

  @override
  Future<IncidentRecord?> getIncident(String incidentId) async {
    return incidents[incidentId];
  }

  @override
  Future<List<IncidentRecord>> getActiveIncidents() async {
    return incidents.values
        .where((i) => i.status.key != 'closed' && i.status.key != 'resolved')
        .toList();
  }

  @override
  Future<void> saveAuditRecord(OperationalAuditRecord auditRecord) async {
    auditLogs.add(auditRecord);
  }

  @override
  Future<List<OperationalAuditRecord>> getAuditLogsByEntity(String targetEntityId) async {
    return auditLogs.where((a) => a.targetEntityId == targetEntityId).toList();
  }

  void clear() {
    spans.clear();
    metricsSnapshots.clear();
    latestHealthReport = null;
    alerts.clear();
    incidents.clear();
    auditLogs.clear();
  }
}
