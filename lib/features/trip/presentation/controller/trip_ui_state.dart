import 'package:dalal_alqaim/features/trip/domain/entities/trip.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum TripViewStatus { loading, searching, active, completed, cancelled, error }

class TripUiState {
  final TripViewStatus status;
  final Trip? trip;
  final LatLng? driverLocation;
  final LatLng? userLocation;
  final List<LatLng> routePoints;
  final int? etaMinutes;
  final String? distanceText;
  final double driverHeading;
  final String? errorMessage;
  final bool isOffline;
  final bool autoFollowEnabled;
  final bool ratingShown;

  TripUiState({
    this.status = TripViewStatus.loading,
    this.trip,
    this.driverLocation,
    this.userLocation,
    this.routePoints = const [],
    this.etaMinutes,
    this.distanceText,
    this.driverHeading = 0.0,
    this.errorMessage,
    this.isOffline = false,
    this.autoFollowEnabled = true,
    this.ratingShown = false,
  });

  TripUiState copyWith({
    TripViewStatus? status,
    Trip? trip,
    LatLng? driverLocation,
    LatLng? userLocation,
    List<LatLng>? routePoints,
    int? etaMinutes,
    String? distanceText,
    double? driverHeading,
    String? errorMessage,
    bool? isOffline,
    bool? autoFollowEnabled,
    bool? ratingShown,
  }) {
    return TripUiState(
      status: status ?? this.status,
      trip: trip ?? this.trip,
      driverLocation: driverLocation ?? this.driverLocation,
      userLocation: userLocation ?? this.userLocation,
      routePoints: routePoints ?? this.routePoints,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      distanceText: distanceText ?? this.distanceText,
      driverHeading: driverHeading ?? this.driverHeading,
      errorMessage: errorMessage ?? this.errorMessage,
      isOffline: isOffline ?? this.isOffline,
      autoFollowEnabled: autoFollowEnabled ?? this.autoFollowEnabled,
      ratingShown: ratingShown ?? this.ratingShown,
    );
  }
}
