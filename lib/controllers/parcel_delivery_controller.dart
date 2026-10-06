import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import '../services/pricing_service.dart';
import '../services/location_service.dart';
import 'parcel_delivery_state.dart';
import '../services/parcel_delivery_service.dart';
import '../services/notification_service.dart';
import '../models/parcel_delivery_request.dart';

class ParcelDeliveryController extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final PricingService _pricingService = PricingService();
  final ParcelDeliveryService _parcelService = ParcelDeliveryService();

  ParcelDeliveryState _state = ParcelDeliveryState();
  ParcelDeliveryState get state => _state;

  void init([BuildContext? context]) {
    _loadInitialData(context);
  }

  Future<void> _loadInitialData([BuildContext? context]) async {
    _state = _state.copyWith(isLoadingLocation: true, isLoadingPlaces: true);
    notifyListeners();

    try {
      final location = await _locationService.getCurrentLocation(context);

      _state = _state.copyWith(
        pickupLocation: location,
        nearbyPlaces: [], // تم إيقاف تحميل الأماكن القريبة لتخفيف الحمل
        isLoadingLocation: false,
        isLoadingPlaces: false,
      );

      _sortNearbyPlaces();
      _updatePricing();
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        isLoadingLocation: false,
        isLoadingPlaces: false,
        errorMessage: "حدث خطأ أثناء تحميل البيانات",
      );
      notifyListeners();
    }
  }

  Timer? _debounceTimer;

  void toggleMapSelectionMode(bool value) {
    _state = _state.copyWith(
      isMapSelectionMode: value,
      mapCenter: value ? (_state.dropoffLocation ?? _state.pickupLocation) : _state.mapCenter,
    );
    if (value && _state.mapCenter != null) {
      _performGeocoding(_state.mapCenter!, immediate: true);
    }
    notifyListeners();
  }

  void updateMapCenter(LatLng center) {
    _state = _state.copyWith(mapCenter: center);
    _performGeocoding(center);
    notifyListeners();
  }

  Future<void> _performGeocoding(LatLng center, {bool immediate = false}) async {
    if (_state.isGeocoding) return;

    if (!immediate) {
      _debounceTimer?.cancel();
    }

    Future<void> geocodeAction() async {
      _state = _state.copyWith(isGeocoding: true);
      notifyListeners();

      try {
        final placemarks = await placemarkFromCoordinates(
          center.latitude,
          center.longitude,
        ).timeout(const Duration(seconds: 5));
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          
          bool isValid(String? val) {
            if (val == null) return false;
            final v = val.trim();
            return v.isNotEmpty && !v.contains('+') && !RegExp(r'^[.,\s،\-_]+$').hasMatch(v);
          }

          String name = 'موقع محدد';
          if (isValid(p.street)) {
            name = p.street!.trim();
          } else if (isValid(p.name)) {
            name = p.name!.trim();
          } else if (isValid(p.locality)) {
            name = p.locality!.trim();
          }

          _state = _state.copyWith(dropoffName: name, isGeocoding: false);
        } else {
          _state = _state.copyWith(dropoffName: "موقع محدد", isGeocoding: false);
        }
      } catch (e) {
        _state = _state.copyWith(dropoffName: "موقع محدد", isGeocoding: false);
      }
      notifyListeners();
    }

    if (immediate) {
      await geocodeAction();
    } else {
      _debounceTimer = Timer(const Duration(milliseconds: 600), geocodeAction);
    }
  }

  void confirmLocation() {
    if (_state.mapCenter != null) {
      _state = _state.copyWith(dropoffLocation: _state.mapCenter, isMapSelectionMode: false);
      _updatePricing();
      notifyListeners();
    }
  }

  void setPickup(LatLng position) {
    _state = _state.copyWith(pickupLocation: position);
    _sortNearbyPlaces();
    _updatePricing();
    notifyListeners();
  }

  void _sortNearbyPlaces() {
    // تم إيقاف ترتيب الأماكن القريبة لتخفيف الحمل
    /*
    if (_state.pickupLocation == null || _state.nearbyPlaces.isEmpty) return;

    final List<PlaceData> sorted = List.from(_state.nearbyPlaces);

    sorted.sort((a, b) {
      final da = Geolocator.distanceBetween(
        _state.pickupLocation!.latitude,
        _state.pickupLocation!.longitude,
        a.position.latitude,
        a.position.longitude,
      );
      final db = Geolocator.distanceBetween(
        _state.pickupLocation!.latitude,
        _state.pickupLocation!.longitude,
        b.position.latitude,
        b.position.longitude,
      );
      return da.compareTo(db);
    });

    _state = _state.copyWith(nearbyPlaces: sorted);

    // Auto-select nearest place if none is selected
    if (_state.dropoffLocation == null && sorted.isNotEmpty) {
      final nearest = sorted.first;
      _state = _state.copyWith(dropoffLocation: nearest.position, dropoffName: nearest.name);
    }
    */
  }

  void setDropoff(LatLng position, String name) {
    _state = _state.copyWith(dropoffLocation: position, dropoffName: name);
    _updatePricing();
    notifyListeners();
  }

  void setVehicle(String vehicle) {
    _state = _state.copyWith(selectedVehicle: vehicle);
    _updatePricing();
    notifyListeners();
  }

  void setRecipientDetails({required String name, required String phone}) {
    _state = _state.copyWith(recipientName: name, recipientPhone: phone);
  }

  void setParcelDescription(String description) {
    _state = _state.copyWith(itemDescription: description);
  }

  void _updatePricing() {
    if (_state.pickupLocation != null && _state.dropoffLocation != null) {
      final pricing = _pricingService.calculate(
        pickup: _state.pickupLocation!,
        dropoff: _state.dropoffLocation!,
        vehicleType: _state.selectedVehicle,
      );
      _state = _state.copyWith(pricingResult: pricing);
    }
  }

  Future<Map<String, dynamic>> submitRequest() async {
    if (_state.pickupLocation == null) {
      return {'success': false, 'error': 'يرجى تفعيل الموقع الجغرافي للاستمرار'};
    }
    if (_state.dropoffLocation == null) {
      return {'success': false, 'error': 'يرجى تحديد وجهة التسليم على الخريطة'};
    }

    _state = _state.copyWith(isSubmitting: true, errorMessage: null);
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final pricing =
          _state.pricingResult ??
          _pricingService.calculate(
            pickup: _state.pickupLocation!,
            dropoff: _state.dropoffLocation!,
            vehicleType: _state.selectedVehicle,
          );

      final request = ParcelDeliveryRequest(
        id: '',
        userId: user.uid,
        userName: userData['name'] ?? 'مستخدم',
        userPhone: userData['phone'] ?? '',
        pickupLat: _state.pickupLocation!.latitude,
        pickupLng: _state.pickupLocation!.longitude,
        pickupAddress: 'موقعي الحالي',
        dropoffLat: _state.dropoffLocation!.latitude,
        dropoffLng: _state.dropoffLocation!.longitude,
        dropoffAddress: _state.dropoffName,
        itemDescription: _state.itemDescription,
        itemSize: 'Medium',
        vehicleType: _state.selectedVehicle,
        recipientName: _state.recipientName,
        recipientPhone: _state.recipientPhone,
        status: 'pending',
        price: pricing.price,
        estimatedTime: pricing.etaMinutes,
        distance: pricing.distanceKm,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final requestId = await _parcelService.createRequest(request);

      // Emit Event to Server
      await NotificationService.emitEvent(
        type: 'parcel_request_created',
        payload: {'request_id': requestId},
      );

      _state = _state.copyWith(isSubmitting: false);
      notifyListeners();
      return {'success': true, 'requestId': requestId};
    } catch (e) {
      _state = _state.copyWith(isSubmitting: false, errorMessage: e.toString());
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }

  void updateSearch(String query) {
    _state = _state.copyWith(searchQuery: query);
    notifyListeners();
  }

  void clearError() {
    _state = _state.copyWith(errorMessage: null);
    notifyListeners();
  }
}
