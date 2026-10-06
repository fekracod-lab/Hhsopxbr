import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/risk/domain/enums/risk_enums.dart';
import 'package:dalal_alqaim/core/risk/domain/services/impossible_travel_engine.dart';

void main() {
  group('Impossible Travel Engine Dedicated Tests', () {
    test('1. Normal urban driving does not trigger impossible travel', () {
      final t1 = DateTime(2026, 8, 28, 12, 0, 0);
      final t2 = t1.add(const Duration(minutes: 10));

      // ~5 km in 10 minutes -> 30 km/h
      final sig = ImpossibleTravelEngine.evaluateTravel(
        subjectId: 'user_car',
        lat1: 33.3000,
        lon1: 44.3000,
        time1: t1,
        lat2: 33.3450,
        lon2: 44.3000,
        time2: t2,
      );

      expect(sig, isNull);
    });

    test('2. Impossible velocity between Baghdad and Al-Qaim in 2 minutes triggers impossibleTravel signal', () {
      final t1 = DateTime(2026, 8, 28, 12, 0, 0);
      final t2 = t1.add(const Duration(minutes: 2));

      // Baghdad -> Al-Qaim (~350 km) in 2 minutes! (10,500 km/h)
      final sig = ImpossibleTravelEngine.evaluateTravel(
        subjectId: 'user_teleport',
        lat1: 33.3152, // Baghdad
        lon1: 44.3661,
        time1: t1,
        lat2: 34.3500, // Al-Qaim
        lon2: 41.2500,
        time2: t2,
      );

      expect(sig, isNotNull);
      expect(sig!.type, equals(RiskSignalType.impossibleTravel));
      expect(sig.weight, equals(35));
    });

    test('3. Zero-second displacement of > 500m triggers critical impossibleTravel', () {
      final t1 = DateTime(2026, 8, 28, 12, 0, 0);

      final sig = ImpossibleTravelEngine.evaluateTravel(
        subjectId: 'user_instant',
        lat1: 33.3000,
        lon1: 44.3000,
        time1: t1,
        lat2: 33.3500, // ~5.5 km in 0 seconds
        lon2: 44.3000,
        time2: t1,
      );

      expect(sig, isNotNull);
      expect(sig!.severity, equals(FraudCaseSeverity.critical));
      expect(sig.weight, equals(40));
    });
  });
}
