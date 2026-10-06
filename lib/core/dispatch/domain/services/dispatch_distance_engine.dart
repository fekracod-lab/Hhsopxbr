import 'dart:math' as math;

/// محرك حساب المسافات الجغرافية الدقيقة (Haversine Distance Engine)
class DispatchDistanceEngine {
  const DispatchDistanceEngine();

  static const double earthRadiusMeters = 6371000.0; // 6,371 km

  /// حساب المسافة بالأمتار بين نقطتين باستخدام معادلة Haversine
  static double computeDistanceMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    if (!_isValidCoordinate(lat1, lon1) || !_isValidCoordinate(lat2, lon2)) {
      return double.infinity;
    }

    if (lat1 == lat2 && lon1 == lon2) {
      return 0.0;
    }

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distance = earthRadiusMeters * c;

    return distance.isNaN || distance.isInfinite ? double.infinity : distance;
  }

  /// حساب المسافة بالكيلومتر
  static double computeDistanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final meters = computeDistanceMeters(
      lat1: lat1,
      lon1: lon1,
      lat2: lat2,
      lon2: lon2,
    );
    return meters / 1000.0;
  }

  static double _toRadians(double degree) => degree * (math.pi / 180.0);

  static bool _isValidCoordinate(double lat, double lon) {
    if (lat.isNaN || lat.isInfinite || lon.isNaN || lon.isInfinite) return false;
    return lat >= -90.0 && lat <= 90.0 && lon >= -180.0 && lon <= 180.0;
  }
}
