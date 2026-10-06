import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/realtime_event.dart';
import 'package:dalal_alqaim/core/realtime/domain/enums/realtime_enums.dart';
import 'package:dalal_alqaim/core/realtime/domain/services/connection_recovery_engine.dart';

void main() {
  group('Connection Recovery Engine Dedicated Tests', () {
    test('1. Queues events when disconnected and flushes on reconnect', () {
      final engine = ConnectionRecoveryEngine();
      expect(engine.status, equals(ConnectionStatus.connected));

      // Network goes down
      engine.updateStatus(ConnectionStatus.disconnected);
      expect(engine.status, equals(ConnectionStatus.disconnected));

      final ev1 = RealtimeEvent(
        eventId: 'ev_1',
        eventType: 'location_update',
        entityId: 'drv_1',
        sequenceNumber: 1,
        occurredAt: DateTime.now(),
      );

      final ev2 = RealtimeEvent(
        eventId: 'ev_2',
        eventType: 'location_update',
        entityId: 'drv_1',
        sequenceNumber: 2,
        occurredAt: DateTime.now(),
      );

      engine.enqueueOfflineEvent(ev1);
      engine.enqueueOfflineEvent(ev2);

      expect(engine.offlineQueue.length, equals(2));

      // Reconnect
      final flushed = engine.flushQueueOnReconnect();
      expect(engine.status, equals(ConnectionStatus.connected));
      expect(flushed.length, equals(2));
      expect(engine.offlineQueue.isEmpty, isTrue);
    });
  });
}
