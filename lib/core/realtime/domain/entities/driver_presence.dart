import 'package:flutter/foundation.dart';
import '../enums/realtime_enums.dart';

/// سجل تواجد وحالة السائق المحدث لحظياً (Driver Presence Entity)
@immutable
class DriverPresence {
  final String driverId;
  final DriverPresenceState state;
  final DateTime lastHeartbeatAt;
  final DateTime lastLocationUpdate;
  final String? currentSessionId;
  final int activeOrdersCount;
  final DateTime updatedAt;

  const DriverPresence({
    required this.driverId,
    required this.state,
    required this.lastHeartbeatAt,
    required this.lastLocationUpdate,
    this.currentSessionId,
    this.activeOrdersCount = 0,
    required this.updatedAt,
  });

  DriverPresence copyWith({
    String? driverId,
    DriverPresenceState? state,
    DateTime? lastHeartbeatAt,
    DateTime? lastLocationUpdate,
    String? currentSessionId,
    int? activeOrdersCount,
    DateTime? updatedAt,
  }) {
    return DriverPresence(
      driverId: driverId ?? this.driverId,
      state: state ?? this.state,
      lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      activeOrdersCount: activeOrdersCount ?? this.activeOrdersCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'state': state.key,
      'lastHeartbeatAt': lastHeartbeatAt.toIso8601String(),
      'lastLocationUpdate': lastLocationUpdate.toIso8601String(),
      'currentSessionId': currentSessionId,
      'activeOrdersCount': activeOrdersCount,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DriverPresence.fromMap(Map<String, dynamic> map, String docId) {
    return DriverPresence(
      driverId: docId,
      state: DriverPresenceState.fromString(map['state']?.toString()),
      lastHeartbeatAt: map['lastHeartbeatAt'] != null
          ? DateTime.tryParse(map['lastHeartbeatAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastLocationUpdate: map['lastLocationUpdate'] != null
          ? DateTime.tryParse(map['lastLocationUpdate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      currentSessionId: map['currentSessionId']?.toString(),
      activeOrdersCount: (map['activeOrdersCount'] as num?)?.toInt() ?? 0,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
