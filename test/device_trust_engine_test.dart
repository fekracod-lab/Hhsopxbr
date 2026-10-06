import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/risk/domain/enums/risk_enums.dart';
import 'package:dalal_alqaim/core/risk/domain/services/device_trust_engine.dart';

void main() {
  group('Device Trust Engine Dedicated Tests', () {
    test('1. Normal single account device remains trusted', () {
      final engine = DeviceTrustEngine();
      final now = DateTime.now();

      final (record, signal) = engine.evaluateDevice(
        deviceId: 'dev_1',
        deviceFingerprintHash: 'hash_abc',
        accountId: 'acc_1',
        maxAccountsPerDevice: 3,
        now: now,
      );

      expect(record.deviceTrustLevel, equals(DeviceTrustLevel.trusted));
      expect(record.associatedAccountsCount, equals(1));
      expect(signal, isNull);
    });

    test('2. Multi-account farming (> 3 accounts) flags device as suspicious', () {
      final engine = DeviceTrustEngine();
      final now = DateTime.now();

      for (int i = 1; i <= 3; i++) {
        engine.evaluateDevice(
          deviceId: 'dev_farm',
          deviceFingerprintHash: 'hash_farm',
          accountId: 'acc_$i',
          maxAccountsPerDevice: 3,
          now: now,
        );
      }

      // 4th account on same device
      final (record, signal) = engine.evaluateDevice(
        deviceId: 'dev_farm',
        deviceFingerprintHash: 'hash_farm',
        accountId: 'acc_4',
        maxAccountsPerDevice: 3,
        now: now,
      );

      expect(record.deviceTrustLevel, equals(DeviceTrustLevel.suspicious));
      expect(record.associatedAccountsCount, equals(4));
      expect(signal, isNotNull);
      expect(signal!.type, equals(RiskSignalType.deviceAccountFarming));
      expect(signal.weight, equals(20));
    });
  });
}
