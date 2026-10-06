import '../entities/risk_signal.dart';
import '../entities/risk_score.dart';
import '../enums/risk_enums.dart';

/// محرك تجميع وتوحيد إشارات الخطر وحساب الدرجة النهائية (Risk Signal Aggregator)
class RiskSignalAggregator {
  const RiskSignalAggregator();

  /// تجميع الإشارات بدون تكرار واحتساب النتيجة المعيارية
  static RiskScore aggregateSignals({
    required List<RiskSignal> signals,
    int trustDiscount = 0,
    String policyVersion = 'v1.0.0',
    DateTime? now,
  }) {
    if (signals.isEmpty) {
      return RiskScore(
        rawScore: 0,
        normalizedScore: 0,
        riskLevel: RiskLevel.trusted,
        confidence: 1.0,
        policyVersion: policyVersion,
        calculatedAt: now ?? DateTime.now(),
      );
    }

    // 1. منع تكرار الإشارات من نفس النوع (Deduplication by Signal Type)
    final uniqueSignalsByType = <RiskSignalType, RiskSignal>{};
    for (final signal in signals) {
      if (!uniqueSignalsByType.containsKey(signal.type) ||
          signal.weight > uniqueSignalsByType[signal.type]!.weight) {
        uniqueSignalsByType[signal.type] = signal;
      }
    }

    // 2. احتساب النتيجة الإجمالية الموزونة
    double totalRaw = 0.0;
    double totalConfidence = 0.0;

    for (final signal in uniqueSignalsByType.values) {
      final signalContribution = signal.weight * signal.confidence;
      totalRaw += signalContribution;
      totalConfidence += signal.confidence;
    }

    final avgConfidence = (totalConfidence / uniqueSignalsByType.length).clamp(0.0, 1.0);
    final rawInt = totalRaw.round().clamp(0, 200);

    // 3. تطبيق خصم الموثوقية
    final normalized = (rawInt - trustDiscount).clamp(0, 100);
    final riskLevel = RiskLevel.fromScore(normalized);

    return RiskScore(
      rawScore: rawInt,
      normalizedScore: normalized,
      riskLevel: riskLevel,
      confidence: avgConfidence,
      policyVersion: policyVersion,
      calculatedAt: now ?? DateTime.now(),
    );
  }
}
