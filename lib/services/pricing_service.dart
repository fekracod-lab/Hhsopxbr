import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class PricingResult {
  final double distanceKm;
  final int etaMinutes;
  final double price;
  PricingResult(this.distanceKm, this.etaMinutes, this.price);
}

class PricingService {
  PricingResult calculate({
    required LatLng pickup,
    required LatLng dropoff,
    required String vehicleType,
  }) {
    final meters = Geolocator.distanceBetween(
      pickup.latitude,
      pickup.longitude,
      dropoff.latitude,
      dropoff.longitude,
    );
    final km = meters / 1000.0;
    final eta = (km / 25.0 * 60).round().clamp(5, 120);

    double base = 1000.0;
    double perKm =
        (vehicleType == 'حمل')
            ? 650.0
            : (vehicleType == 'بيك اب')
            ? 450.0
            : 300.0;
    double totalPrice = (base + (km * perKm)).clamp(1000.0, 4250.0);

    return PricingResult(km, eta, totalPrice);
  }
}
