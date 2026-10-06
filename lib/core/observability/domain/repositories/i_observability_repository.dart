import '../entities/trace_span.dart';
import '../entities/system_metrics_snapshot.dart';
import '../entities/system_health_report.dart';
import '../entities/alert_record.dart';
import '../entities/incident_record.dart';
import '../entities/operational_audit_record.dart';

/// العقد التجريدي لمستودع المراقبة والعمليات (IObservabilityRepository)
abstract class IObservabilityRepository {
  /// حفظ مقطع تتبع موزع
  Future<void> saveSpan(TraceSpan span);

  /// جلب مقاطع تتبع لمعاملة معينة
  Future<List<TraceSpan>> getSpansByTraceId(String traceId);

  /// حفظ لقطة المؤشرات العامة
  Future<void> saveMetricsSnapshot(SystemMetricsSnapshot snapshot);

  /// جلب أحدث لقطة مؤشرات عامة
  Future<SystemMetricsSnapshot?> getLatestMetricsSnapshot();

  /// حفظ تقرير صحة النظام
  Future<void> saveHealthReport(SystemHealthReport report);

  /// جلب أحدث تقرير صحة للنظام
  Future<SystemHealthReport?> getLatestHealthReport();

  /// حفظ وتحديث سجل تنبيه تشغيلي
  Future<void> saveAlert(AlertRecord alert);

  /// جلب التنبيهات النشطة حالياً
  Future<List<AlertRecord>> getActiveAlerts();

  /// حفظ وتحديث سجل حادث تشغيلي
  Future<void> saveIncident(IncidentRecord incident);

  /// جلب سجل حادث بالمعرف
  Future<IncidentRecord?> getIncident(String incidentId);

  /// جلب الحوادث التشغيلية النشطة
  Future<List<IncidentRecord>> getActiveIncidents();

  /// حفظ سجل تدقيق عملياتي دائم غير قابل للتعديل (Append-Only)
  Future<void> saveAuditRecord(OperationalAuditRecord auditRecord);

  /// جلب سجلات التدقيق لكيان معين
  Future<List<OperationalAuditRecord>> getAuditLogsByEntity(String targetEntityId);
}
