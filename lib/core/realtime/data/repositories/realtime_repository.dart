import '../../domain/entities/driver_presence.dart';
import '../../domain/entities/driver_location.dart';
import '../../domain/entities/tracking_session.dart';
import '../../domain/entities/heartbeat_record.dart';
import '../../domain/entities/realtime_event.dart';
import '../../domain/entities/realtime_recovery_job.dart';
import '../../domain/repositories/i_realtime_repository.dart';
import '../datasources/realtime_remote_datasource.dart';

/// تطبيق مستودع العمليات اللحظية (RealtimeRepository)
class RealtimeRepository implements IRealtimeRepository {
  final RealtimeRemoteDatasource _remoteDatasource;

  RealtimeRepository({RealtimeRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? RealtimeRemoteDatasource();

  @override
  Future<void> updateDriverPresence(DriverPresence presence) {
    return _remoteDatasource.updateDriverPresence(presence);
  }

  @override
  Future<DriverPresence?> getDriverPresence(String driverId) {
    return _remoteDatasource.getDriverPresence(driverId);
  }

  @override
  Future<void> saveHeartbeat(HeartbeatRecord heartbeat) {
    return _remoteDatasource.saveHeartbeat(heartbeat);
  }

  @override
  Future<void> updateDriverLocation(DriverLocation location) {
    return _remoteDatasource.updateDriverLocation(location);
  }

  @override
  Future<DriverLocation?> getDriverLocation(String driverId) {
    return _remoteDatasource.getDriverLocation(driverId);
  }

  @override
  Future<void> saveTrackingSession(TrackingSession session) {
    return _remoteDatasource.saveTrackingSession(session);
  }

  @override
  Future<TrackingSession?> getTrackingSession(String sessionId) {
    return _remoteDatasource.getTrackingSession(sessionId);
  }

  @override
  Future<void> saveRealtimeEvent(RealtimeEvent event) {
    return _remoteDatasource.saveRealtimeEvent(event);
  }

  @override
  Future<void> saveRecoveryJob(RealtimeRecoveryJob job) {
    return _remoteDatasource.saveRecoveryJob(job);
  }

  @override
  Stream<DriverLocation> streamDriverLocation(String driverId) {
    return _remoteDatasource.streamDriverLocation(driverId);
  }

  @override
  Stream<TrackingSession> streamTrackingSession(String sessionId) {
    return _remoteDatasource.streamTrackingSession(sessionId);
  }
}
