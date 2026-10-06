import 'dart:math' as math;
import '../entities/delivery_execution_models.dart';
import 'delivery_execution_calculator.dart';

/// محرك إدارة المسارات والتحكم في تكرار استدعاءات OSRM (Pure Route Engine)
class DeliveryRouteEngine {
  static const double minDriverMovementForRecalcMeters = 35.0; // متر
  static const double routeDeviationThresholdMeters = 60.0; // متر انحراف عن المسار
  static const int minRecalcIntervalSeconds = 12; // ثانية

  /// هل يجب إعادة حساب المسار عبر OSRM API؟
  static bool shouldRecalculateRoute({
    required DeliveryLocationEntity currentDriverLocation,
    required DeliveryPoint targetDestination,
    required DeliveryRouteEntity? existingRoute,
    DeliveryLocationEntity? lastCalculatedDriverLocation,
    DeliveryPoint? lastCalculatedDestination,
    DateTime? now,
  }) {
    if (!currentDriverLocation.isValid || !targetDestination.isValid) {
      return false;
    }

    // 1. لا يوجد مسار حالي
    if (existingRoute == null || existingRoute.isEmpty) {
      return true;
    }

    // 2. تغيرت الوجهة المستهدفة (مثلاً الانتقال من المحل إلى الزبون)
    if (lastCalculatedDestination != null &&
        (lastCalculatedDestination.latitude != targetDestination.latitude ||
         lastCalculatedDestination.longitude != targetDestination.longitude)) {
      return true;
    }

    final currentTime = now ?? DateTime.now();

    // 3. التحقق من الفاصل الزمني لتفادي الضغط على السيرفر (Throttling)
    if (lastCalculatedDriverLocation != null) {
      final elapsed = currentTime.difference(existingRoute.calculatedAt).inSeconds;
      if (elapsed < minRecalcIntervalSeconds) {
        return false;
      }

      final moveDistance = DeliveryExecutionCalculator.calculateDistanceMeters(
        lastCalculatedDriverLocation.latitude,
        lastCalculatedDriverLocation.longitude,
        currentDriverLocation.latitude,
        currentDriverLocation.longitude,
      );

      // إذا تحرك السائق مسافة كافية وكان الفاصل الزمني قد انقضى
      if (moveDistance >= minDriverMovementForRecalcMeters) {
        return true;
      }
    }

    // 4. فحص انحراف السائق عن المسار الحالي (Off-Route Deviation)
    final distanceToTrack = calculateMinDistanceToPolyline(
      currentDriverLocation,
      existingRoute.polylinePoints,
    );

    if (distanceToTrack > routeDeviationThresholdMeters) {
      return true;
    }

    return false;
  }

  /// حساب أقل مسافة بين موقع السائق وخط مسار الملاحة (Distance to Polyline)
  static double calculateMinDistanceToPolyline(
    DeliveryLocationEntity location,
    List<DeliveryLocationEntity> polyline,
  ) {
    if (polyline.isEmpty) return double.infinity;
    if (polyline.length == 1) {
      return DeliveryExecutionCalculator.calculateDistanceMeters(
        location.latitude,
        location.longitude,
        polyline.first.latitude,
        polyline.first.longitude,
      );
    }

    double minDistance = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      final p1 = polyline[i];
      final p2 = polyline[i + 1];

      final dist = _distanceToSegment(
        location.latitude,
        location.longitude,
        p1.latitude,
        p1.longitude,
        p2.latitude,
        p2.longitude,
      );

      if (dist < minDistance) {
        minDistance = dist;
      }
    }

    return minDistance;
  }

  static double _distanceToSegment(
    double pLat,
    double pLng,
    double aLat,
    double aLng,
    double bLat,
    double bLng,
  ) {
    final dAB = DeliveryExecutionCalculator.calculateDistanceMeters(aLat, aLng, bLat, bLng);
    if (dAB == 0.0) {
      return DeliveryExecutionCalculator.calculateDistanceMeters(pLat, pLng, aLat, aLng);
    }

    final dAP = DeliveryExecutionCalculator.calculateDistanceMeters(aLat, aLng, pLat, pLng);
    final dBP = DeliveryExecutionCalculator.calculateDistanceMeters(bLat, bLng, pLat, pLng);

    // إذا كانت زاوية النقطة خارج القطعة المستقيمة
    if (dAP * dAP >= dBP * dBP + dAB * dAB) return dBP;
    if (dBP * dBP >= dAP * dAP + dAB * dAB) return dAP;

    // مساحة المثلث وحساب الارتفاع العمودي
    final s = (dAB + dAP + dBP) / 2.0;
    final area = math.sqrt(math.max(0.0, s * (s - dAB) * (s - dAP) * (s - dBP)));
    return (2.0 * area) / dAB;
  }
}
