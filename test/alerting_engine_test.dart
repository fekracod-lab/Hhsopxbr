import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/observability/domain/entities/system_metrics_snapshot.dart';
import 'package:dalal_alqaim/core/observability/domain/enums/observability_enums.dart';
import 'package:dalal_alqaim/core/observability/domain/services/alerting_engine.dart';

void main() {
  group('Alerting Engine Dedicated Tests', () {
    test('1. Severe GPS drop with active drivers triggers HIGH alert', () {
      final engine = AlertingEngine();
      final now = DateTime.now();

      final badSnapshot = SystemMetricsSnapshot(
        snapshotId: 'snap_1',
        onlineDrivers: 25,
        gpsUpdateRatePerSec: 0.05, // Severely degraded (< 0.2)
        timestamp: now,
      );

      final alerts = engine.evaluateMetrics(badSnapshot, now: now);

      expect(alerts.length, equals(1));
      expect(alerts.first.severity, equals(AlertSeverity.high));
      expect(alerts.first.service, equals(ServiceType.realtimeTracking));
      expect(engine.activeAlerts.length, equals(1));
    });

    test('2. Critical surge in failed financial transactions triggers CRITICAL alert', () {
      final engine = AlertingEngine();
      final now = DateTime.now();

      final criticalSnapshot = SystemMetricsSnapshot(
        snapshotId: 'snap_crit',
        failedTransactionsCount: 7, // >= 5
        timestamp: now,
      );

      final alerts = engine.evaluateMetrics(criticalSnapshot, now: now);

      expect(alerts.any((a) => a.severity == AlertSeverity.critical), isTrue);
      final txAlert = alerts.firstWhere((a) => a.service == ServiceType.financialEngine);
      expect(txAlert.severity, equals(AlertSeverity.critical));
    });

    test('3. Deduplicates active alerts to avoid spamming the operations team', () {
      final engine = AlertingEngine();
      final now = DateTime.now();

      final badSnapshot = SystemMetricsSnapshot(
        snapshotId: 'snap_dup',
        onlineDrivers: 10,
        gpsUpdateRatePerSec: 0.05,
        timestamp: now,
      );

      // 1st evaluation -> creates alert
      final firstRun = engine.evaluateMetrics(badSnapshot, now: now);
      expect(firstRun.length, equals(1));

      // 2nd evaluation with same issue -> does not create duplicate active alert
      final secondRun = engine.evaluateMetrics(badSnapshot, now: now.add(const Duration(seconds: 5)));
      expect(secondRun.isEmpty, isTrue);
      expect(engine.activeAlerts.length, equals(1));
    });
  });
}
