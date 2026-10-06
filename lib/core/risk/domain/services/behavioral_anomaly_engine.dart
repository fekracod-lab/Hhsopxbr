import '../entities/risk_signal.dart';
import '../enums/risk_enums.dart';

/// محرك كشف الشذوذ السلوكي الحتمي والقائم على القواعد (Rule-Based Behavioral Anomaly Engine)
class BehavioralAnomalyEngine {
  final Map<String, (int success, int failure)> _userStats = {};

  BehavioralAnomalyEngine();

  /// تسجيل نتيجة عملية وتحليل النسبة
  RiskSignal? recordOperationResult({
    required String subjectId,
    required bool isSuccess,
    DateTime? now,
  }) {
    final current = _userStats[subjectId] ?? (0, 0);
    final updated = isSuccess
        ? (current.$1 + 1, current.$2)
        : (current.$1, current.$2 + 1);
    _userStats[subjectId] = updated;

    final total = updated.$1 + updated.$2;
    if (total >= 5) {
      final failureRatio = updated.$2 / total;
      if (failureRatio > 0.8) {
        return RiskSignal(
          signalId: 'sig-behav-$subjectId-${(now ?? DateTime.now()).millisecondsSinceEpoch}',
          type: RiskSignalType.behavioralAnomaly,
          source: RiskSource.securityEngine,
          subjectId: subjectId,
          severity: FraudCaseSeverity.medium,
          confidence: 0.85,
          weight: 25,
          timestamp: now ?? DateTime.now(),
          metadata: {
            'totalOps': total,
            'failureCount': updated.$2,
            'failureRatio': failureRatio,
            'reason': 'Abnormal failure ratio exceeding 80% across operations',
          },
        );
      }
    }

    return null;
  }

  void clear() {
    _userStats.clear();
  }
}
