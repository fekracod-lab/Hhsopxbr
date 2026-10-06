import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/tracking_session.dart';
import 'package:dalal_alqaim/core/realtime/domain/enums/realtime_enums.dart';
import 'package:dalal_alqaim/core/realtime/domain/services/reconciliation_engine.dart';

void main() {
  group('Reconciliation Engine Dedicated Tests', () {
    test('1. Authoritative server state overrides stale local state during reconnect', () {
      final local = TrackingSession(
        sessionId: 'sess_reconcile',
        orderId: 'ord_1',
        serviceType: 'taxi',
        driverId: 'drv_1',
        customerId: 'cust_1',
        status: TrackingSessionStatus.active,
        destinationLat: 33.32,
        destinationLng: 44.30,
        destinationAddress: 'Mansour',
        startedAt: DateTime.now(),
        version: 2,
      );

      final server = local.copyWith(
        status: TrackingSessionStatus.completed,
        version: 3,
      );

      final (effective, result) = ReconciliationEngine.reconcileTrackingSession(
        localSession: local,
        serverSession: server,
      );

      expect(effective.status, equals(TrackingSessionStatus.completed));
      expect(effective.version, equals(3));
      expect(result.resolvedConflicts.isNotEmpty, isTrue);
    });

    test('2. Handles missing session on server gracefully', () {
      final local = TrackingSession(
        sessionId: 'sess_missing',
        orderId: 'ord_1',
        serviceType: 'taxi',
        driverId: 'drv_1',
        customerId: 'cust_1',
        destinationLat: 33.32,
        destinationLng: 44.30,
        destinationAddress: 'Mansour',
        startedAt: DateTime.now(),
        version: 1,
      );

      final (effective, result) = ReconciliationEngine.reconcileTrackingSession(
        localSession: local,
        serverSession: null,
      );

      expect(effective.sessionId, equals('sess_missing'));
      expect(result.isConsistent, isFalse);
    });
  });
}
