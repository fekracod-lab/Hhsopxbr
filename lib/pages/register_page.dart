import 'package:dalal_alqaim/shared/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import 'package:dalal_alqaim/widgets/app_tour_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';


// --- Corporate Palette (Teal & Clean) ---
// نفس لوحة الألوان المستخدمة في صفحة تسجيل الدخول لتوحيد الهوية
const Color primaryColor = Color(0xFF26A69A);
const Color accentColor = Color(0xFF00796B);
const Color backgroundColor = Color(0xFFFFFFFF);
const Color textColor = Color(0xFF333333);
const Color hintColor = Color(0xFF9E9E9E);
const Color subTextColor = Color(0xFF757575);
const Color surfaceColor = Color(0xFFF8F9FA);

// Dark Mode Palette
const Color darkBackground = Color(0xFF07191A);
const Color darkSurface = Color(0xFF0F2323);
const Color darkCard = Color(0xFF113033);
const Color darkText = Color(0xFFE0F2F1);
const Color darkSubText = Color(0xFF80CBC4);
const Color darkHint = Color(0xFF4DB6AC);

class EnhancedRegisterPage extends StatefulWidget {
  const EnhancedRegisterPage({super.key});

  @override
  State<EnhancedRegisterPage> createState() => _EnhancedRegisterPageState();
}

