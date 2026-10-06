import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dalal_alqaim/core/location_permission_helper.dart';

class LocationService {
  Future<LatLng?> getCurrentLocation([BuildContext? context]) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      if (context != null) {
        if (!context.mounted) return null;
        bool hasPerm = await LocationPermissionHelper.requestLocationPermissionWithDisclosure(
          context,
        );
        if (!context.mounted || !hasPerm) return null;
      } else {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return null;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint("Error getting location: $e");
      return null;
    }
  }
}
