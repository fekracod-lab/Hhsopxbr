import 'dart:async';
import 'package:dalal_alqaim/core/realtime/domain/entities/driver_presence.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/driver_location.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/tracking_session.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/heartbeat_record.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/realtime_event.dart';
import 'package:dalal_alqaim/core/realtime/domain/entities/realtime_recovery_job.dart';
import 'package:dalal_alqaim/core/realtime/domain/repositories/i_realtime_repository.dart';

/// 🧪 مستودع ذاكرة افتراضي لاختبارات العمليات اللحظية بدون Firebase
class InMemoryRealtimeRepository implements IRealtimeRepository {
  final Map<String, DriverPresence> presences = {};
  final Map<String, DriverLocation> locations = {};
  final Map<String, TrackingSession> sessions = {};
  final List<HeartbeatRecord> heartbeats = [];
  final List<RealtimeEvent> events = [];
  final List<RealtimeRecoveryJob> jobs = [];

  final _locationControllers = <String, StreamController<DriverLocation>>{};
  final _sessionControllers = <String, StreamController<TrackingSession>>{};

  @override
  Future<void> updateDriverPresence(DriverPresence presence) async {
    presences[presence.driverId] = presence;
  }

  @override
  Future<DriverPresence?> getDriverPresence(String driverId) async {
    return presences[driverId];
  }

  @override
  Future<void> saveHeartbeat(HeartbeatRecord heartbeat) async {
    heartbeats.add(heartbeat);
  }

  @override
  Future<void> updateDriverLocation(DriverLocation location) async {
    locations[location.driverId] = location;
    if (_locationControllers.containsKey(location.driverId)) {
      _locationControllers[location.driverId]!.add(location);
    }
  }

  @override
  Future<DriverLocation?> getDriverLocation(String driverId) async {
    return locations[driverId];
  }

  @override
  Future<void> saveTrackingSession(TrackingSession session) async {
    sessions[session.sessionId] = session;
    if (_sessionControllers.containsKey(session.sessionId)) {
      _sessionControllers[session.sessionId]!.add(session);
    }
  }

  @override
  Future<TrackingSession?> getTrackingSession(String sessionId) async {
    return sessions[sessionId];
  }

  @override
  Future<void> saveRealtimeEvent(RealtimeEvent event) async {
    events.add(event);
  }

  @override
  Future<void> saveRecoveryJob(RealtimeRecoveryJob job) async {
    jobs.add(job);
  }

  @override
  Stream<DriverLocation> streamDriverLocation(String driverId) {
    _locationControllers.putIfAbsent(driverId, () => StreamController<DriverLocation>.broadcast());
    return _locationControllers[driverId]!.stream;
  }

  @override
  Stream<TrackingSession> streamTrackingSession(String sessionId) {
    _sessionControllers.putIfAbsent(sessionId, () => StreamController<TrackingSession>.broadcast());
    return _sessionControllers[sessionId]!.stream;
  }

  void clear() {
    presences.clear();
    locations.clear();
    sessions.clear();
    heartbeats.clear();
    events.clear();
    jobs.clear();
  }
}
