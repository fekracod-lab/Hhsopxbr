import 'package:flutter/material.dart';

class RideConstants {
  static const double kMinMarkerZoom = 13.0;
  static const double kDetailedMarkerZoom = 15.0;
  static const double kTextMarkerZoom = 16.5;

  static const double kZoomUpdateThreshold = 0.3;
  static const double kPickupRadiusMeters = 50.0;

  static const EdgeInsets kRoutePadding = EdgeInsets.fromLTRB(50, 100, 50, 450);

  static const Duration kGeocodingTimeout = Duration(seconds: 6);
  static const Duration kRoutingTimeout = Duration(seconds: 8);
  static const Duration kRideRequestTimeout = Duration(minutes: 5);
  static const Color secondaryText = Color(0xFF5F6C7B);
}
