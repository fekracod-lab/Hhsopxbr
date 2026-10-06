import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:math' as math;
import 'package:dalal_alqaim/services/role_guard_service.dart';
import 'captain_register_page.dart';
import 'driver_dashboard_page.dart';
import 'driver_registration_status_page.dart';

import 'package:dalal_alqaim/widgets/premium_widgets.dart';

// --- Palette ---
const Color _primary = Color(0xFF26A69A);
const Color _accent = Color(0xFF00796B);
const Color _lightText = Color(0xFF2C3E50);
const Color _lightSub = Color(0xFF7F8C8D);

class CaptainLoginPage extends StatefulWidget {
  const CaptainLoginPage({super.key});

  @override
  State<CaptainLoginPage> createState() => _CaptainLoginPageState();
}

class _CaptainLoginPageState extends State<CaptainLoginPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _rememberMe = true;

  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ── Shimmer & Pulse Animations ──
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );
    _entranceController.forward();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadRememberedData();
  }

  Future<void> _loadRememberedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('captain_identifier');
      final savedPass = prefs.getString('captain_password');
      final remember = prefs.getBool('captain_remember') ?? true;

      if (remember && mounted) {
        setState(() {
          _rememberMe = true;
          if (savedId != null) _identifier.text = savedId;
          if (savedPass != null) _password.text = savedPass;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _entranceController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // --- Validators ---
  String? _validateIdentifier(String? v) {
    final val = (v ?? '').trim();
    if (val.isEmpty) return 'يرجى إدخال البريد، رقم الهاتف، أو الاسم الثلاثي';
    return null;
  }

  String? _validatePassword(String? v) {
    if ((v ?? '').isEmpty) return 'كلمة المرور مطلوبة';
    return null;
  }



  // --- Login ---
  Future<void> _loginCaptain() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      String input = _identifier.text.trim();
      String email = input;

      // Check if input is a phone number or name (doesn't contain '@')
      if (!input.contains('@')) {
        // 1. Try finding by phone number
        var userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: input)
            .limit(1)
            .get();

        // 2. If not found by phone, try finding by full name
        if (userQuery.docs.isEmpty) {
          userQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('fullName', isEqualTo: input)
              .limit(1)
              .get();
        }

        if (userQuery.docs.isEmpty) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'لم يتم العثور على حساب بهذا الاسم أو الرقم',
          );
        }
        email = userQuery.docs.first.data()['email'];
      }

      // 3. Sign in with the fetched/input email
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _password.text,
      );

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('captain_identifier', input);
        await prefs.setString('captain_password', _password.text);
        await prefs.setBool('captain_remember', true);
      } else {
        await prefs.remove('captain_identifier');
        await prefs.remove('captain_password');
        await prefs.setBool('captain_remember', false);
      }

      if (!mounted) return;

      await RoleGuardService.validateRole(
        context: context,
        requiredRole: 'driver',
        deniedMessage: 'عذراً: أنت غير مسجل ككابتن.',
        onPending: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const DriverRegistrationStatusPage(),
            ),
          );
        },
        onSuccess: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DriverDashboardPage()),
          );
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'فشل تسجيل الدخول. تحقق من البيانات.';
      if (e.code == 'user-not-found') message = 'رقم الهاتف غير مسجل.';
      if (e.code == 'wrong-password') message = 'كلمة المرور غير صحيحة.';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e', style: const TextStyle()),
          backgroundColor: Colors.redAccent,
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
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // ── Animated Background ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.55,
              child: Image.asset(
                'assets/images/taxi_login_bg.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            
            // ── Gradient Fade to White ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.55,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.2),
                      Colors.white.withValues(alpha: 0.8),
                      Colors.white,
                    ],
                    stops: const [0.0, 0.6, 0.9, 1.0],
                  ),
                ),
              ),
            ),

            // ── Solid White Bottom ──
            Positioned(
              top: MediaQuery.of(context).size.height * 0.54,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.white,
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          // ── Floating Logo ──
                          _buildPremiumHeader(),

                          const SizedBox(height: 100),

                          // ── White Form Card ──
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 30,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    PremiumTextField(
                                      controller: _identifier,
                                      label: 'البريد، الهاتف، أو الاسم الثلاثي',
                                      icon: Icons.person_outline_rounded,
                                      validator: _validateIdentifier,
                                      keyboard: TextInputType.emailAddress,
                                    ),
                                    const SizedBox(height: 18),
                                    PremiumTextField(
                                      controller: _password,
                                      label: 'كلمة المرور',
                                      icon: Icons.lock_person_outlined,
                                      validator: _validatePassword,
                                      obscure: _obscure,
                                      suffix: IconButton(
                                        onPressed: () => setState(
                                          () => _obscure = !_obscure,
                                        ),
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: _primary.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildRememberMe(),
                                    const SizedBox(height: 24),
                                    _buildLoginButton(),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),
                          _buildRegisterLink(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Back Button
            if (Navigator.canPop(context))
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: _lightText,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Column(
      children: [
        const SizedBox(height: 24),

        // ── Animated Shimmer Title ──
        AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            return ShaderMask(
              shaderCallback: (bounds) {
                final shimmerTranslate = _shimmerController.value * 3 - 1;
                return LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: const [
                    Colors.white,
                    Color(0xFF80CBC4), // teal shimmer
                    Colors.white,
                    Color(0xFFB2DFDB), // light teal flash
                    Colors.white,
                  ],
                  stops: [
                    0.0,
                    (0.35 + shimmerTranslate).clamp(0.0, 1.0),
                    (0.5 + shimmerTranslate).clamp(0.0, 1.0),
                    (0.65 + shimmerTranslate).clamp(0.0, 1.0),
                    1.0,
                  ],
                ).createShader(bounds);
              },
              child: child!,
            );
          },
          child: const Text(
            'كابتن مدار',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2.0,
              height: 1.1,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 6),
                  blurRadius: 20,
                ),
                Shadow(
                  color: Color(0x3326A69A),
                  offset: Offset(0, 2),
                  blurRadius: 30,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ── Animated Decorative Divider ──
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, _) {
            final lineWidth = 30 + (_pulseAnimation.value * 25);
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: lineWidth,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: _pulseAnimation.value * 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 10),
                // ── Spinning Diamond ──
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _shimmerController.value * 2 * math.pi,
                      child: Icon(
                        Icons.diamond_rounded,
                        size: 12,
                        color: Colors.white.withValues(
                          alpha: 0.5 + (_pulseAnimation.value * 0.5),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: lineWidth,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: _pulseAnimation.value * 0.8),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            );
          },
        ),


      ],
    );
  }

  Widget _buildRememberMe() {
    return InkWell(
      onTap: () => setState(() => _rememberMe = !_rememberMe),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                activeColor: _primary,
                side: BorderSide(color: _lightSub.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'تذكر بياناتي',
              style: TextStyle(
                color: _lightSub,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: _loading
            ? null
            : const LinearGradient(
                colors: [_primary, _accent],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        color: _loading ? Colors.grey[200] : null,
        boxShadow: _loading
            ? null
            : [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  _loginCaptain();
                },
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: _primary,
                      strokeWidth: 3,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'دخول الكابتن',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(
                        Icons.local_taxi_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return TextButton(
      onPressed: _loading
          ? null
          : () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, animation, __) =>
                      const CaptainRegisterPage(),
                  transitionsBuilder: (_, animation, __, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.05),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 400),
                ),
              );
            },
      child: RichText(
        text: const TextSpan(
          style: TextStyle(fontSize: 14),
          children: [
            TextSpan(
              text: 'ليس لديك حساب؟',
              style: TextStyle(color: Color(0xFF7F8C8D)),
            ),
            TextSpan(
              text: 'انضم ككابتن الآن',
              style: TextStyle(
                color: _primary,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }


}

// ─── Custom Animated Background ───

class _AnimatedMapBackground extends StatefulWidget {
  final Color primaryColor;
  const _AnimatedMapBackground({required this.primaryColor});

  @override
  State<_AnimatedMapBackground> createState() => _AnimatedMapBackgroundState();
}

class _AnimatedMapBackgroundState extends State<_AnimatedMapBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _MapPulsePainter(
            progress: _controller.value,
            color: widget.primaryColor,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _MapPulsePainter extends CustomPainter {
  final double progress;
  final Color color;

  _MapPulsePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.35);
    final maxRadius = size.width * 0.8;

    // Draw Grid (Map style)
    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double gridSize = 30.0;
    for (double i = 0; i < size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // Draw pulsing waves
    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + (i * 0.33)) % 1.0;
      final waveRadius = maxRadius * waveProgress;
      final waveOpacity = 1.0 - waveProgress;

      final wavePaint = Paint()
        ..color = color.withValues(alpha: waveOpacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, waveRadius, wavePaint);
      
      final fillPaint = Paint()
        ..color = color.withValues(alpha: waveOpacity * 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, waveRadius, fillPaint);
    }

    // Draw center pin (Location Marker)
    final pinPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
      
    final shadowPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      
    canvas.drawCircle(center, 12, shadowPaint);
    canvas.drawCircle(center, 8, pinPaint);
    canvas.drawCircle(center, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _MapPulsePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
