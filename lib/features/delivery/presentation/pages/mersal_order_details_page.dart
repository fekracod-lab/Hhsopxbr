import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:dalal_alqaim/models/mersal_request.dart';
import 'package:dalal_alqaim/services/mersal_service.dart';
import 'package:dalal_alqaim/services/ringtone_manager.dart';
import 'package:dalal_alqaim/services/routing/osrm_route_service.dart';

class MersalOrderDetailsPage extends StatefulWidget {
  final MersalRequest request;
  final Map<String, dynamic> driverData;

  const MersalOrderDetailsPage({
    super.key,
    required this.request,
    required this.driverData,
  });

  @override
  State<MersalOrderDetailsPage> createState() => _MersalOrderDetailsPageState();
}

class _MersalOrderDetailsPageState extends State<MersalOrderDetailsPage> {
  final MersalService _mersalService = MersalService();
  final TextEditingController _priceController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'ar');

  bool _isProcessing = false;
  GoogleMapController? _mapController;

  // In-App Native Audio Player (داخل مدار)
  VideoPlayerController? _voiceController;
  bool _isVoiceInitializing = false;
  bool _isPlayingVoice = false;
  Duration _voicePosition = Duration.zero;
  Duration _voiceDuration = Duration.zero;

  // Custom Map Markers
  BitmapDescriptor? _bikeMarkerIcon;
  BitmapDescriptor? _customerMarkerIcon;

  // Real-time Driver GPS & Dynamic Route Tracking
  LatLng? _driverLocation;
  double _driverHeading = 0.0;
  double _driverSpeedKmh = 0.0;
  StreamSubscription<Position>? _positionSub;
  List<LatLng> _routePoints = [];
  double? _distanceKm;
  int? _durationMinutes;
  bool _isLoadingRoute = false;
  bool _isDetailsExpanded = false;
  bool _isAutoTrackingEnabled = true;

  // Modern Enterprise Taxi & Delivery Theme Palette
  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSub = Color(0xFF475569);
  static const Color _borderLight = Color(0xFFE2E8F0);
  static const Color _primary = Color(0xFF00BFA5);
  static const Color _accent = Color(0xFF0284C7);
  static const Color _success = Color(0xFF00C853);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _danger = Color(0xFFE53935);

  final List<String> _quickPrices = [
    '750',
    '1000',
    '1250',
    '1500',
    '1750',
    '2000',
    '2500',
    '3000',
  ];

  @override
  void initState() {
    super.initState();
    RingtoneManager.stopAll();
    if (widget.request.price != null &&
        widget.request.price!.isNotEmpty &&
        widget.request.price != '0') {
      _priceController.text = widget.request.price!;
    } else {
      _priceController.text = '2000';
    }

    _initCustomMarkers();
    _initDriverLocationTracking();
  }

  @override
  void dispose() {
    _voiceController?.dispose();
    _positionSub?.cancel();
    _priceController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initCustomMarkers() async {
    try {
      final bikeIcon = await _createBikeDriverMarker();
      final customerIcon = await _createCustomerMarker();
      if (mounted) {
        setState(() {
          _bikeMarkerIcon = bikeIcon;
          _customerMarkerIcon = customerIcon;
        });
      }
    } catch (e) {
      debugPrint('Error generating custom marker icons: $e');
    }
  }

  Future<BitmapDescriptor> _createCustomerMarker() async {
    final recorder = ui.PictureRecorder();
    const double size = 110.0;
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size + 20));

    // 1. Drop Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(const Offset(size / 2, size / 2 + 3), 36, shadowPaint);

    // 2. Pointer needle (Triangle pointing to location)
    final pointerPath = Path()
      ..moveTo(size / 2 - 12, size / 2 + 25)
      ..lineTo(size / 2, size + 16)
      ..lineTo(size / 2 + 12, size / 2 + 25)
      ..close();
    final needlePaint = Paint()..color = _danger;
    canvas.drawPath(pointerPath, needlePaint);

    // 3. Red Outer Circle
    final outerPaint = Paint()..color = _danger;
    canvas.drawCircle(const Offset(size / 2, size / 2), 36, outerPaint);

    // 4. White Middle Ring
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), 31, whitePaint);

    // 5. Light Red Inner Circle
    final innerPaint = Paint()..color = const Color(0xFFFFEBEE);
    canvas.drawCircle(const Offset(size / 2, size / 2), 26, innerPaint);

    // 6. Draw Person Icon (أيقونة زبون)
    final textPainter = TextPainter(textDirection: TextDirection.rtl);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.person_rounded.codePoint),
      style: TextStyle(
        fontSize: 32,
        fontFamily: Icons.person_rounded.fontFamily,
        package: Icons.person_rounded.fontPackage,
        color: _danger,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final img = await recorder.endRecording().toImage(size.toInt(), (size + 20).toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createBikeDriverMarker() async {
    final recorder = ui.PictureRecorder();
    const double size = 100.0;
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    // 1. Drop Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(const Offset(size / 2, size / 2 + 2), 38, shadowPaint);

    // 2. Cyan / Accent Outer Circle
    final outerPaint = Paint()..color = _accent;
    canvas.drawCircle(const Offset(size / 2, size / 2), 38, outerPaint);

    // 3. White Middle Ring
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), 33, whitePaint);

    // 4. Accent Inner Circle
    final innerPaint = Paint()..color = _accent;
    canvas.drawCircle(const Offset(size / 2, size / 2), 28, innerPaint);

    // 5. Draw Motorcycle / Bike Icon (أيقونة دراجة)
    final textPainter = TextPainter(textDirection: TextDirection.rtl);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.two_wheeler_rounded.codePoint),
      style: TextStyle(
        fontSize: 32,
        fontFamily: Icons.two_wheeler_rounded.fontFamily,
        package: Icons.two_wheeler_rounded.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  Future<void> _initDriverLocationTracking() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        if (mounted) {
          setState(() {
            _driverLocation = LatLng(pos.latitude, pos.longitude);
            _driverHeading = pos.heading;
            _driverSpeedKmh = (pos.speed * 3.6).clamp(0, 160);
          });
          _calculateAndDrawDynamicRoute();
        }

        // Live moving GPS stream (updates every 5 meters)
        _positionSub = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((newPos) {
          if (mounted) {
            final prev = _driverLocation;
            final newLoc = LatLng(newPos.latitude, newPos.longitude);
            final speed = (newPos.speed * 3.6).clamp(0.0, 160.0);

            setState(() {
              _driverLocation = newLoc;
              _driverHeading = newPos.heading;
              _driverSpeedKmh = speed;
            });

            // Smoothly follow camera if auto-tracking is enabled
            if (_isAutoTrackingEnabled && _mapController != null) {
              _mapController?.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: newLoc,
                    zoom: 16.5,
                    bearing: newPos.heading,
                  ),
                ),
              );
            }

            // Recalculate remaining route and duration if driver moved more than 20 meters
            if (prev == null ||
                Geolocator.distanceBetween(
                      prev.latitude,
                      prev.longitude,
                      newLoc.latitude,
                      newLoc.longitude,
                    ) >
                    20) {
              _calculateAndDrawDynamicRoute();
            }
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _driverLocation = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Driver location tracking error: $e');
      if (mounted) {
        setState(() {
          _driverLocation = null;
        });
      }
    }
  }

  Future<void> _calculateAndDrawDynamicRoute() async {
    final customerLatLng = LatLng(widget.request.dropoffLat, widget.request.dropoffLng);
    if (_driverLocation == null || (customerLatLng.latitude == 0 && customerLatLng.longitude == 0)) {
      return;
    }

    setState(() => _isLoadingRoute = true);

    try {
      final result = await OsrmRouteService.getDrivingRoute(
        start: _driverLocation!,
        end: customerLatLng,
      );

      if (mounted) {
        setState(() {
          _routePoints = result.points;
          _distanceKm = result.distanceMeters / 1000.0;
          _durationMinutes = (result.durationSeconds / 60.0).ceil();
          _isLoadingRoute = false;
        });
        if (!_isAutoTrackingEnabled) {
          _fitMapCameraToBounds();
        }
      }
    } catch (e) {
      debugPrint('OSRM Route fallback to straight polyline: $e');
      if (mounted) {
        final dist = Geolocator.distanceBetween(
          _driverLocation!.latitude,
          _driverLocation!.longitude,
          customerLatLng.latitude,
          customerLatLng.longitude,
        );
        setState(() {
          _routePoints = [_driverLocation!, customerLatLng];
          _distanceKm = dist / 1000.0;
          _durationMinutes = ((dist / 1000.0) * 2.5).ceil();
          _isLoadingRoute = false;
        });
        if (!_isAutoTrackingEnabled) {
          _fitMapCameraToBounds();
        }
      }
    }
  }

  void _fitMapCameraToBounds() {
    if (_mapController == null || _driverLocation == null) return;
    final customerLatLng = LatLng(widget.request.dropoffLat, widget.request.dropoffLng);

    final southWestLat = _driverLocation!.latitude < customerLatLng.latitude
        ? _driverLocation!.latitude
        : customerLatLng.latitude;
    final southWestLng = _driverLocation!.longitude < customerLatLng.longitude
        ? _driverLocation!.longitude
        : customerLatLng.longitude;
    final northEastLat = _driverLocation!.latitude > customerLatLng.latitude
        ? _driverLocation!.latitude
        : customerLatLng.latitude;
    final northEastLng = _driverLocation!.longitude > customerLatLng.longitude
        ? _driverLocation!.longitude
        : customerLatLng.longitude;

    final bounds = LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  // ────────────────────────────────────────────
  // تشغيل البصمة الصوتية داخل مدار مباشرة
  // ────────────────────────────────────────────
  Future<void> _toggleInAppVoiceNote(String url) async {
    if (url.isEmpty) return;

    if (_voiceController != null && _voiceController!.dataSource == url) {
      if (_voiceController!.value.isPlaying) {
        await _voiceController!.pause();
        if (mounted) setState(() => _isPlayingVoice = false);
      } else {
        await _voiceController!.play();
        if (mounted) setState(() => _isPlayingVoice = true);
      }
      return;
    }

    setState(() => _isVoiceInitializing = true);
    try {
      await _voiceController?.dispose();
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      controller.addListener(() {
        if (!mounted) return;
        final val = controller.value;
        setState(() {
          _isPlayingVoice = val.isPlaying;
          _voicePosition = val.position;
          _voiceDuration = val.duration;
        });
        if (val.position >= val.duration && val.duration > Duration.zero) {
          controller.seekTo(Duration.zero);
          controller.pause();
          setState(() => _isPlayingVoice = false);
        }
      });

      _voiceController = controller;
      await controller.play();
      if (mounted) {
        setState(() {
          _isPlayingVoice = true;
          _isVoiceInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('Error playing voice note in-app: $e');
      if (mounted) {
        setState(() => _isVoiceInitializing = false);
        _showSnackBar('حدث خطأ أثناء تشغيل البصمة الصوتية');
      }
    }
  }

  Future<void> _acceptOrder() async {
    final entered = _priceController.text.trim();
    final pNum = double.tryParse(entered) ?? 0.0;
    if (pNum <= 0) {
      _showSnackBar('يرجى تحديد أو كتابة أجرة التوصيل');
      return;
    }

    setState(() => _isProcessing = true);
    await RingtoneManager.stopAll();
    HapticFeedback.heavyImpact();
    try {
      final driverId = widget.driverData['id'] ??
          widget.driverData['uid'] ??
          FirebaseAuth.instance.currentUser?.uid ??
          '';

      final success = await _mersalService.acceptRequest(
        requestId: widget.request.id,
        driverId: driverId,
        driverData: widget.driverData,
        agreedPrice: entered,
      );

      if (success) {
        if (mounted) {
          _showSnackBar('تم قبول الطلب بنجاح بأجرة ${_currencyFormat.format(pNum)} د.ع!');
        }
      } else {
        _showSnackBar('تعذر قبول الطلب، قد يكون استلمه مندوب آخر');
      }
    } catch (e) {
      _showSnackBar('خطأ في قبول الطلب: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _updateStatus(String status, {Map<String, dynamic>? extraData}) async {
    setState(() => _isProcessing = true);
    await RingtoneManager.stopAll();
    HapticFeedback.mediumImpact();
    try {
      await _mersalService.updateStatus(widget.request.id, status, extraData: extraData);
      if (mounted) {
        _showSnackBar('تم تحديث حالة التوصيل بنجاح');
        if (status == 'delivered') {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) Navigator.pop(context);
          });
        }
      }
    } catch (e) {
      _showSnackBar('خطأ في تحديث الحالة: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        backgroundColor: _textMain,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('mersal_requests')
          .doc(widget.request.id)
          .snapshots(),
      builder: (context, snapshot) {
        MersalRequest currentRequest = widget.request;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          currentRequest = MersalRequest.fromMap(data, widget.request.id);
        }

        final customerLatLng = LatLng(currentRequest.dropoffLat, currentRequest.dropoffLng);
        final isPending = currentRequest.status == 'pending';

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Stack(
              children: [
                // 1. خريطة كامل الشاشة التفاعلية الحية مع أيقونات الزبون والدراجة
                _buildFullscreenMap(customerLatLng, currentRequest),

                // 2. شريط الأدوات العلوي العائم وشارة السرعة والمسافة
                _buildFloatingTopBar(currentRequest),

                // 3. أزرار التحكم بالملاحة والتمركز
                _buildFloatingMapControls(customerLatLng),

                // 4. اللوحة السفلية التفاعلية للرحلة ومشغل البصمة الصوتي المباشر داخل مدار
                _buildBottomTripPanel(currentRequest, customerLatLng, isPending),

                // مؤشر التحميل العام
                if (_isProcessing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: const Center(
                      child: CircularProgressIndicator(color: _primary),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────
  // 1. الخريطة الرئيسية بأيقونة الزبون وأيقونة الدراجة
  // ────────────────────────────────────────────
  Widget _buildFullscreenMap(LatLng customerLatLng, MersalRequest request) {
    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('customer_destination'),
        position: customerLatLng,
        icon: _customerMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        anchor: const Offset(0.5, 0.9),
        infoWindow: InfoWindow(
          title: 'موقع الزبون',
          snippet: request.dropoffAddress.isNotEmpty ? request.dropoffAddress : 'نقطة التسليم',
        ),
      ),
      if (_driverLocation != null)
        Marker(
          markerId: const MarkerId('driver_current_pos'),
          position: _driverLocation!,
          rotation: _driverHeading,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          icon: _bikeMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: 'موقعك (كابتن مدار)',
            snippet: '${_driverSpeedKmh.toInt()} كم/س',
          ),
        ),
    };

    final Set<Polyline> polylines = {
      if (_routePoints.isNotEmpty)
        Polyline(
          polylineId: const PolylineId('active_delivery_route'),
          points: _routePoints,
          color: _accent,
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
    };

    return Positioned.fill(
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: customerLatLng.latitude != 0 ? customerLatLng : const LatLng(34.3418, 41.0775),
          zoom: 15.5,
        ),
        onMapCreated: (controller) {
          _mapController = controller;
          _fitMapCameraToBounds();
        },
        markers: markers,
        polylines: polylines,
        zoomControlsEnabled: false,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        mapToolbarEnabled: false,
        padding: const EdgeInsets.only(top: 110, bottom: 250),
      ),
    );
  }

  // ────────────────────────────────────────────
  // 2. الشريط العلوي العائم
  // ────────────────────────────────────────────
  Widget _buildFloatingTopBar(MersalRequest request) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // زر الرجوع
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, color: _textMain, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              // شارة الحالة الحية للطلب
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _getStatusColor(request.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getStatusText(request.status),
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: _textMain,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // زر تتبع الكاميرا
              Container(
                decoration: BoxDecoration(
                  color: _isAutoTrackingEnabled ? _accent : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    _isAutoTrackingEnabled ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                    color: _isAutoTrackingEnabled ? Colors.white : _textMain,
                    size: 20,
                  ),
                  tooltip: 'تتبع حركتي',
                  onPressed: () {
                    setState(() => _isAutoTrackingEnabled = !_isAutoTrackingEnabled);
                    if (_isAutoTrackingEnabled && _driverLocation != null) {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(_driverLocation!, 16.5),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  // 3. أزرار التحكم بالملاحة والتمركز
  // ────────────────────────────────────────────
  Widget _buildFloatingMapControls(LatLng customerLatLng) {
    return Positioned(
      bottom: _isDetailsExpanded ? 440 : 290,
      left: 16,
      child: Column(
        children: [
          // زر إعادة ضبط المسار
          _buildMapActionButton(
            icon: Icons.alt_route_rounded,
            color: _textMain,
            tooltip: 'إعادة ضبط المسار',
            onTap: () {
              setState(() => _isAutoTrackingEnabled = false);
              _fitMapCameraToBounds();
            },
          ),
          const SizedBox(height: 10),
          // زر التمركز على موقع الزبون
          _buildMapActionButton(
            icon: Icons.person_pin_circle_rounded,
            color: _danger,
            tooltip: 'موقع الزبون',
            onTap: () {
              setState(() => _isAutoTrackingEnabled = false);
              _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(customerLatLng, 16.5),
              );
            },
          ),
          const SizedBox(height: 10),
          // زر فتح خرائط Google الخارجية
          _buildMapActionButton(
            icon: Icons.navigation_rounded,
            color: _accent,
            tooltip: 'الملاحة والتوجيه الصوتي',
            isPrimary: true,
            onTap: () => _launchMap(customerLatLng.latitude, customerLatLng.longitude),
          ),
        ],
      ),
    );
  }

  Widget _buildMapActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isPrimary ? _accent : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: isPrimary ? Colors.white : color, size: 22),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  // ────────────────────────────────────────────
  // 4. اللوحة السفلية التفاعلية للرحلة والتحكم المباشر
  // ────────────────────────────────────────────
  Widget _buildBottomTripPanel(MersalRequest request, LatLng customerLatLng, bool isPending) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _cardLight,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // مقبض السحب
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _borderLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // شريط الوقت الحي المتبقي والمسافة الديناميكية والأجرة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _isLoadingRoute
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
                                )
                              : const Icon(Icons.two_wheeler_rounded, color: _accent, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _durationMinutes != null ? '~ $_durationMinutes دقيقة للوصول' : 'حساب المسار...',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: _textMain,
                                fontWeight: FontWeight.w900,
                                fontSize: 14.5,
                              ),
                            ),
                            Text(
                              _distanceKm != null
                                  ? 'المسافة: ${_distanceKm!.toStringAsFixed(1)} كم • ${_driverSpeedKmh.toInt()} كم/س'
                                  : 'جاري التحديد...',
                              style: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (request.price != null && request.price!.isNotEmpty && request.price != '0')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFA5D6A7)),
                        ),
                        child: Text(
                          '${_currencyFormat.format(double.tryParse(request.price!) ?? 0)} د.ع',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: const Color(0xFF2E7D32),
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // بطاقة الزبون المباشرة
                _buildCustomerRow(request),
                const SizedBox(height: 12),

                // مسار الاستلام والتسليم
                _buildRouteOverview(request),
                const SizedBox(height: 14),

                // زر توسيع التفاصيل المتقدمة (البصمة الصوتية، المتجر، الملاحظات)
                InkWell(
                  onTap: () {
                    setState(() => _isDetailsExpanded = !_isDetailsExpanded);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, color: _accent, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'تفاصيل الطلب والمشتريات والبصمة',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: _textMain,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          _isDetailsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: _textSub,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_isDetailsExpanded) ...[
                  const SizedBox(height: 12),
                  _buildExpandedOrderDetails(request),
                ],

                const SizedBox(height: 16),

                // زر الإجراء والتقدم بالمرحلة الفوري (بدون صور) أو تحديد السعر
                if (isPending) _buildPendingAcceptSection(request) else _buildActiveStageActions(request),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerRow(MersalRequest request) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: _primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        request.userName.isNotEmpty ? request.userName : 'زبون مدار',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: _textMain,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded, color: _accent, size: 15),
                  ],
                ),
                Text(
                  request.userPhone.isNotEmpty ? request.userPhone : 'بدون رقم',
                  style: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 12),
                ),
              ],
            ),
          ),
          if (request.userPhone.isNotEmpty) ...[
            IconButton(
              onPressed: () => launchUrl(Uri.parse('tel:${request.userPhone}')),
              icon: const Icon(Icons.phone_in_talk_rounded, color: _success, size: 22),
              tooltip: 'اتصال',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFE8F5E9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: () => launchUrl(Uri.parse('https://wa.me/${request.userPhone}')),
              icon: const Icon(Icons.chat_bubble_rounded, color: _accent, size: 20),
              tooltip: 'واتساب',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFE0F2FE),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteOverview(MersalRequest request) {
    final store = request.storeName ?? 'نقطة الشراء / الأمانة';
    final dropoff = request.dropoffAddress.isNotEmpty ? request.dropoffAddress : 'موقع الزبون المحدد';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF00C853), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'من: $store',
                  style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontSize: 12.5, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                height: 12,
                width: 2,
                color: _borderLight,
              ),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Color(0xFFE53935), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'إلى: $dropoff',
                  style: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedOrderDetails(MersalRequest request) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'نص الطلب والمشتريات:',
            style: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 11.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            request.requestDescription.isNotEmpty ? request.requestDescription : 'بدون وصف نصي',
            style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
          ),
          if (request.voiceUrl != null && request.voiceUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInAppVoicePlayer(request.voiceUrl!),
          ],
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  // مشغل البصمة الصوتية الداخلي الخاص بتطبيق مدار
  // ────────────────────────────────────────────
  Widget _buildInAppVoicePlayer(String voiceUrl) {
    final isCurrent = _voiceController != null && _voiceController!.dataSource == voiceUrl;
    final isPlaying = isCurrent && _isPlayingVoice;
    final pos = isCurrent ? _voicePosition : Duration.zero;
    final dur = isCurrent ? _voiceDuration : Duration.zero;

    String formatDuration(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        children: [
          // زر التشغيل والإيقاف المباشر داخل مدار
          InkWell(
            onTap: () => _toggleInAppVoiceNote(voiceUrl),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF0284C7),
                shape: BoxShape.circle,
              ),
              child: _isVoiceInitializing
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'بصمة صوتية من الزبون',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: const Color(0xFF0369A1),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      dur.inSeconds > 0
                          ? '${formatDuration(pos)} / ${formatDuration(dur)}'
                          : 'صوت الزبون',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: const Color(0xFF0284C7),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // سلايدر التقدم المباشر
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: dur.inMilliseconds > 0
                        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                        : 0.0,
                    minHeight: 6,
                    backgroundColor: Colors.white,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  // 5. قسم تحديد وقبول السعر عند الانتظار
  // ────────────────────────────────────────────
  Widget _buildPendingAcceptSection(MersalRequest request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'حدد أجرة التوصيل المناسبة للبدء',
          style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.w900, fontSize: 14),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _quickPrices.map((val) {
              final isSelected = _priceController.text == val;
              final formatted = _currencyFormat.format(int.parse(val));
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Text('$formatted د.ع'),
                  selected: isSelected,
                  selectedColor: _accent,
                  labelStyle: GoogleFonts.ibmPlexSansArabic(
                    color: isSelected ? Colors.white : _textMain,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                  backgroundColor: const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (_) {
                    setState(() {
                      _priceController.text = val;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          style: GoogleFonts.ibmPlexSansArabic(color: _textMain, fontWeight: FontWeight.w900, fontSize: 15),
          decoration: InputDecoration(
            labelText: 'الأجرة المحددة',
            labelStyle: GoogleFonts.ibmPlexSansArabic(color: _textSub, fontSize: 12),
            suffixText: 'د.ع',
            suffixStyle: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, color: _accent),
            prefixIcon: const Icon(Icons.payments_rounded, color: _accent, size: 20),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _borderLight)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _borderLight)),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _acceptOrder,
            icon: const Icon(Icons.check_circle_rounded, size: 20),
            label: Text(
              'تأكيد وقبول الطلب والبدء',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────
  // 6. أزرار مراحل الطلب للرحلة النشطة (مباشر وبدون صور)
  // ────────────────────────────────────────────
  Widget _buildActiveStageActions(MersalRequest request) {
    final status = request.status;

    if (status == 'accepted') {
      return _buildLargeActionBtn(
        'وصلت لمكان الشراء / الاستلام',
        Icons.storefront_rounded,
        _warning,
        () => _updateStatus('arrived_at_pickup'),
      );
    }
    if (status == 'arrived_at_pickup') {
      return _buildLargeActionBtn(
        'تم استلام الأمانة / المشتريات',
        Icons.inventory_2_rounded,
        _accent,
        () => _updateStatus('picked_up'),
      );
    }
    if (status == 'picked_up') {
      return _buildLargeActionBtn(
        'متوجه للزبون حالياً',
        Icons.delivery_dining_rounded,
        const Color(0xFFEA580C),
        () => _updateStatus('on_the_way'),
      );
    }
    if (status == 'on_the_way') {
      return _buildLargeActionBtn(
        'تأكيد تسليم الطلب للزبون بنجاح',
        Icons.done_all_rounded,
        _success,
        () => _updateStatus('delivered'),
      );
    }
    if (status == 'delivered' || status == 'completed') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_rounded, color: _success, size: 22),
            const SizedBox(width: 8),
            Text(
              'تم تسليم الطلب بنجاح',
              style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFF2E7D32), fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildLargeActionBtn(String text, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        label: Text(text, style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w900, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 2,
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'بانتظار الموافقة';
      case 'accepted':
        return 'مقبول (توجه للمحل)';
      case 'arrived_at_pickup':
        return 'وصلت للمحل';
      case 'picked_up':
        return 'تم استلام الأمانة';
      case 'on_the_way':
        return 'بالطريق للزبون';
      case 'delivered':
      case 'completed':
        return 'تم التسليم بنجاح';
      default:
        return 'قيد التوصيل';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return _warning;
      case 'accepted':
      case 'arrived_at_pickup':
      case 'picked_up':
      case 'on_the_way':
        return _accent;
      case 'delivered':
      case 'completed':
        return _success;
      default:
        return _primary;
    }
  }

  Future<void> _launchMap(double lat, double lng) async {
    final url = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
