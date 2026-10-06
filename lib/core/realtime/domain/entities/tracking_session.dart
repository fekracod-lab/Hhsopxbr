import 'package:flutter/foundation.dart';
import '../enums/realtime_enums.dart';
import 'driver_location.dart';

/// جلسة التتبع المباشر لرحلة أو توصيل طلب (Active Tracking Session)
@immutable
class TrackingSession {
  final String sessionId;
  final String orderId;
  final String serviceType; // 'taxi', 'food', 'store', 'mersal'
  final String driverId;
  final String customerId;
  final TrackingSessionStatus status;
  final DriverLocation? currentLocation;
  final double destinationLat;
  final double destinationLng;
  final String destinationAddress;
  final int currentEtaSeconds;
  final DateTime startedAt;
  final DateTime? lastLocationAt;
  final int version;

  const TrackingSession({
    required this.sessionId,
    required this.orderId,
    required this.serviceType,
    required this.driverId,
    required this.customerId,
    this.status = TrackingSessionStatus.active,
    this.currentLocation,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationAddress,
    this.currentEtaSeconds = 0,
    required this.startedAt,
    this.lastLocationAt,
    this.version = 1,
  });

  TrackingSession copyWith({
    String? sessionId,
    String? orderId,
    String? serviceType,
    String? driverId,
    String? customerId,
    TrackingSessionStatus? status,
    DriverLocation? currentLocation,
    double? destinationLat,
    double? destinationLng,
    String? destinationAddress,
    int? currentEtaSeconds,
    DateTime? startedAt,
    DateTime? lastLocationAt,
    int? version,
  }) {
    return TrackingSession(
      sessionId: sessionId ?? this.sessionId,
      orderId: orderId ?? this.orderId,
      serviceType: serviceType ?? this.serviceType,
      driverId: driverId ?? this.driverId,
      customerId: customerId ?? this.customerId,
      status: status ?? this.status,
      currentLocation: currentLocation ?? this.currentLocation,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      currentEtaSeconds: currentEtaSeconds ?? this.currentEtaSeconds,
      startedAt: startedAt ?? this.startedAt,
      lastLocationAt: lastLocationAt ?? this.lastLocationAt,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'orderId': orderId,
      'serviceType': serviceType,
      'driverId': driverId,
      'customerId': customerId,
      'status': status.key,
      'currentLocation': currentLocation?.toMap(),
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
      'destinationAddress': destinationAddress,
      'currentEtaSeconds': currentEtaSeconds,
      'startedAt': startedAt.toIso8601String(),
      'lastLocationAt': lastLocationAt?.toIso8601String(),
      'version': version,
    };
  }

  factory TrackingSession.fromMap(Map<String, dynamic> map, String docId) {
    final locData = map['currentLocation'] is Map ? Map<String, dynamic>.from(map['currentLocation'] as Map) : null;
    return TrackingSession(
      sessionId: docId,
      orderId: map['orderId']?.toString() ?? '',
      serviceType: map['serviceType']?.toString() ?? 'taxi',
      driverId: map['driverId']?.toString() ?? '',
      customerId: map['customerId']?.toString() ?? '',
      status: TrackingSessionStatus.fromString(map['status']?.toString()),
      currentLocation: locData != null ? DriverLocation.fromMap(locData, map['driverId']?.toString() ?? '') : null,
      destinationLat: (map['destinationLat'] as num?)?.toDouble() ?? 0.0,
      destinationLng: (map['destinationLng'] as num?)?.toDouble() ?? 0.0,
      destinationAddress: map['destinationAddress']?.toString() ?? '',
      currentEtaSeconds: (map['currentEtaSeconds'] as num?)?.toInt() ?? 0,
      startedAt: map['startedAt'] != null
          ? DateTime.tryParse(map['startedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastLocationAt: map['lastLocationAt'] != null
          ? DateTime.tryParse(map['lastLocationAt'].toString())
          : null,
      version: (map['version'] as num?)?.toInt() ?? 1,
    );
  }
}
