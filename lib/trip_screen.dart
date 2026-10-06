import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dalal_alqaim/features/trip/data/datasources/google_directions_datasource.dart';
import 'package:dalal_alqaim/features/trip/data/datasources/trip_remote_datasource.dart';
import 'package:dalal_alqaim/features/trip/data/repositories/trip_repository_impl.dart';
import 'package:dalal_alqaim/features/trip/presentation/controller/trip_controller.dart';
import 'package:dalal_alqaim/features/trip/presentation/controller/trip_ui_state.dart';
import 'package:dalal_alqaim/features/trip/presentation/widgets/live_map_view.dart';
import 'package:dalal_alqaim/features/trip/presentation/widgets/trip_components.dart';
import 'package:dalal_alqaim/features/trip/presentation/widgets/offline_handler.dart';
import 'package:dalal_alqaim/features/trip/domain/entities/trip.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/ride_tracking_page.dart';
import 'package:dalal_alqaim/services/driver_service.dart';
import 'package:dalal_alqaim/services/rating_service.dart';
import 'package:dalal_alqaim/models/rating_model.dart';

class TripScreen extends StatelessWidget {
  final String rideId;

  const TripScreen({super.key, required this.rideId});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
      ),
    );

    return ChangeNotifierProvider(
      create: (_) => TripController(
        repository: TripRepositoryImpl(TripRemoteDataSource(), GoogleDirectionsDataSource()),
        tripId: rideId,
      ),
      child: const _TripBody(),
    );
  }
}

class _TripBody extends StatefulWidget {
  const _TripBody();

  @override
  State<_TripBody> createState() => _TripBodyState();
}

