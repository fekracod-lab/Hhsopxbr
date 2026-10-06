import 'package:google_maps_flutter/google_maps_flutter.dart';

/// يمثل خيار مسار واحد من بين عدة مسارات بديلة
class RouteOption {
  /// نقاط الطريق (polyline)
  final List<LatLng> points;

  /// المسافة بالأمتار
  final double distanceMeters;

  /// المدة بالثواني
  final double durationSeconds;

  /// تصنيف المسار: fastest / cheapest / shortest
  final String tag;

  /// اسم المسار بالعربي (الأسرع / الأرخص / الأقصر)
  final String label;

  /// المسافة بالكيلومتر (محسوبة)
  double get distanceKm => distanceMeters / 1000;

  /// المدة بالدقائق (محسوبة)
  int get durationMin => (durationSeconds / 60).round();

  const RouteOption({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.tag,
    required this.label,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteOption &&
          runtimeType == other.runtimeType &&
          tag == other.tag &&
          distanceMeters == other.distanceMeters;

  @override
  int get hashCode => tag.hashCode ^ distanceMeters.hashCode;
}
