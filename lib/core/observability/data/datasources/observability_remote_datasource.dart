import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/trace_span.dart';
import '../../domain/entities/system_metrics_snapshot.dart';
import '../../domain/entities/system_health_report.dart';
import '../../domain/entities/alert_record.dart';
import '../../domain/entities/incident_record.dart';
import '../../domain/entities/operational_audit_record.dart';

/// مصدر البيانات البعيد لمنظومة المراقبة ومركز العمليات (Observability Remote Datasource)
class ObservabilityRemoteDatasource {
  final FirebaseFirestore? _customFirestore;

  ObservabilityRemoteDatasource({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  /// حفظ مقطع تتبع موزع
  Future<void> saveSpan(TraceSpan span) async {
    final docRef = _firestore.collection('observability_spans').doc(span.spanId);
    await docRef.set(span.toMap());
  }

  /// جلب مقاطع تتبع لمعاملة معينة
  Future<List<TraceSpan>> getSpansByTraceId(String traceId) async {
    final snap = await _firestore
        .collection('observability_spans')
        .where('traceId', isEqualTo: traceId)
        .get();

    return snap.docs
        .map((d) => TraceSpan.fromMap(d.data(), d.id))
        .toList();
  }

  /// حفظ لقطة المؤشرات
  Future<void> saveMetricsSnapshot(SystemMetricsSnapshot snapshot) async {
    final docRef = _firestore.collection('observability_metrics').doc(snapshot.snapshotId);
    await docRef.set(snapshot.toMap());
  }

  /// جلب أحدث لقطة مؤشرات
  Future<SystemMetricsSnapshot?> getLatestMetricsSnapshot() async {
    final snap = await _firestore
        .collection('observability_metrics')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return SystemMetricsSnapshot.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  /// حفظ تقرير صحة النظام
  Future<void> saveHealthReport(SystemHealthReport report) async {
    final docRef = _firestore.collection('system_health').doc('latest');
    await docRef.set(report.toMap());
  }

  /// جلب أحدث تقرير صحة
  Future<SystemHealthReport?> getLatestHealthReport() async {
    final doc = await _firestore.collection('system_health').doc('latest').get();
    if (!doc.exists || doc.data() == null) return null;
    return SystemHealthReport.fromMap(doc.data()!);
  }

  /// حفظ تنبيه
  Future<void> saveAlert(AlertRecord alert) async {
    final docRef = _firestore.collection('observability_alerts').doc(alert.alertId);
    await docRef.set(alert.toMap(), SetOptions(merge: true));
  }

  /// جلب التنبيهات النشطة
  Future<List<AlertRecord>> getActiveAlerts() async {
    final snap = await _firestore
        .collection('observability_alerts')
        .where('status', isEqualTo: 'active')
        .get();

    return snap.docs.map((d) => AlertRecord.fromMap(d.data(), d.id)).toList();
  }

  /// حفظ حادث تشغيلي
  Future<void> saveIncident(IncidentRecord incident) async {
    final docRef = _firestore.collection('observability_incidents').doc(incident.incidentId);
    await docRef.set(incident.toMap(), SetOptions(merge: true));
  }

  /// جلب حادث بالمعرف
  Future<IncidentRecord?> getIncident(String incidentId) async {
    final doc = await _firestore.collection('observability_incidents').doc(incidentId).get();
    if (!doc.exists || doc.data() == null) return null;
    return IncidentRecord.fromMap(doc.data()!, doc.id);
  }

  /// جلب الحوادث النشطة
  Future<List<IncidentRecord>> getActiveIncidents() async {
    final snap = await _firestore
        .collection('observability_incidents')
        .where('status', whereIn: ['open', 'acknowledged', 'investigating', 'mitigating'])
        .get();

    return snap.docs.map((d) => IncidentRecord.fromMap(d.data(), d.id)).toList();
  }

  /// حفظ سجل التدقيق الدائم (Append-Only)
  Future<void> saveAuditRecord(OperationalAuditRecord auditRecord) async {
    final docRef = _firestore.collection('operational_audit_log').doc(auditRecord.auditId);
    await docRef.set(auditRecord.toMap());
  }

  /// جلب سجلات التدقيق لكيان معين
  Future<List<OperationalAuditRecord>> getAuditLogsByEntity(String targetEntityId) async {
    final snap = await _firestore
        .collection('operational_audit_log')
        .where('targetEntityId', isEqualTo: targetEntityId)
        .orderBy('timestamp', descending: true)
        .get();

    return snap.docs.map((d) => OperationalAuditRecord.fromMap(d.data(), d.id)).toList();
  }
}
