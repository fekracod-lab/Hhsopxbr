import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dalal_alqaim/features/taxi/presentation/controller/taxi_controller.dart';
import 'package:dalal_alqaim/features/taxi/presentation/controller/taxi_ui_state.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import 'package:dalal_alqaim/core/utils/map_marker_utils.dart';
import 'package:dalal_alqaim/core/maps/google_maps_initializer.dart';

// --- Design System Constants ---
final Color kPrimaryColor = AppTheme.primaryColor;
final Color kAccentColor = AppTheme.accentColor;
const Color kBackgroundColor = Color(0xFFFFFFFF);
const Color kTextColor = Color(0xFF2D3436);
const Color kSubTextColor = Color(0xFF757575);
const Color kSurfaceColor = Color(0xFFF8F9FA);

class TaxiMapView extends StatefulWidget {
  final Function(GoogleMapController)? onMapCreated;
  final VoidCallback? onSearchTap;

  const TaxiMapView({super.key, this.onMapCreated, this.onSearchTap});

  @override
  State<TaxiMapView> createState() => _TaxiMapViewState();
}

class _TaxiMapViewState extends State<TaxiMapView> with SingleTickerProviderStateMixin {
  bool _isMapMoving = false;
  bool _isMapReady = false;
  GoogleMapController? _mapController;
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;
  LatLng? _currentMapCenter;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _loadIcons();

