import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/observability/domain/entities/alert_record.dart';
import 'package:dalal_alqaim/core/observability/domain/enums/observability_enums.dart';
import 'package:dalal_alqaim/core/observability/domain/services/incident_engine.dart';

void main() {
  group('Incident Engine Dedicated Tests', () {
    test('1. Escalates high/critical alert to formal Incident with Open status', () {
      final engine = IncidentEngine();
      final now = DateTime.now();

      final highAlert = AlertRecord(
        alertId: 'alt_gps_drop',
        name: 'GPS Degradation',
        severity: AlertSeverity.high,
        metricName: 'gpsUpdateRatePerSec',
        threshold: 0.2,
        actualValue: 0.05,
        service: ServiceType.realtimeTracking,
        message: 'GPS updates dropped severely',
        triggeredAt: now,
      );

      final incident = engine.escalateAlertToIncident(
        alert: highAlert,
        traceIds: ['trace_1', 'trace_2'],
        affectedDriverIds: ['drv_1', 'drv_2'],
        now: now,
      );

      expect(incident, isNotNull);
      expect(incident!.severity, equals(IncidentSeverity.high));
      expect(incident.status, equals(IncidentStatus.open));
      expect(incident.affectedService, equals(ServiceType.realtimeTracking));
      expect(incident.traceIds.length, equals(2));
      expect(engine.activeIncidents.length, equals(1));
    });

    test('2. Manages full incident lifecycle (Acknowledge -> Mitigate -> Resolve)', () {
      final engine = IncidentEngine();
      final now = DateTime.now();

      final criticalAlert = AlertRecord(
        alertId: 'alt_tx_fail',
        name: 'Financial Failures',
        severity: AlertSeverity.critical,
        metricName: 'failedTransactions',
        threshold: 5,
        actualValue: 8,
        service: ServiceType.financialEngine,
        message: 'Critical transaction failure surge',
        triggeredAt: now,
      );

      final incident = engine.escalateAlertToIncident(alert: criticalAlert, now: now)!;

      // 1. Acknowledge
      final ack = engine.acknowledgeIncident(
        incidentId: incident.incidentId,
        adminId: 'admin_omar',
        now: now.add(const Duration(minutes: 1)),
      );
      expect(ack!.status, equals(IncidentStatus.acknowledged));
      expect(ack.assignedTo, equals('admin_omar'));

      // 2. Mitigate
      final mit = engine.recordMitigationStep(
        incidentId: incident.incidentId,
        mitigationAction: 'Switched to fallback payment gateway & flusher',
        now: now.add(const Duration(minutes: 3)),
      );
      expect(mit!.status, equals(IncidentStatus.mitigating));
      expect(mit.recoveryAttempts.length, equals(1));

      // 3. Resolve
      final res = engine.resolveIncident(
        incidentId: incident.incidentId,
        resolution: 'Payment gateway connection restored and verified',
        now: now.add(const Duration(minutes: 10)),
      );
      expect(res!.status, equals(IncidentStatus.resolved));
      expect(res.resolution, isNotNull);
      expect(engine.activeIncidents.isEmpty, isTrue); // Resolved is no longer active
    });
  });
}
