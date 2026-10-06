import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:dalal_alqaim/features/taxi/presentation/pages/ride_tracking_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/ride_chat_screen.dart';
import 'package:dalal_alqaim/trip_screen.dart';
import 'package:dalal_alqaim/pages/my_orders_page.dart';

/// ══════════════════════════════════════════════════════════════════════════════
/// Madar Next-Gen Dynamic Island (iOS 18 + Live Activity & Notification Hub)
/// ══════════════════════════════════════════════════════════════════════════════
class MadarDynamicIslandOverlay extends StatefulWidget {
  const MadarDynamicIslandOverlay({super.key});

  /// Static Helper to trigger immediate in-app Island Notification
  static void showIslandNotification(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.notifications_active_rounded,
    Color color = const Color(0xFF00BFA5),
  }) {
    _islandNotificationNotifier.value = _IslandAlert(
      title: title,
      message: message,
      icon: icon,
      color: color,
      timestamp: DateTime.now(),
    );
  }

  @override
  State<MadarDynamicIslandOverlay> createState() => _MadarDynamicIslandOverlayState();
}

class _IslandAlert {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final DateTime timestamp;

  _IslandAlert({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.timestamp,
  });
}

final ValueNotifier<_IslandAlert?> _islandNotificationNotifier = ValueNotifier<_IslandAlert?>(null);

