import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dalal_alqaim/services/google_maps_service.dart';
import 'package:dalal_alqaim/models/route_option.dart';

class GoogleDirectionsDataSource {
  Future<({List<LatLng> points, double distance, double duration})> getRoute(
    LatLng start,
    LatLng end,
  ) async {
    return GoogleMapsService.instance.getDirections(start, end);
  }

  Future<List<RouteOption>> getRouteAlternatives(
    LatLng start,
    LatLng end,
  ) async {
    return GoogleMapsService.instance.getDirectionsAlternatives(start, end);
  }
}
