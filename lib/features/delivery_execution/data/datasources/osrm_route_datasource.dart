import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dalal_alqaim/services/routing/osrm_route_service.dart';
import '../../domain/entities/delivery_execution_models.dart';
import '../../domain/services/delivery_execution_calculator.dart';

/// مصدر بيانات مسارات OSRM مع خطة التعافي الاحتياطية (OSRM Route Datasource)
class OsrmRouteDatasource {
  Future<DeliveryRouteEntity> calculateDrivingRoute({
    required DeliveryLocationEntity start,
    required DeliveryPoint destination,
  }) async {
    if (!start.isValid || !destination.isValid) {
      return DeliveryRouteEntity.empty();
    }

    try {
      final startLatLng = LatLng(start.latitude, start.longitude);
      final destLatLng = LatLng(destination.latitude, destination.longitude);

      final routeResult = await OsrmRouteService.getDrivingRoute(
        start: startLatLng,
        end: destLatLng,
      );

      final polylineEntities = routeResult.points
          .map((p) => DeliveryLocationEntity(
                latitude: p.latitude,
                longitude: p.longitude,
                timestamp: DateTime.now(),
              ))
          .toList();

      final stepEntities = routeResult.steps
          .map((s) => DeliveryRouteStepEntity(
                latitude: s.location.latitude,
                longitude: s.location.longitude,
                distanceMeters: s.distance,
                durationSeconds: s.duration,
                instruction: s.name,
                maneuverType: s.type,
              ))
          .toList();

      return DeliveryRouteEntity(
        polylinePoints: polylineEntities,
        steps: stepEntities,
        totalDistanceMeters: routeResult.distanceMeters,
        totalDurationSeconds: routeResult.durationSeconds,
        calculatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint(' [OsrmRouteDatasource] OSRM error, using straight line fallback: $e');

      // Fallback: Straight line path between start & destination
      final directDistance = DeliveryExecutionCalculator.calculateDistanceMeters(
        start.latitude,
        start.longitude,
        destination.latitude,
        destination.longitude,
      );

      final estimatedDuration = directDistance / (30.0 * 1000.0 / 3600.0); // 30 km/h

      return DeliveryRouteEntity(
        polylinePoints: [
          start,
          DeliveryLocationEntity(
            latitude: destination.latitude,
            longitude: destination.longitude,
            timestamp: DateTime.now(),
          ),
        ],
        steps: const [],
        totalDistanceMeters: directDistance,
        totalDurationSeconds: estimatedDuration,
        calculatedAt: DateTime.now(),
      );
    }
  }
}
