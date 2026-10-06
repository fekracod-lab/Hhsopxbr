import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dalal_alqaim/services/role_guard_service.dart';
import 'delivery_register_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/driver_registration_status_page.dart';
import 'delivery_dashboard_page.dart';

// --- Palette (delivery cyan) ---
const Color _primary = Color(0xFF00BFA5);
const Color _accent = Color(0xFF00897B);
const Color _darkBg = Color(0xFF07191A);
const Color _darkCard = Color(0xFF113033);
const Color _darkText = Color(0xFFE0F2F1);
const Color _darkSub = Color(0xFF80CBC4);
const Color _darkHint = Color(0xFF4DB6AC);

class DeliveryLoginPage extends StatefulWidget {
  const DeliveryLoginPage({super.key});

  @override
  State<DeliveryLoginPage> createState() => _DeliveryLoginPageState();
}

class _DeliveryLoginPageState extends State<DeliveryLoginPage> with SingleTickerProviderStateMixin {
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
    _fadeAnim = CurvedAnimation(parent: _entranceController, curve: Curves.easeOutQuart);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
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

  String? _valPass(String? v) => (v ?? '').isEmpty ? 'كلمة المرور مطلوبة' : null;

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
        requiredRole: 'delivery',
        deniedMessage: 'عذراً: أنت غير مسجل في فريق التوصيل.',
        onPending: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DriverRegistrationStatusPage()),
          );
        },
        onSuccess: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DeliveryDashboardPage()),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
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
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [_primary, _accent]),
                              boxShadow: [
                                BoxShadow(
                                  color: _primary.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(3),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: _darkCard,
                              ),
                              child: const Icon(
                                Icons.delivery_dining_rounded,
                                color: _primary,
                                size: 38,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'دخول فريق الدليفري',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _darkText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'ابدأ توصيل الطلبات الآن',
                            style: TextStyle(color: _darkSub, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Form ──
                  SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: _darkCard.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
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
                                keyboard: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 16),
                              _field(
                                controller: _password,
                                label: 'كلمة المرور',
                                icon: Icons.lock_outline,
                                validator: _valPass,
                                obscure: _obscure,
                                suffix: IconButton(
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: _darkSub,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Button
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient:
                                        _loading
                                            ? null
                                            : const LinearGradient(colors: [_primary, _accent]),
                                    color: _loading ? _darkCard : null,
                                    boxShadow:
                                        _loading
                                            ? null
                                            : [
                                              BoxShadow(
                                                color: _primary.withValues(alpha: 0.3),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap:
                                          _loading
                                              ? null
                                              : () {
                                                HapticFeedback.lightImpact();
                                                _login();
                                              },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Center(
                                        child:
                                            _loading
                                                ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2.5,
                                                  ),
                                                )
                                                : const Text(
                                                  'تسجيل الدخول',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
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

                  const SizedBox(height: 28),

                  // ── Register link ──
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: TextButton(
                      onPressed:
                          _loading
                              ? null
                              : () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, animation, __) => const DeliveryRegisterPage(),
                                    transitionsBuilder:
                                        (_, animation, __, child) => FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                                  begin: const Offset(1, 0),
                                                  end: Offset.zero,
                                                )
                                                .chain(CurveTween(curve: Curves.easeOutCubic))
                                                .animate(animation),
                                            child: child,
                                          ),
                                        ),
                                    transitionDuration: const Duration(milliseconds: 500),
                                  ),
                                );
                              },
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(),
                          children: [
                            TextSpan(
                              text: 'عضو جديد؟',
                              style: TextStyle(color: _darkText.withValues(alpha: 0.7)),
                            ),
                            const TextSpan(
                              text: 'انضم لفريق التوصيل',
                              style: TextStyle(color: _primary, fontWeight: FontWeight.bold),
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
      style: const TextStyle(color: _darkText),
      cursorColor: _primary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _darkSub),
        prefixIcon: Icon(icon, color: _darkHint),
        suffixIcon: suffix,
        filled: true,
        fillColor: _darkBg.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _darkSub.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}
