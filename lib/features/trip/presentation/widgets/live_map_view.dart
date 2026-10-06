import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:dalal_alqaim/features/trip/presentation/controller/trip_controller.dart';
import 'package:dalal_alqaim/features/trip/presentation/trip_design.dart';
import 'package:dalal_alqaim/core/utils/map_marker_utils.dart';

class LiveMapView extends StatefulWidget {
  final Function(GoogleMapController)? onMapCreated;
  final VoidCallback onShowChat;

  const LiveMapView({super.key, this.onMapCreated, required this.onShowChat});

  @override
  State<LiveMapView> createState() => _LiveMapViewState();
}

class _LiveMapViewState extends State<LiveMapView> {
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
  }

  Future<void> _loadCustomMarkers() async {
    try {
      final car = await MapMarkerUtils.createTealCarMarker(scale: 1.2);
      final pickup = await MapMarkerUtils.createPickupMarker(label: 'موقع الزبون');
      final dropoff = await MapMarkerUtils.createDestinationMarker(label: 'موقع الوجهة');
      if (mounted) {
        setState(() {
          _carIcon = car;
          _pickupIcon = pickup;
          _dropoffIcon = dropoff;
        });
      }
    } catch (e) {
      debugPrint("Error loading custom markers in LiveMapView: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TripController>();
    final state = controller.state;
    final trip = state.trip;

    if (trip == null) return const Center(child: CircularProgressIndicator(color: TripDesign.primary));

    final pickup = LatLng(trip.pickupLat, trip.pickupLng);
    final dropoff = LatLng(trip.dropoffLat, trip.dropoffLng);

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: pickup,
            zoom: 16,
            tilt: 0.0, // 2D اعتيادي
            bearing: 0.0,
          ),
          mapType: MapType.normal,
          buildingsEnabled: false,
          tiltGesturesEnabled: false, // تعطيل الإمالة 3D
          rotateGesturesEnabled: true,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          onMapCreated: widget.onMapCreated,
          polylines: {
            if (state.routePoints.isNotEmpty) ...[
              // ظل المسار
              Polyline(
                polylineId: const PolylineId('route_shadow'),
                points: state.routePoints,
                width: 9,
                color: Colors.black.withValues(alpha: 0.15),
                jointType: JointType.round,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
              // المسار الأساسي
              Polyline(
                polylineId: const PolylineId('route'),
                points: state.routePoints,
                width: 6,
                color: TripDesign.primary,
                jointType: JointType.round,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
            ],
          },
          markers: {
            if (state.userLocation != null)
              Marker(
                markerId: const MarkerId('user_location'),
                position: state.userLocation!,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                infoWindow: const InfoWindow(title: 'موقعك الحالي'),
              ),
            Marker(
              markerId: const MarkerId('pickup'),
              position: pickup,
              icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: const InfoWindow(title: 'موقع الزبون'),
            ),
            Marker(
              markerId: const MarkerId('dropoff'),
              position: dropoff,
              icon: _dropoffIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: const InfoWindow(title: 'موقع الوجهة'),
            ),
            if (state.driverLocation != null)
              Marker(
                markerId: const MarkerId('driver'),
                position: state.driverLocation!,
                rotation: state.driverHeading,
                anchor: const Offset(0.5, 0.5),
                flat: true,
                icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                infoWindow: const InfoWindow(title: 'الكابتن'),
              ),
          },
          onCameraMove: (position) {
            if (state.autoFollowEnabled) {
              controller.disableAutoFollowTemporarily();
            }
          },
        ),

        // UI Overlays
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    _glassIconButton(context, Icons.arrow_back, () => Navigator.pop(context)),
                    const Spacer(),
                    if (!state.autoFollowEnabled)
                      _glassIconButton(
                        context,
                        Icons.my_location,
                        () => controller.toggleAutoFollow(),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),

        // Bottom Details and Chat Button
        Positioned(
          right: 20,
          bottom: MediaQuery.of(context).size.height * 0.45,
          child: FloatingActionButton(
            onPressed: widget.onShowChat,
            backgroundColor: TripDesign.accent,
            elevation: 10,
            child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _glassIconButton(BuildContext context, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: TripDesign.cardShadow,
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }
}
