import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dalal_alqaim/services/role_guard_service.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/driver_registration_status_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/driver_requests_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/taxi_driver_page.dart';

// --- Palette (taxi gold) ---
const Color _primary = Color(0xFFFFB300);
const Color _accent = Color(0xFFF57F17);
const Color _darkBg = Color(0xFF1A1200);
const Color _darkCard = Color(0xFF2C2100);
const Color _darkText = Color(0xFFFFF8E1);
const Color _darkSub = Color(0xFFFFD54F);
const Color _darkHint = Color(0xFFFFCA28);

class TaxiLoginPage extends StatefulWidget {
  const TaxiLoginPage({super.key});

  @override
  State<TaxiLoginPage> createState() => _TaxiLoginPageState();
}

class _TaxiLoginPageState extends State<TaxiLoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  late AnimationController _entranceController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
        parent: _entranceController, curve: Curves.easeOutQuart);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  String? _valEmail(String? v) {
    final val = (v ?? '').trim();
    if (val.isEmpty) return 'البريد الإلكتروني مطلوب';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val)) return 'بريد غير صالح';
    return null;
  }

  String? _valPass(String? v) =>
      (v ?? '').isEmpty ? 'كلمة المرور مطلوبة' : null;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;

      await RoleGuardService.validateRole(
        context: context,
        requiredRole: 'driver',
        deniedMessage: 'عذراً: أنت غير مسجل كسائق تاكسي.',
        onPending: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const DriverRegistrationStatusPage()),
          );
        },
        onSuccess: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const DriverRequestsPage()),
          );
        },
      );
    } on FirebaseAuthException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'فشل تسجيل الدخول. تحقق من البيانات.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.fixed,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _darkBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
              child: Column(
                children: [
                  // ── Header ──
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        children: [
                          Container(
                            width: 88.r,
                            height: 88.r,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                  colors: [_primary, _accent]),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      _primary.withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.all(3.r),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: _darkCard,
                              ),
                              child: Icon(
                                Icons.local_taxi_rounded,
                                color: _primary,
                                size: 38.sp,
                              ),
                            ),
                          ),
                          SizedBox(height: 24.h),
                          Text(
                            'دخول سائقي التاكسي',
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                              color: _darkText,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            'سجّل دخولك لبدء استقبال الطلبات',
                            style: TextStyle(
                              color: _darkSub,
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 36.h),

                  // ── Form Card ──
                  SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(28.r),
                        decoration: BoxDecoration(
                          color: _darkCard.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(
                              color: Colors.white
                                  .withValues(alpha: 0.06)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: 0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _field(
                                controller: _email,
                                label: 'البريد الإلكتروني',
                                icon: Icons.email_outlined,
                                validator: _valEmail,
                                keyboard:
                                    TextInputType.emailAddress,
                              ),
                              SizedBox(height: 16.h),
                              _field(
                                controller: _password,
                                label: 'كلمة المرور',
                                icon: Icons.lock_outline,
                                validator: _valPass,
                                obscure: _obscure,
                                suffix: IconButton(
                                  onPressed: () => setState(
                                      () => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons
                                            .visibility_off_outlined
                                        : Icons
                                            .visibility_outlined,
                                    color: _darkSub,
                                  ),
                                ),
                              ),
                              SizedBox(height: 28.h),

                              // Login Button
                              SizedBox(
                                width: double.infinity,
                                height: 54.h,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(16.r),
                                    gradient: _loading
                                        ? null
                                        : const LinearGradient(
                                            colors: [
                                                _primary,
                                                _accent
                                              ]),
                                    color: _loading
                                        ? _darkCard
                                        : null,
                                    boxShadow: _loading
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: _primary
                                                  .withValues(
                                                      alpha: 0.35),
                                              blurRadius: 14,
                                              offset:
                                                  const Offset(
                                                      0, 4),
                                            ),
                                          ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _loading
                                          ? null
                                          : () {
                                              HapticFeedback
                                                  .lightImpact();
                                              _login();
                                            },
                                      borderRadius:
                                          BorderRadius.circular(
                                              16.r),
                                      child: Center(
                                        child: _loading
                                            ? SizedBox(
                                                width: 22.r,
                                                height: 22.r,
                                                child:
                                                    const CircularProgressIndicator(
                                                  color:
                                                      Colors.white,
                                                  strokeWidth: 2.5,
                                                ),
                                              )
                                            : Text(
                                                'تسجيل الدخول',
                                                style: TextStyle(
                                                  color:
                                                      const Color(
                                                          0xFF1A1200),
                                                  fontSize: 16.sp,
                                                  fontWeight:
                                                      FontWeight
                                                          .bold,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 28.h),

                  // ── Register link ──
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (_, animation, __) =>
                                      const TaxiDriverPage(),
                                  transitionsBuilder:
                                      (_, animation, __, child) =>
                                          FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(1, 0),
                                        end: Offset.zero,
                                      )
                                          .chain(CurveTween(
                                              curve: Curves
                                                  .easeOutCubic))
                                          .animate(animation),
                                      child: child,
                                    ),
                                  ),
                                  transitionDuration:
                                      const Duration(
                                          milliseconds: 500),
                                ),
                              );
                            },
                      child: RichText(
                        text: TextSpan(
                          style:
                              const TextStyle(),
                          children: [
                            TextSpan(
                              text: 'كابتن جديد؟',
                              style: TextStyle(
                                  color: _darkText.withValues(
                                      alpha: 0.7)),
                            ),
                            const TextSpan(
                              text: 'انضم كسائق تاكسي',
                              style: TextStyle(
                                color: _primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      validator: validator,
      style: TextStyle(
          color: _darkText, fontSize: 14.sp),
      cursorColor: _primary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: _darkSub, fontSize: 13.sp),
        prefixIcon: Icon(icon, color: _darkHint),
        suffixIcon: suffix,
        filled: true,
        fillColor: _darkBg.withValues(alpha: 0.5),
        contentPadding:
            EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide:
              BorderSide(color: _darkSub.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide:
              BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}
