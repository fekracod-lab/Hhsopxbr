import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/realtime/domain/enums/realtime_enums.dart';
import 'package:dalal_alqaim/core/realtime/domain/services/realtime_event_ordering_engine.dart';

void main() {
  group('Realtime Event Ordering Engine Dedicated Tests', () {
    test('1. Evaluates strict monotonic sequence and detects duplicates/gaps', () {
      final engine = RealtimeEventOrderingEngine();
      const entityId = 'trip_100';

      // 1. First event
      expect(
        engine.evaluateSequence(entityId: entityId, incomingSequence: 1),
        equals(EventSequenceStatus.inOrder),
      );

      // 2. Next sequential event
      expect(
        engine.evaluateSequence(entityId: entityId, incomingSequence: 2),
        equals(EventSequenceStatus.inOrder),
      );

      // 3. Duplicate event (replayed seq 2)
      expect(
        engine.evaluateSequence(entityId: entityId, incomingSequence: 2),
        equals(EventSequenceStatus.duplicate),
      );

      // 4. Stale event (seq 1 arriving late)
      expect(
        engine.evaluateSequence(entityId: entityId, incomingSequence: 1),
        equals(EventSequenceStatus.stale),
      );

      // 5. Sequence Gap (seq 5 arriving when expecting 3)
      expect(
        engine.evaluateSequence(entityId: entityId, incomingSequence: 5),
        equals(EventSequenceStatus.gapDetected),
      );
    });
  });
}
