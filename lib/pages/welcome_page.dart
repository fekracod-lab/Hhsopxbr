import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/features/auth/pages/login_page.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:dalal_alqaim/shared/widgets/glass_container.dart';
import 'package:dalal_alqaim/shared/widgets/madar_button.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late Animation<double> _fadeHero;
  late Animation<double> _fadeText;
  late Animation<double> _fadeButton;
  late Animation<Offset> _slideHero;
  late Animation<Offset> _slideText;
  late Animation<Offset> _slideButton;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _fadeHero = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _fadeText = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.7, curve: Curves.easeOut),
    );
    _fadeButton = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );

    _slideHero = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    ));
    _slideText = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.7, curve: Curves.easeOutCubic),
    ));
    _slideButton = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    HapticFeedback.mediumImpact();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const EnhancedLoginPage(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: isDark ? app_colors.darkBackground : const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            // ── Minimalist Geometric Ambient Glow ──
            Positioned(
              top: -60.h,
              right: -50.w,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 240.r + (_pulseController.value * 25),
                    height: 240.r + (_pulseController.value * 25),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: app_colors.primaryColor.withValues(
                        alpha: isDark ? 0.16 : 0.1,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: -50.h,
              left: -40.w,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 200.r + (_pulseController.value * 20),
                    height: 200.r + (_pulseController.value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: app_colors.accentColor.withValues(
                        alpha: isDark ? 0.12 : 0.08,
                      ),
                    ),
                  );
                },
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 10.h),

                      // ── Top Brand Badge ──
                      FadeTransition(
                        opacity: _fadeText,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
                          decoration: BoxDecoration(
                            color: isDark
                                ? app_colors.darkCard.withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(30.r),
                            border: Border.all(
                              color: app_colors.primaryColor.withValues(alpha: 0.35),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8.r,
                                height: 8.r,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: app_colors.primaryColor,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'منصة مدار الذكية',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? app_colors.darkText : app_colors.textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 36.h),

                      // ── Official Madar Logo Showcase ──
                      FadeTransition(
                        opacity: _fadeHero,
                        child: SlideTransition(
                          position: _slideHero,
                          child: GlassContainer(
                            borderRadius: 36.r,
                            padding: EdgeInsets.all(20.r),
                            width: 170.r,
                            height: 170.r,
                            child: Center(
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: app_colors.primaryColor.withValues(alpha: 0.35),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(30.r),
                                  child: Image.asset(
                                    'imges/dala_alqaim_logo.png',
                                    width: 120.r,
                                    height: 120.r,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      'assets/images/logo.png',
                                      width: 120.r,
                                      height: 120.r,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.hub_rounded,
                                        size: 58.r,
                                        color: app_colors.primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 40.h),

                      // ── Title & Subtitle with IBM Plex Sans Arabic ──
                      FadeTransition(
                        opacity: _fadeText,
                        child: SlideTransition(
                          position: _slideText,
                          child: Column(
                            children: [
                              Text(
                                'يا هلا بيك في مَدار',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 27.sp,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? app_colors.darkText : app_colors.textColor,
                                  height: 1.3,
                                ),
                              ),
                              SizedBox(height: 10.h),
                              Text(
                                'تكسي سريع، طلبات طعام، وتوصيل مسواك وجملة، كل خدماتك بمكان واحد وبكبسة زر واحدة.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                  color: isDark ? app_colors.darkSubText : app_colors.subTextColor,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 28.h),

                      // ── Clean Minimal Feature Badges ──
                      FadeTransition(
                        opacity: _fadeText,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildFeaturePill(Icons.speed_rounded, 'سرعة فورية', isDark),
                            SizedBox(width: 8.w),
                            _buildFeaturePill(Icons.security_rounded, 'أمان وضمان', isDark),
                            SizedBox(width: 8.w),
                            _buildFeaturePill(Icons.local_shipping_outlined, 'تغطية شاملة', isDark),
                          ],
                        ),
                      ),

                      SizedBox(height: 38.h),

                      // ── Interactive CTA Button ──
                      FadeTransition(
                        opacity: _fadeButton,
                        child: SlideTransition(
                          position: _slideButton,
                          child: MadarButton(
                            text: 'ادخل هسّه وتدلل',
                            icon: Icons.arrow_back_rounded, // RTL direction
                            textStyle: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            onPressed: _goToLogin,
                            height: 56.h,
                            borderRadius: 18.r,
                          ),
                        ),
                      ),

                      SizedBox(height: 24.h),

                      // ── Clean Footnote ──
                      FadeTransition(
                        opacity: _fadeButton,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 15.sp,
                              color: app_colors.primaryColor,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'تسجيل دخول آمن ومباشر لكافة المستخدمين',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: isDark ? app_colors.darkSubText : app_colors.subTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 10.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String text, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isDark
            ? app_colors.darkSurface.withValues(alpha: 0.6)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? app_colors.darkBorderSubtle : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13.sp,
            color: app_colors.primaryColor,
          ),
          SizedBox(width: 5.w),
          Text(
            text,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: isDark ? app_colors.darkSubText : app_colors.subTextColor,
            ),
          ),
        ],
      ),
    );
  }
}
