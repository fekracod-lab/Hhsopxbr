import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/routing/osrm_route_service.dart';
import '../../../services/routing/route_instructions.dart';
import '../../../core/utils/map_marker_utils.dart';

// ─── Theme Colors ───
const Color _kPrimaryTeal = Color(0xFF00A896);
const Color _kAccentBlue = Color(0xFF2979FF);
const Color _kCardBg = Colors.white;
const Color _kTextDark = Color(0xFF1E293B);

class RideMapWidget extends StatefulWidget {
  final GoogleMapController? mapController;
  final String status;
  final LatLng driverLocation;
  final LatLng pickup;
  final LatLng dropoff;
  final Function(double, double) onLaunchNavigation;

  const RideMapWidget({
    super.key,
    this.mapController,
    required this.status,
    required this.driverLocation,
    required this.pickup,
    required this.dropoff,
    required this.onLaunchNavigation,
  });

  @override
  State<RideMapWidget> createState() => _RideMapWidgetState();
}

class _RideMapWidgetState extends State<RideMapWidget> {
  GoogleMapController? _localMapController;
  RouteResult? _route;
  bool _loading = false;
  RouteStep? _nextStep;
  double _nextStepDistance = 0;
  Timer? _debounce;
  double _currentSpeed = 0; // m/s
  StreamSubscription<Position>? _speedSub;

  LatLng? _lastStart;
  LatLng? _lastEnd;

