import '../entities/risk_signal.dart';
import '../enums/risk_enums.dart';

/// محرك رصد مؤشرات وأنماط التواطؤ المتكرر (Collusion Signal Engine)
class CollusionSignalEngine {
  final Map<String, List<DateTime>> _pairings = {};

  CollusionSignalEngine();

  /// فحص تكرار الاقتران بين زبون وسائق/متجر معين
  RiskSignal? evaluatePairing({
    required String customerId,
    required String driverId,
    int suspiciousThreshold24h = 5,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final pairKey = '$customerId:$driverId';

    _pairings.putIfAbsent(pairKey, () => []);
    final history = _pairings[pairKey]!;
    history.removeWhere((t) => t.isBefore(currentTime.subtract(const Duration(hours: 24))));
    history.add(currentTime);

    if (history.length > suspiciousThreshold24h) {
      return RiskSignal(
        signalId: 'sig-col-$customerId-$driverId-${currentTime.millisecondsSinceEpoch}',
        type: RiskSignalType.collusionPattern,
        source: RiskSource.dispatchEngine,
        subjectId: customerId,
        severity: FraudCaseSeverity.medium,
        confidence: 0.75,
        weight: 20,
        timestamp: currentTime,
        metadata: {
          'customerId': customerId,
          'driverId': driverId,
          'pairCount24h': history.length,
          'threshold': suspiciousThreshold24h,
          'reason': 'Statistically abnormal repeated pairing between same customer and driver',
        },
      );
    }

    return null;
  }

  void clear() {
    _pairings.clear();
  }
}
