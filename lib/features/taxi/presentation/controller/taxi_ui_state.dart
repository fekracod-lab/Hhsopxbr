import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dalal_alqaim/models/ride_type.dart';
import 'package:dalal_alqaim/models/route_option.dart';

typedef TaxiPoi = ({String name, String category, LatLng location});
typedef TaxiDriverLocation = ({LatLng location, double heading});

enum TaxiViewStatus {
  idle, // Initial state, selecting pickup
  selectingDropoff, // Panning to select destination
  calculating, // Fetching route and price
  ready, // Route found, selecting ride type
  requesting, // Submitting to Firebase
}

class TaxiUiState {
  final TaxiViewStatus status;
  final LatLng? pickupLocation;
  final String pickupAddress;
  final LatLng? dropoffLocation;
  final String dropoffAddress;

  // Multi-Route support
  final List<RouteOption> routeAlternatives;
  final RouteOption? selectedRoute;

  // Legacy (kept for safety, but we'll use selectedRoute)
  final List<LatLng> routePoints;
  final double? distanceKm;
  final int? durationMin;

  final RideType? selectedRideType;
  final String? errorMessage;
  final bool isGeocoding;
  final bool isSearching;
  final bool isSearchingPickup;
  final List<TaxiPoi> poiResults;
  final List<TaxiPoi> allPois;
  final List<RideType> rideTypes;

  // Saved Locations
  final LatLng? homeLocation;
  final String? homeAddress;
  final LatLng? workLocation;
  final String? workAddress;

  // Shortcut Selection Mode
  final bool isSavingHome;
  final bool isSavingWork;
  final bool isPlaceSelected;
  final int passengerCount; // 0 = Full car, 1-4 = Passengers
  final DateTime? scheduledTime; // New field for scheduled rides

  final bool hasLocationPermission;

  // Nearby Drivers Tracking
  final Map<String, TaxiDriverLocation> nearbyDrivers;

  TaxiUiState({
    this.status = TaxiViewStatus.idle,
    this.pickupLocation,
    this.pickupAddress = 'جاي نحدد مكانك هسة...',
    this.dropoffLocation,
    this.dropoffAddress = '',
    this.routeAlternatives = const [],
    this.selectedRoute,
    this.routePoints = const [],
    this.distanceKm,
    this.durationMin,
    this.selectedRideType,
    this.errorMessage,
    this.isGeocoding = false,
    this.isSearching = false,
    this.isSearchingPickup = false,
    this.poiResults = const [],
    this.allPois = const [],
    this.rideTypes = const [],
    this.homeLocation,
    this.homeAddress,
    this.workLocation,
    this.workAddress,
    this.isSavingHome = false,
    this.isSavingWork = false,
    this.isPlaceSelected = false,
    this.passengerCount = 0,
    this.scheduledTime,
    this.hasLocationPermission = false,
    this.nearbyDrivers = const {},
  });

  TaxiUiState copyWith({
    TaxiViewStatus? status,
    LatLng? pickupLocation,
    String? pickupAddress,
    LatLng? dropoffLocation,
    String? dropoffAddress,
    List<RouteOption>? routeAlternatives,
    RouteOption? selectedRoute,
    List<LatLng>? routePoints,
    double? distanceKm,
    int? durationMin,
    RideType? selectedRideType,
    String? errorMessage,
    bool? isGeocoding,
    bool? isSearching,
    bool? isSearchingPickup,
    List<TaxiPoi>? poiResults,
    List<TaxiPoi>? allPois,
    List<RideType>? rideTypes,
    LatLng? homeLocation,
    String? homeAddress,
    LatLng? workLocation,
    String? workAddress,
    bool? isSavingHome,
    bool? isSavingWork,
    bool? isPlaceSelected,
    int? passengerCount,
    DateTime? scheduledTime,
    bool? hasLocationPermission,
    Map<String, TaxiDriverLocation>? nearbyDrivers,
  }) {
    return TaxiUiState(
      status: status ?? this.status,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      routeAlternatives: routeAlternatives ?? this.routeAlternatives,
      selectedRoute: selectedRoute ?? this.selectedRoute,
      routePoints: routePoints ?? this.routePoints,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMin: durationMin ?? this.durationMin,
      selectedRideType: selectedRideType ?? this.selectedRideType,
      errorMessage: errorMessage ?? this.errorMessage,
      isGeocoding: isGeocoding ?? this.isGeocoding,
      isSearching: isSearching ?? this.isSearching,
      isSearchingPickup: isSearchingPickup ?? this.isSearchingPickup,
      poiResults: poiResults ?? this.poiResults,
      allPois: allPois ?? this.allPois,
      rideTypes: rideTypes ?? this.rideTypes,
      homeLocation: homeLocation ?? this.homeLocation,
      homeAddress: homeAddress ?? this.homeAddress,
      workLocation: workLocation ?? this.workLocation,
      workAddress: workAddress ?? this.workAddress,
      isSavingHome: isSavingHome ?? this.isSavingHome,
      isSavingWork: isSavingWork ?? this.isSavingWork,
      isPlaceSelected: isPlaceSelected ?? this.isPlaceSelected,
      passengerCount: passengerCount ?? this.passengerCount,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      hasLocationPermission: hasLocationPermission ?? this.hasLocationPermission,
      nearbyDrivers: nearbyDrivers ?? this.nearbyDrivers,
    );
  }
}
