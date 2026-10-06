import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dalal_alqaim/features/home/pages/home_page.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dalal_alqaim/services/ahyxi_otp_service.dart';
import 'package:dalal_alqaim/features/auth/widgets/iraqi_phone_input_field.dart';
import 'package:dalal_alqaim/features/auth/widgets/otp_verification_dialog.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> with TickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  int? _resendToken;

  late AnimationController _entranceController;
  late AnimationController _bgController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _bgController.dispose();
    _pulseController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'رقم الهاتف غير صحيح';
      case 'invalid-verification-code':
        return 'رمز التحقق غير صحيح';
      case 'session-expired':
        return 'انتهت صلاحية الرمز، يرجى إعادة الإرسال';
      case 'quota-exceeded':
        return 'تجاوزت الحد المسموح من المحاولات، حاول مرة ثانية بعد شوية';
      case 'too-many-requests':
        return 'طلبات كثيرة جداً، انتظر شوية... قليلاً';
      case 'network-request-failed':
        return 'فشل الاتصال، تحقق من الإنترنت.';
      default:
        return 'حدث خطأ: $code';
    }
  }

  void _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
    });

    final String rawPhone = _phoneController.text.trim();
    final String formattedPhone = AhyxiOtpService.formatIraqiPhoneNumber(rawPhone);

    try {
      // 1. إرسال OTP عبر خدمة Ahyxi العراقية المباشرة
      final otpRes = await AhyxiOtpService.sendOtp(phoneNumber: formattedPhone);

      if (otpRes.isSuccess) {
        if (!mounted) return;
        setState(() => _loading = false);

        final success = await OtpVerificationDialog.show(
          context: context,
          phoneNumber: formattedPhone,
        );

        if (success == true && mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomePage()),
            (Route<dynamic> route) => false,
          );
        }
        return;
      }

      // 2. Fallback: إذا ما قدرنا نرسل Ahyxi، التحويل التلقائي لـ Firebase Phone Auth
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (!mounted) return;
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (!mounted) return;
            setState(() => _loading = false);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          } catch (e) {
            if (!mounted) return;
            setState(() => _loading = false);
            _showErrorSnackBar('فشل تسجيل الدخول التلقائي');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() => _loading = false);
          _showErrorSnackBar(_mapFirebaseError(e.code));
        },
        codeSent: (String verificationId, int? resendToken) async {
          _resendToken = resendToken;
          if (!mounted) return;
          setState(() => _loading = false);

          final success = await OtpVerificationDialog.show(
            context: context,
            phoneNumber: formattedPhone,
            verificationId: verificationId,
          );

          if (success == true && mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomePage()),
              (Route<dynamic> route) => false,
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showErrorSnackBar('حدث خطأ أثناء إرسال الرمز');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle()),
        behavior: SnackBarBehavior.fixed,
        backgroundColor: Colors.redAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = app_colors.primaryColor;
    final textColor = isDark ? Colors.white : const Color(0xFF1A2E2E);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF050D0D) : const Color(0xFFF6FAFA),
        body: Stack(
          children: [
            // ── Animated Background ──
            _AnimatedBackground(
              controller: _bgController,
              primary: primary,
              isDark: isDark,
            ),

            SafeArea(
              child: Column(
                children: [
                  // ── Top Bar ──
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: textColor.withValues(alpha: 0.6),
                            size: 20.sp,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // ── Content ──
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: 28.w),
                          child: Column(
                            children: [
                              _buildHeader(primary, textColor, isDark),
                              SizedBox(height: 36.h),
                              _buildPhoneForm(isDark, primary, textColor),
                              SizedBox(height: 40.h),
                            ],
                          ),
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

  Widget _buildHeader(Color primary, Color textColor, bool isDark) {
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
            // Icon with glow
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final glow = 0.1 + (_pulseController.value * 0.12);
                return Container(
                  padding: EdgeInsets.all(18.r),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary.withValues(alpha: 0.08),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: glow),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.phone_android_rounded,
                    size: 40.sp,
                    color: primary,
                  ),
                );
              },
            ),
            SizedBox(height: 20.h),
            Text(
              'تسجيل الدخول',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'أدخل رقم هاتفك للمتابعة',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.45)
                    : const Color(0xFF5A7A7A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneForm(bool isDark, Color primary, Color textColor) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 0.75, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.3, 0.75, curve: Curves.easeOutCubic),
        )),
        child: Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : primary.withValues(alpha: 0.08),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.06),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h, right: 4.w),
                  child: Text(
                    'رقم الهاتف',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                IraqiPhoneInputField(
                  controller: _phoneController,
                  hintText: '0770 123 4567',
                ),
                SizedBox(height: 24.h),
                _buildSubmitButton(primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(Color primary) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glow = _loading ? 0.0 : (0.15 + _pulseController.value * 0.1);
        return GestureDetector(
          onTap: _loading ? null : _submit,
          child: Container(
            height: 58.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.r),
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [primary, const Color(0xFF00897B)],
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: glow),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: _loading
                  ? SizedBox(
                      height: 22.h,
                      width: 22.h,
                      child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, color: Colors.white, size: 20.sp),
                        SizedBox(width: 10.w),
                        Text(
                          'إرسال الرمز',
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ANIMATED BACKGROUND
// ═══════════════════════════════════════════════════════════════
class _AnimatedBackground extends StatelessWidget {
  final AnimationController controller;
  final Color primary;
  final bool isDark;

  const _AnimatedBackground({
    required this.controller,
    required this.primary,
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
              top: -50.h + sin(t * 0.5) * 20,
              right: -40.w + cos(t * 0.3) * 15,
              child: Container(
                width: 250.r,
                height: 250.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primary.withValues(alpha: isDark ? 0.14 : 0.1),
                      primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60.h + cos(t * 0.4) * 25,
              left: -50.w + sin(t * 0.6) * 20,
              child: Container(
                width: 280.r,
                height: 280.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00796B).withValues(alpha: isDark ? 0.1 : 0.06),
                      const Color(0xFF00796B).withValues(alpha: 0.0),
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
