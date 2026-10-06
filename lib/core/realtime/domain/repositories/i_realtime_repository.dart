import '../entities/driver_presence.dart';
import '../entities/driver_location.dart';
import '../entities/tracking_session.dart';
import '../entities/heartbeat_record.dart';
import '../entities/realtime_event.dart';
import '../entities/realtime_recovery_job.dart';

/// العقد التجريدي لمستودع العمليات اللحظية والتتبع (IRealtimeRepository)
abstract class IRealtimeRepository {
  /// حفظ وتحديث حالة تواجد السائق
  Future<void> updateDriverPresence(DriverPresence presence);

  /// جلب حالة تواجد السائق
  Future<DriverPresence?> getDriverPresence(String driverId);

  /// تسجيل نبضة اتصال جديدة
  Future<void> saveHeartbeat(HeartbeatRecord heartbeat);

  /// تحديث موقع السائق اللحظي
  Future<void> updateDriverLocation(DriverLocation location);

  /// جلب آخر موقع معتمد للسائق
  Future<DriverLocation?> getDriverLocation(String driverId);

  /// حفظ وتحديث جلسة التتبع المباشر
  Future<void> saveTrackingSession(TrackingSession session);

  /// جلب جلسة التتبع المباشر
  Future<TrackingSession?> getTrackingSession(String sessionId);

  /// حفظ حدث تشغيلي لحظي
  Future<void> saveRealtimeEvent(RealtimeEvent event);

  /// حفظ مهمة تعافي لحظية
  Future<void> saveRecoveryJob(RealtimeRecoveryJob job);

  /// الاستماع اللحظي لموقع السائق
  Stream<DriverLocation> streamDriverLocation(String driverId);

  /// الاستماع اللحظي لجلسة التتبع
  Stream<TrackingSession> streamTrackingSession(String sessionId);
}
