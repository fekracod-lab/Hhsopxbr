import '../entities/location_sample.dart';

/// محرك فحص وتدقيق إحداثيات الـ GPS الخام (GPS Validation Engine)
class GPSValidationEngine {
  const GPSValidationEngine();

  static const double maxAcceptableAccuracyMeters = 200.0;
  static const Duration maxFutureDrift = Duration(seconds: 30);
  static const Duration maxStaleAge = Duration(minutes: 10);

  /// التحقق من صحة الإحداثيات الجغرافية
  static bool isValidCoordinate(double lat, double lon) {
    if (lat.isNaN || lat.isInfinite || lon.isNaN || lon.isInfinite) return false;
    if (lat < -90.0 || lat > 90.0) return false;
    if (lon < -180.0 || lon > 180.0) return false;
    // التحقق من الإحداثيات الصفرية المشبوهة (Null Island: 0,0)
    if (lat == 0.0 && lon == 0.0) return false;
    return true;
  }

  /// فحص شامل لعينة الموقع
  static bool validateSample({
    required LocationSample sample,
    DateTime? now,
  }) {
    // 1. فحص صحة الإحداثيات الجغرافية
    if (!isValidCoordinate(sample.latitude, sample.longitude)) {
      return false;
    }

    // 2. فحص دقة إشارة الـ GPS
    if (sample.accuracy <= 0.0 || sample.accuracy > maxAcceptableAccuracyMeters) {
      return false;
    }

    // 3. فحص التوقيت
    final currentTime = now ?? DateTime.now();
    if (sample.timestamp.isAfter(currentTime.add(maxFutureDrift))) {
      return false; // توقيت مستقبلي مشبوه
    }

    if (currentTime.difference(sample.timestamp).abs() > maxStaleAge) {
      return false; // إحداثيات قديمة منتهية الصلاحية
    }

    return true;
  }
}
