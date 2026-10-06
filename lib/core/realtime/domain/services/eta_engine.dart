import '../entities/eta_result.dart';
import 'package:dalal_alqaim/core/dispatch/domain/services/dispatch_distance_engine.dart';

/// محرك احتساب زمن الوصول المتوقع الحتمي والذكي (Deterministic ETA Engine)
class ETAEngine {
  const ETAEngine();

  /// متوسط السرعة الحضرية داخل المدينة (25 كم/ساعة = 6.944 م/ث)
  static const double averageUrbanSpeedMps = 6.944;

  /// احتساب الوقت المتوقع للوصول
  static ETAResult computeETA({
    required double currentLat,
    required double currentLng,
    required double targetLat,
    required double targetLng,
    double trafficMultiplier = 1.2,
    DateTime? now,
  }) {
    final distanceMeters = DispatchDistanceEngine.computeDistanceMeters(
      lat1: currentLat,
      lon1: currentLng,
      lat2: targetLat,
      lon2: targetLng,
    );

    if (distanceMeters.isNaN || distanceMeters.isInfinite || distanceMeters < 0) {
      return ETAResult(
        durationSeconds: 0,
        distanceMeters: 0,
        confidence: 0.0,
        calculatedAt: now ?? DateTime.now(),
        source: 'error_fallback',
      );
    }

    if (distanceMeters == 0.0) {
      return ETAResult(
        durationSeconds: 0,
        distanceMeters: 0,
        confidence: 1.0,
        calculatedAt: now ?? DateTime.now(),
        source: 'arrived',
      );
    }

    final rawSeconds = (distanceMeters / averageUrbanSpeedMps) * trafficMultiplier;
    final durationSeconds = rawSeconds.round().clamp(0, 86400); // أقصى حد 24 ساعة

    return ETAResult(
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters.round(),
      confidence: 0.95,
      calculatedAt: now ?? DateTime.now(),
      source: 'deterministic_urban_model',
    );
  }
}