class _MadarDynamicIslandOverlayState extends State<MadarDynamicIslandOverlay>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  late final AnimationController _radarRotateController;
  Timer? _alertDismissTimer;
  _IslandAlert? _currentAlert;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _radarRotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _islandNotificationNotifier.addListener(_onNewAlert);
  }

  void _onNewAlert() {
    final alert = _islandNotificationNotifier.value;
    if (alert != null && mounted) {
      HapticFeedback.heavyImpact();
      setState(() {
        _currentAlert = alert;
        _isExpanded = true;
      });

      _alertDismissTimer?.cancel();
      _alertDismissTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _currentAlert = null;
            _isExpanded = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _radarRotateController.dispose();
    _alertDismissTimer?.cancel();
    _islandNotificationNotifier.removeListener(_onNewAlert);
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (e) {
      debugPrint('Error launching phone call: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    // 0. If there's an active in-app Island Alert
    if (_currentAlert != null) {
      return _buildAlertIsland();
    }

    // 1. Listen to active Taxi Ride Requests
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ride_requests')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, taxiSnap) {
        final taxiDocs = taxiSnap.data?.docs ?? [];
        QueryDocumentSnapshot? activeTaxiDoc;

        for (var doc in taxiDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString().toLowerCase();
          if (status == 'pending' ||
              status == 'accepted' ||
              status == 'driver_assigned' ||
              status == 'arrived' ||
              status == 'in_progress' ||
              status == 'picked_up' ||
              status == 'on_way') {
            activeTaxiDoc = doc;
            break;
          }
        }

        if (activeTaxiDoc != null) {
          final data = activeTaxiDoc.data() as Map<String, dynamic>;
          return _buildIslandContainer(
            isTaxi: true,
            docId: activeTaxiDoc.id,
            data: data,
          );
        }

        // 2. If no active taxi, listen to active food/store/delivery orders
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('userId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, orderSnap) {
            final orderDocs = orderSnap.data?.docs ?? [];
            QueryDocumentSnapshot? activeOrderDoc;

            for (var doc in orderDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final status = (data['status'] ?? '').toString().toLowerCase();
              if (status == 'pending' ||
                  status == 'preparing' ||
                  status == 'cooking' ||
                  status == 'ready' ||
                  status == 'on_way' ||
                  status == 'out_for_delivery' ||
                  status == 'picked_up' ||
                  status == 'assigned' ||
                  status == 'accepted') {
                activeOrderDoc = doc;
                break;
              }
            }

            if (activeOrderDoc != null) {
              final data = activeOrderDoc.data() as Map<String, dynamic>;
              return _buildIslandContainer(
                isTaxi: false,
                docId: activeOrderDoc.id,
                data: data,
              );
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  // ─── Alert / Notification Banner Island ───
  Widget _buildAlertIsland() {
    final topPadding = MediaQuery.of(context).padding.top;
    final alert = _currentAlert!;

    return Positioned(
      top: topPadding > 0 ? (topPadding + 2.h) : 8.h,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          width: MediaQuery.of(context).size.width - 24.w,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D10),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: alert.color.withValues(alpha: 0.6), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: alert.color.withValues(alpha: 0.3),
                blurRadius: 14,
              ),
            ],
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: alert.color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: alert.color, width: 1),
                  ),
                  child: Icon(alert.icon, color: alert.color, size: 20.sp),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        alert.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white70,
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _currentAlert = null;
                      _isExpanded = false;
                    });
                  },
                  icon: Icon(Icons.close_rounded, color: Colors.white60, size: 18.sp),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Main Island Container (Taxi & Delivery Activities) ───
  Widget _buildIslandContainer({
    required bool isTaxi,
    required String docId,
    required Map<String, dynamic> data,
  }) {
    final topPadding = MediaQuery.of(context).padding.top;
    final status = (data['status'] ?? 'pending').toString().toLowerCase();

    // Data extraction
    final isPending = status == 'pending';
    final title = isTaxi
        ? (isPending
            ? 'جاري البحث عن كابتن تكسي...'
            : (data['driverName'] ?? data['captainName'] ?? 'كابتن تكسي مدار').toString())
        : (data['restaurantName'] ?? data['storeName'] ?? 'طلب مدار').toString();
    final driverPhone = (data['driverPhone'] ?? data['phone'] ?? '').toString();
    final driverId = (data['driverId'] ?? '').toString();
    final carModel = (data['carModel'] ?? data['carType'] ?? 'سيارة تكسي مدار').toString();
    final carColor = (data['carColor'] ?? '').toString();
    final carPlate = (data['carPlate'] ?? data['plateNumber'] ?? '').toString();

    String statusText;
    String etaText;
    Color accentColor;
    IconData leadingIcon;

    if (isTaxi) {
      accentColor = const Color(0xFFF59E0B);
      leadingIcon = Icons.local_taxi_rounded;
      switch (status) {
        case 'accepted':
        case 'driver_assigned':
          statusText = 'الكابتن قادم لموقعك';
          etaText = '٥ د';
          break;
        case 'arrived':
          statusText = 'الكابتن بانتظارك بالخارج';
          etaText = 'وصل';
          break;
        case 'in_progress':
        case 'picked_up':
        case 'on_way':
          statusText = 'الرحلة جارية للوجهة';
          etaText = 'مباشر';
          break;
        default:
          statusText = 'نبحث عن أقرب كابتن لك...';
          etaText = 'بحث';
      }
    } else {
      accentColor = app_colors.primaryColor;
      leadingIcon = Icons.delivery_dining_rounded;
      switch (status) {
        case 'preparing':
        case 'cooking':
        case 'accepted':
          statusText = 'قيد التجهيز بالمطعم';
          etaText = 'تجهيز';
          break;
        case 'ready':
        case 'assigned':
          statusText = 'بانتظار استلام المندوب';
          etaText = 'جاهز';
          break;
        case 'on_way':
        case 'out_for_delivery':
        case 'picked_up':
          statusText = 'المندوب في الطريق إليك';
          etaText = 'قريب';
          break;
        default:
          statusText = 'تم استلام الطلب';
          etaText = 'معالجة';
      }
    }

    return Positioned(
      top: topPadding > 0 ? (topPadding + 2.h) : 8.h,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: _isExpanded ? (MediaQuery.of(context).size.width - 24.w) : 220.w,
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            borderRadius: BorderRadius.circular(_isExpanded ? 24.r : 28.r),
            border: Border.all(
              color: accentColor.withValues(alpha: _isExpanded ? 0.65 : 0.4),
              width: _isExpanded ? 1.4 : 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.75),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: accentColor.withValues(alpha: 0.25),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isExpanded = !_isExpanded);
              },
              borderRadius: BorderRadius.circular(_isExpanded ? 24.r : 28.r),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _isExpanded ? 14.w : 10.w,
                  vertical: _isExpanded ? 12.h : 6.h,
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: _isExpanded
                      ? _buildExpandedContent(
                          isTaxi: isTaxi,
                          isPending: isPending,
                          docId: docId,
                          driverId: driverId,
                          title: title,
                          statusText: statusText,
                          etaText: etaText,
                          driverPhone: driverPhone,
                          carModel: carModel,
                          carColor: carColor,
                          carPlate: carPlate,
                          accentColor: accentColor,
                          leadingIcon: leadingIcon,
                        )
                      : _buildCompactContent(
                          isPending: isPending,
                          title: title,
                          etaText: etaText,
                          accentColor: accentColor,
                          leadingIcon: leadingIcon,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── 1. Compact Island (Pill State) ───
  Widget _buildCompactContent({
    required bool isPending,
    required String title,
    required String etaText,
    required Color accentColor,
    required IconData leadingIcon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Right Side: Leading Icon / Radar
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPending)
              RotationTransition(
                turns: _radarRotateController,
                child: Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withValues(alpha: 0.25),
                  ),
                  child: Icon(Icons.radar_rounded, color: accentColor, size: 14.sp),
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.25),
                ),
                child: Icon(leadingIcon, color: accentColor, size: 14.sp),
              ),
            SizedBox(width: 6.w),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 85.w),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        // Left Side: Live Pulse Dot + ETA
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 6.r,
                  height: 6.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.8),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 5.w),
            Text(
              etaText,
              style: GoogleFonts.ibmPlexSansArabic(
                color: accentColor,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── 2. Expanded Island Card ───
  Widget _buildExpandedContent({
    required bool isTaxi,
    required bool isPending,
    required String docId,
    required String driverId,
    required String title,
    required String statusText,
    required String etaText,
    required String driverPhone,
    required String carModel,
    required String carColor,
    required String carPlate,
    required Color accentColor,
    required IconData leadingIcon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header
        Row(
          children: [
            if (isPending)
              RotationTransition(
                turns: _radarRotateController,
                child: Container(
                  padding: EdgeInsets.all(7.r),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withValues(alpha: 0.2),
                    border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.2),
                  ),
                  child: Icon(Icons.radar_rounded, color: accentColor, size: 18.sp),
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(7.r),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.2),
                  border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.2),
                ),
                child: Icon(leadingIcon, color: accentColor, size: 18.sp),
              ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!isPending) ...[
                        SizedBox(width: 4.w),
                        Icon(Icons.verified_rounded, color: accentColor, size: 14.sp),
                      ],
                    ],
                  ),
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: Colors.white70,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // ETA Badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: accentColor, width: 1),
              ),
              child: Text(
                etaText,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: accentColor,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        // Taxi Car & Plate details if driver assigned
        if (isTaxi && !isPending && carPlate.isNotEmpty) ...[
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: Colors.white12, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_car_rounded, color: Colors.white70, size: 15.sp),
                SizedBox(width: 6.w),
                Text(
                  '$carModel ${carColor.isNotEmpty ? "• $carColor" : ""}',
                  style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 10.5.sp, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  child: Text(
                    carPlate,
                    style: GoogleFonts.ibmPlexSansArabic(color: accentColor, fontSize: 10.sp, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],

        SizedBox(height: 10.h),

        // Quick Actions Row (Call, Chat, Full Screen Map)
        Row(
          children: [
            // Quick Call
            if (driverPhone.isNotEmpty) ...[
              Expanded(
                child: SizedBox(
                  height: 36.h,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _makePhoneCall(driverPhone);
                    },
                    icon: Icon(Icons.call_rounded, size: 14.sp, color: Colors.greenAccent),
                    label: Text(
                      'اتصال',
                      style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 10.5.sp, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.greenAccent, width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 6.w),
            ],

            // Quick Chat
            if (isTaxi && driverId.isNotEmpty) ...[
              Expanded(
                child: SizedBox(
                  height: 36.h,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RideChatScreen(
                            rideId: docId,
                            peerName: title,
                            peerId: driverId,
                            peerPhone: driverPhone.isNotEmpty ? driverPhone : null,
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.chat_bubble_rounded, size: 14.sp, color: Colors.amberAccent),
                    label: Text(
                      'محادثة',
                      style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 10.5.sp, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.amberAccent, width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 6.w),
            ],

            // Full Map / Details Button
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 36.h,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    if (isTaxi) {
                      if (driverId.isNotEmpty) {
                        // Driver is on the way -> Open live driver tracking
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RideTrackingPage(
                              driverId: driverId,
                              requestId: docId,
                            ),
                          ),
                        );
                      } else {
                        // Finding driver in progress -> Open live radar trip screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TripScreen(rideId: docId),
                          ),
                        );
                      }
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MyOrdersPage()),
                      );
                    }
                  },
                  icon: Icon(Icons.map_rounded, size: 15.sp, color: Colors.black),
                  label: Text(
                    isPending ? 'رادار البحث' : 'الخريطة الكاملة',
                    style: GoogleFonts.ibmPlexSansArabic(color: Colors.black, fontSize: 11.sp, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    elevation: 3,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
