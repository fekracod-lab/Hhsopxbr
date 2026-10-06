import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../controllers/parcel_delivery_controller.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class ParcelMapWidget extends StatelessWidget {
  final GoogleMapController? mapController;
  final Function(LatLng)? onLocationSelected;

  const ParcelMapWidget({super.key, this.mapController, this.onLocationSelected});

  @override
  Widget build(BuildContext context) {
    return Consumer<ParcelDeliveryController>(
      builder: (context, controller, child) {
        final state = controller.state;
        final pickup = state.pickupLocation ?? const LatLng(33.3152, 44.3661);

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: pickup,
                zoom: state.pickupLocation != null ? 15.0 : 7.0,
              ),
              onMapCreated: (mapController) {
                // If the parent needs to handle the controller, it can via a callback
              },
              onCameraMoveStarted: () {
                if (state.isMapSelectionMode) {
                  // Can add feedback if needed
                }
              },
              onCameraMove: (position) {
                if (state.isMapSelectionMode) {
                  controller.updateMapCenter(position.target);
                }
              },
              onTap: (point) {
                if (!state.isMapSelectionMode) {
                  if (onLocationSelected != null) {
                    onLocationSelected!(point);
                  } else {
                    controller.setDropoff(point, "موقع محدد على الخريطة");
                  }
                }
              },
              polylines: {
                if (state.pickupLocation != null &&
                    state.dropoffLocation != null &&
                    !state.isMapSelectionMode)
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: [state.pickupLocation!, state.dropoffLocation!],
                    width: 3,
                    color: app_colors.primaryColor.withValues(alpha: 0.5),
                    patterns: [PatternItem.dash(10), PatternItem.gap(10)],
                  ),
              },
              markers: {
                if (state.pickupLocation != null && !state.isMapSelectionMode)
                  Marker(
                    markerId: const MarkerId('pickup'),
                    position: state.pickupLocation!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                  ),
                if (state.dropoffLocation != null && !state.isMapSelectionMode)
                  Marker(
                    markerId: const MarkerId('dropoff'),
                    position: state.dropoffLocation!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  ),
                if (!state.isMapSelectionMode)
                  ...state.filteredNearbyPlaces
                      .take(6)
                      .map(
                        (place) => Marker(
                          markerId: MarkerId(place.id),
                          position: place.position,
                          onTap: () => controller.setDropoff(place.position, place.name),
                          infoWindow: InfoWindow(title: place.name),
                        ),
                      ),
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
            if (state.isMapSelectionMode)
              IgnorePointer(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SelectionPinPin(),
                      const SizedBox(height: 38), // Center over the tip
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SelectionPinPin extends StatefulWidget {
  @override
  State<_SelectionPinPin> createState() => _SelectionPinPinState();
}

class _SelectionPinPinState extends State<_SelectionPinPin> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -10 * _controller.value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: app_colors.primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: app_colors.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.location_on, color: Colors.white, size: 28),
              ),
            ],
          ),
        );
      },
    );
  }
}
