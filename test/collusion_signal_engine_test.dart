import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/risk/domain/enums/risk_enums.dart';
import 'package:dalal_alqaim/core/risk/domain/services/collusion_signal_engine.dart';

void main() {
  group('Collusion Signal Engine Dedicated Tests', () {
    test('1. Normal sporadic customer-driver pairings return no signal', () {
      final engine = CollusionSignalEngine();
      final sig = engine.evaluatePairing(
        customerId: 'cust_1',
        driverId: 'drv_1',
      );
      expect(sig, isNull);
    });

    test('2. Statistically abnormal repeated pairing (> 5 times in 24h) emits collusionPattern signal', () {
      final engine = CollusionSignalEngine();
      final now = DateTime.now();

      for (int i = 0; i < 5; i++) {
        final sig = engine.evaluatePairing(
          customerId: 'cust_col',
          driverId: 'drv_col',
          suspiciousThreshold24h: 5,
          now: now.add(Duration(hours: i)),
        );
        expect(sig, isNull);
      }

      // 6th trip together in 24h
      final sig6 = engine.evaluatePairing(
        customerId: 'cust_col',
        driverId: 'drv_col',
        suspiciousThreshold24h: 5,
        now: now.add(const Duration(hours: 6)),
      );

      expect(sig6, isNotNull);
      expect(sig6!.type, equals(RiskSignalType.collusionPattern));
      expect(sig6.weight, equals(20));
    });
  });
}
