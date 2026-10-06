import '../entities/driver_presence.dart';
import '../entities/tracking_session.dart';
import '../entities/heartbeat_record.dart';

/// محرك رصد الحالات القديمة وفقدان الاتصال (Stale State Detector)
class StaleStateDetector {
  const StaleStateDetector();

  /// فحص هل السائق أصبح قديماً وغير موثوق (Stale)
  static bool isDriverStale({
    required DriverPresence presence,
    Duration staleThreshold = const Duration(seconds: 90),
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    return currentTime.difference(presence.lastHeartbeatAt).abs() > staleThreshold;
  }

  /// فحص هل انقطع اتصال السائق تماماً (Offline)
  static bool isDriverOffline({
    required DriverPresence presence,
    Duration offlineThreshold = const Duration(minutes: 5),
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    return currentTime.difference(presence.lastHeartbeatAt).abs() > offlineThreshold;
  }

  /// فحص هل جلسة التتبع المباشر أصبحت راكدة (Stale Session)
  static bool isTrackingSessionStale({
    required TrackingSession session,
    Duration staleThreshold = const Duration(minutes: 15),
    DateTime? now,
  }) {
    final lastActive = session.lastLocationAt ?? session.startedAt;
    final currentTime = now ?? DateTime.now();
    return currentTime.difference(lastActive).abs() > staleThreshold;
  }

  /// فحص هل نبضة الاتصال قديمة
  static bool isHeartbeatStale({
    required HeartbeatRecord heartbeat,
    Duration threshold = const Duration(seconds: 90),
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    return currentTime.difference(heartbeat.serverTimestamp).abs() > threshold;
  }
}
