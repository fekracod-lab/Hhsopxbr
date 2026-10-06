import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/driver_location.dart';
import 'package:dalal_alqaim/core/realtime/domain/enums/realtime_enums.dart';
import 'package:dalal_alqaim/core/risk/domain/enums/risk_enums.dart';
import 'package:dalal_alqaim/core/risk/domain/services/fake_location_risk_engine.dart';

void main() {
  group('Fake Location Risk Engine Dedicated Tests', () {
    test('1. Valid location returns no risk signals', () {
      final loc = DriverLocation(
        driverId: 'drv_good',
        latitude: 33.3152,
        longitude: 44.3661,
        confidence: LocationConfidence.valid,
        timestamp: DateTime.now(),
      );

      final sig = FakeLocationRiskEngine.evaluateLocation(loc);
      expect(sig, isNull);
    });

    test('2. Suspicious GPS confidence generates gpsTeleportation signal', () {
      final loc = DriverLocation(
        driverId: 'drv_jump',
        latitude: 33.3152,
        longitude: 44.3661,
        confidence: LocationConfidence.suspicious,
        timestamp: DateTime.now(),
      );

      final sig = FakeLocationRiskEngine.evaluateLocation(loc);
      expect(sig, isNotNull);
      expect(sig!.type, equals(RiskSignalType.gpsTeleportation));
      expect(sig.weight, equals(20));
    });

    test('3. Rejected GPS confidence generates high severity fakeLocationDetected signal', () {
      final loc = DriverLocation(
        driverId: 'drv_fake',
        latitude: 0.0,
        longitude: 0.0,
        confidence: LocationConfidence.rejected,
        timestamp: DateTime.now(),
      );

      final sig = FakeLocationRiskEngine.evaluateLocation(loc);
      expect(sig, isNotNull);
      expect(sig!.type, equals(RiskSignalType.fakeLocationDetected));
      expect(sig.severity, equals(FraudCaseSeverity.high));
      expect(sig.weight, equals(35));
    });
  });
}