  BitmapDescriptor? _carMarker;
  BitmapDescriptor? _pickupMarker;
  BitmapDescriptor? _dropoffMarker;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
    _loadRoute();
    _startSpeedTracking();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _speedSub?.cancel();
    _localMapController?.dispose();
    super.dispose();
  }

  Future<void> _loadCustomMarkers() async {
    try {
      final car = await MapMarkerUtils.createTealCarMarker(scale: 1.2);
      final pickup = await MapMarkerUtils.createPickupMarker(label: 'موقع الزبون');
      final dropoff = await MapMarkerUtils.createDestinationMarker(label: 'موقع الوجهة');
      if (mounted) {
        setState(() {
          _carMarker = car;
          _pickupMarker = pickup;
          _dropoffMarker = dropoff;
        });
      }
    } catch (e) {
      debugPrint(' Error loading custom map markers: $e');
    }
  }

  void _startSpeedTracking() {
    _speedSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, distanceFilter: 5),
    ).listen((pos) {
      if (mounted && pos.speed >= 0) {
        setState(() => _currentSpeed = pos.speed);
      }
    }, onError: (_) {});
  }

  @override
  void didUpdateWidget(covariant RideMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final start = _calcStart();
    final end = _calcEnd();
    final statusChanged = oldWidget.status != widget.status;

    double distStart = _lastStart == null
        ? double.infinity
        : Geolocator.distanceBetween(_lastStart!.latitude, _lastStart!.longitude, start.latitude, start.longitude);
    double distEnd = _lastEnd == null
        ? double.infinity
        : Geolocator.distanceBetween(_lastEnd!.latitude, _lastEnd!.longitude, end.latitude, end.longitude);

    if (statusChanged || _lastStart == null || distStart > 100 || _lastEnd == null || distEnd > 10) {
      _loadRoute(debounced: true);
      _moveCamera(start);
    } else if (_route != null) {
      _updateNextStep();
      double distDriver = Geolocator.distanceBetween(
        oldWidget.driverLocation.latitude,
        oldWidget.driverLocation.longitude,
        widget.driverLocation.latitude,
        widget.driverLocation.longitude,
      );
      if (distDriver > 5) _moveCamera(widget.driverLocation);
    }
  }

  /// تحريك الكاميرا بوضع 2D اعتيادي تماماً (tilt = 0, bearing = 0)
  void _moveCamera(LatLng point) {
    _localMapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: point,
          zoom: 16.0,
          tilt: 0.0, // وضع اعتيادي مسطح 2D
          bearing: 0.0,
        ),
      ),
    );
  }

  /// يضبط الكاميرا لتشمل المسار بالكامل بوضعية 2D
  void _fitBounds() {
    if (_localMapController == null) return;
    final end = _calcEnd();
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(widget.driverLocation.latitude, end.latitude),
        math.min(widget.driverLocation.longitude, end.longitude),
      ),
      northeast: LatLng(
        math.max(widget.driverLocation.latitude, end.latitude),
        math.max(widget.driverLocation.longitude, end.longitude),
      ),
    );
    _localMapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 75));
  }

  double _calcBearing() {
    if (_route == null || _route!.points.length < 2) return 0;
    final here = widget.driverLocation;
    double minD = double.infinity;
    int idx = 0;
    for (int i = 0; i < _route!.points.length; i++) {
      final d = Geolocator.distanceBetween(
        here.latitude,
        here.longitude,
        _route!.points[i].latitude,
        _route!.points[i].longitude,
      );
      if (d < minD) {
        minD = d;
        idx = i;
      }
    }
    if (idx < _route!.points.length - 1) {
      return Geolocator.bearingBetween(
        _route!.points[idx].latitude,
        _route!.points[idx].longitude,
        _route!.points[idx + 1].latitude,
        _route!.points[idx + 1].longitude,
      );
    }
    return 0;
  }

  LatLng _calcStart() => widget.driverLocation;

  LatLng _calcEnd() {
    if (widget.status == 'accepted' || widget.status == 'arrived') return widget.pickup;
    return widget.dropoff;
  }

  Future<void> _loadRoute({bool debounced = false}) async {
    _debounce?.cancel();
    if (debounced) {
      _debounce = Timer(const Duration(milliseconds: 800), _loadRoute);
      return;
    }

    final start = _calcStart();
    final end = _calcEnd();
    if (start.latitude == 0 || end.latitude == 0) return;

    if (mounted) setState(() => _loading = true);

    try {
      _lastStart = start;
      _lastEnd = end;
      final r = await OsrmRouteService.getDrivingRoute(start: start, end: end);
      if (mounted) {
        final isNewRoute = _route == null;
        setState(() {
          _route = r;
          _loading = false;
        });
        _updateNextStep();
        if (isNewRoute) _fitBounds();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint('Routing error: $e');
    }
  }

  void _updateNextStep() {
    if (_route == null || _route!.steps.isEmpty) return;

    final here = widget.driverLocation;
    RouteStep? best;
    double bestD = double.infinity;

    for (final s in _route!.steps) {
      final d = Geolocator.distanceBetween(
        here.latitude,
        here.longitude,
        s.location.latitude,
        s.location.longitude,
      );
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }

    if (best != null && bestD < 2000) {
      setState(() {
        _nextStep = best;
        _nextStepDistance = bestD;
      });
    } else {
      setState(() => _nextStep = null);
    }
  }

  Set<Marker> _buildMarkers() {
    final isGoingToPickup = widget.status == 'accepted' || widget.status == 'arrived';
    final isInTrip = widget.status == 'in_progress';

    return {
      // 1. موقع الكابتن
      Marker(
        markerId: const MarkerId('driver'),
        position: widget.driverLocation,
        icon: _carMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: const Offset(0.5, 0.5),
        flat: true,
        rotation: _calcBearing(),
        infoWindow: const InfoWindow(title: 'موقعك الحالي'),
      ),

      // 2. موقع الزبون (عند التوجه للاستلام)
      if (isGoingToPickup)
        Marker(
          markerId: const MarkerId('pickup'),
          position: widget.pickup,
          icon: _pickupMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'موقع الزبون'),
        ),

      // 3. موقع الوجهة (عند بدء المشوار)
      if (isInTrip)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: widget.dropoff,
          icon: _dropoffMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'موقع الوجهة'),
        ),

      // 4. في حالة الحالات الأخرى إظهار النقطتين
      if (!isGoingToPickup && !isInTrip) ...[
        Marker(
          markerId: const MarkerId('pickup'),
          position: widget.pickup,
          icon: _pickupMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'موقع الزبون'),
        ),
        Marker(
          markerId: const MarkerId('dropoff'),
          position: widget.dropoff,
          icon: _dropoffMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'موقع الوجهة'),
        ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final target = _calcEnd();
    final speedKmh = (_currentSpeed * 3.6).round();
    final etaMinutes = _route != null ? (_route!.durationSeconds / 60).ceil() : null;
    final distanceText = _route != null ? formatDistanceMeters(_route!.distanceMeters) : null;
    final isGoingToPickup = widget.status == 'accepted' || widget.status == 'arrived';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          // ── الخريطة الاعتيادية 2D ──
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.driverLocation,
                zoom: 16.0,
                tilt: 0.0, // 2D مسطح
                bearing: 0.0,
              ),
              mapType: MapType.normal, // خريطة عادية واضحة
              buildingsEnabled: false, // بدون مجسمات 3D
              tiltGesturesEnabled: false, // منع إمالة الخريطة لـ 3D
              rotateGesturesEnabled: true,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              onMapCreated: (controller) {
                if (mounted) {
                  setState(() => _localMapController = controller);
                  _fitBounds();
                }
              },
              polylines: {
                if (_route != null && _route!.points.isNotEmpty) ...[
                  // ظل المسار
                  Polyline(
                    polylineId: const PolylineId('route_shadow'),
                    points: _route!.points,
                    width: 9,
                    color: Colors.black.withValues(alpha: 0.18),
                    jointType: JointType.round,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                  ),
                  // المسار الأساسي الملون
                  Polyline(
                    polylineId: const PolylineId('route_main'),
                    points: _route!.points,
                    width: 6,
                    color: isGoingToPickup ? _kPrimaryTeal : _kAccentBlue,
                    jointType: JointType.round,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                  ),
                ],
              },
              markers: _buildMarkers(),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
            ),
          ),

          // ── شريط الحالة والوجهة العلوي الأنيق ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: (isGoingToPickup ? _kPrimaryTeal : _kAccentBlue).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: (isGoingToPickup ? _kPrimaryTeal : _kAccentBlue).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isGoingToPickup ? Icons.person_pin_circle_rounded : Icons.flag_rounded,
                      color: isGoingToPickup ? _kPrimaryTeal : _kAccentBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isGoingToPickup ? 'متوجه لموقع الزبون' : 'متوجه للوجهة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isGoingToPickup ? _kPrimaryTeal : _kAccentBlue,
                          ),
                        ),
                        if (_nextStep != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '${stepToArabic(_nextStep!)} (بعد ${formatDistanceMeters(_nextStepDistance)})',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          )
                        else
                          Text(
                            distanceText != null && etaMinutes != null
                                ? 'المسافة: $distanceText • الوقت: $etaMinutes دقيقة'
                                : 'جاي نحسبلك أفضل مسار...',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimaryTeal),
                    ),
                ],
              ),
            ),
          ),

          // ── مؤشر السرعة (أسفل يسار) ──
          Positioned(
            bottom: 24,
            left: 16,
            child: _SpeedIndicatorWidget(speedKmh: speedKmh),
          ),

          // ── أزرار التحكم بالخريطة والملاحة (يمين الوسط) ──
          Positioned(
            bottom: 24,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // زر إظهار المسار كاملاً
                _MapButton(
                  icon: Icons.alt_route_rounded,
                  tooltip: 'عرض المسار بالكامل',
                  color: _kPrimaryTeal,
                  onTap: _fitBounds,
                ),
                const SizedBox(height: 10),
                // زر تمركز موقع الكابتن
                _MapButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'موقعي',
                  onTap: () => _moveCamera(widget.driverLocation),
                ),
                const SizedBox(height: 10),
                // زر فتح Google Maps الخارجي
                _MapButton(
                  icon: Icons.navigation_rounded,
                  tooltip: 'فتح خرائط جوجل',
                  color: _kAccentBlue,
                  iconColor: Colors.white,
                  bgColor: _kAccentBlue,
                  onTap: () => widget.onLaunchNavigation(target.latitude, target.longitude),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────
// مؤشر السرعة الأنيق
// ────────────────────────────────────────────
class _SpeedIndicatorWidget extends StatelessWidget {
  final int speedKmh;
  const _SpeedIndicatorWidget({required this.speedKmh});

  @override
  Widget build(BuildContext context) {
    final isOverSpeed = speedKmh > 120;
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOverSpeed ? Colors.redAccent : Colors.white,
        border: Border.all(
          color: isOverSpeed ? Colors.red : _kPrimaryTeal.withValues(alpha: 0.5),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$speedKmh',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isOverSpeed ? Colors.white : _kTextDark,
              height: 1,
            ),
          ),
          Text(
            'كم/س',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isOverSpeed ? Colors.white70 : Colors.black45,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────
// أزرار التحكم العائمة بالخريطة
// ────────────────────────────────────────────
class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;
  final Color? iconColor;
  final Color? bgColor;

  const _MapButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
    this.iconColor,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: bgColor ?? Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: iconColor ?? color ?? _kTextDark,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
