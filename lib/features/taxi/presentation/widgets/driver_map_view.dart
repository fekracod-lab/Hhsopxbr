import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../domain/entities/driver_dashboard_models.dart';
import 'pending_request_card_widget.dart';
import 'driver_active_ride_overlay.dart';

/// ويدجت خريطة الكابتن الحية وإدارة العلامات والمسارات
class DriverMapView extends StatelessWidget {
  final LatLng? initialPosition;
  final LatLng? livePosition;
  final BitmapDescriptor? carIcon;
  final Set<Polyline> polylines;
  final bool shouldFollowDriver;
  final RideRequestEntity? activeRide;
  final List<RideRequestEntity> pendingRequests;
  final bool isProcessing;
  final void Function(GoogleMapController controller) onMapCreated;
  final VoidCallback onToggleFollow;
  final Future<void> Function(RideRequestEntity request) onAcceptRequest;
  final Future<void> Function(RideRequestEntity request) onRejectRequest;
  final Future<void> Function(String newStatus) onUpdateRideStatus;

  const DriverMapView({
    super.key,
    required this.initialPosition,
    required this.livePosition,
    this.carIcon,
    required this.polylines,
    required this.shouldFollowDriver,
    this.activeRide,
    required this.pendingRequests,
    required this.isProcessing,
    required this.onMapCreated,
    required this.onToggleFollow,
    required this.onAcceptRequest,
    required this.onRejectRequest,
    required this.onUpdateRideStatus,
  });

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};

    if (livePosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver_live_marker'),
          position: livePosition!,
          icon: carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    if (activeRide != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup_marker'),
          position: LatLng(activeRide!.pickupLat, activeRide!.pickupLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'نقطة الانطلاق', snippet: activeRide!.pickupAddress),
        ),
      );
      markers.add(
        Marker(
          markerId: const MarkerId('destination_marker'),
          position: LatLng(activeRide!.destinationLat, activeRide!.destinationLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'الوجهة', snippet: activeRide!.destinationAddress),
        ),
      );
    }

    final defaultPos = initialPosition ?? const LatLng(33.3152, 44.3661); // Baghdad default

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: defaultPos, zoom: 15.0),
          onMapCreated: onMapCreated,
          markers: markers,
          polylines: polylines,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),

        // زر إعادة تثبيت وتتبع موقع الكابتن
        Positioned(
          left: 16,
          bottom: activeRide != null ? 240 : (pendingRequests.isNotEmpty ? 260 : 20),
          child: FloatingActionButton.small(
            onPressed: onToggleFollow,
            backgroundColor: shouldFollowDriver ? const Color(0xFF26A69A) : const Color(0xFF1E293B),
            child: Icon(
              shouldFollowDriver ? Icons.my_location_rounded : Icons.location_searching_rounded,
              color: Colors.white,
            ),
          ),
        ),

        // بطاقة الرحلة النشطة الحالية (إذا كان في رحلة)
        if (activeRide != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DriverActiveRideOverlay(
              activeRide: activeRide!,
              onUpdateStatus: onUpdateRideStatus,
            ),
          )
        // بطاقة أول طلب معلق جديد (إذا كان متاحاً وبانتظار الموافقة)
        else if (pendingRequests.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PendingRequestCardWidget(
              request: pendingRequests.first,
              isProcessing: isProcessing,
              onAccept: onAcceptRequest,
              onReject: onRejectRequest,
            ),
          ),
      ],
    );
  }
}
