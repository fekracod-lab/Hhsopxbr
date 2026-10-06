import '../entities/alert_record.dart';
import '../entities/incident_record.dart';
import '../enums/observability_enums.dart';

/// محرك إدارة وتصعيد وحل الحوادث التشغيلية (Incident Management Engine)
class IncidentEngine {
  final Map<String, IncidentRecord> _incidents = {};

  IncidentEngine();

  List<IncidentRecord> get activeIncidents => _incidents.values
      .where((i) => i.status != IncidentStatus.closed && i.status != IncidentStatus.resolved)
      .toList();

  List<IncidentRecord> get allIncidents => _incidents.values.toList();

  /// تصعيد التنبيه الحرج أو العالي إلى حادث تشغيلي رسمي
  IncidentRecord? escalateAlertToIncident({
    required AlertRecord alert,
    List<String> traceIds = const [],
    List<String> affectedUserIds = const [],
    List<String> affectedDriverIds = const [],
    DateTime? now,
  }) {
    if (alert.severity != AlertSeverity.high && alert.severity != AlertSeverity.critical) {
      return null;
    }

    final currentTime = now ?? DateTime.now();
    final incidentSeverity = alert.severity == AlertSeverity.critical
        ? IncidentSeverity.critical
        : IncidentSeverity.high;

    final incidentId = 'inc-${alert.service.key}-${currentTime.millisecondsSinceEpoch}';

    final incident = IncidentRecord(
      incidentId: incidentId,
      title: 'Incident: ${alert.name}',
      severity: incidentSeverity,
      status: IncidentStatus.open,
      affectedService: alert.service,
      firstSeenAt: alert.triggeredAt,
      lastSeenAt: currentTime,
      traceIds: traceIds,
      evidence: [alert.message],
      affectedUserIds: affectedUserIds,
      affectedDriverIds: affectedDriverIds,
      createdAt: currentTime,
      updatedAt: currentTime,
    );

    _incidents[incidentId] = incident;
    return incident;
  }

  /// إقرار واستلام الحادث من قبل المشرف (Acknowledge)
  IncidentRecord? acknowledgeIncident({
    required String incidentId,
    required String adminId,
    DateTime? now,
  }) {
    final incident = _incidents[incidentId];
    if (incident == null) return null;

    final updated = incident.copyWith(
      status: IncidentStatus.acknowledged,
      assignedTo: adminId,
      updatedAt: now ?? DateTime.now(),
    );

    _incidents[incidentId] = updated;
    return updated;
  }

  /// تسجيل إجراء تخفيف أو تعافي للحادث (Mitigation Record)
  IncidentRecord? recordMitigationStep({
    required String incidentId,
    required String mitigationAction,
    DateTime? now,
  }) {
    final incident = _incidents[incidentId];
    if (incident == null) return null;

    final updatedAttempts = List<String>.from(incident.recoveryAttempts)..add(mitigationAction);

    final updated = incident.copyWith(
      status: IncidentStatus.mitigating,
      recoveryAttempts: updatedAttempts,
      updatedAt: now ?? DateTime.now(),
    );

    _incidents[incidentId] = updated;
    return updated;
  }

  /// حل الحادث وتوثيق سبب المعالجة (Resolve)
  IncidentRecord? resolveIncident({
    required String incidentId,
    required String resolution,
    DateTime? now,
  }) {
    final incident = _incidents[incidentId];
    if (incident == null) return null;

    final updated = incident.copyWith(
      status: IncidentStatus.resolved,
      resolution: resolution,
      updatedAt: now ?? DateTime.now(),
    );

    _incidents[incidentId] = updated;
    return updated;
  }

  void clear() {
    _incidents.clear();
  }
}
