import 'package:flutter/foundation.dart';
import 'package:dalal_alqaim/core/realtime/domain/enums/realtime_enums.dart';
import '../enums/observability_enums.dart';

/// الرؤية التشغيلية الحية الشاملة للسائق (Unified Driver Live Operations View)
/// تدمج محرك الـ Realtime (Phase 8.8) ومحرك الـ Risk (Phase 8.9) والطلبات النشطة
@immutable
class DriverLiveOperationsView {
  final String driverId;
  final DriverPresenceState presenceStatus;
  final HealthStatus gpsHealth;
  final int lastHeartbeatAgeSeconds;
  final bool trackingSessionActive;
  final int currentEtaMinutes;
  final int riskScore; // 0 .. 100
  final List<String> activeOrderIds;
  final String connectionQuality;
  final int activeIncidentsCount;
  final DateTime lastUpdatedAt;

  const DriverLiveOperationsView({
    required this.driverId,
    this.presenceStatus = DriverPresenceState.offline,
    this.gpsHealth = HealthStatus.healthy,
    this.lastHeartbeatAgeSeconds = 0,
    this.trackingSessionActive = false,
    this.currentEtaMinutes = 0,
    this.riskScore = 0,
    this.activeOrderIds = const [],
    this.connectionQuality = 'stable',
    this.activeIncidentsCount = 0,
    required this.lastUpdatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'presenceStatus': presenceStatus.key,
      'gpsHealth': gpsHealth.key,
      'lastHeartbeatAgeSeconds': lastHeartbeatAgeSeconds,
      'trackingSessionActive': trackingSessionActive,
      'currentEtaMinutes': currentEtaMinutes,
      'riskScore': riskScore,
      'activeOrderIds': activeOrderIds,
      'connectionQuality': connectionQuality,
      'activeIncidentsCount': activeIncidentsCount,
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
    };
  }

  factory DriverLiveOperationsView.fromMap(Map<String, dynamic> map, String docId) {
    return DriverLiveOperationsView(
      driverId: docId,
      presenceStatus: DriverPresenceState.fromString(map['presenceStatus']?.toString()),
      gpsHealth: HealthStatus.fromString(map['gpsHealth']?.toString()),
      lastHeartbeatAgeSeconds: (map['lastHeartbeatAgeSeconds'] as num?)?.toInt() ?? 0,
      trackingSessionActive: map['trackingSessionActive'] == true,
      currentEtaMinutes: (map['currentEtaMinutes'] as num?)?.toInt() ?? 0,
      riskScore: (map['riskScore'] as num?)?.toInt() ?? 0,
      activeOrderIds: (map['activeOrderIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      connectionQuality: map['connectionQuality']?.toString() ?? 'stable',
      activeIncidentsCount: (map['activeIncidentsCount'] as num?)?.toInt() ?? 0,
      lastUpdatedAt: map['lastUpdatedAt'] != null
          ? DateTime.tryParse(map['lastUpdatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
