import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/observability/presentation/screens/admin_operations_center_screen.dart';
import 'package:dalal_alqaim/core/observability/domain/entities/system_metrics_snapshot.dart';
import 'package:dalal_alqaim/core/observability/domain/entities/service_health.dart';
import 'package:dalal_alqaim/core/observability/domain/entities/system_health_report.dart';
import 'package:dalal_alqaim/core/observability/domain/entities/incident_record.dart';
import 'package:dalal_alqaim/core/observability/domain/entities/driver_live_operations_view.dart';
import 'package:dalal_alqaim/core/observability/domain/entities/operational_audit_record.dart';
import 'package:dalal_alqaim/core/observability/domain/enums/observability_enums.dart';
import 'package:dalal_alqaim/core/realtime/domain/enums/realtime_enums.dart';

void main() {
  group('Admin Operations Center Screen UI Tests', () {
    testWidgets('Renders KPI cards, health grid and switches tabs smoothly', (tester) async {
      final now = DateTime.now();

      final metrics = SystemMetricsSnapshot(
        snapshotId: 'snap_ui',
        onlineDrivers: 128,
        activeRides: 43,
        activeDeliveries: 87,
        timestamp: now,
      );

      final health = SystemHealthReport(
        overallStatus: HealthStatus.healthy,
        services: {
          ServiceType.firestore: ServiceHealth(
            service: ServiceType.firestore,
            status: HealthStatus.healthy,
            latencyMs: 14,
            lastCheckedAt: now,
          ),
        },
        timestamp: now,
      );

      final incident = IncidentRecord(
        incidentId: 'inc_102',
        title: 'Notification Latency Spike',
        severity: IncidentSeverity.high,
        affectedService: ServiceType.notifications,
        firstSeenAt: now,
        lastSeenAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final liveDriver = DriverLiveOperationsView(
        driverId: 'drv_123',
        presenceStatus: DriverPresenceState.available,
        gpsHealth: HealthStatus.healthy,
        lastHeartbeatAgeSeconds: 8,
        riskScore: 12,
        lastUpdatedAt: now,
      );

      final auditRecord = OperationalAuditRecord(
        auditId: 'audit_1',
        actorId: 'admin_omar',
        actorRole: 'SuperAdmin',
        action: AuditActionType.blockDriver,
        targetEntityId: 'drv_hacker',
        targetEntityType: 'Driver',
        reason: 'GPS spoofing detected',
        riskScore: 95,
        traceId: 'trace_1',
        timestamp: now,
        immutableHash: 'abc123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminOperationsCenterScreen(
            initialMetrics: metrics,
            initialHealth: health,
            initialIncidents: [incident],
            liveDrivers: [liveDriver],
            auditLogs: [auditRecord],
          ),
        ),
      );

      // Verify Header & Live badge
      expect(find.text('MADAR OPERATIONS CENTER'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);

      // Verify KPI Ribbon
      expect(find.text('128'), findsOneWidget); // Online drivers
      expect(find.text('43'), findsOneWidget);  // Active rides
      expect(find.text('87'), findsOneWidget);  // Active deliveries

      // Verify Overview Grid
      expect(find.text('Core Services Health Grid'), findsOneWidget);
      expect(find.text('FIRESTORE'), findsOneWidget);

      // Switch to Driver Telemetry tab
      await tester.tap(find.text('Driver Telemetry & Risk'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Driver #drv_123'), findsOneWidget);
      expect(find.text('Risk: 12'), findsOneWidget);

      // Switch to Incidents tab
      await tester.tap(find.text('Active Incidents (1)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Notification Latency Spike'), findsOneWidget);

      // Switch to Audit Log tab
      await tester.tap(find.text('Audit Log'));
      await tester.pumpAndSettle();
      expect(find.textContaining('admin_omar -> block_driver'), findsOneWidget);
    });
  });
}
