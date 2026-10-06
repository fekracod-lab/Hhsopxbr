import '../entities/device_trust_record.dart';
import '../entities/risk_signal.dart';
import '../enums/risk_enums.dart';

/// محرك تقييم موثوقية الأجهزة وكشف إنشاء الحسابات المتعددة (Device Trust Engine)
class DeviceTrustEngine {
  final Map<String, Set<String>> _deviceAccounts = {};
  final Map<String, DateTime> _deviceFirstSeen = {};

  DeviceTrustEngine();

  /// تقييم الجهاز وتحديث سجل الموثوقية
  (DeviceTrustRecord, RiskSignal?) evaluateDevice({
    required String deviceId,
    required String deviceFingerprintHash,
    required String accountId,
    int maxAccountsPerDevice = 3,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();

    _deviceFirstSeen.putIfAbsent(deviceId, () => currentTime);
    _deviceAccounts.putIfAbsent(deviceId, () => {});
    _deviceAccounts[deviceId]!.add(accountId);

    final accountCount = _deviceAccounts[deviceId]!.length;
    var trustLevel = DeviceTrustLevel.trusted;
    final riskSignals = <String>[];
    RiskSignal? signal;

    if (accountCount > maxAccountsPerDevice) {
      trustLevel = DeviceTrustLevel.suspicious;
      riskSignals.add('Multi-account farming detected on device');

      signal = RiskSignal(
        signalId: 'sig-dev-$deviceId-${currentTime.millisecondsSinceEpoch}',
        type: RiskSignalType.deviceAccountFarming,
        source: RiskSource.securityEngine,
        subjectId: accountId,
        severity: FraudCaseSeverity.medium,
        confidence: 0.85,
        weight: 20,
        timestamp: currentTime,
        metadata: {
          'deviceId': deviceId,
          'accountCount': accountCount,
          'limit': maxAccountsPerDevice,
        },
      );
    }

    final record = DeviceTrustRecord(
      deviceId: deviceId,
      deviceFingerprintHash: deviceFingerprintHash,
      firstSeenAt: _deviceFirstSeen[deviceId]!,
      lastSeenAt: currentTime,
      deviceTrustLevel: trustLevel,
      associatedAccountsCount: accountCount,
      riskSignals: riskSignals,
    );

    return (record, signal);
  }

  void clear() {
    _deviceAccounts.clear();
    _deviceFirstSeen.clear();
  }
}
