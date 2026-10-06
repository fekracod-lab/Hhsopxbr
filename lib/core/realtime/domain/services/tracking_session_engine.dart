import '../entities/tracking_session.dart';
import '../entities/driver_location.dart';
import '../enums/realtime_enums.dart';
import 'eta_engine.dart';

/// محرك إدارة وتحديث جلسات التتبع المباشر (Tracking Session Engine)
class TrackingSessionEngine {
  const TrackingSessionEngine();

  /// إنشاء جلسة تتبع جديدة
  static TrackingSession createSession({
    required String sessionId,
    required String orderId,
    required String serviceType,
    required String driverId,
    required String customerId,
    required double destinationLat,
    required double destinationLng,
    required String destinationAddress,
    DriverLocation? initialLocation,
  }) {
    int initialEta = 0;
    if (initialLocation != null) {
      final eta = ETAEngine.computeETA(
        currentLat: initialLocation.latitude,
        currentLng: initialLocation.longitude,
        targetLat: destinationLat,
        targetLng: destinationLng,
      );
      initialEta = eta.durationSeconds;
    }

    return TrackingSession(
      sessionId: sessionId,
      orderId: orderId,
      serviceType: serviceType,
      driverId: driverId,
      customerId: customerId,
      status: TrackingSessionStatus.active,
      currentLocation: initialLocation,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      destinationAddress: destinationAddress,
      currentEtaSeconds: initialEta,
      startedAt: DateTime.now(),
      lastLocationAt: initialLocation?.timestamp,
      version: 1,
    );
  }

  /// تحديث موقع السائق وإعادة احتساب وقت الوصول المتوقع (ETA)
  static TrackingSession updateLocation({
    required TrackingSession session,
    required DriverLocation location,
  }) {
    if (session.status != TrackingSessionStatus.active && session.status != TrackingSessionStatus.paused) {
      return session; // الجلسة منتهية أو ملغاة
    }

    final eta = ETAEngine.computeETA(
      currentLat: location.latitude,
      currentLng: location.longitude,
      targetLat: session.destinationLat,
      targetLng: session.destinationLng,
    );

    return session.copyWith(
      currentLocation: location,
      currentEtaSeconds: eta.durationSeconds,
      lastLocationAt: location.timestamp,
      version: session.version + 1,
    );
  }

  /// إتمام جلسة التتبع
  static TrackingSession completeSession(TrackingSession session) {
    return session.copyWith(
      status: TrackingSessionStatus.completed,
      version: session.version + 1,
    );
  }

  /// إلغاء جلسة التتبع
  static TrackingSession cancelSession(TrackingSession session) {
    return session.copyWith(
      status: TrackingSessionStatus.cancelled,
      version: session.version + 1,
    );
  }
}
