import 'package:dalal_alqaim/features/trip/data/datasources/google_directions_datasource.dart';
import 'package:dalal_alqaim/services/routing/osrm_route_service.dart';
import 'package:dalal_alqaim/features/trip/data/datasources/trip_remote_datasource.dart';
import 'package:dalal_alqaim/features/trip/data/models/trip_model.dart';
import 'package:dalal_alqaim/features/trip/domain/entities/trip.dart';
import 'package:dalal_alqaim/features/trip/domain/repositories/trip_repository.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:dalal_alqaim/models/route_option.dart';

class TripRepositoryImpl implements TripRepository {
  final TripRemoteDataSource _remoteDataSource;
  final GoogleDirectionsDataSource _googleDataSource;

  TripRepositoryImpl(this._remoteDataSource, this._googleDataSource);

  @override
  Stream<Trip> listenToTrip(String tripId) {
    return _remoteDataSource.listenToTrip(tripId).map((map) {
      if (map.isEmpty) {
        throw Exception("Trip not found");
      }
      return TripModel.fromMap(map, tripId);
    });
  }

  @override
  Stream<LatLng> listenToDriverLocation(String driverId) {
    return _remoteDataSource.listenToDriver(driverId).map((map) {
      // Captain app writes location as 'currentLat'/'currentLng'
      final lat = map['currentLat'] ?? map['lat'];
      final lng = map['currentLng'] ?? map['lng'];
      if (lat != null && lng != null) {
        return LatLng((lat as num).toDouble(), (lng as num).toDouble());
      }
      return const LatLng(0, 0);
    });
  }

  @override
  Stream<Map<String, dynamic>> listenToDriver(String driverId) {
    return _remoteDataSource.listenToDriver(driverId);
  }

  @override
  Future<void> cancelTrip(String tripId, {String? reason}) {
    return _remoteDataSource.cancelTrip(tripId, reason: reason);
  }

  @override
  Future<void> updateTripStatus(String tripId, TripStatus status) {
    return _remoteDataSource.updateTripStatus(tripId, status.name);
  }

  @override
  Future<void> submitDriverRating(String driverId, String tripId, double rating) {
    return _remoteDataSource.submitDriverRating(driverId, tripId, rating);
  }

  @override
  Future<void> completeTrip(String rideId, double rating, String feedback) {
    return _remoteDataSource.completeTrip(rideId, rating, feedback);
  }

  @override
  Future<String> createRideRequest(Map<String, dynamic> rideData) {
    return _remoteDataSource.createRideRequest(rideData);
  }

  @override
  Future<({List<LatLng> points, double distance, double duration})> getRoute(
    LatLng start,
    LatLng end,
  ) async {
    // Priority 1: Google Directions API (Primary)
    try {
      final result = await _googleDataSource.getRoute(start, end);
      if (result.points.isNotEmpty) {
        return result;
      }
    } catch (e) {
      debugPrint(' Google Directions failed: $e');
    }

    // Priority 2: OSRM (Fallback)
    try {
      final route = await OsrmRouteService.getDrivingRoute(
        start: start,
        end: end,
        overview: 'simplified',
        includeSteps: false,
      );
      if (route.points.isNotEmpty) {
        return (
          points: route.points,
          distance: route.distanceMeters,
          duration: route.durationSeconds,
        );
      }
    } catch (_) {}

    return (points: <LatLng>[], distance: 0.0, duration: 0.0);
  }

