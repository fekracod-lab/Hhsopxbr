import '../entities/location_sample.dart';
import '../entities/driver_location.dart';
import '../enums/realtime_enums.dart';
import 'gps_validation_engine.dart';
import 'package:dalal_alqaim/core/dispatch/domain/services/dispatch_distance_engine.dart';

/// محرك فحص سلامة وتناسق حركة السائقين وكشف القفزات المشبوهة (Location Integrity Engine)
class LocationIntegrityEngine {
  const LocationIntegrityEngine();

  /// أقصى سرعة فيزيائية معقولة لسيارة/دراجة داخل المدينة (50 متر/ثانية = 180 كم/ساعة)
  static const double maxRealisticVelocityMps = 50.0;

  /// تقييم وتدقيق عينة الموقع ومقارنتها بالموقع السابق
  static DriverLocation evaluateSample({
    required String driverId,
    required LocationSample currentSample,
    DriverLocation? previousLocation,
    int sequenceNumber = 0,
    DateTime? now,
  }) {
    // 1. التحقق الأساسي من الـ GPS
    if (!GPSValidationEngine.validateSample(sample: currentSample, now: now)) {
      return DriverLocation(
        driverId: driverId,
        latitude: currentSample.latitude,
        longitude: currentSample.longitude,
        heading: currentSample.heading,
        speed: currentSample.speed,
        accuracy: currentSample.accuracy,
        confidence: LocationConfidence.rejected,
        timestamp: currentSample.timestamp,
        sequenceNumber: sequenceNumber,
      );
    }

    var confidence = LocationConfidence.valid;

    // 2. إذا كانت الدقة منخفضة نسبياً
    if (currentSample.accuracy > 50.0) {
      confidence = LocationConfidence.degraded;
    }

    // 3. التحقق الفيزيائي من السرعة والقفزات المكانية (Teleportation Detection)
    if (previousLocation != null) {
      final distance = DispatchDistanceEngine.computeDistanceMeters(
        lat1: previousLocation.latitude,
        lon1: previousLocation.longitude,
        lat2: currentSample.latitude,
        lon2: currentSample.longitude,
      );

      final timeDiffSeconds = currentSample.timestamp.difference(previousLocation.timestamp).inSeconds.abs();

      if (timeDiffSeconds == 0) {
        if (distance > 20.0) {
          confidence = LocationConfidence.suspicious;
        }
      } else {
        final calculatedSpeedMps = distance / timeDiffSeconds;
        if (calculatedSpeedMps > maxRealisticVelocityMps) {
          confidence = LocationConfidence.suspicious;
        }
      }
    }

    return DriverLocation(
      driverId: driverId,
      latitude: currentSample.latitude,
      longitude: currentSample.longitude,
      heading: currentSample.heading,
      speed: currentSample.speed,
      accuracy: currentSample.accuracy,
      confidence: confidence,
      timestamp: currentSample.timestamp,
      sequenceNumber: sequenceNumber,
    );
  }
}
