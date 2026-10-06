import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/driver_presence.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/driver_location.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/heartbeat_record.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/tracking_session.dart';
import 'package:dalal_alqaim/core/realtime/domain/enums/realtime_enums.dart';
import 'package:dalal_alqaim/core/risk/domain/entities/risk_score.dart';
import 'package:dalal_alqaim/core/risk/domain/enums/risk_enums.dart';
import 'package:dalal_alqaim/core/observability/domain/enums/observability_enums.dart';
import 'package:dalal_alqaim/core/observability/domain/services/driver_operations_aggregator.dart';

void main() {
  group('Driver Operations Aggregator Dedicated Tests (Cross-Engine 8.8 + 8.9)', () {
    test('1. Fuses presence, location, risk score, and tracking session into single view', () {
      final now = DateTime(2026, 8, 28, 12, 0, 0);

      final presence = DriverPresence(
        driverId: 'drv_10',
        state: DriverPresenceState.available,
        lastHeartbeatAt: now.subtract(const Duration(seconds: 5)),
        lastLocationUpdate: now.subtract(const Duration(seconds: 2)),
        updatedAt: now,
      );

      final location = DriverLocation(
        driverId: 'drv_10',
        latitude: 33.3152,
        longitude: 44.3661,
        confidence: LocationConfidence.valid,
        timestamp: now,
      );

      final heartbeat = HeartbeatRecord(
        heartbeatId: 'hb_10',
        driverId: 'drv_10',
        sessionId: 'sess_10',
        clientTimestamp: now.subtract(const Duration(seconds: 5)),
        serverTimestamp: now.subtract(const Duration(seconds: 5)),
        sequenceNumber: 42,
      );

      final tracking = TrackingSession(
        sessionId: 'trk_10',
        orderId: 'ord_10',
        serviceType: 'taxi',
        driverId: 'drv_10',
        customerId: 'cust_10',
        status: TrackingSessionStatus.active,
        destinationLat: 33.3500,
        destinationLng: 44.4000,
        destinationAddress: 'Al-Mansour, Baghdad',
        startedAt: now.subtract(const Duration(minutes: 5)),
      );

      final riskScore = RiskScore(
        rawScore: 12,
        normalizedScore: 12,
        riskLevel: RiskLevel.trusted,
        policyVersion: 'v1.0.0',
        calculatedAt: now,
      );

      final liveView = DriverOperationsAggregator.aggregateDriverOperations(
        driverId: 'drv_10',
        presence: presence,
        location: location,
        latestHeartbeat: heartbeat,
        activeTrackingSession: tracking,
        riskScore: riskScore,
        activeOrderIds: ['ord_10'],
        activeIncidentsCount: 0,
        now: now,
      );

      expect(liveView.driverId, equals('drv_10'));
      expect(liveView.presenceStatus, equals(DriverPresenceState.available));
      expect(liveView.gpsHealth, equals(HealthStatus.healthy));
      expect(liveView.lastHeartbeatAgeSeconds, equals(5));
      expect(liveView.trackingSessionActive, isTrue);
      expect(liveView.riskScore, equals(12));
      expect(liveView.connectionQuality, equals('stable'));
      expect(liveView.activeOrderIds, contains('ord_10'));
    });

    test('2. Accurately flags rejected GPS and stale connection in live view', () {
      final now = DateTime(2026, 8, 28, 12, 0, 0);

      final presence = DriverPresence(
        driverId: 'drv_bad',
        state: DriverPresenceState.busy,
        lastHeartbeatAt: now.subtract(const Duration(seconds: 40)),
        lastLocationUpdate: now.subtract(const Duration(seconds: 40)),
        updatedAt: now,
      );

      final badLocation = DriverLocation(
        driverId: 'drv_bad',
        latitude: 0.0,
        longitude: 0.0,
        confidence: LocationConfidence.rejected,
        timestamp: now,
      );

      final liveView = DriverOperationsAggregator.aggregateDriverOperations(
        driverId: 'drv_bad',
        presence: presence,
        location: badLocation,
        now: now,
      );

      expect(liveView.gpsHealth, equals(HealthStatus.unhealthy)); // Rejected GPS -> Unhealthy
      expect(liveView.connectionQuality, equals('disconnected')); // > 30s heartbeat age
    });
  });
}
