import '../entities/risk_signal.dart';
import '../entities/velocity_record.dart';
import '../enums/risk_enums.dart';

/// محرك فحص وحوكمة سرعة وتكرار العمليات (Sliding Window Velocity Engine)
class VelocityEngine {
  final Map<String, List<DateTime>> _actionTimestamps = {};

  VelocityEngine();

  /// تسجيل عملية والتحقق من حدود السرعة والتكرار
  (VelocityRecord, RiskSignal?) recordAndEvaluate({
    required String subjectId,
    required String actionType,
    VelocityWindow window = VelocityWindow.oneHour,
    int limit = 10,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final key = '$subjectId:$actionType';

    _actionTimestamps.putIfAbsent(key, () => []);
    final timestamps = _actionTimestamps[key]!;

    // 1. تنظيف السجلات الأقدم من النافذة الزمنية (Sliding Window Purge)
    final windowStart = currentTime.subtract(window.duration);
    timestamps.removeWhere((t) => t.isBefore(windowStart));

    // 2. إضافة العملية الحالية
    timestamps.add(currentTime);

    final currentCount = timestamps.length;
    final exceeded = currentCount > limit;

    final record = VelocityRecord(
      recordId: 'vel-$subjectId-$actionType-${window.key}-${currentTime.millisecondsSinceEpoch}',
      subjectId: subjectId,
      actionType: actionType,
      window: window,
      count: currentCount,
      limit: limit,
      firstEventAt: timestamps.isNotEmpty ? timestamps.first : currentTime,
      lastEventAt: currentTime,
      exceeded: exceeded,
    );

    RiskSignal? signal;
    if (exceeded) {
      signal = RiskSignal(
        signalId: 'sig-vel-$subjectId-${currentTime.millisecondsSinceEpoch}',
        type: RiskSignalType.velocityLimitExceeded,
        source: RiskSource.securityEngine,
        subjectId: subjectId,
        severity: FraudCaseSeverity.high,
        confidence: 1.0,
        weight: 25,
        timestamp: currentTime,
        metadata: {
          'actionType': actionType,
          'count': currentCount,
          'limit': limit,
          'window': window.key,
        },
      );
    }

    return (record, signal);
  }

  void clear() {
    _actionTimestamps.clear();
  }
}