  @override
  Future<List<RouteOption>> getRouteAlternatives(LatLng start, LatLng end) async {
    final List<RouteOption> rawRoutes = [];

    // 1. Google Directions API (Primary)
    try {
      final googleResults = await _googleDataSource.getRouteAlternatives(start, end);
      rawRoutes.addAll(googleResults);
    } catch (e) {
      debugPrint(' Google Directions Alternatives failed: $e');
    }

    // 2. OSRM (Secondary - provides "shortcuts" or alternative branches)
    try {
      final osrmRoute = await OsrmRouteService.getDrivingRoute(
        start: start,
        end: end,
        overview: 'simplified',
        includeSteps: false,
      );

      if (osrmRoute.points.isNotEmpty) {
        // Check if OSRM route is truly "unique" compared to Google
        bool isDuplicate = false;
        for (final r in rawRoutes) {
          final distDiff = (r.distanceMeters - osrmRoute.distanceMeters).abs();
          final durationDiff = (r.durationSeconds - osrmRoute.durationSeconds).abs();

          // If distance and duration are almost identical, consider it a duplicate
          if (distDiff < 200 && durationDiff < 60) {
            isDuplicate = true;
            break;
          }
        }

        if (!isDuplicate) {
          rawRoutes.add(
            RouteOption(
              points: osrmRoute.points,
              distanceMeters: osrmRoute.distanceMeters,
              durationSeconds: osrmRoute.durationSeconds,
              tag: 'osrm_alt',
              label: 'مسار بديل',
            ),
          );
        }
      }
    } catch (e) {
      debugPrint(' OSRM in Alternatives failed: $e');
    }

    if (rawRoutes.isEmpty) return [];

    // 3. Intelligent Classification
    final List<RouteOption> processed = [];

    rawRoutes.sort((a, b) => a.durationSeconds.compareTo(b.durationSeconds));
    final fastest = rawRoutes.first;

    // Define a rough price heuristic to assign "Cheapest" label correctly
    // Price = Distance * 0.5 IQD/m + Time * 1 IQD/s (roughly 500/km and 60/min)
    double getRoughPrice(RouteOption r) =>
        (r.distanceMeters * 0.5) + (r.durationSeconds * 0.83); // 0.83 IQD/s = 50 IQD/min

    rawRoutes.sort((a, b) => getRoughPrice(a).compareTo(getRoughPrice(b)));
    final cheapest = rawRoutes.first;

    if (fastest == cheapest) {
      processed.add(
        RouteOption(
          points: fastest.points,
          distanceMeters: fastest.distanceMeters,
          durationSeconds: fastest.durationSeconds,
          tag: 'fastest_cheapest',
          label: 'الأسرع والأوفر',
        ),
      );
    } else {
      processed.add(
        RouteOption(
          points: fastest.points,
          distanceMeters: fastest.distanceMeters,
          durationSeconds: fastest.durationSeconds,
          tag: 'fastest',
          label: 'الأسرع',
        ),
      );
      processed.add(
        RouteOption(
          points: cheapest.points,
          distanceMeters: cheapest.distanceMeters,
          durationSeconds: cheapest.durationSeconds,
          tag: 'cheapest',
          label: 'الأرخص',
        ),
      );
    }

    // Add a third option (Shortest distance) if it's not already added
    rawRoutes.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    final shortest = rawRoutes.first;

    bool alreadyAdded(RouteOption r) => processed.any(
      (p) => p.distanceMeters == r.distanceMeters && p.durationSeconds == r.durationSeconds,
    );

    if (!alreadyAdded(shortest)) {
      processed.add(
        RouteOption(
          points: shortest.points,
          distanceMeters: shortest.distanceMeters,
          durationSeconds: shortest.durationSeconds,
          tag: 'shortest',
          label: 'الأقصر',
        ),
      );
    }

    // Fallback if we still need more options to fill 3
    if (processed.length < 3) {
      for (final r in rawRoutes) {
        if (!alreadyAdded(r)) {
          processed.add(
            RouteOption(
              points: r.points,
              distanceMeters: r.distanceMeters,
              durationSeconds: r.durationSeconds,
              tag: 'alt',
              label: 'مسار بديل',
            ),
          );
        }
        if (processed.length >= 3) break;
      }
    }

    return processed;
  }

  @override
  Future<List<LatLng>> getRoutePoints(LatLng start, LatLng end) async {
    // Try Google first
    try {
      final result = await _googleDataSource.getRoute(start, end);
      if (result.points.isNotEmpty) return result.points;
    } catch (_) {}

    // Fallback to OSRM
    final route = await OsrmRouteService.getDrivingRoute(
      start: start,
      end: end,
      overview: 'simplified',
      includeSteps: false,
    );
    return route.points;
  }
}
