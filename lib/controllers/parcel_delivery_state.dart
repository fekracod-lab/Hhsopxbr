import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/place_data.dart';
import '../models/parcel_delivery_request.dart';
import '../services/pricing_service.dart';

class ParcelDeliveryState {
  final LatLng? pickupLocation;
  final LatLng? dropoffLocation;
  final String dropoffName;
  final List<PlaceData> nearbyPlaces;
  final List<ParcelDeliveryRequest> activeShipments;
  final bool isLoadingLocation;
  final bool isLoadingPlaces;
  final bool isSubmitting;
  final String selectedVehicle;
  final String? errorMessage;

  // New fields for the overhaul
  final PricingResult? pricingResult;
  final String itemDescription;
  final String recipientName;
  final String recipientPhone;
  final String searchQuery;
  final bool isMapSelectionMode;
  final LatLng? mapCenter;
  final bool isGeocoding;

  List<PlaceData> get filteredNearbyPlaces {
    if (searchQuery.isEmpty) return nearbyPlaces;
    return nearbyPlaces.where((p) => p.name.contains(searchQuery)).toList();
  }

  ParcelDeliveryState({
    this.pickupLocation,
    this.dropoffLocation,
    this.dropoffName = "لم يتم تحديد وجهة",
    this.nearbyPlaces = const [],
    this.activeShipments = const [],
    this.isLoadingLocation = false,
    this.isLoadingPlaces = false,
    this.isSubmitting = false,
    this.selectedVehicle = 'motorcycle', // Standardized default
    this.errorMessage,
    this.pricingResult,
    this.itemDescription = '',
    this.recipientName = '',
    this.recipientPhone = '',
    this.searchQuery = '',
    this.isMapSelectionMode = false,
    this.mapCenter,
    this.isGeocoding = false,
  });

  ParcelDeliveryState copyWith({
    LatLng? pickupLocation,
    LatLng? dropoffLocation,
    String? dropoffName,
    List<PlaceData>? nearbyPlaces,
    List<ParcelDeliveryRequest>? activeShipments,
    bool? isLoadingLocation,
    bool? isLoadingPlaces,
    bool? isSubmitting,
    String? selectedVehicle,
    String? errorMessage,
    PricingResult? pricingResult,
    String? itemDescription,
    String? recipientName,
    String? recipientPhone,
    String? searchQuery,
    bool? isMapSelectionMode,
    LatLng? mapCenter,
    bool? isGeocoding,
  }) {
    return ParcelDeliveryState(
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      dropoffName: dropoffName ?? this.dropoffName,
      nearbyPlaces: nearbyPlaces ?? this.nearbyPlaces,
      activeShipments: activeShipments ?? this.activeShipments,
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      isLoadingPlaces: isLoadingPlaces ?? this.isLoadingPlaces,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      selectedVehicle: selectedVehicle ?? this.selectedVehicle,
      errorMessage: errorMessage ?? this.errorMessage,
      pricingResult: pricingResult ?? this.pricingResult,
      itemDescription: itemDescription ?? this.itemDescription,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      searchQuery: searchQuery ?? this.searchQuery,
      isMapSelectionMode: isMapSelectionMode ?? this.isMapSelectionMode,
      mapCenter: mapCenter ?? this.mapCenter,
      isGeocoding: isGeocoding ?? this.isGeocoding,
    );
  }
}
