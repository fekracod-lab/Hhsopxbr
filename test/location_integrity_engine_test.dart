import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/location_sample.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/driver_location.dart';
import 'package:dalal_alqaim/core/realtime/domain/enums/realtime_enums.dart';
import 'package:dalal_alqaim/core/realtime/domain/services/location_integrity_engine.dart';

void main() {
  group('Location Integrity Engine Dedicated Tests', () {
    test('1. Validates normal driving movement within speed limits', () {
      final t0 = DateTime(2026, 8, 28, 12, 0, 0);
      final t1 = t0.add(const Duration(seconds: 10));

      final prev = DriverLocation(
        driverId: 'drv_1',
        latitude: 33.3000,
        longitude: 44.3000,
        timestamp: t0,
      );

      final sample = LocationSample(
        latitude: 33.3005, // ~60 meters in 10s -> ~6 m/s = ~22 km/h
        longitude: 44.3000,
        accuracy: 8.0,
        timestamp: t1,
      );

      final result = LocationIntegrityEngine.evaluateSample(
        driverId: 'drv_1',
        currentSample: sample,
        previousLocation: prev,
        now: t1,
      );

      expect(result.confidence, equals(LocationConfidence.valid));
    });

    test('2. Flags impossible speed (> 180 km/h) as suspicious', () {
      final t0 = DateTime(2026, 8, 28, 12, 0, 0);
      final t1 = t0.add(const Duration(seconds: 2));

      final prev = DriverLocation(
        driverId: 'drv_speed',
        latitude: 33.3000,
        longitude: 44.3000,
        timestamp: t0,
      );

      final sample = LocationSample(
        latitude: 33.3200, // ~2.2 km in 2s -> 1100 m/s = 3960 km/h teleport!
        longitude: 44.3000,
        accuracy: 8.0,
        timestamp: t1,
      );

      final result = LocationIntegrityEngine.evaluateSample(
        driverId: 'drv_speed',
        currentSample: sample,
        previousLocation: prev,
        now: t1,
      );

      expect(result.confidence, equals(LocationConfidence.suspicious));
    });

    test('3. Flags degraded confidence when GPS accuracy is low (> 50m)', () {
      final now = DateTime.now();
      final sample = LocationSample(
        latitude: 34.35,
        longitude: 41.25,
        accuracy: 75.0, // 75m error
        timestamp: now,
      );

      final result = LocationIntegrityEngine.evaluateSample(
        driverId: 'drv_low_acc',
        currentSample: sample,
        now: now,
      );

      expect(result.confidence, equals(LocationConfidence.degraded));
    });
  });
}
