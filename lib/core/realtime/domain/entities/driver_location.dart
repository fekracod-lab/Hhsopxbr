import 'package:flutter/foundation.dart';
import '../enums/realtime_enums.dart';

/// موقع السائق المعتمد والمفحوص أمنياً وفيزيائياً (Validated Driver Location)
@immutable
class DriverLocation {
  final String driverId;
  final double latitude;
  final double longitude;
  final double heading;
  final double speed;
  final double accuracy;
  final LocationConfidence confidence;
  final DateTime timestamp;
  final int sequenceNumber;

  const DriverLocation({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    this.heading = 0.0,
    this.speed = 0.0,
    this.accuracy = 5.0,
    this.confidence = LocationConfidence.valid,
    required this.timestamp,
    this.sequenceNumber = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'accuracy': accuracy,
      'confidence': confidence.key,
      'timestamp': timestamp.toIso8601String(),
      'sequenceNumber': sequenceNumber,
    };
  }

  factory DriverLocation.fromMap(Map<String, dynamic> map, String docId) {
    return DriverLocation(
      driverId: map['driverId']?.toString() ?? docId,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble() ?? 0.0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 5.0,
      confidence: LocationConfidence.values.firstWhere(
        (c) => c.key == map['confidence']?.toString(),
        orElse: () => LocationConfidence.valid,
      ),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sequenceNumber: (map['sequenceNumber'] as num?)?.toInt() ?? 0,
    );
  }
}
