import 'package:flutter/foundation.dart';

/// عينة موقع خام قادمة من جهاز السائق (Raw Location Sample)
@immutable
class LocationSample {
  final double latitude;
  final double longitude;
  final double accuracy; // بالأمتار
  final double speed; // متر/ثانية
  final double heading; // 0 - 360 درجة
  final DateTime timestamp;

  const LocationSample({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.speed = 0.0,
    this.heading = 0.0,
    required this.timestamp,
  });
}
