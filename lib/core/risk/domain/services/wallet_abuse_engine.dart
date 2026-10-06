import '../entities/risk_signal.dart';
import '../enums/risk_enums.dart';

/// محرك كشف الاحتيال وإساءة استخدام المحفظة المالية (Wallet Abuse Engine)
class WalletAbuseEngine {
  final Map<String, List<DateTime>> _failedPayments = {};
  final Map<String, List<DateTime>> _walletMutations = {};

  WalletAbuseEngine();

  /// تسجيل وفحص محاولة دفع فاشلة
  RiskSignal? recordFailedPayment({
    required String subjectId,
    int threshold = 5,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    _failedPayments.putIfAbsent(subjectId, () => []);
    final fails = _failedPayments[subjectId]!;

    fails.removeWhere((t) => t.isBefore(currentTime.subtract(const Duration(minutes: 15))));
    fails.add(currentTime);

    if (fails.length >= threshold) {
      return RiskSignal(
        signalId: 'sig-pay-fail-$subjectId-${currentTime.millisecondsSinceEpoch}',
        type: RiskSignalType.repeatedFailedPayments,
        source: RiskSource.financialEngine,
        subjectId: subjectId,
        severity: FraudCaseSeverity.high,
        confidence: 0.90,
        weight: 30,
        timestamp: currentTime,
        metadata: {
          'failedCount': fails.length,
          'window': '15m',
          'reason': 'Repeated failed payments in short duration',
        },
      );
    }

    return null;
  }

  /// تسجيل وفحص حركات المحفظة السريعة
  RiskSignal? recordWalletMutation({
    required String subjectId,
    int threshold = 10,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    _walletMutations.putIfAbsent(subjectId, () => []);
    final mutations = _walletMutations[subjectId]!;

    mutations.removeWhere((t) => t.isBefore(currentTime.subtract(const Duration(hours: 1))));
    mutations.add(currentTime);

    if (mutations.length > threshold) {
      return RiskSignal(
        signalId: 'sig-wal-rapid-$subjectId-${currentTime.millisecondsSinceEpoch}',
        type: RiskSignalType.walletRapidMutation,
        source: RiskSource.financialEngine,
        subjectId: subjectId,
        severity: FraudCaseSeverity.medium,
        confidence: 0.85,
        weight: 20,
        timestamp: currentTime,
        metadata: {
          'mutationCount': mutations.length,
          'window': '1h',
          'reason': 'Rapid wallet debit/refund mutation cycles',
        },
      );
    }

    return null;
  }

  void clear() {
    _failedPayments.clear();
    _walletMutations.clear();
  }
}
