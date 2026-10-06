import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as native_geo; // Use as fallback
import 'package:geolocator/geolocator.dart';
import 'package:dalal_alqaim/features/taxi/presentation/controller/taxi_ui_state.dart';
import 'package:dalal_alqaim/features/trip/domain/repositories/trip_repository.dart';
import 'package:dalal_alqaim/models/ride_type.dart';
import 'package:dalal_alqaim/models/route_option.dart';
import 'package:dalal_alqaim/services/google_maps_service.dart';
import 'package:dalal_alqaim/core/location_permission_helper.dart'; // Added helper import
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/material.dart'; // Added Material for BuildContext
import 'package:flutter/foundation.dart'; // Added back for kIsWeb
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/core/location/iraq_location_resolver.dart';

class TaxiController extends ChangeNotifier {
  final TripRepository _repository;
  TaxiUiState _state = TaxiUiState();
  TaxiUiState get state => _state;
  bool _disposed = false;

  Timer? _debounceTimer;
  StreamSubscription<QuerySnapshot>? _driversSubscription;

  TaxiController({required TripRepository repository, LatLng? initialLocation})
    : _repository = repository {
    _init(initialLocation);
    _loadSavedLocations();

    // DELAY START: Ensure notifyListeners() isn't called during the first build/constructor
    Future.microtask(() {
      _startDriversStream();
    });
  }

  Future<void> _init(LatLng? initialLocation) async {
    await _loadTaxiSettings(); // Load dynamic pricing
    if (initialLocation != null) {
      _state = _state.copyWith(
        pickupLocation: initialLocation,
        status: TaxiViewStatus.selectingDropoff,
      );
      notifyListeners();
      _fetchPickupAddress(initialLocation);
    } // Cannot call _checkPermissionsAndLocate here without context, it will be called from UI
  }

