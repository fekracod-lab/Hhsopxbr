import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/location_sample.dart';
import 'package:dalal_alqaim/core/realtime/domain/services/gps_validation_engine.dart';

void main() {
  group('GPS Validation Engine Dedicated Tests', () {
    test('1. Validates normal coordinates and reject null island (0,0)', () {
      expect(GPSValidationEngine.isValidCoordinate(33.3152, 44.3661), isTrue); // Baghdad
      expect(GPSValidationEngine.isValidCoordinate(34.3500, 41.2500), isTrue); // Al-Qaim
      expect(GPSValidationEngine.isValidCoordinate(0.0, 0.0), isFalse);        // Null Island
      expect(GPSValidationEngine.isValidCoordinate(95.0, 44.0), isFalse);       // Latitude out of bounds
      expect(GPSValidationEngine.isValidCoordinate(33.0, 195.0), isFalse);      // Longitude out of bounds
    });

    test('2. Rejects sample with negative or excessive accuracy error', () {
      final now = DateTime.now();

      final goodSample = LocationSample(
        latitude: 34.35,
        longitude: 41.25,
        accuracy: 10.0, // 10m error
        timestamp: now,
      );
      expect(GPSValidationEngine.validateSample(sample: goodSample, now: now), isTrue);

      final zeroAccSample = LocationSample(
        latitude: 34.35,
        longitude: 41.25,
        accuracy: 0.0, // Invalid accuracy
        timestamp: now,
      );
      expect(GPSValidationEngine.validateSample(sample: zeroAccSample, now: now), isFalse);

      final terribleAccSample = LocationSample(
        latitude: 34.35,
        longitude: 41.25,
        accuracy: 350.0, // > 200m
        timestamp: now,
      );
      expect(GPSValidationEngine.validateSample(sample: terribleAccSample, now: now), isFalse);
    });

    test('3. Rejects stale GPS sample (> 10m old)', () {
      final now = DateTime(2026, 8, 28, 12, 0, 0);
      final staleSample = LocationSample(
        latitude: 34.35,
        longitude: 41.25,
        accuracy: 10.0,
        timestamp: now.subtract(const Duration(minutes: 15)),
      );
      expect(GPSValidationEngine.validateSample(sample: staleSample, now: now), isFalse);
    });
  });
}
