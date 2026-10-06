import '../entities/risk_signal.dart';
import '../enums/risk_enums.dart';

/// محرك كشف تكرار إلغاء الطلبات والرحلات (Cancellation Abuse Engine)
class CancellationAbuseEngine {
  final Map<String, List<DateTime>> _cancellations = {};

  CancellationAbuseEngine();

  /// تسجيل إلغاء وفحص هل يتجاوز الحد المسموح
  RiskSignal? recordCancellation({
    required String subjectId,
    required RiskSubjectType subjectType,
    int maxCancellationsPerHour = 5,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    _cancellations.putIfAbsent(subjectId, () => []);
    final userCancels = _cancellations[subjectId]!;

    userCancels.removeWhere((t) => t.isBefore(currentTime.subtract(const Duration(hours: 1))));
    userCancels.add(currentTime);

    if (userCancels.length > maxCancellationsPerHour) {
      return RiskSignal(
        signalId: 'sig-cancel-$subjectId-${currentTime.millisecondsSinceEpoch}',
        type: RiskSignalType.cancellationSpam,
        source: RiskSource.orderEngine,
        subjectId: subjectId,
        severity: FraudCaseSeverity.medium,
        confidence: 0.85,
        weight: 20,
        timestamp: currentTime,
        metadata: {
          'subjectType': subjectType.key,
          'cancellationCount': userCancels.length,
          'limit': maxCancellationsPerHour,
          'reason': 'Excessive order/ride cancellations within 1 hour',
        },
      );
    }

    return null;
  }

  void clear() {
    _cancellations.clear();
  }
}