  Future<void> _loadTaxiSettings() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('settings')
              .doc('taxi')
              .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> typesList = data['rideTypes'] ?? [];
        if (typesList.isNotEmpty) {
          final rawTypes =
              typesList
                  .map((e) => RideType.fromMap(Map<String, dynamic>.from(e)))
                  .toList();
          // Deduplicate by id — keep only the first entry per id
          final seen = <String>{};
          final types = rawTypes.where((t) => seen.add(t.id)).toList();
          // Find 'saver' or use first
          final saver = types.firstWhere(
            (t) => t.id == 'saver',
            orElse: () => types[0],
          );
          _state = _state.copyWith(rideTypes: types, selectedRideType: saver);
        }
      } else {
        // Fallback to hardcoded list if settings document doesn't exist yet
        final types = RideTypes.list;
        final saver = types.firstWhere(
          (t) => t.id == 'saver',
          orElse: () => types[0],
        );
        _state = _state.copyWith(rideTypes: types, selectedRideType: saver);
      }
    } catch (e) {
      debugPrint("Error loading taxi settings: $e");
      // Safety fallback on error
      if (_state.rideTypes.isEmpty) {
        _state = _state.copyWith(
          rideTypes: RideTypes.list,
          selectedRideType: RideTypes.list[0],
        );
      }
    }
  }

  Future<void> centerOnUser(GoogleMapController? mapController) async {
    try {
      final resolved = await IraqLocationResolver().getCurrentDeviceLocation(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      if (resolved != null) {
        mapController?.animateCamera(CameraUpdate.newLatLngZoom(resolved.latLng, 16.5));
        _state = _state.copyWith(
          pickupLocation: resolved.latLng,
          pickupAddress: resolved.formattedAddress,
          hasLocationPermission: true,
          errorMessage: null,
        );
        notifyListeners();
      } else {
        _state = _state.copyWith(
          errorMessage: 'ما قدرنا نحدد موقعك بدقة، حاول مرة ثانية.',
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint("centerOnUser failed: $e");
      _state = _state.copyWith(
        errorMessage: 'ما قدرنا نحدد موقعك بدقة، حاول مرة ثانية.',
      );
      notifyListeners();
    }
  }

  void toggleSearch(
    bool value, {
    bool isPickup = false,
    bool isHomeShortcut = false,
    bool isWorkShortcut = false,
  }) {
    _state = _state.copyWith(
      isSearching: value,
      isSearchingPickup: isPickup,
      isSavingHome: isHomeShortcut,
      isSavingWork: isWorkShortcut,
      errorMessage: null,
    );
    if (!value) _state = _state.copyWith(poiResults: []);
    notifyListeners();
  }

  void onMapMoveStarted() {
    if (_state.isPlaceSelected) {
      _state = _state.copyWith(isPlaceSelected: false);
      notifyListeners();
    }
  }

  void searchPois(String query) {
    // تم إيقاف البحث المحلي بناءً على طلب المستخدم لتخفيف التطبيق
    _state = _state.copyWith(poiResults: []);
    notifyListeners();
  }

  // تحديد الموقع الحقيقي للجهاز بدون أي إحداثيات افتراضية
  Future<void> checkPermissionsAndLocate(BuildContext context) async {
    try {
      bool hasPermission =
          await LocationPermissionHelper.requestLocationPermissionWithDisclosure(
            context,
          );

      if (!hasPermission) {
        _state = _state.copyWith(
          pickupLocation: null,
          hasLocationPermission: false,
          status: TaxiViewStatus.selectingDropoff,
          errorMessage: 'ما انطيتنا صلاحية الموقع، نحتاج الموقع حتى نحدد مكانك بدقة',
        );
        notifyListeners();
        return;
      }

      // جلب الموقع الفعلي للجهاز (Real Device GPS Only)
      final resolved = await IraqLocationResolver().getCurrentDeviceLocation(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      if (resolved != null) {
        debugPrint('[Madar GPS] REAL_FIX=true LAT=${resolved.latitude} LNG=${resolved.longitude} ACCURACY=${resolved.accuracy ?? 0}m GOVERNORATE=${resolved.governorate ?? "Unknown"} DISTRICT=${resolved.district ?? "Unknown"} AREA=${resolved.area ?? resolved.formattedAddress}');
        _state = _state.copyWith(
          pickupLocation: resolved.latLng,
          pickupAddress: resolved.formattedAddress,
          hasLocationPermission: true,
          status: TaxiViewStatus.selectingDropoff,
          errorMessage: null,
        );
        notifyListeners();
      } else {
        _state = _state.copyWith(
          pickupLocation: null,
          hasLocationPermission: true,
          status: TaxiViewStatus.selectingDropoff,
          errorMessage: 'ما قدرنا نحدد موقعك بدقة، حاول مرة ثانية.',
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Location error: $e");
      _state = _state.copyWith(
        pickupLocation: null,
        hasLocationPermission: false,
        status: TaxiViewStatus.selectingDropoff,
        errorMessage: 'ما قدرنا نحدد موقعك بدقة، حاول مرة ثانية.',
      );
      notifyListeners();
    }
  }

  Future<void> _fetchPickupAddress(LatLng location) async {
    final name = await _resolveHumanReadableLocation(location, isPickup: true);
    _state = _state.copyWith(pickupAddress: name);
    notifyListeners();
  }

  // حل العنوان والموقع بالاعتماد على محرك العراق الإداري
  Future<String> _resolveHumanReadableLocation(
    LatLng loc, {
    bool isPickup = false,
  }) async {
    try {
      final resolved = await IraqLocationResolver().resolveFromCoordinates(
        latitude: loc.latitude,
        longitude: loc.longitude,
      );
      if (resolved.formattedAddress.isNotEmpty &&
          resolved.formattedAddress != 'موقع غير معروف' &&
          !RegExp(r'^[.,\s،\-_]+$').hasMatch(resolved.formattedAddress)) {
        return resolved.formattedAddress;
      }
    } catch (e) {
      debugPrint(' IraqLocationResolver reverseGeocode failed: $e');
    }

    return isPickup ? 'مكاني هسة' : 'مكان مختار';
  }

  void clearPlaceSelection() {
    if (_state.isPlaceSelected) {
      _state = _state.copyWith(isPlaceSelected: false);
      notifyListeners();
    }
  }

  // جلب اسم المكان من Place ID — uses centralized GoogleMapsService
  Future<String?> getPlaceNameFromPlaceId(String placeId) async {
    try {
      return await GoogleMapsService.instance.getPlaceName(placeId);
    } catch (e) {
      debugPrint('Place Details error: $e');
      return null;
    }
  }

  // يتم استدعاؤها عند الضغط على أيقونة POI في الخريطة أو اختيار نتيجة بحث
  void onPlaceSelected(String placeId, LatLng location) async {
    _state = _state.copyWith(isGeocoding: true);
    notifyListeners();

    final name = await getPlaceNameFromPlaceId(placeId);

    _state = _state.copyWith(
      dropoffLocation: location,
      dropoffAddress: name ?? 'موقع محدد',
      isGeocoding: false,
      isPlaceSelected: true,
    );
    notifyListeners();
  }

  void updateLocationFromMap(LatLng? location) {
    if (location == null || _disposed) return;

    if (_state.isPlaceSelected) return;

    if (_state.status != TaxiViewStatus.selectingDropoff) return;

    _state = _state.copyWith(
      dropoffLocation: location,
      isGeocoding: true,
      errorMessage: null,
    );
    notifyListeners();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final name = await _resolveHumanReadableLocation(
        location,
        isPickup: false,
      );
      _state = _state.copyWith(dropoffAddress: name, isGeocoding: false);
      notifyListeners();
    });
  }

  Future<void> _loadSavedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final homeLat = prefs.getDouble('taxi_home_lat');
    final homeLng = prefs.getDouble('taxi_home_lng');
    final homeAddr = prefs.getString('taxi_home_addr');
    final workLat = prefs.getDouble('taxi_work_lat');
    final workLng = prefs.getDouble('taxi_work_lng');
    final workAddr = prefs.getString('taxi_work_addr');

    _state = _state.copyWith(
      homeLocation: homeLat != null ? LatLng(homeLat, homeLng!) : null,
      homeAddress: homeAddr,
      workLocation: workLat != null ? LatLng(workLat, workLng!) : null,
      workAddress: workAddr,
    );
    notifyListeners();
  }

  Future<void> saveQuickLocation(
    bool isHome,
    LatLng location,
    String address,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = isHome ? 'taxi_home' : 'taxi_work';
    await prefs.setDouble('${prefix}_lat', location.latitude);
    await prefs.setDouble('${prefix}_lng', location.longitude);
    await prefs.setString('${prefix}_addr', address);

    if (isHome) {
      _state = _state.copyWith(homeLocation: location, homeAddress: address);
    } else {
      _state = _state.copyWith(workLocation: location, workAddress: address);
    }
    notifyListeners();
  }

  Future<void> deleteQuickLocation(bool isHome) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = isHome ? 'taxi_home' : 'taxi_work';
    await prefs.remove('${prefix}_lat');
    await prefs.remove('${prefix}_lng');
    await prefs.remove('${prefix}_addr');

    if (isHome) {
      _state = _state.copyWith(homeLocation: null, homeAddress: null);
    } else {
      _state = _state.copyWith(workLocation: null, workAddress: null);
    }
    notifyListeners();
  }

  void useQuickAction(bool isHome) {
    final loc = isHome ? _state.homeLocation : _state.workLocation;
    final addr = isHome ? _state.homeAddress : _state.workAddress;

    if (loc != null && addr != null) {
      setDropoff(loc, addr);
    } else {
      // If not saved, open search for that slot
      toggleSearch(
        true,
        isPickup: false,
        isHomeShortcut: isHome,
        isWorkShortcut: !isHome,
      );
    }
  }

  void confirmPickup() {
    if (_state.pickupLocation == null) return;
    _state = _state.copyWith(
      status: TaxiViewStatus.selectingDropoff,
      dropoffLocation: _state.dropoffLocation ?? _state.pickupLocation,
    );
    notifyListeners();
    // Trigger address fetch for the initial dropoff location if not already present
    if (_state.dropoffAddress.isEmpty) {
      updateLocationFromMap(_state.dropoffLocation ?? _state.pickupLocation);
    }
  }

  void confirmDropoff() {
    if (_state.dropoffLocation == null) return;

    if (_state.isSavingHome) {
      saveQuickLocation(true, _state.dropoffLocation!, _state.dropoffAddress);
    } else if (_state.isSavingWork) {
      saveQuickLocation(false, _state.dropoffLocation!, _state.dropoffAddress);
    }

    _state = _state.copyWith(
      status: TaxiViewStatus.calculating,
      isSavingHome: false,
      isSavingWork: false,
    );
    notifyListeners();
    _loadRoute();
  }

  void setDropoff(LatLng location, String address) {
    if (_state.isSavingHome) {
      saveQuickLocation(true, location, address);
    } else if (_state.isSavingWork) {
      saveQuickLocation(false, location, address);
    }

    _state = _state.copyWith(
      dropoffLocation: location,
      dropoffAddress: address,
      status: TaxiViewStatus.calculating,
      isSearching: false,
      isSavingHome: false,
      isSavingWork: false,
    );
    notifyListeners();

    // Instant Heuristic Estimation for Zero-Latency Pricing
    _applyHeuristicPricing(location);

    _loadRoute();
  }

  // New helper for zero-latency feedback
  void _applyHeuristicPricing(LatLng dropoff) {
    if (_state.pickupLocation == null) return;

    final pickup = _state.pickupLocation!;
    // Calculate Crow-fly distance in meters
    final double crowFlyDistance = Geolocator.distanceBetween(
      pickup.latitude,
      pickup.longitude,
      dropoff.latitude,
      dropoff.longitude,
    );

    // Heuristic: Straight-line + 30% for road winding
    final double estimatedDistanceKm = (crowFlyDistance * 1.3) / 1000;

    _state = _state.copyWith(
      distanceKm: estimatedDistanceKm,
      durationMin:
          (estimatedDistanceKm * 2.0).round(), // Rough estimate: 2 mins per Km
      // Don't change status to 'ready' yet, wait for real route if possible
    );
    notifyListeners();
  }

  Future<void> _loadRoute() async {
    if (_state.pickupLocation == null || _state.dropoffLocation == null) return;

    try {
      final alternatives = await _repository.getRouteAlternatives(
        _state.pickupLocation!,
        _state.dropoffLocation!,
      );

      if (alternatives.isNotEmpty) {
        // نختار الأرخص (cheapest) كافتراضي، أو أول واحد
        final selected = alternatives.firstWhere(
          (r) => r.tag == 'cheapest',
          orElse: () => alternatives.first,
        );

        RideType? currentSelected = _state.selectedRideType;
        final String? currentId = currentSelected?.id;

        RideType selectedType;
        if (currentId != null &&
            _state.rideTypes.any((t) => t.id == currentId)) {
          selectedType = _state.rideTypes.firstWhere((t) => t.id == currentId);
        } else {
          selectedType = _state.rideTypes.firstWhere(
            (t) => t.id == 'saver',
            orElse:
                () =>
                    _state.rideTypes.isNotEmpty
                        ? _state.rideTypes[0]
                        : RideTypes.list[0],
          );
        }

        _state = _state.copyWith(
          routeAlternatives: alternatives,
          selectedRoute: selected,
          // Legacy fields for backward compatibility
          routePoints: selected.points,
          distanceKm: selected.distanceKm,
          durationMin: selected.durationMin,
          selectedRideType: selectedType,
          status: TaxiViewStatus.ready,
        );
        debugPrint(
          " Alternatives loaded: ${alternatives.length}. Default: ${selected.label} (${selected.distanceKm.toStringAsFixed(2)} km)",
        );
        notifyListeners();
      } else {
        _fallbackToHeuristic();
      }
    } catch (e) {
      debugPrint("Error loading routes: $e");
      _fallbackToHeuristic();
    }
  }

  void _fallbackToHeuristic() {
    // Fallback: If network returned empty but we have heuristic, just go to ready
    if ((_state.distanceKm ?? 0) > 0) {
      _state = _state.copyWith(status: TaxiViewStatus.ready);
      notifyListeners();
    } else {
      _state = _state.copyWith(
        status: TaxiViewStatus.selectingDropoff,
        errorMessage: "تعذر حساب المسار عيوني، جرّب مرة ثانية",
      );
      notifyListeners();
    }
  }

  void selectRoute(RouteOption route) {
    _state = _state.copyWith(
      selectedRoute: route,
      // Update legacy fields too
      routePoints: route.points,
      distanceKm: route.distanceKm,
      durationMin: route.durationMin,
    );
    debugPrint(
      " User selected route: ${route.label} (${route.distanceKm.toStringAsFixed(2)} km)",
    );
    notifyListeners();
  }

  void selectRideType(RideType type) {
    _state = _state.copyWith(selectedRideType: type);
    notifyListeners();
  }

  void setPassengerCount(int count) {
    _state = _state.copyWith(passengerCount: count);
    notifyListeners();
  }

  void setScheduledTime(DateTime? time) {
    _state = _state.copyWith(scheduledTime: time);
    notifyListeners();
  }

  void reset() {
    _state = _state.copyWith(
      status: TaxiViewStatus.selectingDropoff,
      dropoffLocation: null,
      dropoffAddress: '',
      routeAlternatives: [],
      selectedRoute: null,
      routePoints: [],
      distanceKm: null,
      durationMin: null,
    );
    notifyListeners();
  }

  Future<String?> submitRideRequest() async {
    if (_state.pickupLocation == null ||
        _state.dropoffLocation == null ||
        _state.selectedRideType == null) {
      _state = _state.copyWith(
        errorMessage: 'ما قدرنا نحدد موقعك بدقة، حاول مرة ثانية.',
      );
      notifyListeners();
      return null;
    }

    _state = _state.copyWith(status: TaxiViewStatus.requesting);
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();

      final userName =
          prefs.getString('user_name') ?? user?.displayName ?? 'مستخدم';
      final userPhone = prefs.getString('user_phone') ?? user?.phoneNumber;

      String? userOneSignalId;
      if (!kIsWeb) {
        userOneSignalId = OneSignal.User.pushSubscription.id;
      }

      // فك التشفير الإداري الحقيقي لموقع الانطلاق
      final resolved = await IraqLocationResolver().resolveFromCoordinates(
        latitude: _state.pickupLocation!.latitude,
        longitude: _state.pickupLocation!.longitude,
      );

      final rideData = {
        'userId': user?.uid,
        'status': 'pending',
        'pickup': {
          'lat': _state.pickupLocation!.latitude,
          'lng': _state.pickupLocation!.longitude,
          'address': _state.pickupAddress,
          'governorate': resolved.governorate,
          'district': resolved.district,
          'area': resolved.area,
        },
        'dropoff': {
          'lat': _state.dropoffLocation!.latitude,
          'lng': _state.dropoffLocation!.longitude,
          'address': _state.dropoffAddress,
        },
        'pickupLat': _state.pickupLocation!.latitude,
        'pickupLng': _state.pickupLocation!.longitude,
        'dropoffLat': _state.dropoffLocation!.latitude,
        'dropoffLng': _state.dropoffLocation!.longitude,
        'pickupAddress': _state.pickupAddress,
        'dropoffAddress': _state.dropoffAddress,
        // Regional metadata for better filtering
        'governorate': resolved.governorate,
        'city': resolved.district,
        'district': resolved.area ?? resolved.district,
        'rideType': _state.selectedRideType!.title,
        'price': _calculatePrice(),
        'distance': _state.distanceKm,
        'duration': _state.durationMin,
        'routeTag': _state.selectedRoute?.tag,
        'passengerCount': _state.passengerCount,
        'bookingType': _state.passengerCount > 0 ? 'seats' : 'full_car',
        'scheduledTime': _state.scheduledTime?.toIso8601String(),
        'userName': userName,
        'userPhone': userPhone,
        'userOneSignalId': userOneSignalId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final rideId = await _repository.createRideRequest(rideData);

      // ℹ لا حاجة لـ emitEvent هنا — Cloud Function (notifyDriversOnNewRide)
      // يتعامل مع الإشعار تلقائياً عبر ride_requests onCreate trigger

      return rideId;
    } catch (e) {
      _state = _state.copyWith(
        status: TaxiViewStatus.ready,
        errorMessage: e.toString(),
      );
      notifyListeners();
      return null;
    }
  }

  double calculatePriceForType(RideType type) {
    if (_state.distanceKm == null || _state.durationMin == null) return 0;

    final distanceKm = _state.distanceKm!;
    final durationMin = _state.durationMin!;

    // Special Case: Long Distance Seat-based Pricing (User Request)
    // 35km+, 1 passenger = 3000, 2 = 6000, 0 = Full Car distance based.
    if (distanceKm >= 30 && _state.passengerCount > 0) {
      return (_state.passengerCount * 3000.0);
    }

    // 1. Base Fare (فتح العداد)
    double price = type.baseFare;

    // 2. Distance Component (Tiered Pricing - تسعير شرائحي)
    final standardRate = type.pricePerKm;

    if (distanceKm <= 5) {
      price += distanceKm * standardRate;
    } else if (distanceKm <= 15) {
      price += 5 * standardRate;
      price += (distanceKm - 5) * (standardRate * 0.70); // 70%
    } else {
      price += 5 * standardRate;
      price += 10 * (standardRate * 0.70);
      price += (distanceKm - 15) * (standardRate * 0.45); // 45%
    }

    // 3. Time Component (حساب الوقت - جديد)
    price += durationMin * type.pricePerMinute;

    // 4. Zone Multiplier (تخفيض المسافات الطويلة جداً - قاعدة الـ 35كم)
    if (distanceKm >= 30) {
      price *= 0.35; // خصم 65% للمسافات الخارجية (لتصبح 35كم بـ 2500 تقريباً)
    } else if (distanceKm > 20) {
      price *= 0.65;
    }

    // 5. Minimum Fare (تسعيرة الأدمن المحدود - الحد الأدنى)
    if (price < type.minFare) {
      price = type.minFare;
    }

    // 6. Long Distance Rule (User: 6km+ starts from 3,000 IQD)
    if (distanceKm >= 6.0 && price < 3000) {
      price = 3000;
    }

    // 7. Price Cap (الحد الأقصى للسعر)
    const double maxPrice = 35000;
    if (price > maxPrice) {
      price = maxPrice;
    }

    // 8. Smart Rounding (التقريب لـ 250 دينار)
    return (price / 250).round() * 250.0;
  }

  double _calculatePrice() {
    if (_state.selectedRideType == null) return 0;
    return calculatePriceForType(_state.selectedRideType!);
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  void _startDriversStream() {
    _driversSubscription?.cancel();
    _driversSubscription = FirebaseFirestore.instance
        .collection('drivers')
        .where('availability', isEqualTo: 'online')
        .snapshots()
        .listen((snapshot) {
          final Map<String, TaxiDriverLocation> realDrivers = {};
          final now = DateTime.now();

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final lat = data['currentLat'] as double?;
            final lng = data['currentLng'] as double?;
            final heading = (data['heading'] as num?)?.toDouble() ?? 0.0;
            final lastUpdate = data['lastLocationUpdate'] as Timestamp?;

            if (lat != null && lng != null && lastUpdate != null) {
              if (now.difference(lastUpdate.toDate()).inMinutes < 15) {
                realDrivers[doc.id] = (
                  location: LatLng(lat, lng),
                  heading: heading,
                );
              }
            }
          }

          // Merge real drivers with demo drivers in state
          _updateNearbyDrivers(realDrivers: realDrivers);
        });
  }

  void _updateNearbyDrivers({Map<String, TaxiDriverLocation>? realDrivers}) {
    final activeDrivers = realDrivers ?? _state.nearbyDrivers;
    _state = _state.copyWith(nearbyDrivers: activeDrivers);
    notifyListeners();
  }

  @override
  void dispose() {
    _driversSubscription?.cancel();
    _debounceTimer?.cancel();
    _disposed = true;
    super.dispose();
  }
}
