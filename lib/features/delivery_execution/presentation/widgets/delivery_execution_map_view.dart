import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../domain/entities/delivery_execution_models.dart';

/// ودجة خريطة الملاحة والتتبع التفاعلية (Delivery Execution Map View)
class DeliveryExecutionMapView extends StatefulWidget {
  final DeliveryLocationEntity? driverLocation;
  final DeliveryPoint pickupPoint;
  final DeliveryPoint dropoffPoint;
  final DeliveryRouteEntity? route;
  final DeliveryExecutionStatus status;
  final EdgeInsets padding;
  final VoidCallback? onMapTap;

  const DeliveryExecutionMapView({
    super.key,
    required this.driverLocation,
    required this.pickupPoint,
    required this.dropoffPoint,
    this.route,
    required this.status,
    this.padding = const EdgeInsets.only(bottom: 240),
    this.onMapTap,
  });

  @override
  State<DeliveryExecutionMapView> createState() => _DeliveryExecutionMapViewState();
}

class _DeliveryExecutionMapViewState extends State<DeliveryExecutionMapView> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _driverMarkerIcon;
  BitmapDescriptor? _pickupMarkerIcon;
  BitmapDescriptor? _dropoffMarkerIcon;

  @override
  void initState() {
    super.initState();
    _initDefaultIcons();
  }

  void _initDefaultIcons() {
    _driverMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
    _pickupMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    _dropoffMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  }

  @override
  void didUpdateWidget(covariant DeliveryExecutionMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driverLocation != widget.driverLocation ||
        oldWidget.status != widget.status ||
        oldWidget.route != widget.route) {
      _fitMapBounds();
    }
  }

  void _fitMapBounds() {
    if (_mapController == null) return;

    final points = <LatLng>[];
    if (widget.driverLocation != null && widget.driverLocation!.isValid) {
      points.add(LatLng(widget.driverLocation!.latitude, widget.driverLocation!.longitude));
    }
    if (widget.pickupPoint.isValid &&
        (widget.status == DeliveryExecutionStatus.accepted ||
         widget.status == DeliveryExecutionStatus.headingToPickup ||
         widget.status == DeliveryExecutionStatus.arrivedAtPickup)) {
      points.add(LatLng(widget.pickupPoint.latitude, widget.pickupPoint.longitude));
    }
    if (widget.dropoffPoint.isValid) {
      points.add(LatLng(widget.dropoffPoint.latitude, widget.dropoffPoint.longitude));
    }

    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(points.first, 16.0));
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    try {
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 65.0));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final LatLng initialPos = widget.driverLocation != null && widget.driverLocation!.isValid
        ? LatLng(widget.driverLocation!.latitude, widget.driverLocation!.longitude)
        : (widget.pickupPoint.isValid
            ? LatLng(widget.pickupPoint.latitude, widget.pickupPoint.longitude)
            : const LatLng(34.3333, 41.0167)); // القائم/الأنبار افتراضياً

    final Set<Marker> markers = {};

    // 1. علامة الكابتن
    if (widget.driverLocation != null && widget.driverLocation!.isValid) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver_marker'),
          position: LatLng(widget.driverLocation!.latitude, widget.driverLocation!.longitude),
          icon: _driverMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          rotation: widget.driverLocation!.heading,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          infoWindow: const InfoWindow(title: 'الكابتن'),
        ),
      );
    }

    // 2. علامة نقطة الاستلام (المحل أو المطعم)
    if (widget.pickupPoint.isValid) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup_marker'),
          position: LatLng(widget.pickupPoint.latitude, widget.pickupPoint.longitude),
          icon: _pickupMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(title: 'نقطة الاستلام', snippet: widget.pickupPoint.name),
        ),
      );
    }

    // 3. علامة نقطة التسليم (الزبون)
    if (widget.dropoffPoint.isValid) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff_marker'),
          position: LatLng(widget.dropoffPoint.latitude, widget.dropoffPoint.longitude),
          icon: _dropoffMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'عنوان الزبون', snippet: widget.dropoffPoint.name),
        ),
      );
    }

    // 4. خط مسار الملاحة (Polyline)
    final Set<Polyline> polylines = {};
    if (widget.route != null && widget.route!.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('delivery_route'),
          points: widget.route!.polylinePoints
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList(),
          color: const Color(0xFF00BFA5),
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialPos, zoom: 15.5),
      onMapCreated: (ctrl) {
        _mapController = ctrl;
        _fitMapBounds();
      },
      markers: markers,
      polylines: polylines,
      padding: widget.padding,
      myLocationButtonEnabled: false,
      myLocationEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      onTap: (_) => widget.onMapTap?.call(),
    );
  }
}
