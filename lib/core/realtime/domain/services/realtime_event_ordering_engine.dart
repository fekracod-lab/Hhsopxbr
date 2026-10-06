import '../enums/realtime_enums.dart';

/// محرك حماية ترتيب وتسلسل الأحداث اللحظية (Realtime Event Ordering Engine)
class RealtimeEventOrderingEngine {
  final Map<String, int> _entitySequences = {};

  RealtimeEventOrderingEngine();

  /// فحص تسلسل الحدث الوارد بالنسبة لكيان معين
  EventSequenceStatus evaluateSequence({
    required String entityId,
    required int incomingSequence,
  }) {
    if (!_entitySequences.containsKey(entityId)) {
      _entitySequences[entityId] = incomingSequence;
      return EventSequenceStatus.inOrder;
    }

    final currentSeq = _entitySequences[entityId]!;

    if (incomingSequence == currentSeq + 1) {
      _entitySequences[entityId] = incomingSequence;
      return EventSequenceStatus.inOrder;
    }

    if (incomingSequence == currentSeq) {
      return EventSequenceStatus.duplicate;
    }

    if (incomingSequence < currentSeq) {
      return EventSequenceStatus.stale;
    }

    // incomingSequence > currentSeq + 1 -> تم فقدان حدث أو أكثر في المنتصف
    _entitySequences[entityId] = incomingSequence;
    return EventSequenceStatus.gapDetected;
  }

  void reset(String entityId) {
    _entitySequences.remove(entityId);
  }

  void clear() {
    _entitySequences.clear();
  }
}
