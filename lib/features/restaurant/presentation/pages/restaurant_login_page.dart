import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/services/ahyxi_otp_service.dart';
import '../../../../services/role_guard_service.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/pages/restaurant_dashboard_page.dart';
import 'restaurant_register_page.dart';

// --- Premium Light Turquoise Theme Palette ---
const Color _primary = Color(0xFF26A69A); // Vibrant Teal/Turquoise
const Color _accent = Color(0xFF00796B); // Deep Teal
const Color _gold = Color(0xFFFFB300); // Soft Gourmet Gold
const Color _lightBg = Color(0xFFF5F9F9); // Soft light turquoise background
const Color _textPrimary = Color(0xFF07191A); // Deep charcoal/teal text
const Color _textSecondary = Color(0xFF5A7375); // Slate grey-teal secondary text
const Color _cardBg = Colors.white; // Pure white card background

class RestaurantLoginPage extends StatefulWidget {
  const RestaurantLoginPage({super.key});

  @override
  State<RestaurantLoginPage> createState() => _RestaurantLoginPageState();
}

class _RestaurantLoginPageState extends State<RestaurantLoginPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _rememberMe = true;

  // Entrance animations
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Aesthetic loop animations
  late AnimationController _shimmerController;
  late AnimationController _liquidController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Smooth upward slide entrance on screen load
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.1, 1.0, curve: Curves.easeOutQuint),
      ),
    );
    _entranceController.forward();

    // Constant sweeps for the golden login button shimmer
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Liquid moving cosmic gradient waves
    _liquidController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Subtle star dust pulse controller
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadRememberedData();
  }

  Future<void> _loadRememberedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('restaurant_identifier');
      final savedPass = prefs.getString('restaurant_password');
      final remember = prefs.getBool('restaurant_remember') ?? true;

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
    _liquidController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String? _validateIdentifier(String? v) {
    final val = (v ?? '').trim();
    if (val.isEmpty) return 'يرجى إدخال البريد الإلكتروني أو رقم هاتف المطعم';
    if (!val.contains('@') && val.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
      return 'يرجى كتابة بريد إلكتروني صالح أو رقم هاتف صحيح';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if ((v ?? '').isEmpty) return 'كلمة المرور مطلوبة';
    return null;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final input = _identifier.text.trim();
      String emailToUse = input;

      // إذا كان الإدخال رقم هاتف، نستعلم عن البريد المسجل للمطعم
      if (!input.contains('@')) {
        final formattedPhone = AhyxiOtpService.formatIraqiPhoneNumber(input);

        // 1. البحث في كولكشن restaurants
        var qSnap = await FirebaseFirestore.instance
            .collection('restaurants')
            .where('phone', isEqualTo: formattedPhone)
            .limit(1)
            .get();

        if (qSnap.docs.isEmpty) {
          qSnap = await FirebaseFirestore.instance
              .collection('restaurants')
              .where('phone', isEqualTo: input)
              .limit(1)
              .get();
        }

        // 2. البحث في كولكشن users
        if (qSnap.docs.isEmpty) {
          qSnap = await FirebaseFirestore.instance
              .collection('users')
              .where('phone', isEqualTo: formattedPhone)
              .limit(1)
              .get();
        }
        if (qSnap.docs.isEmpty) {
          qSnap = await FirebaseFirestore.instance
              .collection('users')
              .where('phone', isEqualTo: input)
              .limit(1)
              .get();
        }

        if (qSnap.docs.isNotEmpty) {
          final foundEmail = qSnap.docs.first.data()['email'] as String?;
          if (foundEmail != null && foundEmail.isNotEmpty) {
            emailToUse = foundEmail;
          } else {
            throw FirebaseAuthException(
              code: 'user-not-found',
              message: 'لم يتم العثور على بريد إلكتروني مرتبط برقم هذا المطعم.',
            );
          }
        } else {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'رقم الهاتف غير مسجل كمطعم في منصة مدار.',
          );
        }
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToUse,
        password: _password.text,
      );
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('restaurant_identifier', _identifier.text.trim());
        await prefs.setString('restaurant_password', _password.text);
        await prefs.setBool('restaurant_remember', true);
      } else {
        await prefs.remove('restaurant_identifier');
        await prefs.remove('restaurant_password');
        await prefs.setBool('restaurant_remember', false);
      }

      if (!mounted) return;
      await RoleGuardService.validateRole(
        context: context,
        requiredRole: 'restaurant',
        deniedMessage: 'عذراً: هذا الحساب غير مسجل كمطعم شريك.',
        onPending: () async {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            _showPendingAccountDialog();
          }
        },
        onSuccess: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RestaurantDashboardPage()),
          );
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMsg = e.message ?? 'فشل تسجيل الدخول. تحقق من البيانات.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMsg = 'البريد الإلكتروني / رقم الهاتف أو كلمة المرور غير صحيحة';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  errorMsg,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ غير متوقع: $e'),
          backgroundColor: Colors.redAccent.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPendingAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 26),
            SizedBox(width: 10),
            Text('طلب المطعم قيد المراجعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أهلاً بك شريكنا العزيز! حساب مطعمك قيد التدقيق والمراجعة حالياً من قبل إدارة منصة مدار.',
              style: TextStyle(fontSize: 13.5, height: 1.5, color: _textPrimary),
            ),
            SizedBox(height: 10),
            Text(
              'سيتم فتح لوحة التحكم تلقائياً فور اعتماد حسابك. يمكنك أيضاً التواصل المباشر للتسريع.',
              style: TextStyle(fontSize: 12, height: 1.4, color: _textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _launchWhatsApp();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 16),
            label: const Text('تواصل عبر واتساب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final resetCtrl = TextEditingController(text: _identifier.text.trim());
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: _primary),
              SizedBox(width: 10),
              Text(
                'استعادة كلمة المرور',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'أدخل البريد الإلكتروني أو رقم هاتف المطعم المسجل لإرسال رابط إعادة تعيين كلمة المرور.',
                style: TextStyle(fontSize: 12.5, color: _textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: resetCtrl,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'البريد أو رقم الهاتف',
                  prefixIcon: const Icon(Icons.email_outlined, color: _primary, size: 20),
                  filled: true,
                  fillColor: _lightBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _primary.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _primary, width: 1.8),
                  ),
                ),
              ),
              if (isResetting) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator(color: _primary)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isResetting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء', style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: isResetting
                  ? null
                  : () async {
                      final input = resetCtrl.text.trim();
                      if (input.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('يرجى كتابة البريد أو رقم الهاتف')),
                        );
                        return;
                      }

                      setDialogState(() => isResetting = true);
                      try {
                        String emailToSend = input;
                        if (!input.contains('@')) {
                          final formattedPhone = AhyxiOtpService.formatIraqiPhoneNumber(input);
                          var q = await FirebaseFirestore.instance
                              .collection('restaurants')
                              .where('phone', isEqualTo: formattedPhone)
                              .limit(1)
                              .get();
                          if (q.docs.isEmpty) {
                            q = await FirebaseFirestore.instance
                                .collection('users')
                                .where('phone', isEqualTo: formattedPhone)
                                .limit(1)
                                .get();
                          }
                          if (q.docs.isNotEmpty) {
                            emailToSend = (q.docs.first.data()['email'] ?? '').toString();
                          }
                        }

                        if (emailToSend.isEmpty || !emailToSend.contains('@')) {
                          throw Exception('لم نعثر على بريد إلكتروني مرتبط بهذا الهاتف. تواصل مع الدعم الفني.');
                        }

                        await FirebaseAuth.instance.sendPasswordResetEmail(email: emailToSend);
                        if (mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم إرسال رابط استعادة كلمة المرور بنجاح إلى: $emailToSend'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isResetting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تعذر إرسال الرابط: ${e.toString().replaceAll('Exception: ', '')}'),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('إرسال الرابط', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchWhatsApp() async {
    final whatsappUrl = Uri.parse("https://wa.me/9647819436408");
    try {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عذراً، ما قدرنا نفتح واتساب تلقائياً. تواصل معنا على الرقم: 07819436408')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: ThemeData.light().copyWith(
          textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(ThemeData.light().textTheme),
        ),
        child: Scaffold(
          backgroundColor: _lightBg,
          body: Stack(
            children: [
              // 1. Full cover image background
              Positioned.fill(
                child: Image.asset(
                  'assets/images/restaurants_cover.png',
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(color: _lightBg),
                ),
              ),

              // Frosted glass and light turquoise gradient mask over the background image
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _lightBg.withValues(alpha: 0.75),
                          _lightBg.withValues(alpha: 0.88),
                          _lightBg,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Shifting Cosmic Liquid Turquoise Canvas
              AnimatedBuilder(
                animation: _liquidController,
                builder: (context, _) {
                  return Positioned.fill(
                    child: CustomPaint(
                      painter: LiquidTealPainter(
                        animationValue: _liquidController.value,
                      ),
                    ),
                  );
                },
              ),

              // 3. Sparkling Ambient Dust particles
              ..._buildAnimatedDustParticles(size),

              // 4. Main Center Floating Content (Frosted Scrollable Canvas)
              Positioned.fill(
                child: SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 60),

                          _buildPremiumHeader(),
                          const SizedBox(height: 40),

                          // 5. Glowing 3D Glassmorphic Card (Elevated & Animating upwards)
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: _buildGlassLoginCard(),
                            ),
                          ),

                          const SizedBox(height: 25),

                          // 6. Actions Footer beautifully sitting outside the main card
                          _buildGlassActionsFooter(),
                          const SizedBox(height: 35),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassLoginCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
        child: Container(
          decoration: BoxDecoration(
            color: _cardBg.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 40,
                spreadRadius: 2,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: _primary.withValues(alpha: 0.05),
                blurRadius: 20,
                spreadRadius: -5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // Premium Custom inputs
                  PremiumLightTextField(
                    controller: _identifier,
                    label: 'البريد الإلكتروني أو رقم هاتف المطعم',
                    icon: Icons.storefront_rounded,
                    validator: _validateIdentifier,
                    keyboard: TextInputType.text,
                  ),
                  const SizedBox(height: 20),

                  PremiumLightTextField(
                    controller: _password,
                    label: 'كلمة المرور',
                    icon: Icons.lock_outline_rounded,
                    validator: _validatePassword,
                    obscure: _obscure,
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: _primary.withValues(alpha: 0.6),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildRememberMe(),
                      _buildForgotPasswordButton(),
                    ],
                  ),
                  const SizedBox(height: 30),

                  _buildLoginButton(),
                  const SizedBox(height: 16),

                  _buildRegisterButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassActionsFooter() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.03),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            children: [
              _buildWhatsAppButton(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAnimatedDustParticles(Size size) {
    return [
      // Particle 1 (Teal - Top Right)
      AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final offset = 10 * math.sin(_pulseController.value * 2 * math.pi);
          return Positioned(
            top: size.height * 0.15 + offset,
            right: size.width * 0.15 + (6 * math.cos(_pulseController.value * 2 * math.pi)),
            child: Icon(
              Icons.blur_on_rounded,
              size: 10,
              color: _primary.withValues(alpha: 0.2 + (0.2 * _pulseAnimation.value)),
            ),
          );
        },
      ),
      // Particle 2 (Gold - Center Left)
      AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final offset = 12 * math.cos(_pulseController.value * 2 * math.pi);
          return Positioned(
            top: size.height * 0.28 + offset,
            left: size.width * 0.10 + (8 * math.sin(_pulseController.value * 2 * math.pi)),
            child: Icon(
              Icons.stars_sharp,
              size: 8,
              color: _gold.withValues(alpha: 0.15 + (0.15 * _pulseAnimation.value)),
            ),
          );
        },
      ),
    ];
  }

  Widget _buildPremiumHeader() {
    return Column(
      children: [
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            return ShaderMask(
              shaderCallback: (bounds) {
                final shimmerTranslate = _shimmerController.value * 3 - 1;
                return LinearGradient(
                  colors: const [
                    _textPrimary,
                    _primary,
                    _accent,
                    _gold,
                    _textPrimary,
                  ],
                  stops: [
                    0.0,
                    (0.3 + shimmerTranslate).clamp(0.0, 1.0),
                    (0.5 + shimmerTranslate).clamp(0.0, 1.0),
                    (0.7 + shimmerTranslate).clamp(0.0, 1.0),
                    1.0,
                  ],
                ).createShader(bounds);
              },
              child: child!,
            );
          },
          child: const Text(
            'مدار للمطاعم',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: _textPrimary,
              letterSpacing: 1.2,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Glowing divider line
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, _) {
            final lineWidth = 40 + (_pulseAnimation.value * 25);
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: lineWidth,
                  height: 2.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _primary.withValues(alpha: 0.0),
                        _primary.withValues(alpha: _pulseAnimation.value * 0.9),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.restaurant_rounded,
                  size: 16,
                  color: _primary.withValues(alpha: 0.7 + (_pulseAnimation.value * 0.3)),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: lineWidth,
                  height: 2.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _primary.withValues(alpha: _pulseAnimation.value * 0.9),
                        _primary.withValues(alpha: 0.0),
                      ],
                    ),
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
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                activeColor: _primary,
                checkColor: Colors.white,
                side: BorderSide(color: _textSecondary.withValues(alpha: 0.4), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'تذكرني',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForgotPasswordButton() {
    return TextButton(
      onPressed: _showForgotPasswordDialog,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        'نسيت كلمة المرور؟',
        style: TextStyle(
          color: _primary,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final shimmerVal = _shimmerController.value;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: _loading
                ? null
                : LinearGradient(
                    colors: const [
                      _primary,
                      Color(0xFF00BFA5),
                      _primary,
                    ],
                    stops: [
                      0.0,
                      shimmerVal.clamp(0.0, 1.0),
                      1.0,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: _loading ? Colors.grey[200] : null,
            boxShadow: _loading
                ? null
                : [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
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
                      _login();
                    },
              borderRadius: BorderRadius.circular(18),
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
                            'دخول لوحة التحكم',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(
                            Icons.login_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRegisterButton() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.2),
            border: Border.all(
              color: _primary.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _loading
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => const RestaurantRegisterPage(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
              borderRadius: BorderRadius.circular(18),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'سجل مطعمك الآن',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(
                      Icons.add_business_rounded,
                      color: _primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWhatsAppButton() {
    return OutlinedButton.icon(
      onPressed: _launchWhatsApp,
      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 18),
      label: const Text(
        'تواصل معنا للتفعيل الفوري عبر واتساب',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: _textSecondary,
          fontSize: 12.5,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: _primary.withValues(alpha: 0.15), width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// ─── Custom Premium Light Text Field ───
class PremiumLightTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?) validator;
  final TextInputType? keyboard;
  final bool obscure;
  final Widget? suffix;
  final Color primaryColor;

  const PremiumLightTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.keyboard,
    this.obscure = false,
    this.suffix,
    this.primaryColor = _primary,
  });

  @override
  State<PremiumLightTextField> createState() => _PremiumLightTextFieldState();
}

class _PremiumLightTextFieldState extends State<PremiumLightTextField>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  bool _isFocused = false;
  late AnimationController _fieldController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
      if (_isFocused) {
        _fieldController.forward();
      } else {
        _fieldController.reverse();
      }
    });

    _fieldController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.015).animate(
      CurvedAnimation(parent: _fieldController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _fieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: _isFocused ? Colors.white : const Color(0xFFF0F7F7),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _isFocused ? widget.primaryColor.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.01),
              blurRadius: _isFocused ? 14 : 6,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: _isFocused ? widget.primaryColor : _primary.withValues(alpha: 0.06),
            width: _isFocused ? 1.5 : 1.0,
          ),
        ),
        child: TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          keyboardType: widget.keyboard,
          obscureText: widget.obscure,
          validator: widget.validator,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          cursorColor: widget.primaryColor,
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(
              color: _isFocused ? widget.primaryColor : _textSecondary,
              fontSize: 13,
              fontWeight: _isFocused ? FontWeight.bold : FontWeight.w600,
            ),
            prefixIcon: Icon(
              widget.icon,
              color: _isFocused ? widget.primaryColor : widget.primaryColor.withValues(alpha: 0.6),
              size: 20,
            ),
            suffixIcon: widget.suffix,
            filled: true,
            fillColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            errorStyle: const TextStyle(
              fontSize: 11,
              color: Colors.redAccent,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Liquid Teal background painter drawing glowing soft light teal waves ───
class LiquidTealPainter extends CustomPainter {
  final double animationValue;

  LiquidTealPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Solid light background base
    paint.color = _lightBg;
    canvas.drawRect(Offset.zero & size, paint);

    // Orb 1: Glowing soft turquoise (Moving slowly in figure-8 loop)
    final dx1 = size.width * (0.5 + 0.32 * math.sin(animationValue * 2 * math.pi));
    final dy1 = size.height * (0.32 + 0.14 * math.cos(animationValue * 4 * math.pi));
    final radius1 = size.width * (0.65 + 0.08 * math.sin(animationValue * 2 * math.pi));
    paint.shader = RadialGradient(
      colors: [
        _primary.withValues(alpha: 0.10),
        _primary.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromCircle(center: Offset(dx1, dy1), radius: radius1));
    canvas.drawCircle(Offset(dx1, dy1), radius1, paint);

    // Orb 2: Soft Gold (Orbiting counter-clockwise at bottom-left)
    final dx2 = size.width * (0.22 + 0.16 * math.cos(animationValue * 2 * math.pi));
    final dy2 = size.height * (0.76 + 0.10 * math.sin(animationValue * 2 * math.pi));
    final radius2 = size.width * (0.55 + 0.05 * math.cos(animationValue * 2 * math.pi));
    paint.shader = RadialGradient(
      colors: [
        _gold.withValues(alpha: 0.05),
        _gold.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromCircle(center: Offset(dx2, dy2), radius: radius2));
    canvas.drawCircle(Offset(dx2, dy2), radius2, paint);

    // Orb 3: Light Teal Accent (Moving along top-right diagonal)
    final dx3 = size.width * (0.78 - 0.18 * math.sin(animationValue * 2 * math.pi));
    final dy3 = size.height * (0.22 + 0.08 * math.cos(animationValue * 2 * math.pi));
    final radius3 = size.width * (0.50 + 0.06 * math.sin(animationValue * 2 * math.pi));
    paint.shader = RadialGradient(
      colors: [
        _primary.withValues(alpha: 0.08),
        _primary.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromCircle(center: Offset(dx3, dy3), radius: radius3));
    canvas.drawCircle(Offset(dx3, dy3), radius3, paint);
  }

  @override
  bool shouldRepaint(covariant LiquidTealPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
