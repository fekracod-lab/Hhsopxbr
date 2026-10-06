import 'package:flutter/foundation.dart';

/// نقطة أثر المسار المباشر (Tracking Trail Point)
@immutable
class TrackingPoint {
  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double speed;

  const TrackingPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.speed = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'recordedAt': recordedAt.toIso8601String(),
      'speed': speed,
    };
  }

  factory TrackingPoint.fromMap(Map<String, dynamic> map) {
    return TrackingPoint(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      recordedAt: map['recordedAt'] != null
          ? DateTime.tryParse(map['recordedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
