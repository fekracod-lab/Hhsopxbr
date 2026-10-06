import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/realtime/domain/enums/realtime_enums.dart';
import 'package:dalal_alqaim/core/realtime/domain/services/heartbeat_engine.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

void main() {
  group('Driver Heartbeat Engine Dedicated Tests', () {
    test('1. Processes valid healthy heartbeat in sequence', () {
      final engine = HeartbeatEngine();
      final now = DateTime(2026, 8, 28, 12, 0, 0);

      final record = engine.processHeartbeat(
        heartbeatId: 'hb_1',
        driverId: 'drv_100',
        sessionId: 'sess_1',
        clientTimestamp: now,
        sequenceNumber: 1,
        serverTimestampOverride: now,
      );

      expect(record.status, equals(HeartbeatStatus.healthy));
      expect(record.sequenceNumber, equals(1));
    });

    test('2. Detects and marks duplicate heartbeat ID as rejected', () {
      final engine = HeartbeatEngine();
      final now = DateTime(2026, 8, 28, 12, 0, 0);

      final first = engine.processHeartbeat(
        heartbeatId: 'hb_dup',
        driverId: 'drv_100',
        sessionId: 'sess_1',
        clientTimestamp: now,
        sequenceNumber: 1,
        serverTimestampOverride: now,
      );
      expect(first.status, equals(HeartbeatStatus.healthy));

      final second = engine.processHeartbeat(
        heartbeatId: 'hb_dup', // Duplicate ID
        driverId: 'drv_100',
        sessionId: 'sess_1',
        clientTimestamp: now,
        sequenceNumber: 1,
        serverTimestampOverride: now,
      );
      expect(second.status, equals(HeartbeatStatus.rejected));
    });

    test('3. Rejects future timestamp drift exceeding threshold with SecurityViolationException', () {
      final engine = HeartbeatEngine();
      final serverNow = DateTime(2026, 8, 28, 12, 0, 0);
      final futureClient = serverNow.add(const Duration(minutes: 5)); // 5 minutes in future!

      expect(
        () => engine.processHeartbeat(
          heartbeatId: 'hb_future',
          driverId: 'drv_100',
          sessionId: 'sess_1',
          clientTimestamp: futureClient,
          sequenceNumber: 1,
          serverTimestampOverride: serverNow,
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('4. Flags out-of-order sequence number as delayed', () {
      final engine = HeartbeatEngine();
      final now = DateTime(2026, 8, 28, 12, 0, 0);

      engine.processHeartbeat(
        heartbeatId: 'hb_seq_5',
        driverId: 'drv_seq',
        sessionId: 'sess_1',
        clientTimestamp: now,
        sequenceNumber: 5,
        serverTimestampOverride: now,
      );

      final outOfOrder = engine.processHeartbeat(
        heartbeatId: 'hb_seq_3',
        driverId: 'drv_seq',
        sessionId: 'sess_1',
        clientTimestamp: now,
        sequenceNumber: 3, // Older sequence arriving late
        serverTimestampOverride: now,
      );

      expect(outOfOrder.status, equals(HeartbeatStatus.delayed));
    });
  });
}
