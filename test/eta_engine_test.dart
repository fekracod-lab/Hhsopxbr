import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/realtime/domain/services/eta_engine.dart';

void main() {
  group('Deterministic ETA Engine Dedicated Tests', () {
    test('1. Computes deterministic ETA for positive distances', () {
      final eta = ETAEngine.computeETA(
        currentLat: 33.3000,
        currentLng: 44.3000,
        targetLat: 33.3200,
        targetLng: 44.3000,
      );

      expect(eta.durationSeconds, greaterThan(0));
      expect(eta.distanceMeters, greaterThan(0));
      expect(eta.durationMinutes, greaterThanOrEqualTo(1));
      expect(eta.confidence, equals(0.95));
      expect(eta.source, equals('deterministic_urban_model'));
    });

    test('2. Returns zero duration for identical locations', () {
      final eta = ETAEngine.computeETA(
        currentLat: 34.3500,
        currentLng: 41.2500,
        targetLat: 34.3500,
        targetLng: 41.2500,
      );

      expect(eta.durationSeconds, equals(0));
      expect(eta.distanceMeters, equals(0));
      expect(eta.source, equals('arrived'));
    });

    test('3. Protects against NaN or infinite coordinates gracefully', () {
      final eta = ETAEngine.computeETA(
        currentLat: double.nan,
        currentLng: 44.3000,
        targetLat: 33.3200,
        targetLng: 44.3000,
      );

      expect(eta.durationSeconds, equals(0));
      expect(eta.distanceMeters, equals(0));
      expect(eta.confidence, equals(0.0));
      expect(eta.source, equals('error_fallback'));
    });
  });
}