    // التسلسل الإجباري: إتاحة رسم أول إطار لواجهة التكسي أولاً، ثم تهيئة الخريطة في الخلفية
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await GoogleMapsInitializer.ensureInitialized();
      if (mounted) {
        setState(() {
          _isMapReady = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadIcons() async {
    if (!mounted) return;
    try {
      final car = await MapMarkerUtils.createTealCarMarker(scale: 1.2);
      final pickup = await MapMarkerUtils.createPickupMarker(label: 'موقعك');
      final dropoff = await MapMarkerUtils.createDestinationMarker(label: 'مكان النزلة');
      if (mounted) {
        setState(() {
          _carIcon = car;
          _pickupIcon = pickup;
          _dropoffIcon = dropoff;
        });
      }
    } catch (e) {
      debugPrint(" Failed to load custom map markers: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TaxiController>();
    final state = controller.state;

    _currentMapCenter ??= state.pickupLocation;
    final isSelecting = state.status == TaxiViewStatus.selectingDropoff;
    final isIdleOrSelecting = state.status == TaxiViewStatus.idle || isSelecting;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. The Map Layer (Background)
          _buildMapLayer(state, controller),

          // 2. Top Floating UI (Search & Back)
          if (isIdleOrSelecting) _buildTopArea(context, controller, state),

          // 3. Selection Pin with Madar Logo & Arrow (Center of Screen)
          if (state.status == TaxiViewStatus.selectingDropoff) _buildMadarCenterPin(state),

          // 4. Floating 'موقعك' Location Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(right: 18, left: 18, bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildMyLocationPill(controller),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Map Layer ---

  Widget _buildMapLayer(TaxiUiState state, TaxiController controller) {
    if (!_isMapReady) {
      return Container(
        color: const Color(0xFFF1F5F9),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF00BFA5),
                ),
              ),
              SizedBox(height: 14),
              Text(
                'جاري تجهيز الخريطة...',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: state.pickupLocation ?? const LatLng(33.3152, 44.3661),
        zoom: state.pickupLocation != null ? 16.5 : 7.0,
      ),
      onMapCreated: (mapController) {
        _mapController = mapController;
        if (widget.onMapCreated != null) {
          widget.onMapCreated!(mapController);
        }
      },
      onCameraMoveStarted: () {
        if (mounted) setState(() => _isMapMoving = true);
        controller.onMapMoveStarted();
      },
      onCameraIdle: () {
        if (mounted) setState(() => _isMapMoving = false);
        if (_currentMapCenter != null &&
            (state.status == TaxiViewStatus.idle ||
                state.status == TaxiViewStatus.selectingDropoff)) {
          controller.updateLocationFromMap(_currentMapCenter);
        }
      },
      onCameraMove: (position) {
        _currentMapCenter = position.target;
      },
      polylines: _buildPolylines(state),
      markers: _buildMarkers(state),
      myLocationEnabled: state.hasLocationPermission,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  Set<Polyline> _buildPolylines(TaxiUiState state) {
    final polylines = <Polyline>{};

    // 1. المسارات البديلة (بشكل خفيف وأنيق)
    for (var i = 0; i < state.routeAlternatives.length; i++) {
      final route = state.routeAlternatives[i];
      final isSelected = state.selectedRoute == route;

      if (!isSelected) {
        polylines.add(
          Polyline(
            polylineId: PolylineId('alt_route_$i'),
            points: route.points,
            color: const Color(0xFF90A4AE).withValues(alpha: 0.55),
            width: 4,
            zIndex: 1,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      }
    }

    // 2. المسار المختار (مزدوج بنمط Glow فخم)
    final points = state.selectedRoute?.points ?? state.routePoints;
    if (points.isNotEmpty) {
      // Glow Casing (توهج خارجي)
      polylines.add(
        Polyline(
          polylineId: const PolylineId('selected_route_glow'),
          points: points,
          color: kPrimaryColor.withValues(alpha: 0.28),
          width: 9,
          zIndex: 8,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );

      // Main Core Line (المسار الرئيسي اللامع)
      polylines.add(
        Polyline(
          polylineId: const PolylineId('selected_route_core'),
          points: points,
          color: kPrimaryColor,
          width: 5,
          zIndex: 10,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }

    return polylines;
  }

  Set<Marker> _buildMarkers(TaxiUiState state) {
    return {
      // نقطة الانطلاق (موقعك )
      if (state.pickupLocation != null && state.status == TaxiViewStatus.ready)
        Marker(
          markerId: const MarkerId('pickup'),
          position: state.pickupLocation!,
          icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          anchor: const Offset(0.5, 0.9),
          infoWindow: const InfoWindow(title: 'موقعك'),
        ),

      // نقطة الوصول (مكان النزلة )
      if (state.dropoffLocation != null && state.status == TaxiViewStatus.ready)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: state.dropoffLocation!,
          icon: _dropoffIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          anchor: const Offset(0.5, 0.9),
          infoWindow: const InfoWindow(title: 'مكان النزلة'),
        ),

      // المعالم والمواقع المفضلة
      ...state.allPois.map(
        (poi) => Marker(
          markerId: MarkerId(poi.name),
          position: poi.location,
          infoWindow: InfoWindow(title: poi.name),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      ),

      // الكباتن القريبين (سيارات تيل حية)
      ...state.nearbyDrivers.entries.map((entry) {
        final driverId = entry.key;
        final data = entry.value;
        return Marker(
          markerId: MarkerId('driver_$driverId'),
          position: data.location,
          rotation: data.heading,
          anchor: const Offset(0.5, 0.5),
          icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          flat: true,
        );
      }),
    };
  }

  // --- Top Area (Search & Quick Chips) ---

  Widget _buildTopArea(BuildContext context, TaxiController controller, TaxiUiState state) {
    final bool canGoBack = state.status != TaxiViewStatus.idle;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (canGoBack) ...[
                  _circularButton(
                    Icons.arrow_back_ios_new_rounded,
                    () => Navigator.pop(context),
                    size: 45,
                  ),
                  const SizedBox(width: 10),
                ],

                // Search Pill
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onSearchTap,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: kPrimaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: kPrimaryColor.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "وين تحب تروح اليوم؟",
                                  style: TextStyle(
                                    fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: kTextColor,
                                  ),
                                ),
                                Text(
                                  "موقعك: ${state.pickupAddress.isNotEmpty ? state.pickupAddress : 'مكاني هسة'}",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                                    fontSize: 10.5,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2F1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.bolt_rounded, size: 15, color: kPrimaryColor),
                                const SizedBox(width: 3),
                                Text(
                                  "هسة",
                                  style: TextStyle(
                                    fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: kPrimaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Quick Actions (Saved Places)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildQuickActionChip(
                  icon: Icons.home_rounded,
                  label: state.homeAddress != null ? 'البيت' : 'ضيف بيتك',
                  isSaved: state.homeAddress != null,
                  onTap: () => controller.useQuickAction(true),
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  icon: Icons.work_rounded,
                  label: state.workAddress != null ? 'الدوام' : 'ضيف دوامك',
                  isSaved: state.workAddress != null,
                  onTap: () => controller.useQuickAction(false),
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  icon: Icons.star_rounded,
                  label: 'المفضلة',
                  isSaved: false,
                  onTap: () {
                    Navigator.pushNamed(context, '/my_addresses');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- تحديد الوصول الفخم مع لوكو مدار والسهم ---

  Widget _buildMadarCenterPin(TaxiUiState state) {
    final double bottomMargin = _isMapMoving ? 38 : 0;
    final double shadowScale = _isMapMoving ? 0.35 : 1.0;
    final double pinScale = _isMapMoving ? 1.12 : 1.0;

    final labelText = state.isSavingHome
        ? "حدد مكان بيتك"
        : state.isSavingWork
            ? "حدد مكان دوامك"
            : "مكان النزلة";

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Radar Glow Target on the ground (توهج الهدف على الأرض)
          Transform.translate(
            offset: const Offset(0, 26),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final double pulse = _isMapMoving ? 0.2 : _pulseController.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Pulsing Wave
                    Container(
                      width: (28 + pulse * 14) * shadowScale,
                      height: (12 + pulse * 6) * shadowScale,
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withValues(alpha: 0.15 * (1.0 - pulse)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    // Inner Target Spot
                    Container(
                      width: 14 * shadowScale,
                      height: 6 * shadowScale,
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: kPrimaryColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 2. The Pin Body Assembly (المقبض + الشعار + السهم)
          AnimatedPadding(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            padding: EdgeInsets.only(bottom: 64 + bottomMargin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Floating Address Badge (شريط العنوان العائم)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _isMapMoving ? 0.0 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E272C),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: kPrimaryColor.withValues(alpha: 0.4), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kPrimaryColor,
                            boxShadow: [
                              BoxShadow(color: kPrimaryColor, blurRadius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          labelText,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                            fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Madar Logo Pin Head (رأس الدبوس بشعار مدار)
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 1.0, end: pinScale),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pin Disc with Madar Logo
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF00BFA5), Color(0xFF00796B)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: kPrimaryColor.withValues(alpha: 0.45),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              border: Border.all(color: Colors.white, width: 2.5),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(7.0),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                padding: const EdgeInsets.all(4.0),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.navigation_rounded,
                                    color: kPrimaryColor,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // The Arrow Pointer (السهم المتجه للأسفل مباشرة)
                          Transform.translate(
                            offset: const Offset(0, -2),
                            child: ClipPath(
                              clipper: _ArrowClipper(),
                              child: Container(
                                width: 16,
                                height: 12,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0xFF00796B), Color(0xFF004D40)],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- زر موقعك الفخم (My Location Pill) ---

  Widget _buildMyLocationPill(TaxiController controller) {
    return GestureDetector(
      onTap: () => controller.centerOnUser(_mapController),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.my_location_rounded, color: kPrimaryColor, size: 18),
            const SizedBox(width: 6),
            Text(
              "موقعك",
              style: TextStyle(
                fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: kTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Utils ---

  Widget _circularButton(
    IconData icon,
    VoidCallback onTap, {
    double size = 45,
    Color iconColor = kTextColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size),
          child: Icon(icon, color: iconColor, size: size * 0.48),
        ),
      ),
    );
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required bool isSaved,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: isSaved ? kPrimaryColor.withValues(alpha: 0.4) : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSaved ? kPrimaryColor : kSubTextColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                fontSize: 12,
                fontWeight: isSaved ? FontWeight.bold : FontWeight.w600,
                color: isSaved ? kTextColor : kSubTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// مثلث السهم المتجه للأسفل
class _ArrowClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