class _TripBodyState extends State<_TripBody> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final ConnectivityService _connectivity = ConnectivityService();
  TripController? _controller;
  bool _didNavigateToTracking = false;
  double _bottomSheetHeight = 280;

  // Extra In-Ride State
  String? _appliedPromoCode;
  int _discountPercentage = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = Provider.of<TripController>(context);
    if (_controller != newController) {
      _controller?.removeListener(_onControllerUpdate);
      _controller = newController;
      _controller?.addListener(_onControllerUpdate);
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final state = _controller?.state;

    // Transition automatically to RideTrackingPage once captain accepts
    if (state != null &&
        state.status == TripViewStatus.active &&
        state.trip?.driverId != null &&
        !_didNavigateToTracking) {
      _didNavigateToTracking = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RideTrackingPage(
                driverId: state.trip!.driverId!,
                requestId: _controller!.tripId,
              ),
            ),
          );
        }
      });
      return;
    }

    if (state != null &&
        state.status == TripViewStatus.active &&
        state.autoFollowEnabled &&
        state.driverLocation != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLng(state.driverLocation!));
    }
  }

  void _recenterMap() {
    final state = _controller?.state;
    if (state?.driverLocation != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(state!.driverLocation!, 16.0));
      _controller?.enableAutoFollow();
    } else if (state?.userLocation != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(state!.userLocation!, 16.0));
    }
  }

  void _fitRouteBounds() {
    final state = _controller?.state;
    if (state?.routePoints != null && state!.routePoints.isNotEmpty && _mapController != null) {
      double minLat = state.routePoints.first.latitude;
      double maxLat = state.routePoints.first.latitude;
      double minLng = state.routePoints.first.longitude;
      double maxLng = state.routePoints.first.longitude;

      for (var p in state.routePoints) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          65.0,
        ),
      );
    }
  }

  void _shareLiveTrip(Trip trip) {
    final pin = _getRidePin(_controller?.tripId ?? '0000');
    final text = 'أنا الآن في رحلة مع كابتن مدار!\n'
        'الكابتن: ${trip.driverName ?? "كابتن مدار"}\n'
        'السيارة: ${trip.driverCar ?? "تكسي مدار"} (${trip.driverCarNumber ?? ""})\n'
        'رمز أمان الرحلة: $pin \n'
        'تابع مسار رحلتي بأمان عبر تطبيق مدار';
    Share.share(text);
  }

  void _callEmergency() {
    launchUrl(Uri.parse('tel:104'));
  }

  String _getRidePin(String id) {
    if (id.isEmpty) return '5841';
    final hash = id.hashCode.abs();
    final pin = (1000 + (hash % 9000)).toString();
    return pin;
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _connectivity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TripController>();
    final state = controller.state;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      double newHeight = 310;
      if (state.status == TripViewStatus.searching) newHeight = 320;
      if (state.status == TripViewStatus.active) newHeight = 390;
      if (state.status == TripViewStatus.completed) newHeight = 330;
      if (state.status == TripViewStatus.cancelled) newHeight = 290;
      if (_bottomSheetHeight != newHeight && mounted) {
        setState(() => _bottomSheetHeight = newHeight);
      }
    });

    return StreamBuilder<bool>(
      stream: _connectivity.isOfflineStream,
      initialData: false,
      builder: (context, snapshot) {
        final isOffline = snapshot.data ?? false;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F8FA),
          extendBodyBehindAppBar: true,
          extendBody: true,
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: Stack(
              children: [
                // 1. الخريطة المباشرة 2D مع رسم المسار التلقائي والدبابيس بشعار مدار
                Positioned.fill(
                  bottom: _bottomSheetHeight * 0.32,
                  child: LiveMapView(
                    onMapCreated: (mapController) => _mapController = mapController,
                    onShowChat: () => _showChatSheet(context, controller.tripId),
                  ),
                ),

                // 2. الشريط العلوي العائم الزجاجي
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // زر الرجوع الزجاجي
                        _buildGlassCircleButton(
                          icon: Icons.arrow_forward_ios_rounded,
                          onTap: () => Navigator.pop(context),
                        ),

                        // شارة هوية تكسي مدار
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF07191A).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF00BFA5).withValues(alpha: 0.5), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.local_taxi_rounded, color: Color(0xFF00BFA5), size: 18),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'تكسي مَــدار',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // زر عرض المسار بالكامل
                        _buildGlassCircleButton(
                          icon: Icons.alt_route_rounded,
                          onTap: _fitRouteBounds,
                        ),
                      ],
                    ),
                  ),
                ),

                // تنبيه انقطاع الإنترنت
                if (isOffline)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 60,
                    left: 16,
                    right: 16,
                    child: const OfflineBanner(isOffline: true),
                  ),

                // 3. أزرار التحكم الجانبية السريعة (تمركز + أمان + مشاركة)
                Positioned(
                  left: 16,
                  bottom: _bottomSheetHeight + 14,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.trip != null) ...[
                        // زر مشاركة مسار الرحلة
                        _buildFloatingActionButton(
                          icon: Icons.share_location_rounded,
                          color: const Color(0xFF00BFA5),
                          tooltip: 'مشاركة مسار الرحلة',
                          onTap: () => _shareLiveTrip(state.trip!),
                        ),
                        const SizedBox(height: 10),
                        // زر الطوارئ
                        _buildFloatingActionButton(
                          icon: Icons.shield_rounded,
                          color: const Color(0xFFFF5252),
                          tooltip: 'طوارئ وأمان',
                          onTap: _callEmergency,
                        ),
                        const SizedBox(height: 10),
                      ],
                      // زر إعادة التمركز
                      _buildFloatingActionButton(
                        icon: Icons.my_location_rounded,
                        color: Colors.white,
                        iconColor: const Color(0xFF004D40),
                        tooltip: 'موقعي الحالي',
                        onTap: _recenterMap,
                      ),
                    ],
                  ),
                ),

                // 4. اللوحة السفلية العصرية التفاعلية
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildBottomPanel(state, controller),
                ),

                // 5. تراكب التحميل الأولي
                if (state.status == TripViewStatus.loading)
                  Container(
                    color: Colors.black38,
                    child: const Center(
                      child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassCircleButton({required IconData icon, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 18),
            onPressed: onTap,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton({
    required IconData icon,
    required Color color,
    Color iconColor = Colors.white,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }

  Widget _buildBottomPanel(TripUiState state, TripController controller) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            Flexible(
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildPanelContent(state, controller),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelContent(TripUiState state, TripController controller) {
    switch (state.status) {
      case TripViewStatus.loading:
        return const SizedBox(
          height: 140,
          child: Center(child: CircularProgressIndicator(color: Color(0xFF00BFA5))),
        );

      case TripViewStatus.searching:
        return _buildSearchingContent(state, controller);

      case TripViewStatus.active:
        return _buildActiveTripContent(state, controller);

      case TripViewStatus.completed:
        return _buildCompletedContent(state, controller);

      case TripViewStatus.cancelled:
        return _buildCancelledContent(context);

      case TripViewStatus.error:
        return _buildErrorContent(state);
    }
  }

  // ── 1. حالة البحث عن كابتن ──
  Widget _buildSearchingContent(TripUiState state, TripController controller) {
    final ridePin = _getRidePin(controller.tripId);

    return Container(
      key: const ValueKey('searching'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // شريط الخطوات والمراحل
          _buildTripStepper(0),

          const SizedBox(height: 14),

          // صف البحث النبضي مع رمز أمان الرحلة
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.85, end: 1.2),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeInOut,
                    builder: (context, val, child) {
                      return Container(
                        width: 48 * val,
                        height: 48 * val,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00BFA5).withValues(alpha: 0.2 * (1.25 - val)),
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00BFA5), Color(0xFF004D40)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00BFA5).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.radar_rounded, color: Colors.white, size: 22),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'جاي نحدد المسار وندورلك كابتن...',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'تم رسم المسار المباشر، جاري ربط أقرب سيارة',
                      style: TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // رمز أمان الرحلة (Ride PIN OTP)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade400, width: 1),
                ),
                child: Column(
                  children: [
                    const Text('رمز الرحلة', style: TextStyle(fontSize: 9.5, color: Colors.brown, fontWeight: FontWeight.bold)),
                    Text(ridePin, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.brown)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // كبسولات معلومات المسار الحية (مسافة + وقت + سعر)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoCapsule(
                  icon: Icons.route_rounded,
                  label: 'المسافة',
                  value: state.distanceText ?? '${state.trip?.distance.toStringAsFixed(1) ?? "--"} كم',
                  color: const Color(0xFF00BFA5),
                ),
                Container(width: 1, height: 28, color: Colors.grey.shade300),
                _buildInfoCapsule(
                  icon: Icons.timer_outlined,
                  label: 'الوقت التقديري',
                  value: state.etaMinutes != null ? '${state.etaMinutes} دقيقة' : 'تقريباً 5 د',
                  color: Colors.amber.shade800,
                ),
                Container(width: 1, height: 28, color: Colors.grey.shade300),
                _buildInfoCapsule(
                  icon: Icons.payments_rounded,
                  label: 'الأجرة',
                  value: _getEffectivePrice(state.trip?.price),
                  color: const Color(0xFF004D40),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // صف الدفع وكوبون الخصم
          Row(
            children: [
              // شارة الدفع نقداً (كاش)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.payments_rounded,
                        color: Color(0xFF16A34A),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'الدفع نقداً (كاش)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // زر كود الخصم
              InkWell(
                onTap: _showPromoCodeDialog,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _appliedPromoCode != null ? Colors.amber.shade50 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _appliedPromoCode != null ? Colors.amber : Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_offer_rounded, size: 15, color: _appliedPromoCode != null ? Colors.amber.shade900 : Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Text(
                        _appliedPromoCode != null ? 'خصم $_discountPercentage%' : 'كود خصم',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _appliedPromoCode != null ? Colors.amber.shade900 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // زر إلغاء الطلب
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: () => _showCancelReasonSheet(context, controller),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('إلغاء البحث عن كابتن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE53935),
                side: BorderSide(color: const Color(0xFFEF5350).withValues(alpha: 0.3)),
                backgroundColor: const Color(0xFFFFF0F0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. حالة المشوار النشط (Active Trip Content) ──
  Widget _buildActiveTripContent(TripUiState state, TripController controller) {
    if (state.trip == null) return const SizedBox.shrink();
    final trip = state.trip!;
    final driverName = trip.driverName ?? 'كابتن مدار';
    final driverPhone = trip.driverPhone ?? '';
    final carInfo = trip.driverCar ?? 'تكسي مدار';
    final plateNumber = trip.driverCarNumber ?? '';
    final ridePin = _getRidePin(controller.tripId);

    int currentStep = 1;
    if (trip.status == TripStatus.arrived) currentStep = 2;
    if (trip.status == TripStatus.started) currentStep = 3;

    return Container(
      key: const ValueKey('active'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // شريط الخطوات والمراحل
          _buildTripStepper(currentStep),

          const SizedBox(height: 12),

          // بطاقة الكابتن الفخمة مع رمز الرحلة
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                // صورة الكابتن
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: const Color(0xFF00BFA5).withValues(alpha: 0.15),
                      child: const Icon(Icons.person_rounded, color: Color(0xFF004D40), size: 28),
                    ),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ],
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
                              driverName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, color: Colors.amber.shade900, size: 12),
                                const SizedBox(width: 2),
                                Text(
                                  '${trip.driverRating ?? 5.0}',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        carInfo + (plateNumber.isNotEmpty ? ' • $plateNumber' : ''),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                // أزرار التواصل المباشر (اتصال + شات)
                if (driverPhone.isNotEmpty)
                  _buildCircleActionIcon(
                    icon: Icons.phone_rounded,
                    color: const Color(0xFF00897B),
                    onTap: () => launchUrl(Uri.parse('tel:$driverPhone')),
                  ),
                const SizedBox(width: 6),
                _buildCircleActionIcon(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: const Color(0xFF00BFA5),
                  onTap: () => _showChatSheet(context, controller.tripId),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ملخص الرحلة والأجرة ورمز التحقق
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF004D40),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.navigation_rounded, color: Colors.tealAccent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _getStatusText(trip.status),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'رمز الرحلة: $ridePin',
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getEffectivePrice(trip.price),
                      style: const TextStyle(color: Colors.tealAccent, fontSize: 13.5, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. حالة اكتمال الرحلة (Completed Content مع الفاتورة الرقمية) ──
  Widget _buildCompletedContent(TripUiState state, TripController controller) {
    if (!state.ratingShown) {
      controller.markRatingShown();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRatingDialog(context, controller);
      });
    }

    return Container(
      key: const ValueKey('completed'),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00BFA5).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00BFA5), size: 36),
          ),
          const SizedBox(height: 8),
          const Text(
            'وصلت بالسلامة عيوني!',
            style: TextStyle(
              fontSize: 17.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'نتمنى لك رحلة مريحة وسعيدة ويا تكسي مدار',
            style: TextStyle(color: Color(0xFF757575), fontSize: 11.5),
          ),
          const SizedBox(height: 14),

          // زر الفاتورة الرقمية
          OutlinedButton.icon(
            onPressed: () => _showDigitalReceiptDialog(state.trip),
            icon: const Icon(Icons.receipt_long_rounded, size: 16),
            label: const Text('عرض ومشاركة الفاتورة الرقمية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00796B),
              side: const BorderSide(color: Color(0xFF00BFA5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('العودة للرئيسية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. حالة إلغاء الرحلة ──
  Widget _buildCancelledContent(BuildContext context) {
    return Container(
      key: const ValueKey('cancelled'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F0),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFEF5350).withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.close_rounded, color: Color(0xFFEF5350), size: 26),
          ),
          const SizedBox(height: 10),
          const Text(
            'تم إلغاء الرحلة',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 4),
          Text(
            'تكدر تطلب رحلة جديدة بأي وقت يعجبك عيوني',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF37474F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
              child: const Text('العودة للرئيسية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. حالة الخطأ ──
  Widget _buildErrorContent(TripUiState state) {
    return Padding(
      key: const ValueKey('error'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
          const SizedBox(height: 8),
          const Text('عذراً، صار خطأ، حاول مرة ثانية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
          const SizedBox(height: 4),
          Text(
            state.errorMessage ?? 'يرجى التحقق من اتصال الإنترنت والمحاولة ثانية',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── شريط مراحل وخطوات الرحلة ──
  Widget _buildTripStepper(int currentStep) {
    final steps = ['البحث', 'القبول', 'الوصول', 'انطلاق'];
    return Row(
      children: List.generate(steps.length, (index) {
        final isCompleted = index <= currentStep;
        final isCurrent = index == currentStep;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: isCompleted ? const Color(0xFF00BFA5) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[index],
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCompleted ? const Color(0xFF004D40) : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < steps.length - 1) const SizedBox(width: 4),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildInfoCapsule({required IconData icon, required String label, required String value, required Color color}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _buildCircleActionIcon({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  String _getStatusText(TripStatus? status) {
    switch (status) {
      case TripStatus.arrived:
        return 'الكابتن وصل يمك';
      case TripStatus.started:
        return 'طايرين للوجهة بالسلامة';
      case TripStatus.accepted:
        return 'الكابتن بالطريق إلك';
      default:
        return 'الرحلة ماشية تمام';
    }
  }

  String _getEffectivePrice(String? rawPrice) {
    if (rawPrice == null) return '-- د.ع';
    final numVal = double.tryParse(rawPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    if (_discountPercentage > 0 && numVal > 0) {
      final discounted = numVal * (1 - (_discountPercentage / 100));
      return '${discounted.toStringAsFixed(0)} د.ع';
    }
    return '$rawPrice د.ع';
  }

  void _showPromoCodeDialog() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.local_offer_rounded, color: Color(0xFF00BFA5)),
              SizedBox(width: 8),
              Text('إضافة كود خصم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('أدخل كود الخصم أو القسيمة للحصول على تخفيض فوري:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'مثال: MADAR20',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), foregroundColor: Colors.white),
              onPressed: () {
                final code = codeCtrl.text.trim().toUpperCase();
                if (code.isNotEmpty) {
                  setState(() {
                    _appliedPromoCode = code;
                    _discountPercentage = 15; // 15% discount for promo
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('عاشت إيدك! تم تطبيق خصم $_discountPercentage% بنجاح', style: const TextStyle()),
                      backgroundColor: const Color(0xFF00BFA5),
                    ),
                  );
                }
              },
              child: const Text('تطبيق الكود', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDigitalReceiptDialog(Trip? trip) {
    if (trip == null) return;
    final pin = _getRidePin(_controller?.tripId ?? '0000');
    final price = _getEffectivePrice(trip.price);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('فاتورة مشوار مدار', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                _buildReceiptRow('الكابتن', trip.driverName ?? 'كابتن مدار'),
                _buildReceiptRow('السيارة', '${trip.driverCar ?? "تكسي مدار"} (${trip.driverCarNumber ?? ""})'),
                _buildReceiptRow('المسافة المقطوعة', '${trip.distance.toStringAsFixed(1)} كم'),
                _buildReceiptRow('طريقة الدفع', 'نقداً (كاش)'),
                _buildReceiptRow('رمز أمان المشوار', pin),
                if (_discountPercentage > 0)
                  _buildReceiptRow('الخصم المطبق', '$_discountPercentage% ($_appliedPromoCode)'),
                const Divider(),
                _buildReceiptRow('المبلغ الإجمالي', price, isTotal: true),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), foregroundColor: Colors.white),
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('مشاركة الفاتورة عبر واتساب', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final receiptText = 'فاتورة رحلة مدار:\n'
                          'الكابتن: ${trip.driverName}\n'
                          'المسافة: ${trip.distance.toStringAsFixed(1)} كم\n'
                          'الأجرة: $price\n'
                          'طريقة الدفع: نقداً (كاش)\n'
                          'شكراً لاختيارك تكسي مدار';
                      Share.share(receiptText);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isTotal ? 14 : 12, color: isTotal ? Colors.black87 : Colors.grey.shade700, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: isTotal ? 16 : 12, color: isTotal ? const Color(0xFF004D40) : Colors.black87, fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold)),
        ],
      ),
    );
  }

  void _showCancelReasonSheet(BuildContext context, TripController controller) {
    final reasons = [
      {'icon': Icons.timer_off_rounded, 'text': 'الكابتن بعيد هواية', 'color': const Color(0xFFFF9800)},
      {'icon': Icons.swap_horiz_rounded, 'text': 'غيرت رأيي', 'color': const Color(0xFF9C27B0)},
      {'icon': Icons.wrong_location_rounded, 'text': 'غيرت المسار', 'color': const Color(0xFFE91E63)},
      {'icon': Icons.local_taxi_rounded, 'text': 'لكيت سيارة ثانية', 'color': const Color(0xFF2196F3)},
      {'icon': Icons.monetization_on_rounded, 'text': 'السعر غير مناسب', 'color': const Color(0xFF4CAF50)},
      {'icon': Icons.more_horiz_rounded, 'text': 'سبب ثاني', 'color': const Color(0xFF607D8B)},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text(
                'ليش تريد تلغي الطلب؟',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 4),
              const Text(
                'اختر سبب الإلغاء لمساعدتنا في تحسين الخدمة',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF757575)),
              ),
              const SizedBox(height: 16),
              ...reasons.map((reason) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.pop(ctx);
                    controller.cancelTrip(reason: reason['text'] as String);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (reason['color'] as Color).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(reason['icon'] as IconData, size: 18, color: reason['color'] as Color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            reason['text'] as String,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14),
                      ],
                    ),
                  ),
                ),
              )),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('الاحتفاظ بالطلب والرجوع', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChatSheet(BuildContext context, String rideId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CloseButton(),
                    const Expanded(
                      child: Text(
                        'محادثة مباشرة مع الكابتن',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: ChatSheet(tripId: rideId)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRatingDialog(BuildContext context, TripController controller) async {
    double stars = 5;
    final List<String> selectedCompliments = [];
    final List<String> selectedIssues = [];
    final commentController = TextEditingController();
    bool isSubmitting = false;

    final trip = controller.state.trip;
    final driverName = trip?.driverName ?? 'كابتن مدار';
    final driverId = trip?.driverId ?? '';
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final currentUserName = FirebaseAuth.instance.currentUser?.displayName ?? 'راكب مدار';

    final List<String> positiveTags = [
      'قيادة آمنة ومريحة',
      'سيارة نظيفة ومرتبة',
      'التزام دقيق بالمواعيد',
      'تعامل راقي ومحترم',
      'معرفة ممتازة بالطرق',
      'تكييف ممتاز ومريح',
    ];

    final List<String> negativeTags = [
      'سرعة زائدة / قيادة متهورة',
      'تدخين داخل السيارة',
      'تأخر في الوصول للموقع',
      'اتخاذ مسار أطول',
      'خلاف في الحساب أو الأجرة',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          String moodText = 'رحلة ممتازة ومثالية!';
          Color moodColor = const Color(0xFF10B981);
          if (stars == 1) {
            moodText = 'تجربة سيئة جداً وغير مرضية';
            moodColor = Colors.redAccent;
          } else if (stars == 2) {
            moodText = 'تجربة تحتاج لتحسين';
            moodColor = Colors.deepOrangeAccent;
          } else if (stars == 3) {
            moodText = 'تجربة مقبولة ومتوسطة';
            moodColor = Colors.amber.shade800;
          } else if (stars == 4) {
            moodText = 'رحلة جيدة جداً ومريحة';
            moodColor = const Color(0xFF00BFA5);
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 14),
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFF00BFA5).withValues(alpha: 0.15),
                      child: const Icon(Icons.local_taxi_rounded, color: Color(0xFF004D40), size: 28),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'شلون كانت تجربتك ويا $driverName؟',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'رأيك الصادق يساعدنا في الحفاظ على جودة وأمان الرحلات',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Interactive Star Ratings
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => stars = index + 1.0);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5.0),
                            child: AnimatedScale(
                              scale: index < stars ? 1.2 : 1.0,
                              duration: const Duration(milliseconds: 180),
                              child: Icon(
                                index < stars ? Icons.star_rounded : Icons.star_border_rounded,
                                color: Colors.amber,
                                size: 38,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: moodColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        moodText,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: moodColor),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tags
                    if (stars >= 4) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'شنو أكثر شي عجبك بالمشوار؟',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade800),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: positiveTags.map((tag) {
                          final isSelected = selectedCompliments.contains(tag);
                          return FilterChip(
                            label: Text(tag),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF00BFA5),
                            backgroundColor: Colors.grey.shade100,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  selectedCompliments.add(tag);
                                } else {
                                  selectedCompliments.remove(tag);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'شنو جانت المشكلة ويا الكابتن؟',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.redAccent.shade700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: negativeTags.map((tag) {
                          final isSelected = selectedIssues.contains(tag);
                          return FilterChip(
                            label: Text(tag),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                            selected: isSelected,
                            selectedColor: Colors.redAccent,
                            backgroundColor: Colors.grey.shade100,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  selectedIssues.add(tag);
                                } else {
                                  selectedIssues.remove(tag);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 14),

                    TextField(
                      controller: commentController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'أضف ملاحظة أو تعليق إضافي (اختياري)...',
                        hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BFA5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setState(() => isSubmitting = true);
                                try {
                                  if (driverId.isNotEmpty) {
                                    await DriverService().submitPassengerReviewForDriver(
                                      rideId: controller.tripId,
                                      driverId: driverId,
                                      passengerId: currentUserId,
                                      passengerName: currentUserName,
                                      rating: stars,
                                      compliments: selectedCompliments,
                                      issues: selectedIssues,
                                      comment: commentController.text.trim(),
                                      driverName: driverName,
                                    );

                                    await RatingService.submitRating(
                                      targetId: driverId,
                                      targetType: RatingTargetType.captain,
                                      targetName: driverName,
                                      authorId: currentUserId,
                                      authorName: currentUserName,
                                      authorRole: 'customer',
                                      referenceId: controller.tripId,
                                      rating: stars,
                                      tags: [...selectedCompliments, ...selectedIssues],
                                      comment: commentController.text.trim(),
                                    );
                                  }
                                  await controller.submitRating(stars);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('عاشت إيدك! تم حفظ تقييمك بنجاح', style: TextStyle()),
                                        backgroundColor: Color(0xFF00BFA5),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('Error submitting rating: $e');
                                  if (ctx.mounted) Navigator.pop(ctx);
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text(
                                'إرسال التقييم',
                                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
