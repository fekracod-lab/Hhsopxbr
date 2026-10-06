import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:dalal_alqaim/features/taxi/presentation/pages/ride_tracking_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/taxi_request_screen.dart';
import 'package:dalal_alqaim/pages/my_orders_page.dart';

/// ══════════════════════════════════════════════════════════════════════════════
/// Madar Live Activity Tracker (Dynamic Island Capsule for Active Trips/Orders)
/// ══════════════════════════════════════════════════════════════════════════════
class MadarLiveActivityTracker extends StatefulWidget {
  const MadarLiveActivityTracker({super.key});

  @override
  State<MadarLiveActivityTracker> createState() => _MadarLiveActivityTrackerState();
}

class _MadarLiveActivityTrackerState extends State<MadarLiveActivityTracker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Listen to active Taxi Ride Requests first
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
          return _buildTaxiLiveCard(context, activeTaxiDoc.id, data, isDark);
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
              return _buildOrderLiveCard(context, activeOrderDoc.id, data, isDark);
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  // ─── Taxi Live Activity Island ───
  Widget _buildTaxiLiveCard(
    BuildContext context,
    String requestId,
    Map<String, dynamic> data,
    bool isDark,
  ) {
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final driverName = (data['driverName'] ?? data['captainName'] ?? 'كابتن مدار').toString();
    final driverId = (data['driverId'] ?? '').toString();

    String statusTitle;
    String statusSubtitle;
    int activeStep = 1;

    switch (status) {
      case 'accepted':
      case 'driver_assigned':
        statusTitle = 'الكابتن $driverName قبل طلبك';
        statusSubtitle = 'في طريقه إلى موقعك الآن';
        activeStep = 1;
        break;
      case 'arrived':
        statusTitle = 'الكابتن $driverName وصل موقعك';
        statusSubtitle = 'الكابتن بانتظارك في الخارج';
        activeStep = 2;
        break;
      case 'in_progress':
      case 'picked_up':
      case 'on_way':
        statusTitle = 'الرحلة جارية مع الكابتن $driverName';
        statusSubtitle = 'نتمنى لك رحلة آمنة ومريحة';
        activeStep = 3;
        break;
      default:
        statusTitle = 'جاري البحث عن أقرب كابتن...';
        statusSubtitle = 'طلب تكسي مدار قيد المعالجة السريعة';
        activeStep = 0;
    }

    return _buildFloatingCapsule(
      context: context,
      isDark: isDark,
      accentColor: const Color(0xFFF59E0B),
      badgeLabel: 'رحلة تكسي جارية',
      icon: Icons.local_taxi_rounded,
      title: statusTitle,
      subtitle: statusSubtitle,
      activeStep: activeStep,
      totalSteps: 3,
      onTap: () {
        HapticFeedback.selectionClick();
        if (driverId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RideTrackingPage(
                driverId: driverId,
                requestId: requestId,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TaxiRequestScreen(),
            ),
          );
        }
      },
    );
  }

  // ─── Order Live Activity Island ───
  Widget _buildOrderLiveCard(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
    bool isDark,
  ) {
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final restaurantName = (data['restaurantName'] ?? data['storeName'] ?? 'المتجر').toString();

    String statusTitle;
    String statusSubtitle;
    int activeStep = 1;

    switch (status) {
      case 'preparing':
      case 'cooking':
      case 'accepted':
        statusTitle = '$restaurantName يحضر طلبك ';
        statusSubtitle = 'الطلب قيد التجهيز بأعلى جودة';
        activeStep = 1;
        break;
      case 'ready':
      case 'assigned':
        statusTitle = 'الطلب جاهز وبانتظار المندوب';
        statusSubtitle = 'المندوب يستلم الوجبة حالاً';
        activeStep = 2;
        break;
      case 'on_way':
      case 'out_for_delivery':
      case 'picked_up':
        statusTitle = 'المندوب في الطريق إليك';
        statusSubtitle = 'طلبك يقترب من موقعك الآن';
        activeStep = 3;
        break;
      default:
        statusTitle = 'تم استلام طلبك في $restaurantName';
        statusSubtitle = 'بانتظار موافقة المطعم/المتجر';
        activeStep = 0;
    }

    return _buildFloatingCapsule(
      context: context,
      isDark: isDark,
      accentColor: app_colors.primaryColor,
      badgeLabel: 'طلب قيد التوصيل',
      icon: Icons.delivery_dining_rounded,
      title: statusTitle,
      subtitle: statusSubtitle,
      activeStep: activeStep,
      totalSteps: 3,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyOrdersPage()),
        );
      },
    );
  }

  // ─── Base Glassmorphic Capsule Layout ───
  Widget _buildFloatingCapsule({
    required BuildContext context,
    required bool isDark,
    required Color accentColor,
    required String badgeLabel,
    required IconData icon,
    required String title,
    required String subtitle,
    required int activeStep,
    required int totalSteps,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.r),
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      accentColor.withValues(alpha: 0.22),
                      const Color(0xFF0F2628),
                    ]
                  : [
                      accentColor.withValues(alpha: 0.14),
                      Colors.white,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.5 : 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: isDark ? 0.25 : 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(22.r),
                  splashColor: accentColor.withValues(alpha: 0.15),
                  highlightColor: accentColor.withValues(alpha: 0.08),
                  child: Padding(
                    padding: EdgeInsets.all(14.r),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header Row: Live Badge & Trailing Action
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                badgeLabel,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : accentColor,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'تتبع مباشر',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: accentColor,
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 10.sp,
                                  color: accentColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),

                        // Content Row: Icon + Title/Subtitle
                        Row(
                          children: [
                            Container(
                              width: 44.r,
                              height: 44.r,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentColor.withValues(alpha: isDark ? 0.25 : 0.15),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.4),
                                  width: 1.2,
                                ),
                              ),
                              child: Icon(
                                icon,
                                color: isDark ? Colors.white : accentColor,
                                size: 22.sp,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 10.5.sp,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),

                        // Progress Bar Steps
                        Row(
                          children: List.generate(totalSteps, (index) {
                            final isCompleted = index <= activeStep;
                            return Expanded(
                              child: Container(
                                height: 4.h,
                                margin: EdgeInsets.symmetric(horizontal: 2.w),
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? accentColor
                                      : (isDark ? Colors.white12 : Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
