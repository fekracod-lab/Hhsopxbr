import 'package:flutter/foundation.dart';

/// مرشح التوزيع (Driver Dispatch Candidate Snapshot)
@immutable
class DispatchCandidate {
  final String driverId;
  final String name;
  final String phone;
  final double rating; // 1.0 - 5.0
  final double acceptanceRate; // 0.0 - 1.0
  final int activeOrdersCount;
  final double latitude;
  final double longitude;
  final DateTime lastLocationUpdate;
  final bool isOnline;
  final bool isApproved;
  final String status;
  final String role;
  final double distanceMeters;
  final double finalScore;

  const DispatchCandidate({
    required this.driverId,
    required this.name,
    required this.phone,
    this.rating = 5.0,
    this.acceptanceRate = 1.0,
    this.activeOrdersCount = 0,
    required this.latitude,
    required this.longitude,
    required this.lastLocationUpdate,
    this.isOnline = true,
    this.isApproved = true,
    this.status = 'active',
    this.role = 'delivery',
    this.distanceMeters = 0.0,
    this.finalScore = 0.0,
  });

  /// المسافة بالكيلومتر
  double get distanceKm => distanceMeters / 1000.0;

  /// عمر آخر تحديث لموقع الـ GPS بالثواني
  int get gpsAgeSeconds => DateTime.now().difference(lastLocationUpdate).inSeconds.abs();

  DispatchCandidate copyWith({
    String? driverId,
    String? name,
    String? phone,
    double? rating,
    double? acceptanceRate,
    int? activeOrdersCount,
    double? latitude,
    double? longitude,
    DateTime? lastLocationUpdate,
    bool? isOnline,
    bool? isApproved,
    String? status,
    String? role,
    double? distanceMeters,
    double? finalScore,
  }) {
    return DispatchCandidate(
      driverId: driverId ?? this.driverId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      rating: rating ?? this.rating,
      acceptanceRate: acceptanceRate ?? this.acceptanceRate,
      activeOrdersCount: activeOrdersCount ?? this.activeOrdersCount,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      isOnline: isOnline ?? this.isOnline,
      isApproved: isApproved ?? this.isApproved,
      status: status ?? this.status,
      role: role ?? this.role,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      finalScore: finalScore ?? this.finalScore,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'name': name,
      'phone': phone,
      'rating': rating,
      'acceptanceRate': acceptanceRate,
      'activeOrdersCount': activeOrdersCount,
      'latitude': latitude,
      'longitude': longitude,
      'lastLocationUpdate': lastLocationUpdate.toIso8601String(),
      'isOnline': isOnline,
      'isApproved': isApproved,
      'status': status,
      'role': role,
      'distanceMeters': distanceMeters,
      'finalScore': finalScore,
    };
  }

  factory DispatchCandidate.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedUpdate = DateTime.now();
    if (map['lastLocationUpdate'] != null) {
      if (map['lastLocationUpdate'] is DateTime) {
        parsedUpdate = map['lastLocationUpdate'] as DateTime;
      } else {
        parsedUpdate = DateTime.tryParse(map['lastLocationUpdate'].toString()) ?? DateTime.now();
      }
    }

    double lat = 0.0;
    double lng = 0.0;
    if (map['latitude'] != null) {
      lat = (map['latitude'] as num).toDouble();
    } else if (map['lat'] != null) {
      lat = (map['lat'] as num).toDouble();
    } else if (map['location'] is Map) {
      lat = ((map['location'] as Map)['latitude'] as num?)?.toDouble() ?? 0.0;
      lng = ((map['location'] as Map)['longitude'] as num?)?.toDouble() ?? 0.0;
    }

    if (map['longitude'] != null) {
      lng = (map['longitude'] as num).toDouble();
    } else if (map['lng'] != null) {
      lng = (map['lng'] as num).toDouble();
    }

    return DispatchCandidate(
      driverId: docId,
      name: map['fullName']?.toString() ?? map['name']?.toString() ?? 'كابتن مدار',
      phone: map['phone']?.toString() ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      acceptanceRate: (map['acceptanceRate'] as num?)?.toDouble() ?? 1.0,
      activeOrdersCount: (map['activeOrdersCount'] as num?)?.toInt() ?? 0,
      latitude: lat,
      longitude: lng,
      lastLocationUpdate: parsedUpdate,
      isOnline: map['isOnline'] == true || map['online'] == true || map['available'] == true,
      isApproved: map['isApproved'] != false,
      status: map['status']?.toString() ?? 'active',
      role: map['role']?.toString() ?? 'delivery',
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      finalScore: (map['finalScore'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
