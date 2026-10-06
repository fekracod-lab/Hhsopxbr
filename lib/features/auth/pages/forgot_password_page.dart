import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _bgController;
  late AnimationController _pulseController;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _sent = false;

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
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      String msg = 'صار خطأ، حاول مرة ثانية';
      if (e.code == 'user-not-found') msg = 'هذا البريد غير مسجل لدينا';
      if (e.code == 'invalid-email') msg = 'البريد الإلكتروني غير صالح';
      setState(() => _error = msg);
    } catch (_) {
      setState(() => _error = 'فشل الاتصال بالخادم');
    } finally {
      setState(() => _loading = false);
    }
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
            _AnimatedBackground(controller: _bgController, primary: primary, isDark: isDark),
            SafeArea(
              child: Column(
                children: [
                   _buildTopBar(textColor),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 28.w),
                        child: _sent ? _buildSuccessUi(primary, textColor) : _buildRequestUi(primary, textColor, isDark),
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

  Widget _buildTopBar(Color textColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor.withValues(alpha: 0.6), size: 20.sp),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestUi(Color primary, Color textColor, bool isDark) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final glow = 0.1 + (_pulseController.value * 0.12);
            return Container(
              padding: EdgeInsets.all(18.r),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withValues(alpha: 0.08),
                boxShadow: [BoxShadow(color: primary.withValues(alpha: glow), blurRadius: 40, spreadRadius: 8)],
              ),
              child: Icon(Icons.lock_reset_rounded, size: 40.sp, color: primary),
            );
          },
        ),
        SizedBox(height: 24.h),
        Text('استعادة كلمة المرور', style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900, color: textColor)),
        SizedBox(height: 8.h),
        Text('أدخل بريدك الإلكتروني وسنرسل لك رابطاً لإعادة التعيين', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.sp, color: textColor.withValues(alpha: 0.5))),
        SizedBox(height: 36.h),
        Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : primary.withValues(alpha: 0.08)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                 if (_error != null) Container(
                   margin: EdgeInsets.only(bottom: 16.h),
                   padding: EdgeInsets.all(12.r),
                   decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12.r)),
                   child: Text(_error!, style: TextStyle(color: Colors.redAccent, fontSize: 12.sp, fontWeight: FontWeight.bold)),
                 ),
                _buildInputField(
                  controller: _emailController,
                  label: 'البريد الإلكتروني',
                  hint: 'name@example.com',
                  icon: Icons.alternate_email_rounded,
                  isDark: isDark,
                  primary: primary,
                  textColor: textColor,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'يرجى إدخال البريد';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                      return 'يرجى إدخال بريد إلكتروني صحيح';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 28.h),
                _buildSubmitButton(primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessUi(Color primary, Color textColor) {
    return Column(
      children: [
        Icon(Icons.mark_email_read_rounded, size: 80.sp, color: primary),
        SizedBox(height: 24.h),
        Text('تم الإرسال!', style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900, color: textColor)),
        SizedBox(height: 12.h),
        Text(
          'يرجى التحقق من بريدك الإلكتروني (بما في ذلك مجلد البريد غير الهام/Spam) واتباع التعليمات لإعادة تعيين كلمة المرور.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.sp,
            color: textColor.withValues(alpha: 0.6),
          ),
        ),
        SizedBox(height: 40.h),
        SizedBox(
          width: double.infinity,
          height: 56.h,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r))),
            child: const Text('العودة لتسجيل الدخول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color primary,
    required Color textColor,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.h, right: 4.w),
          child: Text(label, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: textColor.withValues(alpha: 0.7))),
        ),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          validator: validator,
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 14.sp, color: isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFB0C4C4)),
            prefixIcon: Icon(icon, size: 20.sp, color: primary),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF2F8F8),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: BorderSide(color: primary.withValues(alpha: 0.5), width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(Color primary) {
    return SizedBox(
      height: 58.h,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
          elevation: 0,
        ),
        child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('إرسال الرابط', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}

class _AnimatedBackground extends StatelessWidget {
  final AnimationController controller;
  final Color primary;
  final bool isDark;

  const _AnimatedBackground({required this.controller, required this.primary, required this.isDark});

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
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [primary.withValues(alpha: isDark ? 0.14 : 0.1), primary.withValues(alpha: 0.0)])),
              ),
            ),
          ],
        );
      },
    );
  }
}
