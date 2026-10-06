import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/driver_presence.dart';
import 'package:dalal_alqaim/core/realtime/domain/enums/realtime_enums.dart';
import 'package:dalal_alqaim/core/realtime/domain/services/driver_presence_engine.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

void main() {
  group('Driver Presence Engine Dedicated Tests', () {
    test('1. Checks dispatch eligibility accurately based on state, active orders, and heartbeat', () {
      final now = DateTime(2026, 8, 28, 12, 0, 0);

      // Available + 0 active orders + fresh heartbeat -> Eligible!
      final eligiblePresence = DriverPresence(
        driverId: 'drv_1',
        state: DriverPresenceState.available,
        lastHeartbeatAt: now.subtract(const Duration(seconds: 20)),
        lastLocationUpdate: now.subtract(const Duration(seconds: 20)),
        activeOrdersCount: 0,
        updatedAt: now,
      );
      expect(DriverPresenceEngine.isEligibleForDispatch(presence: eligiblePresence, now: now), isTrue);

      // Busy with active order -> Ineligible!
      final busyPresence = eligiblePresence.copyWith(activeOrdersCount: 1);
      expect(DriverPresenceEngine.isEligibleForDispatch(presence: busyPresence, now: now), isFalse);

      // Offline -> Ineligible!
      final offlinePresence = eligiblePresence.copyWith(state: DriverPresenceState.offline);
      expect(DriverPresenceEngine.isEligibleForDispatch(presence: offlinePresence, now: now), isFalse);

      // Stale heartbeat (> 90s) -> Ineligible!
      final stalePresence = eligiblePresence.copyWith(
        lastHeartbeatAt: now.subtract(const Duration(seconds: 120)),
      );
      expect(DriverPresenceEngine.isEligibleForDispatch(presence: stalePresence, now: now), isFalse);
    });

    test('2. Automatically switches to Busy if driver has active orders', () {
      final presence = DriverPresence(
        driverId: 'drv_2',
        state: DriverPresenceState.available,
        lastHeartbeatAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
        activeOrdersCount: 0,
        updatedAt: DateTime.now(),
      );

      final updated = DriverPresenceEngine.transitionState(
        current: presence,
        nextState: DriverPresenceState.available,
        newActiveOrdersCount: 1,
      );

      expect(updated.state, equals(DriverPresenceState.busy));
    });

    test('3. Prevents suspended driver from transitioning to available', () {
      final suspendedPresence = DriverPresence(
        driverId: 'drv_banned',
        state: DriverPresenceState.suspended,
        lastHeartbeatAt: DateTime.now(),
        lastLocationUpdate: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () => DriverPresenceEngine.transitionState(
          current: suspendedPresence,
          nextState: DriverPresenceState.available,
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });
  });
}
