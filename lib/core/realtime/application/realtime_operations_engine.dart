import '../domain/entities/driver_presence.dart';
import '../domain/entities/driver_location.dart';
import '../domain/entities/location_sample.dart';
import '../domain/entities/tracking_session.dart';
import '../domain/entities/heartbeat_record.dart';
import '../domain/entities/reconciliation_result.dart';
import '../domain/enums/realtime_enums.dart';
import '../domain/services/driver_presence_engine.dart';
import '../domain/services/heartbeat_engine.dart';
import '../domain/services/location_integrity_engine.dart';
import '../domain/services/tracking_session_engine.dart';
import '../domain/services/reconciliation_engine.dart';
import '../domain/services/realtime_event_ordering_engine.dart';
import '../domain/repositories/i_realtime_repository.dart';
import '../data/repositories/realtime_repository.dart';

import 'package:dalal_alqaim/core/security/application/security_engine.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';
import 'package:dalal_alqaim/core/notifications/application/notification_engine.dart';

/// المحرك المركزي للعمليات اللحظية والتتبع المباشر (MADAR Realtime Operations Engine)
class RealtimeOperationsEngine {
  static RealtimeOperationsEngine? _instance;
  static RealtimeOperationsEngine get instance => _instance ??= RealtimeOperationsEngine();

  final IRealtimeRepository _repository;
  final HeartbeatEngine _heartbeatEngine;
  final RealtimeEventOrderingEngine _orderingEngine;
  final SecurityEngine _securityEngine;
  final NotificationEngine _notificationEngine;

  RealtimeOperationsEngine({
    IRealtimeRepository? repository,
    HeartbeatEngine? heartbeatEngine,
    RealtimeEventOrderingEngine? orderingEngine,
    SecurityEngine? securityEngine,
    NotificationEngine? notificationEngine,
  }) : _repository = repository ?? RealtimeRepository(),
        _heartbeatEngine = heartbeatEngine ?? HeartbeatEngine(),
        _orderingEngine = orderingEngine ?? RealtimeEventOrderingEngine(),
        _securityEngine = securityEngine ?? SecurityEngine.instance,
        _notificationEngine = notificationEngine ?? NotificationEngine.instance;

  RealtimeEventOrderingEngine get orderingEngine => _orderingEngine;
  SecurityEngine get securityEngine => _securityEngine;
  NotificationEngine get notificationEngine => _notificationEngine;

  /// معالجة وتوثيق نبضة اتصال السائق
  Future<HeartbeatRecord> processHeartbeat({
    required String driverId,
    required String sessionId,
    required DateTime clientTimestamp,
    required int sequenceNumber,
  }) async {
    final heartbeatId = 'hb-$driverId-$sequenceNumber-${DateTime.now().millisecondsSinceEpoch}';

    final record = _heartbeatEngine.processHeartbeat(
      heartbeatId: heartbeatId,
      driverId: driverId,
      sessionId: sessionId,
      clientTimestamp: clientTimestamp,
      sequenceNumber: sequenceNumber,
    );

    if (record.status == HeartbeatStatus.rejected) {
      return record;
    }

    await _repository.saveHeartbeat(record);

    // تحديث حالة تواجد السائق
    var currentPresence = await _repository.getDriverPresence(driverId);
    if (currentPresence == null) {
      currentPresence = DriverPresence(
        driverId: driverId,
        state: DriverPresenceState.available,
        lastHeartbeatAt: record.serverTimestamp,
        lastLocationUpdate: record.serverTimestamp,
        currentSessionId: sessionId,
        updatedAt: DateTime.now(),
      );
    } else {
      currentPresence = currentPresence.copyWith(
        lastHeartbeatAt: record.serverTimestamp,
        currentSessionId: sessionId,
        state: currentPresence.state == DriverPresenceState.offline
            ? DriverPresenceState.available
            : currentPresence.state,
        updatedAt: DateTime.now(),
      );
    }

    await _repository.updateDriverPresence(currentPresence);
    return record;
  }

  /// معالجة وتوثيق موقع السائق اللحظي
  Future<DriverLocation> processDriverLocation({
    required String driverId,
    required LocationSample sample,
    int sequenceNumber = 0,
  }) async {
    // التحقق من ترتيب الأحداث
    _orderingEngine.evaluateSequence(
      entityId: driverId,
      incomingSequence: sequenceNumber,
    );

    final prevLocation = await _repository.getDriverLocation(driverId);

    final validatedLocation = LocationIntegrityEngine.evaluateSample(
      driverId: driverId,
      currentSample: sample,
      previousLocation: prevLocation,
      sequenceNumber: sequenceNumber,
    );

    if (validatedLocation.confidence != LocationConfidence.rejected) {
      await _repository.updateDriverLocation(validatedLocation);

      // تحديث آخر موقع في سجل التواجد
      final presence = await _repository.getDriverPresence(driverId);
      if (presence != null) {
        await _repository.updateDriverPresence(
          presence.copyWith(lastLocationUpdate: validatedLocation.timestamp),
        );
      }

      if (validatedLocation.confidence == LocationConfidence.suspicious) {
        await _securityEngine.logViolation(
          type: SecurityViolationType.tamperedPayload,
          userId: driverId,
          actionAttempted: 'processDriverLocation',
          reason: 'تم رصد موقع غير منطقي أو سرعة غير فيزيائية',
          severity: 'HIGH',
          metadata: validatedLocation.toMap(),
        );
      }
    }

    return validatedLocation;
  }

  /// بدء جلسة تتبع جديدة لرحلة أو طلب
  Future<TrackingSession> startTrackingSession({
    required String sessionId,
    required String orderId,
    required String serviceType,
    required String driverId,
    required String customerId,
    required double destinationLat,
    required double destinationLng,
    required String destinationAddress,
  }) async {
    final initialLocation = await _repository.getDriverLocation(driverId);

    final session = TrackingSessionEngine.createSession(
      sessionId: sessionId,
      orderId: orderId,
      serviceType: serviceType,
      driverId: driverId,
      customerId: customerId,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      destinationAddress: destinationAddress,
      initialLocation: initialLocation,
    );

    await _repository.saveTrackingSession(session);
    return session;
  }

  /// تحديث موقع جلسة التتبع وإعادة احتساب الـ ETA
  Future<TrackingSession?> updateTrackingSessionLocation({
    required String sessionId,
    required DriverLocation location,
  }) async {
    final session = await _repository.getTrackingSession(sessionId);
    if (session == null) return null;

    final updated = TrackingSessionEngine.updateLocation(
      session: session,
      location: location,
    );

    await _repository.saveTrackingSession(updated);
    return updated;
  }

  /// مطابقة جلسة تتبع محلية مع حالة الخادم الموثقة
  Future<(TrackingSession, ReconciliationResult)> reconcileTrackingSession({
    required TrackingSession localSession,
  }) async {
    final serverSession = await _repository.getTrackingSession(localSession.sessionId);
    return ReconciliationEngine.reconcileTrackingSession(
      localSession: localSession,
      serverSession: serverSession,
    );
  }

  /// التحقق من أهلية السائق للتوزيع الفوري
  Future<bool> isDriverEligibleForDispatch(String driverId) async {
    final presence = await _repository.getDriverPresence(driverId);
    if (presence == null) return false;
    return DriverPresenceEngine.isEligibleForDispatch(presence: presence);
  }
}
