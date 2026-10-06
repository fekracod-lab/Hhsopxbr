import 'dart:async';

/// محرك حماية التزامن والأقفال الحصرية (Concurrency Guard & Mutex Engine)
class ConcurrencyGuardEngine {
  final Map<String, String> _exclusiveAssignments = {}; // resourceId -> winnerCandidateId
  final Map<String, int> _resourceVersions = {}; // resourceId -> version
  final Map<String, Completer<void>> _resourceLocks = {};

  ConcurrencyGuardEngine();

  Map<String, String> get assignments => Map.unmodifiable(_exclusiveAssignments);
  Map<String, int> get versions => Map.unmodifiable(_resourceVersions);

  /// محاولة الاستحواذ الحصري على مورد (مثل تعيين سائق أو قبول طلب) تحت التزامن الشديد
  Future<(bool won, String assignedWinnerId)> acquireExclusiveAssignment({
    required String resourceId,
    required String candidateId,
  }) async {
    // الانتظار إذا كان هناك قفل متزامن على المورد
    while (_resourceLocks.containsKey(resourceId)) {
      await _resourceLocks[resourceId]!.future;
    }

    final lockCompleter = Completer<void>();
    _resourceLocks[resourceId] = lockCompleter;

    try {
      if (_exclusiveAssignments.containsKey(resourceId)) {
        return (false, _exclusiveAssignments[resourceId]!);
      }

      _exclusiveAssignments[resourceId] = candidateId;
      _resourceVersions[resourceId] = (_resourceVersions[resourceId] ?? 0) + 1;
      return (true, candidateId);
    } finally {
      _resourceLocks.remove(resourceId);
      lockCompleter.complete();
    }
  }

  /// تحرير الاستحواذ الحصري
  Future<void> releaseAssignment(String resourceId) async {
    _exclusiveAssignments.remove(resourceId);
  }

  /// تنفيذ تعديل متفائل مع التحقق من تطابق الإصدار (Optimistic Concurrency Compare-And-Swap)
  Future<(T? result, bool success, String? error)> compareAndSwap<T>({
    required String resourceId,
    required int expectedVersion,
    required Future<T> Function() updateAction,
  }) async {
    final currentVersion = _resourceVersions[resourceId] ?? 0;

    if (currentVersion != expectedVersion) {
      return (null, false, 'Optimistic concurrency conflict on resource [$resourceId]. Expected version $expectedVersion, found $currentVersion');
    }

    try {
      final res = await updateAction();
      _resourceVersions[resourceId] = currentVersion + 1;
      return (res, true, null);
    } catch (e) {
      return (null, false, e.toString());
    }
  }

  void reset() {
    _exclusiveAssignments.clear();
    _resourceVersions.clear();
    _resourceLocks.clear();
  }
}
