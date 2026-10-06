import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dalal_alqaim/pages/emergency_services_page.dart';
import 'package:dalal_alqaim/pages/vacancies_page.dart';
import 'package:dalal_alqaim/pages/real_estate_page.dart';
import 'package:dalal_alqaim/pages/complaints_page.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/madar_stores_page.dart';
import 'package:dalal_alqaim/pages/technical_support_chat_page.dart';

import 'package:dalal_alqaim/features/home/widgets/madar_3d_service_graphics.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

/// ══════════════════════════════════════════════════════════════════════════════
/// Madar Visual Identity 3D Quick Services Row (هوية مدار البصرية المتكاملة)
/// ══════════════════════════════════════════════════════════════════════════════
class DraggableServicesRow extends StatefulWidget {
  const DraggableServicesRow({super.key});

  @override
  State<DraggableServicesRow> createState() => _DraggableServicesRowState();
}

class _DraggableServicesRowState extends State<DraggableServicesRow> {
  final List<_QuickServiceData> _services = [
    _QuickServiceData(
      serviceType: 'jobs',
      title: 'الوظائف',
      tag: 'شواغر',
      gradientColors: [const Color(0xFF0D9488), const Color(0xFF115E59)],
      accentColor: const Color(0xFF14B8A6),
      page: const VacanciesPage(),
    ),
    _QuickServiceData(
      serviceType: 'complaints',
      title: 'الشكاوي',
      tag: 'صوتك',
      gradientColors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      accentColor: const Color(0xFFFBBF24),
      page: const ComplaintsPage(),
    ),
    _QuickServiceData(
      serviceType: 'emergency',
      title: 'الطوارئ',
      tag: '24/7',
      gradientColors: [const Color(0xFFEF4444), const Color(0xFFB91C1C)],
      accentColor: const Color(0xFFF87171),
      page: const EmergencyServicesPage(),
    ),
    _QuickServiceData(
      serviceType: 'real_estate',
      title: 'العقارات',
      tag: 'إيجار وبيع',
      gradientColors: [const Color(0xFF00BFA5), const Color(0xFF00897B)],
      accentColor: const Color(0xFF00BFA5),
      page: const RealEstatePage(),
    ),
    _QuickServiceData(
      serviceType: 'stores',
      title: 'المتاجر',
      tag: 'عروض',
      gradientColors: [const Color(0xFF00BFA5), const Color(0xFF004D40)],
      accentColor: const Color(0xFF26A69A),
      page: const MadarStoresPage(),
    ),
    _QuickServiceData(
      serviceType: 'help',
      title: 'المساعدة',
      tag: 'دعم مباشر',
      gradientColors: [const Color(0xFF00BFA5), const Color(0xFF0F766E)],
      accentColor: const Color(0xFF2DD4BF),
      action: _showHelpDialog,
    ),
  ];

  // ─── Help Dialog ───
  static void _showHelpDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
          backgroundColor: isDark ? const Color(0xFF0F1E1E) : Colors.white,
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: app_colors.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: app_colors.primaryColor,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'مركز المساعدة والدعم',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.w800,
                  fontSize: 16.sp,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'فريق دعم مدار متاح دائماً لمساعدتك في أي استفسار أو مشكلة تواجهك في التطبيق.',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12.5.sp,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                height: 46.h,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TechnicalSupportChatPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_rounded, color: Colors.white),
                  label: Text(
                    'بدء محادثة فورية مع الدعم',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.sp,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: app_colors.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'إغلاق',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: 130.h,
        child: ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _services.length,
          itemBuilder: (context, index) {
            final service = _services[index];
            return _MadarVisualIdentityTile(
              data: service,
              isDark: isDark,
            );
          },
        ),
      ),
    );
  }
}

/// ─── Data Class ───
class _QuickServiceData {
  final String serviceType;
  final String title;
  final String tag;
  final List<Color> gradientColors;
  final Color accentColor;
  final Widget? page;
  final void Function(BuildContext context)? action;

  const _QuickServiceData({
    required this.serviceType,
    required this.title,
    required this.tag,
    required this.gradientColors,
    required this.accentColor,
    this.page,
    this.action,
  });
}

/// ─── Madar Visual Identity 3D Service Tile ───
class _MadarVisualIdentityTile extends StatefulWidget {
  final _QuickServiceData data;
  final bool isDark;

  const _MadarVisualIdentityTile({
    required this.data,
    required this.isDark,
  });

  @override
  State<_MadarVisualIdentityTile> createState() => _MadarVisualIdentityTileState();
}

class _MadarVisualIdentityTileState extends State<_MadarVisualIdentityTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    if (widget.data.page != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => widget.data.page!),
      );
    } else if (widget.data.action != null) {
      widget.data.action!(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final data = widget.data;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) {
          _pressController.reverse();
          _handleTap();
        },
        onTapCancel: () => _pressController.reverse(),
        child: Container(
          width: 92.w,
          margin: EdgeInsetsDirectional.only(end: 10.w),
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131D20) : const Color(0xFFF7FAF9),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: isDark ? const Color(0xFF1F3538) : const Color(0xFFE2EBE9),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.03),
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Floating 3D Graphic ──
              Flexible(
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Madar3DServiceGraphic(
                        serviceType: data.serviceType,
                        size: 62.r,
                      ),

                      // Floating Micro-Badge on top-corner
                      PositionedDirectional(
                        top: -2.h,
                        start: -2.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: data.gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(6.r),
                            boxShadow: [
                              BoxShadow(
                                color: data.gradientColors[0].withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            data.tag,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 7.5.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 6.h),

              // ── Title Label (IBM Plex Sans Arabic) ──
              Text(
                data.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
