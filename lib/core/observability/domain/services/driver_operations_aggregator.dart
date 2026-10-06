import 'package:dalal_alqaim/core/realtime/domain/entities/driver_presence.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/driver_location.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/heartbeat_record.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/tracking_session.dart';
import 'package:dalal_alqaim/core/realtime/domain/enums/realtime_enums.dart';
import 'package:dalal_alqaim/core/risk/domain/entities/risk_score.dart';
import '../entities/driver_live_operations_view.dart';
import '../enums/observability_enums.dart';

/// محرك توحيد وتجميع بيانات السائق التشغيلية الحية (Driver Live Operations Aggregator)
/// يدمج طبقة الـ Realtime (Phase 8.8) وطبقة الـ Risk (Phase 8.9) في شاشة العمليات
class DriverOperationsAggregator {
  const DriverOperationsAggregator();

  /// تجميع الحالة الحية للسائق
  static DriverLiveOperationsView aggregateDriverOperations({
    required String driverId,
    required DriverPresence presence,
    DriverLocation? location,
    HeartbeatRecord? latestHeartbeat,
    TrackingSession? activeTrackingSession,
    RiskScore? riskScore,
    List<String> activeOrderIds = const [],
    int activeIncidentsCount = 0,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();

    // 1. حساب صحة الـ GPS
    var gpsHealth = HealthStatus.healthy;
    if (location != null) {
      if (location.confidence == LocationConfidence.rejected) {
        gpsHealth = HealthStatus.unhealthy;
      } else if (location.confidence == LocationConfidence.suspicious) {
        gpsHealth = HealthStatus.degraded;
      }
    }

    // 2. حساب عمر آخر نبضة
    final heartbeatAge = latestHeartbeat != null
        ? currentTime.difference(latestHeartbeat.serverTimestamp).inSeconds.abs()
        : currentTime.difference(presence.lastHeartbeatAt).inSeconds.abs();

    // 3. تحديد جودة الاتصال
    String connectionQuality = 'stable';
    if (heartbeatAge > 30) {
      connectionQuality = 'disconnected';
    } else if (heartbeatAge > 15) {
      connectionQuality = 'degraded';
    }

    return DriverLiveOperationsView(
      driverId: driverId,
      presenceStatus: presence.state,
      gpsHealth: gpsHealth,
      lastHeartbeatAgeSeconds: heartbeatAge,
      trackingSessionActive: activeTrackingSession != null && activeTrackingSession.status == TrackingSessionStatus.active,
      currentEtaMinutes: 0,
      riskScore: riskScore?.normalizedScore ?? 0,
      activeOrderIds: activeOrderIds,
      connectionQuality: connectionQuality,
      activeIncidentsCount: activeIncidentsCount,
      lastUpdatedAt: currentTime,
    );
  }
}
