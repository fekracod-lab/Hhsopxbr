import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/pos_language_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/restaurant_categories.dart';
import '../../../../services/role_guard_service.dart';
import '../../../../services/offline_auth_service.dart';
import '../../../shell/presentation/desktop_shell_page.dart';
import 'restaurant_welcome_page.dart';

class RestaurantLoginPage extends StatefulWidget {
  const RestaurantLoginPage({super.key});

  @override
  State<RestaurantLoginPage> createState() => _RestaurantLoginPageState();
}

class _RestaurantLoginPageState extends State<RestaurantLoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  bool _rememberMe = true;

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _loadRememberedData();
    OfflineAuthService.instance.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('restaurant_remember') ?? true;
      if (remember) {
        final id = prefs.getString('restaurant_identifier');
        final pw = prefs.getString('restaurant_password');
        if (mounted) {
          setState(() {
            _rememberMe = true;
            if (id != null) _identifierController.text = id;
            if (pw != null) _passwordController.text = pw;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _identifierController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('restaurant_identifier', _identifierController.text.trim());
        await prefs.setString('restaurant_password', _passwordController.text);
        await prefs.setBool('restaurant_remember', true);
      } else {
        await prefs.remove('restaurant_identifier');
        await prefs.remove('restaurant_password');
        await prefs.setBool('restaurant_remember', false);
      }

      if (!mounted) return;
      final isEn = PosLanguageController.instance.isEnglish;
      await RoleGuardService.validateRole(
        context: context,
        requiredRole: 'merchant',
        deniedMessage: isEn
            ? 'Sorry: This account is not registered as a partner restaurant in Madar system.'
            : 'عذراً: هذا الحساب غير مسجل كمطعم شريك في منظومة مدار.',
        onPending: () async {
          await FirebaseAuth.instance.signOut();
        },
        onSuccess: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await OfflineAuthService.instance.cacheOnlineCredentials(
              uid: user.uid,
              email: _identifierController.text.trim(),
              password: _passwordController.text,
              restaurantName: user.displayName ?? 'مطعم مدار',
              ownerName: 'صاحب المطعم',
            );
          }
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DesktopShellPage()),
            );
          }
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final isEn = PosLanguageController.instance.isEnglish;
      String errorMsg = isEn ? 'Login failed. Please check your credentials.' : 'فشل تسجيل الدخول. تأكد من البيانات.';

      // التحويل التلقائي للمصادقة بدون إنترنت في حال انقطاع الشبكة
      if (e.code == 'network-request-failed' || e.code == 'unavailable') {
        final offlineResult = await OfflineAuthService.instance.authenticateOffline(
          email: _identifierController.text.trim(),
          password: _passwordController.text,
        );
        if (offlineResult.success) {
          _showToast(
            isEn ? 'Logged in offline successfully!' : 'تم تسجيل الدخول في وضع عدم الاتصال (أوفلاين) بنجاح!',
            isError: false,
          );
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DesktopShellPage()),
            );
          }
          return;
        } else {
          errorMsg = isEn
              ? 'No internet connection and credentials mismatch. Use Quick PIN or Local Setup.'
              : 'لا يوجد اتصال بالإنترنت والبيانات غير مطابقة للحساب المحفوظ. استخدم رمز PIN أو أسّس مطعماً محلياً.';
        }
      } else if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMsg = isEn ? 'Invalid email or password.' : 'البريد الإلكتروني أو رمز المرور غير صحيح.';
      }
      _showToast(errorMsg, isError: true);
    } catch (e) {
      if (!mounted) return;
      // محاولة فحص الأوفلاين في حال حدوث أي خطأ غير متوقع في الاتصال
      final offlineResult = await OfflineAuthService.instance.authenticateOffline(
        email: _identifierController.text.trim(),
        password: _passwordController.text,
      );
      if (offlineResult.success) {
        _showToast('تم تسجيل الدخول في وضع الأوفلاين بنجاح.', isError: false);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DesktopShellPage()),
          );
        }
        return;
      }
      final isEn = PosLanguageController.instance.isEnglish;
      _showToast(isEn ? 'An error occurred during login: $e' : 'صار خطأ أثناء تسجيل الدخول: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent.shade700 : PosTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _openWhatsAppSupport() async {
    final uri = Uri.parse(
        'https://wa.me/9647700000000?text=${Uri.encodeComponent('مرحباً فريق مدار سيستم، عندي استفسار بخصوص تسجيل الدخول لنظام المطاعم.')}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) _showToast('تعذر فتح واتساب تلقائياً.');
      }
    } catch (_) {
      if (mounted) _showToast('تعذر فتح واتساب.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PosLanguageController.instance,
      builder: (context, _) {
        final size = MediaQuery.of(context).size;
        final isDesktop = size.width >= 960;
        final textDir = PosLanguageController.instance.textDirection;

        return Directionality(
          textDirection: textDir,
          child: Scaffold(
            backgroundColor: PosTheme.bgDark,
            body: Stack(
              children: [
                // Background ambient lights
                Positioned(
                  top: -150,
                  right: -100,
                  child: Container(
                    width: 500,
                    height: 500,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PosTheme.primaryDark.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -200,
                  left: -120,
                  child: Container(
                    width: 600,
                    height: 600,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PosTheme.accent.withValues(alpha: 0.12),
                    ),
                  ),
                ),

                SafeArea(
                  child: isDesktop ? _buildDesktopView() : _buildMobileView(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopView() {
    return Row(
      children: [
        // Right Panel: Ecosystem, Cuisines & Madar Identity
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSystemIdentityHeader(),
                const SizedBox(height: 28),
                _buildGreetingCard(),
                const SizedBox(height: 24),
                _buildCuisinesShowcase(),
                const Spacer(),
                _buildSystemFeaturesBar(),
              ],
            ),
          ),
        ),

        // Left Panel: Login Terminal Glass Card
        Expanded(
          flex: 5,
          child: Center(
            child: Container(
              width: 480,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: PosTheme.surfaceDark.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: PosTheme.borderDark),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 40,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: _buildLoginForm(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSystemIdentityHeader(),
          const SizedBox(height: 20),
          _buildGreetingCard(),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: PosTheme.surfaceDark,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: PosTheme.borderDark),
            ),
            child: _buildLoginForm(),
          ),
          const SizedBox(height: 24),
          _buildCuisinesShowcase(),
          const SizedBox(height: 24),
          _buildSystemFeaturesBar(),
        ],
      ),
    );
  }

  Widget _buildSystemIdentityHeader() {
    final isEn = PosLanguageController.instance.isEnglish;
    return Row(
      children: [
        // App Icon
        Container(
          width: 52,
          height: 52,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: PosTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PosTheme.accent.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: PosTheme.accent.withValues(alpha: 0.25),
                blurRadius: 18,
              ),
            ],
          ),
          child: Image.asset(
            'assets/logo.png',
            errorBuilder: (_, _, _) => const Icon(
              Icons.restaurant_menu_rounded,
              color: PosTheme.accent,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'MADAR POS SYSTEM',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: PosTheme.primaryDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: PosTheme.accent.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    isEn ? 'Windows Enterprise' : 'نظام ويندوز المعتمد',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: PosTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              isEn ? 'Cloud Restaurant Management & POS System' : 'منظومة إدارة المطاعم ونقاط البيع السحابية • القائم',
              style: GoogleFonts.ibmPlexSansArabic(
                color: PosTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const Spacer(),
        // Language Toggle Button
        Tooltip(
          message: isEn ? 'Switch to Arabic' : 'التحويل إلى الإنجليزية',
          child: InkWell(
            onTap: () => PosLanguageController.instance.toggle(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: PosTheme.surfaceDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PosTheme.borderDark),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language_rounded, size: 15, color: PosTheme.accent),
                  const SizedBox(width: 5),
                  Text(
                    isEn ? 'EN' : 'عربي',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: PosTheme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Help / Tour button
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RestaurantWelcomePage()),
            );
          },
          tooltip: isEn ? 'System Tour & Features' : 'شرح ومزايا النظام',
          icon: const Icon(Icons.help_outline_rounded, color: PosTheme.accent),
        ),
      ],
    );
  }

  Widget _buildGreetingCard() {
    final isEn = PosLanguageController.instance.isEnglish;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PosTheme.surfaceDark.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PosTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.waving_hand_rounded, color: PosTheme.gold, size: 22),
              const SizedBox(width: 10),
              Text(
                isEn ? 'Welcome to Madar POS System!' : 'يا هلا بيك بنظام مدار للمطاعم!',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isEn
                ? 'Sign in to start receiving orders and manage tables with silent printing and live cloud sync.'
                : 'سجّل دخولك وبلّش استلم طلبات زباينك وطاولاتك بلحظتها مع الطباعة المباشرة وربط تطبيق مدار التلقائي.',
            style: GoogleFonts.ibmPlexSansArabic(
              color: PosTheme.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCuisinesShowcase() {
    final isEn = PosLanguageController.instance.isEnglish;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.restaurant_rounded, color: PosTheme.accent, size: 18),
            const SizedBox(width: 8),
            Text(
              isEn ? 'Supported Dining Categories in Madar:' : 'مجموعات وتسجيل المطاعم في تطبيق مدار:',
              style: GoogleFonts.ibmPlexSansArabic(
                color: PosTheme.textLight,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              isEn ? '10 Specialities' : '10 تخصصات معتمدة',
              style: GoogleFonts.ibmPlexSansArabic(
                color: PosTheme.gold,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MadarRestaurantCategories.all.map((cat) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: PosTheme.cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cat.accentColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cat.icon, color: cat.accentColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    cat.title,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: PosTheme.textLight,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSystemFeaturesBar() {
    final isEn = PosLanguageController.instance.isEnglish;
    final items = [
      {'icon': Icons.print_rounded, 'label': isEn ? 'Silent ESC/POS' : 'طباعة صامتة ESC/POS'},
      {'icon': Icons.qr_code_2_rounded, 'label': isEn ? 'Table QR Menu' : 'منيو QR للطاولات'},
      {'icon': Icons.soup_kitchen_rounded, 'label': isEn ? 'Live Kitchen KDS' : 'شاشة المطبخ KDS'},
      {'icon': Icons.wifi_off_rounded, 'label': isEn ? 'Offline SQLite' : 'أوفلاين SQLite'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: PosTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosTheme.borderDark),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((it) {
          return Row(
            children: [
              Icon(it['icon'] as IconData, color: PosTheme.accent, size: 16),
              const SizedBox(width: 6),
              Text(
                it['label'] as String,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: PosTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLoginForm() {
    final isEn = PosLanguageController.instance.isEnglish;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_person_rounded, color: PosTheme.accent, size: 24),
              const SizedBox(width: 10),
              Text(
                isEn ? 'Terminal Sign In' : 'تسجيل الدخول للمنظومة',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isEn ? 'Enter restaurant credentials to continue' : 'ادخل بيانات حساب مطعمك للمتابعة',
            style: GoogleFonts.ibmPlexSansArabic(
              color: PosTheme.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),

          // Email Input
          Text(
            isEn ? 'Restaurant Email' : 'البريد الإلكتروني للمطعم',
            style: GoogleFonts.ibmPlexSansArabic(
              color: PosTheme.textLight,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _identifierController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            keyboardType: TextInputType.emailAddress,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return isEn ? 'Please enter restaurant email' : 'اكتب الإيميل الخاص بالمطعم';
              }
              if (!val.contains('@')) {
                return isEn ? 'Invalid email address' : 'صيغة البريد مو صحيحة';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'restaurant@madar.iq',
              hintStyle: const TextStyle(color: PosTheme.textDisabled, fontSize: 13),
              prefixIcon: const Icon(Icons.alternate_email_rounded, color: PosTheme.accent, size: 20),
              filled: true,
              fillColor: PosTheme.cardDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: PosTheme.borderDark),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: PosTheme.borderDark),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: PosTheme.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Password Input
          Text(
            isEn ? 'Password' : 'كلمة المرور',
            style: GoogleFonts.ibmPlexSansArabic(
              color: PosTheme.textLight,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscure,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return isEn ? 'Please enter password' : 'اكتب كلمة المرور';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: const TextStyle(color: PosTheme.textDisabled, fontSize: 16),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: PosTheme.accent, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: PosTheme.textMuted,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              filled: true,
              fillColor: PosTheme.cardDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: PosTheme.borderDark),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: PosTheme.borderDark),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: PosTheme.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Remember Me Checkbox
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _rememberMe,
                  activeColor: PosTheme.accent,
                  checkColor: Colors.black,
                  onChanged: (v) => setState(() => _rememberMe = v ?? true),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isEn ? 'Remember restaurant on this device' : 'تذكر حساب المطعم على هذا الجهاز',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: PosTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: PosTheme.accent,
                disabledBackgroundColor: PosTheme.accent.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.login_rounded, color: Colors.black, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isEn ? 'Sign In to System' : 'تسجيل الدخول للمنظومة',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Offline-First Access Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: PosTheme.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PosTheme.accent.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: PosTheme.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isEn ? 'Offline-First Access' : 'الدخول بدون إنترنت (أوفلاين)',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: PosTheme.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: PosTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: PosTheme.borderDark),
                      ),
                      child: Text(
                        isEn ? 'No Internet Required' : 'بدون إنترنت نهائياً',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: PosTheme.success,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (OfflineAuthService.instance.hasAnyCachedMerchant) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: PosTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: PosTheme.borderDark),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_rounded, size: 15, color: PosTheme.gold),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isEn
                                ? 'Cached: ${OfflineAuthService.instance.cachedRestaurantName}'
                                : 'المطعم المحفوظ: ${OfflineAuthService.instance.cachedRestaurantName}',
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: PosTheme.textLight,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  isEn
                      ? 'No internet? Use Cashier PIN or initialize a local restaurant directly.'
                      : 'إذا ماكو إنترنت بالمطعم، استخدم رمز PIN السريع أو شغّل مطعمك محلياً مباشرة.',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: PosTheme.textMuted,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showPinLoginDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PosTheme.surfaceDark,
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: PosTheme.accent, width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.pin_rounded, size: 16, color: PosTheme.accent),
                        label: Text(
                          isEn ? 'Quick PIN' : 'دخول برمز PIN',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showCreateLocalRestaurantDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PosTheme.gold,
                          side: BorderSide(color: PosTheme.gold.withValues(alpha: 0.6)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.add_business_rounded, size: 16, color: PosTheme.gold),
                        label: Text(
                          isEn ? 'Local Setup' : 'تأسيس محلي',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Secondary Quick Actions (Demo & WhatsApp)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const DesktopShellPage()),
                  );
                },
                icon: const Icon(Icons.play_circle_outline_rounded, color: PosTheme.textMuted, size: 16),
                label: Text(
                  isEn ? 'Offline Demo Cashier' : 'كاشير تجريبي أوفلاين',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: PosTheme.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _openWhatsAppSupport,
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: PosTheme.accent, size: 16),
                label: Text(
                  isEn ? 'Madar Support' : 'دعم مدار الفني',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: PosTheme.accent,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPinLoginDialog() {
    final pinController = TextEditingController();
    final isEn = PosLanguageController.instance.isEnglish;
    String errorMessage = '';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          void submitPin() async {
            final pin = pinController.text.trim();
            if (pin.isEmpty) {
              setDlgState(() => errorMessage = isEn ? 'Enter 4-digit PIN' : 'أدخل رمز الـ PIN');
              return;
            }
            final navigator = Navigator.of(context);
            final res = await OfflineAuthService.instance.authenticateWithPin(pin);
            if (res.success) {
              if (ctx.mounted) Navigator.pop(ctx);
              _showToast(
                isEn ? 'Logged in offline successfully!' : 'تم الدخول بنجاح برمز PIN (وضع أوفلاين)!',
                isError: false,
              );
              navigator.pushReplacement(
                MaterialPageRoute(builder: (_) => const DesktopShellPage()),
              );
            } else {
              setDlgState(() => errorMessage = res.message);
            }
          }

          return Dialog(
            backgroundColor: PosTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: PosTheme.borderDark),
            ),
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: PosTheme.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pin_rounded, color: PosTheme.accent, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isEn ? 'Cashier Quick PIN Login' : 'تسجيل دخول الكاشير السريع',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isEn
                        ? 'Enter 4-digit PIN (Default: 0000) for instant offline POS access'
                        : 'أدخل رمز PIN للكاشير (الافتراضي: 0000) للبدء بدون إنترنت',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: PosTheme.textMuted),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    maxLength: 6,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: PosTheme.accent,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••',
                      hintStyle: const TextStyle(color: PosTheme.textDisabled, letterSpacing: 8),
                      filled: true,
                      fillColor: PosTheme.cardDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: PosTheme.borderDark),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: PosTheme.accent, width: 2),
                      ),
                    ),
                    onSubmitted: (_) => submitPin(),
                  ),
                  if (errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMessage,
                      style: GoogleFonts.ibmPlexSansArabic(color: Colors.redAccent, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: PosTheme.borderDark),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            isEn ? 'Cancel' : 'إلغاء',
                            style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textMuted),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: submitPin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PosTheme.accent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            isEn ? 'Sign In' : 'دخول',
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreateLocalRestaurantDialog() {
    final nameCtrl = TextEditingController(text: 'مطعم محلي');
    final ownerCtrl = TextEditingController(text: 'كاشير المحطة');
    final cityCtrl = TextEditingController(text: 'القائم');
    final pinCtrl = TextEditingController(text: '0000');
    final isEn = PosLanguageController.instance.isEnglish;
    String errorMsg = '';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          void submitCreate() async {
            if (nameCtrl.text.trim().isEmpty) {
              setDlgState(() => errorMsg = isEn ? 'Enter restaurant name' : 'اكتب اسم المطعم');
              return;
            }
            final navigator = Navigator.of(context);
            final res = await OfflineAuthService.instance.createLocalOfflineRestaurant(
              restaurantName: nameCtrl.text.trim(),
              ownerName: ownerCtrl.text.trim(),
              city: cityCtrl.text.trim(),
              pin: pinCtrl.text.trim().isNotEmpty ? pinCtrl.text.trim() : '0000',
            );
            if (res.success) {
              if (ctx.mounted) Navigator.pop(ctx);
              _showToast(
                isEn ? 'Local restaurant initialized successfully!' : 'تم تأسيس المطعم المحلي بنجاح وبدء العمل!',
                isError: false,
              );
              navigator.pushReplacement(
                MaterialPageRoute(builder: (_) => const DesktopShellPage()),
              );
            } else {
              setDlgState(() => errorMsg = res.message);
            }
          }

          return Dialog(
            backgroundColor: PosTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: PosTheme.borderDark),
            ),
            child: Container(
              width: 440,
              padding: const EdgeInsets.all(28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: PosTheme.gold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.storefront_rounded, color: PosTheme.gold, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEn ? 'Setup Local Offline Restaurant' : 'تأسيس مطعم محلي أوفلاين بالكامل',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                isEn
                                    ? 'For restaurants operating permanently without internet'
                                    : 'مخصص للمطاعم التي تعمل بدون إنترنت بصورة دائمة',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: PosTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isEn ? 'Restaurant Name' : 'اسم المطعم',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: PosTheme.textLight, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'مثال: مطعم ومشويات القائم',
                        filled: true,
                        fillColor: PosTheme.cardDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: PosTheme.borderDark)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isEn ? 'Cashier / Manager Name' : 'اسم الكاشير أو المسؤول',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: PosTheme.textLight, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: ownerCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'مثال: أحمد علي',
                        filled: true,
                        fillColor: PosTheme.cardDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: PosTheme.borderDark)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEn ? 'City' : 'المدينة',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: PosTheme.textLight, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: cityCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'القائم',
                                  filled: true,
                                  fillColor: PosTheme.cardDark,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: PosTheme.borderDark)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEn ? 'Cashier PIN' : 'رمز PIN للدخول',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: PosTheme.textLight, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: pinCtrl,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: '0000',
                                  filled: true,
                                  fillColor: PosTheme.cardDark,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: PosTheme.borderDark)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (errorMsg.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(errorMsg, style: GoogleFonts.ibmPlexSansArabic(color: Colors.redAccent, fontSize: 12)),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: PosTheme.borderDark),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(isEn ? 'Cancel' : 'إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textMuted)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: submitCreate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PosTheme.gold,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              isEn ? 'Start POS Now' : 'بدء العمل فورياً',
                              style: GoogleFonts.ibmPlexSansArabic(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

