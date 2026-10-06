import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/features/auth/pages/unified_login_page.dart';
import 'package:dalal_alqaim/features/auth/widgets/role_selector_tab.dart';

class EmployeeSubRolePage extends StatefulWidget {
  const EmployeeSubRolePage({super.key});

  @override
  State<EmployeeSubRolePage> createState() => _EmployeeSubRolePageState();
}

class _EmployeeSubRolePageState extends State<EmployeeSubRolePage>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _entranceController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/illustrations/role_taxi_partner.png'), context);
    precacheImage(const AssetImage('assets/illustrations/role_delivery_partner.png'), context);
    precacheImage(const AssetImage('assets/illustrations/role_transport_partner.png'), context);
  }
  @override
  void dispose() {
    _bgController.dispose();
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _navigateTo(Widget page) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => page,
        transitionsBuilder: (_, a, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.12, 0),
                end: Offset.zero,
              ).animate(
                  CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A2E2E);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF050D0D) : const Color(0xFFF6FAFA),
        body: Stack(
          children: [
            // ── Animated Background ──
            _AnimatedBg(
              controller: _bgController,
              isDark: isDark,
            ),

            // ── Content ──
            SafeArea(
              child: Column(
                children: [
                  // AppBar
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18.sp,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main content
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: 28.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Header
                            _buildHeader(isDark, textColor),
                            SizedBox(height: 40.h),

                            // Three driver cards
                            _buildSubRoleCard(
                              isDark: isDark,
                              imagePath: 'assets/illustrations/role_taxi_partner.png',
                              title: 'سائق تاكسي',
                              subtitle:
                                  'استقبل طلبات الركاب وابدأ العمل ككابتن تاكسي في مدار',
                              gradient: [
                                const Color(0xFFFFB300),
                                const Color(0xFFF57F17)
                              ],
                              delay: 0.2,
                              onTap: () =>
                                  _navigateTo(const UnifiedLoginPage(initialRole: UserRole.captain)),
                            ),

                            SizedBox(height: 16.h),

                            _buildSubRoleCard(
                              isDark: isDark,
                              imagePath: 'assets/illustrations/role_delivery_partner.png',
                              title: 'مندوب توصيل',
                              subtitle:
                                  'انضم لفريق التوصيل وابدأ بتوصيل الطلبات في منطقتك',
                              gradient: [
                                const Color(0xFF42A5F5),
                                const Color(0xFF1565C0)
                              ],
                              delay: 0.35,
                              onTap: () =>
                                  _navigateTo(const UnifiedLoginPage(initialRole: UserRole.delivery)),
                            ),

                            SizedBox(height: 16.h),

                            _buildSubRoleCard(
                              isDark: isDark,
                              imagePath: 'assets/illustrations/role_transport_partner.png',
                              title: 'شريك نقل',
                              subtitle:
                                  'سجّل سيارتك وانضم كشريك نقل بضائع ومنتجات',
                              gradient: [
                                const Color(0xFFAB47BC),
                                const Color(0xFF7B1FA2)
                              ],
                              delay: 0.5,
                              onTap: () =>
                                  _navigateTo(const UnifiedLoginPage(initialRole: UserRole.captain)),
                            ),

                            SizedBox(height: 24.h),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color textColor) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
        )),
        child: Column(
          children: [
            Container(
              width: 80.r,
              height: 80.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB300), Color(0xFF42A5F5)],
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        const Color(0xFFFFB300).withValues(alpha: 0.25),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.drive_eta_rounded,
                color: Colors.white,
                size: 36.sp,
              ),
            ),

            SizedBox(height: 20.h),

            Text(
              'بوابة الشركاء',
              style: TextStyle(
                fontSize: 26.sp,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),

            SizedBox(height: 6.h),

            Text(
              'حدد نوع الخدمة والعمل الذي تقدمه',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : const Color(0xFF5A7A7A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubRoleCard({
    required bool isDark,
    required String imagePath,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required double delay,
    required VoidCallback onTap,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.25),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _entranceController,
        curve: Interval(delay, (delay + 0.4).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic),
      )),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _entranceController,
          curve: Interval(delay, (delay + 0.3).clamp(0.0, 1.0),
              curve: Curves.easeOut),
        ),
        child: _SubRoleCardWidget(
          imagePath: imagePath,
          title: title,
          subtitle: subtitle,
          gradient: gradient,
          isDark: isDark,
          pulseController: _pulseController,
          onTap: onTap,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SUB-ROLE CARD WIDGET
// ═══════════════════════════════════════════════════════════════
class _SubRoleCardWidget extends StatefulWidget {
  final String imagePath;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final bool isDark;
  final AnimationController pulseController;
  final VoidCallback onTap;

  const _SubRoleCardWidget({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.isDark,
    required this.pulseController,
    required this.onTap,
  });

  @override
  State<_SubRoleCardWidget> createState() => _SubRoleCardWidgetState();
}

class _SubRoleCardWidgetState extends State<_SubRoleCardWidget> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedBuilder(
          animation: widget.pulseController,
          builder: (context, _) {
            final glow =
                0.12 + (widget.pulseController.value * 0.08);

            return Container(
              padding: EdgeInsets.all(2.r),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24.r),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.gradient[0]
                        .withValues(alpha: glow + 0.15),
                    widget.gradient[1].withValues(alpha: glow),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.gradient[0]
                        .withValues(alpha: glow * 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Container(
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? const Color(0xFF0A1818)
                          .withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(22.r),
                ),
                child: Row(
                  children: [
                    // Illustration Image
                    SizedBox(
                      width: 60.r,
                      height: 60.r,
                      child: Image.asset(
                        widget.imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.drive_eta_rounded,
                          color: widget.gradient[0],
                          size: 28.sp,
                        ),
                      ),
                    ),

                    SizedBox(width: 16.w),

                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w800,
                              color: widget.isDark
                                  ? Colors.white
                                  : const Color(0xFF1A2E2E),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: widget.isDark
                                  ? Colors.white
                                      .withValues(alpha: 0.4)
                                  : const Color(0xFF5A7A7A),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Arrow
                    Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: widget.gradient[0]
                            .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 18.sp,
                        color: widget.gradient[0],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ANIMATED BACKGROUND
// ═══════════════════════════════════════════════════════════════
class _AnimatedBg extends StatelessWidget {
  final AnimationController controller;
  final bool isDark;

  const _AnimatedBg({
    required this.controller,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value * 2 * pi;
        return Stack(
          children: [
            Positioned(
              top: -80.h + sin(t * 0.4) * 20,
              right: -60.w + cos(t * 0.3) * 15,
              child: Container(
                width: 280.r,
                height: 280.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF42A5F5)
                          .withValues(alpha: isDark ? 0.12 : 0.07),
                      const Color(0xFF42A5F5).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60.h + cos(t * 0.5) * 25,
              left: -40.w + sin(t * 0.4) * 20,
              child: Container(
                width: 260.r,
                height: 260.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7B1FA2)
                          .withValues(alpha: isDark ? 0.10 : 0.05),
                      const Color(0xFF7B1FA2).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
