import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/risk/domain/enums/risk_enums.dart';
import 'package:dalal_alqaim/core/risk/domain/services/behavioral_anomaly_engine.dart';

void main() {
  group('Behavioral Anomaly Engine Dedicated Tests', () {
    test('1. Normal operations ratio generates no signals', () {
      final engine = BehavioralAnomalyEngine();
      for (int i = 0; i < 5; i++) {
        engine.recordOperationResult(subjectId: 'user_good', isSuccess: true);
      }
      final sig = engine.recordOperationResult(subjectId: 'user_good', isSuccess: false);
      expect(sig, isNull);
    });

    test('2. Severe failure ratio (> 80%) across 5+ operations triggers behavioralAnomaly signal', () {
      final engine = BehavioralAnomalyEngine();

      for (int i = 0; i < 4; i++) {
        engine.recordOperationResult(subjectId: 'user_bot', isSuccess: false);
      }

      // 5th failed operation (5/5 = 100% failure rate)
      final sig = engine.recordOperationResult(subjectId: 'user_bot', isSuccess: false);

      expect(sig, isNotNull);
      expect(sig!.type, equals(RiskSignalType.behavioralAnomaly));
      expect(sig.weight, equals(25));
    });
  });
}