class _EnhancedRegisterPageState extends State<EnhancedRegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  double _passwordStrength = 0.0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final GlobalKey _usernameKey = GlobalKey();
  final GlobalKey _emailKey = GlobalKey();
  final GlobalKey _passwordKey = GlobalKey();
  final GlobalKey _registerKey = GlobalKey();

  bool _showTour = false;

  @override
  void initState() {
    super.initState();
    _checkTourStatus();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart));

    _animationController.forward();
    _passwordController.addListener(_onPasswordChanged);
  }

  Future<void> _checkTourStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool tourShown = prefs.getBool('app_tour_completed') ?? false;
    if (!tourShown) {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        setState(() => _showTour = true);
      }
    }
  }

  Future<void> _onTourComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_tour_completed', true);
    setState(() => _showTour = false);
  }

  void _onPasswordChanged() => _checkPasswordStrength(_passwordController.text);

  void _checkPasswordStrength(String password) {
    double strength = 0.0;
    if (password.isEmpty) {
      setState(() => _passwordStrength = 0.0);
      return;
    }
    if (password.length >= 8) strength += 0.25;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.25;
    if (password.contains(RegExp(r'[!@#\$%\^&\*(),.?":{}|<>]'))) strength += 0.1;
    setState(() => _passwordStrength = strength.clamp(0.0, 1.0));
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    if (!_agreeToTerms) {
      setState(() => _error = 'يجب الموافقة على الشروط والأحكام أولاً');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // حفظ بيانات المستخدم الإضافية
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'user',
      });

      if (!mounted) return;
      await _showSuccessDialog();
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _error = 'البريد الإلكتروني مسجل مسبقاً.';
            break;
          case 'invalid-email':
            _error = 'صيغة البريد الإلكتروني غير صحيحة.';
            break;
          case 'weak-password':
            _error = 'كلمة المرور ضعيفة جداً.';
            break;
          default:
            _error = 'حدث خطأ أثناء إنشاء الحساب.';
        }
      });
    } catch (_) {
      setState(() => _error = 'صار خطأ، حاول مرة ثانية، حاول مرة ثانية بعد شوية.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showSuccessDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: isDark ? darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: primaryColor, size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  'تم إنشاء الحساب',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: isDark ? darkText : textColor,
                  ),
                ),
              ],
            ),
            content: Text(
              'أهلاً بك في ${AppConstants.appName}! تم تسجيل حسابك بنجاح.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? darkSubText : subTextColor),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(); // Close dialog
                    Navigator.of(context).pop(); // Return to Login
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'المتابعة لتسجيل الدخول',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Color _getPasswordStrengthColor() {
    if (_passwordStrength <= 0.3) return Colors.redAccent;
    if (_passwordStrength <= 0.6) return Colors.orangeAccent;
    return Colors.green;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Size size = MediaQuery.of(context).size;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? darkBackground : primaryColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          systemOverlayStyle: SystemUiOverlayStyle.light,
          actions: [
            IconButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                setState(() => _showTour = true);
              },
              icon: const Icon(Icons.help_outline_rounded, color: Colors.white70),
              tooltip: 'تعليمات الاستخدام',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            Stack(
              children: [
                // زخرفة خلفية بسيطة
                Positioned(
                  top: -80,
                  left: -40,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Column(
                  children: [
                    // --- 1. Brand Header Section (Consistent with Login) ---
                    SizedBox(
                      height: size.height * 0.22, // مساحة أقل قليلاً من تسجيل الدخول
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Image.asset(
                                      'imges/dala_alqaim_logo.png',
                                      width: 32,
                                      height: 32,
                                      color: Colors.white,
                                      errorBuilder:
                                          (c, e, s) => const Icon(
                                            Icons.language,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    AppConstants.appName,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Text(
                                'حساب جديد،\nبداية لرحلة جديدة',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // --- 2. Form Section (Bottom Sheet Style) ---
                    Expanded(
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? darkBackground : backgroundColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                              physics: const BouncingScrollPhysics(),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (_error != null) _buildErrorAlert(isDark),
                                    // Username
                                    _buildLabel('اسم المستخدم', isDark),
                                    const SizedBox(height: 8),
                                    _buildEnterpriseTextField(
                                      key: _usernameKey,
                                      controller: _usernameController,
                                      hint: 'أحمد محمد',
                                      icon: Icons.person_outline_rounded,
                                      isDark: isDark,
                                      validator:
                                          (v) =>
                                              (v == null || v.length < 3)
                                                  ? 'يجب أن يكون الاسم 3 أحرف على الأقل'
                                                  : null,
                                    ),
                                    const SizedBox(height: 20),
                                    // Email
                                    _buildLabel('البريد الإلكتروني', isDark),
                                    const SizedBox(height: 8),
                                    _buildEnterpriseTextField(
                                      key: _emailKey,
                                      controller: _emailController,
                                      hint: 'ahmed@example.com',
                                      icon: Icons.email_outlined,
                                      isDark: isDark,
                                      keyboardType: TextInputType.emailAddress,
                                      validator:
                                          (v) =>
                                              (v == null || !v.contains('@'))
                                                  ? 'البريد الإلكتروني غير صالح'
                                                  : null,
                                    ),
                                    const SizedBox(height: 20),
                                    // Password
                                    _buildLabel('كلمة المرور', isDark),
                                    const SizedBox(height: 8),
                                    _buildEnterpriseTextField(
                                      key: _passwordKey,
                                      controller: _passwordController,
                                      hint: '••••••••',
                                      icon: Icons.lock_outline,
                                      isDark: isDark,
                                      obscureText: _obscurePassword,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: isDark ? darkHint : hintColor,
                                          size: 20,
                                        ),
                                        onPressed:
                                            () => setState(
                                              () => _obscurePassword = !_obscurePassword,
                                            ),
                                      ),
                                      validator:
                                          (v) =>
                                              (v == null || v.length < 6)
                                                  ? 'كلمة المرور قصيرة (6 أحرف على الأقل)'
                                                  : null,
                                    ),
                                    // Password Strength Indicator
                                    if (_passwordController.text.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: _passwordStrength,
                                                backgroundColor:
                                                    isDark ? Colors.white10 : Colors.grey[200],
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  _getPasswordStrengthColor(),
                                                ),
                                                minHeight: 4,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            _passwordStrength < 0.3
                                                ? 'ضعيفة'
                                                : (_passwordStrength < 0.7 ? 'متوسطة' : 'قوية'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _getPasswordStrengthColor(),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 20),
                                    // Confirm Password
                                    _buildLabel('تأكيد كلمة المرور', isDark),
                                    const SizedBox(height: 8),
                                    _buildEnterpriseTextField(
                                      controller: _confirmPasswordController,
                                      hint: '••••••••',
                                      icon: Icons.lock_reset_outlined,
                                      isDark: isDark,
                                      obscureText: _obscureConfirmPassword,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureConfirmPassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: isDark ? darkHint : hintColor,
                                          size: 20,
                                        ),
                                        onPressed:
                                            () => setState(
                                              () =>
                                                  _obscureConfirmPassword =
                                                      !_obscureConfirmPassword,
                                            ),
                                      ),
                                      validator:
                                          (v) =>
                                              (v != _passwordController.text)
                                                  ? 'كلمتا المرور غير متطابقتين'
                                                  : null,
                                    ),
                                    const SizedBox(height: 24),
                                    // Terms Checkbox
                                    GestureDetector(
                                      onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: Checkbox(
                                              value: _agreeToTerms,
                                              onChanged:
                                                  (val) =>
                                                      setState(() => _agreeToTerms = val ?? false),
                                              activeColor: primaryColor,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              side: BorderSide(
                                                color: isDark ? darkHint : Colors.grey.shade400,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text.rich(
                                              TextSpan(
                                                text: 'أوافق على',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isDark ? darkSubText : subTextColor,
                                                ),
                                                children: const [
                                                  TextSpan(
                                                    text: 'الشروط والأحكام',
                                                    style: TextStyle(
                                                      color: primaryColor,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  TextSpan(text: 'وسياسة الخصوصية.'),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    // Register Button
                                    SizedBox(
                                      key: _registerKey,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: _loading ? null : _register,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          disabledBackgroundColor: primaryColor.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                        child:
                                            _loading
                                                ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2.5,
                                                  ),
                                                )
                                                : const Text(
                                                  'إنشاء الحساب',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    // Footer
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'لديك حساب بالفعل؟',
                                          style: TextStyle(
                                            color: isDark ? darkSubText : subTextColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: const Text(
                                            'تسجيل الدخول',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_showTour)
              AppTourOverlay(
                steps: [
                  TourStep(
                    targetKey: _usernameKey,
                    title: 'اسمك بالكامل',
                    description: 'يرجى إدخال اسمك لتخصيص تجربتك في التطبيق.',
                  ),
                  TourStep(
                    targetKey: _emailKey,
                    title: 'البريد الإلكتروني',
                    description: 'استخدم بريداً فعالاً لتلقي الإشعارات وتأمين حسابك.',
                  ),
                  TourStep(
                    targetKey: _passwordKey,
                    title: 'كلمة المرور',
                    description: 'اختر كلمة مرور قوية لحماية حسابك.',
                  ),
                  TourStep(
                    targetKey: _registerKey,
                    title: 'إتمام التسجيل',
                    description: 'اضغط هنا لإنشاء حسابك والانطلاق في رحلتك معنا.',
                  ),
                ],
                onComplete: _onTourComplete,
                onSkip: _onTourComplete,
              ),
            // SmartAssistantFAB removed for App Store compliance
          ],
        ),
      ),
    );

  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isDark ? darkText : textColor,
      ),
    );
  }

  Widget _buildErrorAlert(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: Colors.red.shade800,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterpriseTextField({
    Key? key,
    required TextEditingController controller,
    required IconData icon,
    required bool isDark,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    String? hint,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    final fillColor = isDark ? darkSurface : const Color(0xFFF5F7F9);

    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(
        color: isDark ? darkText : textColor,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark ? darkHint : hintColor.withValues(alpha: 0.7),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, size: 20, color: isDark ? darkSubText : subTextColor),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
      ),
      validator: validator,
    );
  }
}
