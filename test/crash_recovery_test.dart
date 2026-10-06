import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/services/recovery_checkpoint_engine.dart';
import 'package:dalal_alqaim/core/resilience/services/crash_recovery_engine.dart';

void main() {
  group('Crash Recovery & Checkpoint Dedicated Tests', () {
    test('1. Creates checkpoint with verifiable SHA-256 integrity hash', () async {
      final engine = RecoveryCheckpointEngine();
      final now = DateTime(2026, 8, 29, 12, 0, 0);

      final checkpoint = await engine.saveCheckpoint(
        operationId: 'ride_active_500',
        domainType: 'ride',
        state: 'trip_started',
        version: 2,
        correlationId: 'driver_omar',
        payload: {'destination': 'Baghdad Mall', 'fare': 7500},
        now: now,
      );

      expect(checkpoint.integrityHash.length, equals(64)); // SHA-256 hex
      expect(engine.verifyCheckpointIntegrity(checkpoint), isTrue);
    });

    test('2. Reconciles state after app crash and adopts Server Authority if server version is higher', () async {
      final checkpointEngine = RecoveryCheckpointEngine();
      final crashRecoveryEngine = CrashRecoveryEngine(checkpointEngine: checkpointEngine);

      // Local state was version 1 before crash
      await checkpointEngine.saveCheckpoint(
        operationId: 'order_crash_1',
        domainType: 'order',
        state: 'preparing',
        version: 1,
        correlationId: 'user_1',
        payload: {'status': 'preparing'},
      );

      // Server had progressed to version 2 (delivering) during the crash
      final (restoredState, payload, mode) = await crashRecoveryEngine.reconcileAfterCrash(
        operationId: 'order_crash_1',
        serverState: 'delivering',
        serverVersion: 2,
        serverPayload: {'status': 'delivering', 'driverId': 'drv_1'},
      );

      expect(restoredState, equals('delivering')); // Server Authority wins
      expect(mode, equals('server_authoritative_sync'));
      expect(payload['driverId'], equals('drv_1'));
    });

    test('3. Reconciles and detects tampered local checkpoint by falling back to server authority', () async {
      final checkpointEngine = RecoveryCheckpointEngine();
      final crashRecoveryEngine = CrashRecoveryEngine(checkpointEngine: checkpointEngine);

      final original = await checkpointEngine.saveCheckpoint(
        operationId: 'ride_tampered',
        domainType: 'ride',
        state: 'requested',
        correlationId: 'user_2',
      );

      // Tamper with state without updating hash
      final tampered = original.copyWith(state: 'settled');
      checkpointEngine.saveRawCheckpoint(tampered);

      final (restoredState, _, mode) = await crashRecoveryEngine.reconcileAfterCrash(
        operationId: 'ride_tampered',
        serverState: 'matching',
        serverVersion: 1,
        serverPayload: {},
      );

      expect(restoredState, equals('matching'));
      expect(mode, equals('corrupted_local_fallback_to_server'));
    });
  });
}
