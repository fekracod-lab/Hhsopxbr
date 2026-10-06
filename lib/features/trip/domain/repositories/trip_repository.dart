import 'package:dalal_alqaim/features/trip/domain/entities/trip.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dalal_alqaim/models/route_option.dart';

abstract class TripRepository {
  Stream<Trip> listenToTrip(String tripId);
  Stream<LatLng> listenToDriverLocation(String driverId);
  Stream<Map<String, dynamic>> listenToDriver(String driverId);

  Future<({List<LatLng> points, double distance, double duration})> getRoute(
    LatLng start,
    LatLng end,
  );
  Future<List<RouteOption>> getRouteAlternatives(LatLng start, LatLng end);
  Future<void> cancelTrip(String tripId, {String? reason});
  Future<void> updateTripStatus(String tripId, TripStatus status);
  Future<void> submitDriverRating(String driverId, String tripId, double rating);
  Future<void> completeTrip(String rideId, double rating, String feedback);
  Future<String> createRideRequest(Map<String, dynamic> rideData);

  Future<List<LatLng>> getRoutePoints(LatLng start, LatLng end);
}
