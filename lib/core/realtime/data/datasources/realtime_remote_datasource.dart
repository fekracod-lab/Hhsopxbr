import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/driver_presence.dart';
import '../../domain/entities/driver_location.dart';
import '../../domain/entities/tracking_session.dart';
import '../../domain/entities/heartbeat_record.dart';
import '../../domain/entities/realtime_event.dart';
import '../../domain/entities/realtime_recovery_job.dart';

/// مصدر البيانات البعيد للعمليات اللحظية والتتبع (Realtime Remote Datasource)
class RealtimeRemoteDatasource {
  final FirebaseFirestore? _customFirestore;

  RealtimeRemoteDatasource({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  /// حفظ حالة تواجد السائق
  Future<void> updateDriverPresence(DriverPresence presence) async {
    final docRef = _firestore.collection('driver_presence').doc(presence.driverId);
    await docRef.set(presence.toMap(), SetOptions(merge: true));
  }

  /// جلب حالة تواجد السائق
  Future<DriverPresence?> getDriverPresence(String driverId) async {
    final doc = await _firestore.collection('driver_presence').doc(driverId).get();
    if (!doc.exists || doc.data() == null) return null;
    return DriverPresence.fromMap(doc.data()!, doc.id);
  }

  /// حفظ نبضة اتصال
  Future<void> saveHeartbeat(HeartbeatRecord heartbeat) async {
    final docRef = _firestore.collection('driver_heartbeats').doc(heartbeat.heartbeatId);
    await docRef.set(heartbeat.toMap());
  }

  /// حفظ موقع السائق اللحظي
  Future<void> updateDriverLocation(DriverLocation location) async {
    final docRef = _firestore.collection('driver_locations').doc(location.driverId);
    await docRef.set(location.toMap(), SetOptions(merge: true));
  }

  /// جلب موقع السائق
  Future<DriverLocation?> getDriverLocation(String driverId) async {
    final doc = await _firestore.collection('driver_locations').doc(driverId).get();
    if (!doc.exists || doc.data() == null) return null;
    return DriverLocation.fromMap(doc.data()!, doc.id);
  }

  /// حفظ جلسة التتبع
  Future<void> saveTrackingSession(TrackingSession session) async {
    final docRef = _firestore.collection('tracking_sessions').doc(session.sessionId);
    await docRef.set(session.toMap(), SetOptions(merge: true));
  }

  /// جلب جلسة التتبع
  Future<TrackingSession?> getTrackingSession(String sessionId) async {
    final doc = await _firestore.collection('tracking_sessions').doc(sessionId).get();
    if (!doc.exists || doc.data() == null) return null;
    return TrackingSession.fromMap(doc.data()!, doc.id);
  }

  /// حفظ حدث تشغيلي
  Future<void> saveRealtimeEvent(RealtimeEvent event) async {
    final docRef = _firestore.collection('realtime_events').doc(event.eventId);
    await docRef.set(event.toMap());
  }

  /// حفظ مهمة تعافي
  Future<void> saveRecoveryJob(RealtimeRecoveryJob job) async {
    final docRef = _firestore.collection('realtime_recovery_jobs').doc(job.jobId);
    await docRef.set(job.toMap());
  }

  /// الاستماع اللحظي لموقع السائق
  Stream<DriverLocation> streamDriverLocation(String driverId) {
    return _firestore.collection('driver_locations').doc(driverId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return DriverLocation(
          driverId: driverId,
          latitude: 0,
          longitude: 0,
          timestamp: DateTime.now(),
        );
      }
      return DriverLocation.fromMap(doc.data()!, doc.id);
    });
  }

  /// الاستماع اللحظي لجلسة التتبع
  Stream<TrackingSession> streamTrackingSession(String sessionId) {
    return _firestore.collection('tracking_sessions').doc(sessionId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        throw Exception('Tracking session not found');
      }
      return TrackingSession.fromMap(doc.data()!, doc.id);
    });
  }
}
