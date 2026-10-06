import '../entities/alert_record.dart';
import '../entities/system_metrics_snapshot.dart';
import '../enums/observability_enums.dart';

/// محرك رصد التنبيهات التشغيلية والشذوذ الإحصائي (Alerting Engine)
class AlertingEngine {
  final Map<String, AlertRecord> _activeAlerts = {}; // key: alertKey (e.g. 'gps_drop:realtimeTracking')
  final List<AlertRecord> _alertHistory = [];

  AlertingEngine();

  List<AlertRecord> get activeAlerts => _activeAlerts.values.toList();
  List<AlertRecord> get alertHistory => List.unmodifiable(_alertHistory);

  /// فحص لقطة المؤشرات العامة وتوليد التنبيهات اللازمة
  List<AlertRecord> evaluateMetrics(SystemMetricsSnapshot snapshot, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final newTriggeredAlerts = <AlertRecord>[];

    // 1. فحص هبوط تحديثات الـ GPS مع وجود سائقين أونلاين
    if (snapshot.onlineDrivers > 0 && snapshot.gpsUpdateRatePerSec < 0.2) {
      _triggerOrUpdateAlert(
        key: 'gps_drop:${ServiceType.realtimeTracking.key}',
        name: 'GPS Update Rate Degradation',
        severity: AlertSeverity.high,
        metricName: 'gpsUpdateRatePerSec',
        threshold: 0.2,
        actualValue: snapshot.gpsUpdateRatePerSec,
        service: ServiceType.realtimeTracking,
        message: 'GPS updates dropped severely (${snapshot.gpsUpdateRatePerSec} updates/s) for ${snapshot.onlineDrivers} active drivers',
        now: currentTime,
        collector: newTriggeredAlerts,
      );
    } else {
      _resolveAlert('gps_drop:${ServiceType.realtimeTracking.key}', now: currentTime);
    }

    // 2. فحص نسبة فشل المعاملات المالية
    if (snapshot.failedTransactionsCount >= 5) {
      _triggerOrUpdateAlert(
        key: 'failed_tx:${ServiceType.financialEngine.key}',
        name: 'High Financial Transaction Failures',
        severity: AlertSeverity.critical,
        metricName: 'failedTransactionsCount',
        threshold: 5.0,
        actualValue: snapshot.failedTransactionsCount.toDouble(),
        service: ServiceType.financialEngine,
        message: 'Critical surge in failed financial transactions (${snapshot.failedTransactionsCount} failures)',
        now: currentTime,
        collector: newTriggeredAlerts,
      );
    }

    // 3. فحص هبوط نجاح النبضات
    if (snapshot.onlineDrivers > 0 && snapshot.heartbeatSuccessRate < 0.8) {
      _triggerOrUpdateAlert(
        key: 'heartbeat_drop:${ServiceType.realtimeTracking.key}',
        name: 'Heartbeat Failure Surge',
        severity: AlertSeverity.medium,
        metricName: 'heartbeatSuccessRate',
        threshold: 0.8,
        actualValue: snapshot.heartbeatSuccessRate,
        service: ServiceType.realtimeTracking,
        message: 'Driver heartbeat success rate dropped to ${(snapshot.heartbeatSuccessRate * 100).round()}%',
        now: currentTime,
        collector: newTriggeredAlerts,
      );
    } else {
      _resolveAlert('heartbeat_drop:${ServiceType.realtimeTracking.key}', now: currentTime);
    }

    return newTriggeredAlerts;
  }

  void _triggerOrUpdateAlert({
    required String key,
    required String name,
    required AlertSeverity severity,
    required String metricName,
    required double threshold,
    required double actualValue,
    required ServiceType service,
    required String message,
    required DateTime now,
    required List<AlertRecord> collector,
  }) {
    if (_activeAlerts.containsKey(key)) {
      // Alert already active -> avoid duplicate noise
      return;
    }

    final alert = AlertRecord(
      alertId: 'alt-$key-${now.millisecondsSinceEpoch}',
      name: name,
      severity: severity,
      status: AlertStatus.active,
      metricName: metricName,
      threshold: threshold,
      actualValue: actualValue,
      service: service,
      message: message,
      triggeredAt: now,
    );

    _activeAlerts[key] = alert;
    _alertHistory.add(alert);
    collector.add(alert);
  }

  void _resolveAlert(String key, {DateTime? now}) {
    final active = _activeAlerts.remove(key);
    if (active != null) {
      final resolved = active.copyWith(
        status: AlertStatus.resolved,
        resolvedAt: now ?? DateTime.now(),
      );
      _alertHistory.add(resolved);
    }
  }

  void clear() {
    _activeAlerts.clear();
    _alertHistory.clear();
  }
}
