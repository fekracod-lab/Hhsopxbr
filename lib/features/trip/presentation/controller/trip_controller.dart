import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dalal_alqaim/features/trip/domain/entities/trip.dart';
import 'package:dalal_alqaim/features/trip/domain/repositories/trip_repository.dart';
import 'package:dalal_alqaim/features/trip/presentation/controller/trip_ui_state.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dalal_alqaim/services/taxi_background_service.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class TripController extends ChangeNotifier {
  final TripRepository _repository;
  final String tripId;

  TripUiState _state = TripUiState();
  TripUiState get state => _state;

  StreamSubscription<Trip>? _tripSubscription;
  StreamSubscription<LatLng>? _driverSubscription;
  StreamSubscription<Map<String, dynamic>>? _driverInfoSubscription;
  StreamSubscription<Position>? _userLocationSubscription;
  Timer? _routeUpdateTimer;
  LatLng? _lastRouteUpdateDriverPos;
  bool _didBroadcastRequest = false;

  TripController({required TripRepository repository, required this.tripId})
    : _repository = repository {
    _init();
  }

  void _init() {
    _listenToTrip();
    _listenToUserLocation();
  }

  void _listenToUserLocation() {
    _userLocationSubscription?.cancel();
    _userLocationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, distanceFilter: 10),
    ).listen((position) {
      _state = _state.copyWith(userLocation: LatLng(position.latitude, position.longitude));
      notifyListeners();
    });
  }

  void _listenToTrip() {
    _tripSubscription?.cancel();
    _tripSubscription = _repository
        .listenToTrip(tripId)
        .listen(
          (trip) {
            final oldStatus = _state.trip?.status;
            final newStatus = trip.status;

            debugPrint(' [TripController] Trip update: status=$newStatus (was $oldStatus), driverId=${trip.driverId}');

            TripViewStatus viewStatus = _mapToViewStatus(newStatus);
            debugPrint(' [TripController] viewStatus=$viewStatus');

            _state = _state.copyWith(status: viewStatus, trip: trip);

            // Start listening to driver if accepted/started
            if (trip.driverId != null && _driverSubscription == null) {
              debugPrint(' [TripController] Starting driver listener for: ${trip.driverId}');
              _listenToDriver(trip.driverId!);
            }

            // If status is searching, ensure it's broadcast to drivers
            if (newStatus == TripStatus.searching && !_didBroadcastRequest) {
              _broadcastRideRequest(trip);
            }

            // Update route if status changed to accepted/started
            if (oldStatus != newStatus &&
                (newStatus == TripStatus.accepted || newStatus == TripStatus.started)) {
              _updateRoute();
            }

            notifyListeners();
          },
          onError: (error) {
            debugPrint(' [TripController] Trip stream error: $error');
            _state = _state.copyWith(status: TripViewStatus.error, errorMessage: error.toString());
            notifyListeners();
          },
        );
  }

  void _listenToDriver(String driverId) {
    _driverSubscription?.cancel();
    _driverSubscription = _repository.listenToDriverLocation(driverId).listen((location) {
      if (_state.driverLocation != null) {
        final bearing = _calculateBearing(_state.driverLocation!, location);
        _state = _state.copyWith(driverLocation: location, driverHeading: bearing);
      } else {
        _state = _state.copyWith(driverLocation: location);
      }

      if (_lastRouteUpdateDriverPos == null ||
          _calculateDistance(_lastRouteUpdateDriverPos!, location) > 100) {
        _updateRoute();
        _lastRouteUpdateDriverPos = location;
      }
      notifyListeners();
    });

    _driverInfoSubscription?.cancel();
    _driverInfoSubscription = _repository.listenToDriver(driverId).listen((driverData) {
      if (_state.trip != null) {
        final updatedTrip = _state.trip!.copyWith(
          driverName: driverData['name'] ?? _state.trip!.driverName,
          driverPhone: driverData['phone'] ?? _state.trip!.driverPhone,
          driverCar: driverData['carModel'] ?? driverData['car'] ?? _state.trip!.driverCar,
          driverCarColor: driverData['carColor'] ?? _state.trip!.driverCarColor,
          driverCarNumber: driverData['carNumber'] ?? _state.trip!.driverCarNumber,
          driverImage: driverData['image'] ?? _state.trip!.driverImage,
          driverRating:
              (driverData['ratingCount'] != null && driverData['ratingCount'] > 0)
                  ? (driverData['ratingSum'] ?? 0.0) / driverData['ratingCount']
                  : _state.trip!.driverRating,
        );
        _state = _state.copyWith(trip: updatedTrip);
        notifyListeners();
      }
    });
  }

  double _calculateBearing(LatLng start, LatLng end) {
    return Geolocator.bearingBetween(start.latitude, start.longitude, end.latitude, end.longitude);
  }

  double _calculateDistance(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(start.latitude, start.longitude, end.latitude, end.longitude);
  }

  TripViewStatus _mapToViewStatus(TripStatus status) {
    switch (status) {
      case TripStatus.searching:
        return TripViewStatus.searching;
      case TripStatus.accepted:
      case TripStatus.arrived:
      case TripStatus.started:
        return TripViewStatus.active;
      case TripStatus.completed:
        return TripViewStatus.completed;
      case TripStatus.cancelled:
        return TripViewStatus.cancelled;
    }
  }

  Future<void> _updateRoute() async {
    if (_state.trip == null || _state.driverLocation == null) return;

    LatLng start;
    LatLng destination;

    if (_state.trip!.status == TripStatus.accepted || _state.trip!.status == TripStatus.arrived) {
      start = _state.driverLocation!;
      destination = LatLng(_state.trip!.pickupLat, _state.trip!.pickupLng);
    } else if (_state.trip!.status == TripStatus.started) {
      start = _state.driverLocation!;
      destination = LatLng(_state.trip!.dropoffLat, _state.trip!.dropoffLng);
    } else {
      return;
    }

    try {
      final route = await _repository.getRoute(start, destination);
      _state = _state.copyWith(
        routePoints: route.points,
        distanceText: "${(route.distance / 1000).toStringAsFixed(1)} كم",
        etaMinutes: (route.duration / 60).round(),
      );
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating route: $e");
    }
  }

  Future<void> _broadcastRideRequest(Trip trip) async {
    _didBroadcastRequest = true;
    try {
      // 1. Get OneSignal ID
      final osId = OneSignal.User.pushSubscription.id;

      // 2. Start background service in rider mode for notifications
      await TaxiBackgroundService.startRiderMode(
        serverUrl: '',
        token: '',
        oneSignalId: osId,
      );
      
      debugPrint("[TripController] Background service started for trip: ${trip.id}");
    } catch (e) {
      debugPrint("Error starting rider mode background: $e");
      _didBroadcastRequest = false; // Allow retry
    }
  }

  void markRatingShown() {
    _state = _state.copyWith(ratingShown: true);
    notifyListeners();
  }

  Future<void> cancelTrip({String? reason}) async {
    try {
      await _repository.cancelTrip(tripId, reason: reason);
    } catch (e) {
      _state = _state.copyWith(errorMessage: "Failed to cancel trip: $e");
      notifyListeners();
    }
  }

  Future<void> submitRating(double stars) async {
    final driverId = _state.trip?.driverId;
    if (driverId != null) {
      try {
        await _repository.submitDriverRating(driverId, tripId, stars);
      } catch (e) {
        debugPrint("Rating error: $e");
      }
    }
  }

  void enableAutoFollow() {
    if (!_state.autoFollowEnabled) {
      _state = _state.copyWith(autoFollowEnabled: true);
      notifyListeners();
    }
  }

  void toggleAutoFollow() {
    _state = _state.copyWith(autoFollowEnabled: !_state.autoFollowEnabled);
    notifyListeners();
  }

  void disableAutoFollowTemporarily() {
    if (_state.autoFollowEnabled) {
      _state = _state.copyWith(autoFollowEnabled: false);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _tripSubscription?.cancel();
    _driverSubscription?.cancel();
    _driverInfoSubscription?.cancel();
    _userLocationSubscription?.cancel();
    _routeUpdateTimer?.cancel();
    super.dispose();
  }
}
