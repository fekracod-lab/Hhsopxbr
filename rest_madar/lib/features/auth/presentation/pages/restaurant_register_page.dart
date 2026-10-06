import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../services/cloudinary_service.dart';
import '../../../../core/constants/restaurant_categories.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:ui';

// --- Premium Light Turquoise Theme Palette ---
const Color _primary = Color(0xFF26A69A); // Vibrant Teal/Turquoise
const Color _accent = Color(0xFF00796B); // Deep Teal
const Color _lightBg = Color(0xFFF5F9F9); // Soft light turquoise background
const Color _textPrimary = Color(0xFF07191A); // Deep charcoal/teal text
const Color _textSecondary = Color(0xFF5A7375); // Slate grey-teal secondary text
const Color _cardBg = Colors.white; // Pure white card background

class RestaurantRegisterPage extends StatefulWidget {
  const RestaurantRegisterPage({super.key});

  @override
  State<RestaurantRegisterPage> createState() => _RestaurantRegisterPageState();
}

class _RestaurantRegisterPageState extends State<RestaurantRegisterPage> with TickerProviderStateMixin {
  // --- Step Control ---
  int _currentStep = 0;
  final _pageController = PageController();

  // --- Form Keys ---
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();
  final _step4Key = GlobalKey<FormState>();

  // --- Controllers ---
  final _restaurantName = TextEditingController();
  final _ownerName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  // --- State ---
  RestaurantCategoryItem _selectedCategory = MadarRestaurantCategories.all.first;
  String? _selectedGovId, _selectedGovName;
  String? _selectedRegId, _selectedRegName;
  List<Map<String, dynamic>> _regions = [];
  bool _isLoadingRegions = false;
  Uint8List? _selectedLogoBytes;
  String? _selectedLogoFilename;
  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isPickingImage = false;

  static const _stepTitles = ['معلومات المنشأة', 'التواصل والموقع', 'المنطقة', 'تأمين الحساب'];
  static const _stepIcons = [
    Icons.storefront_outlined,
    Icons.phone_outlined,
    Icons.location_on_outlined,
    Icons.lock_outline,
  ];

  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _restaurantName.dispose();
    _ownerName.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _password.dispose();
    _confirm.dispose();
    _pageController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // --- Navigation ---

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < 3) {
      HapticFeedback.lightImpact();
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _register();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      HapticFeedback.lightImpact();
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_selectedLogoBytes == null) {
          _showError('يرجى تحميل شعار المنشأة');
          return false;
        }
        return _step1Key.currentState?.validate() ?? false;
      case 1:
        return _step2Key.currentState?.validate() ?? false;
      case 2:
        if (_selectedGovId == null) {
          _showError('يرجى اختيار المحافظة');
          return false;
        }
        if (_selectedRegId == null) {
          _showError('يرجى اختيار المنطقة الجغرافية');
          return false;
        }
        return _step3Key.currentState?.validate() ?? false;
      case 3:
        return _step4Key.currentState?.validate() ?? false;
      default:
        return true;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // --- Image Source Choice Dialog ---

  Future<void> _pickLogo() async {
    if (_isPickingImage) return;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'شعار المنشأة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _sourceButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'الكاميرا',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromSource(ImageSource.camera);
                    },
                  ),
                  _sourceButton(
                    icon: Icons.photo_library_rounded,
                    label: 'المعرض',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromSource(ImageSource.gallery);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _primary.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, color: _primary, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    setState(() => _isPickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedLogoBytes = bytes;
          _selectedLogoFilename = picked.name.isNotEmpty
              ? picked.name
              : 'logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        });
      }
    } catch (_) {
      _showError('عذراً، فشل التقاط أو تحديد الصورة.');
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  // --- Regions ---

  Future<void> _fetchRegions(String govId) async {
    setState(() {
      _isLoadingRegions = true;
      _regions = [];
      _selectedRegId = null;
      _selectedRegName = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('governorates')
          .doc(govId)
          .collection('regions')
          .where('isActive', isEqualTo: true)
          .get();
      final docs = snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      docs.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
      if (mounted) {
        setState(() {
          _regions = docs;
          _isLoadingRegions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRegions = false);
    }
  }

  // --- Register ---

  Future<void> _register() async {
    if (!_validateCurrentStep()) return;
    setState(() => _loading = true);

    String? uid;
    User? createdUser;
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      createdUser = cred.user;
      uid = createdUser!.uid;

      final filename = _selectedLogoFilename ?? 'logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String? logoUrl;

      // Direct Cloudinary Upload
      logoUrl = await CloudinaryService.uploadBytes(_selectedLogoBytes!, filename);
      if (logoUrl == null) {
        throw Exception('فشل رفع شعار المطعم إلى خادم الصور. يرجى التحقق من اتصال الإنترنت.');
      }

      final data = {
        'uid': uid,
        'fullName': _ownerName.text.trim(),
        'restaurantName': _restaurantName.text.trim(),
        'email': _email.text.trim(),
        'plainPassword': _password.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'governorateId': _selectedGovId,
        'governorateName': _selectedGovName,
        'regionId': _selectedRegId,
        'regionName': _selectedRegName,
        'type': _selectedCategory.id,
        'category': _selectedCategory.id,
        'cuisine': _selectedCategory.title,
        'cuisineType': _selectedCategory.title,
        'storeCategory': _selectedCategory.title,
        'photoUrl': logoUrl,
        'imageUrl': logoUrl,
        'role': 'merchant',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(uid).set(data),
        FirebaseFirestore.instance.collection('restaurants').doc(uid).set(data, SetOptions(merge: true)),
        FirebaseFirestore.instance.collection('restaurant_requests').doc(uid).set({
          ...data,
          'imageUrl': logoUrl,
          'ownerName': _ownerName.text.trim(),
        }),
      ]);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إرسال طلب انضمام مطعمك بنجاح! هو الآن قيد المراجعة.',
            style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }
      if (!mounted) return;

      String msg = 'صار خطأ، حاول مرة ثانية أثناء التسجيل';
      if (e is FirebaseAuthException) {
        msg = e.message ?? e.code;
      } else if (e is FirebaseException) {
        msg = 'خطأ في السيرفر: ${e.message ?? e.code}';
      } else {
        msg = 'خطأ: ${e.toString()}';
      }
      _showError(msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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

              SafeArea(
                child: Column(
                  children: [
                    // ── Header Bar ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary),
                            onPressed: _currentStep > 0 ? _prevStep : () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          Text(
                            'تسجيل شريك جديد',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.w900,
                              color: _textPrimary,
                              fontSize: 18,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    _buildPremiumHeader(),
                    const SizedBox(height: 20),

                    // Stepper Indicator
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildStepper(),
                    ),
                    const SizedBox(height: 16),

                    // Page View inside expanded white card
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.05),
                              blurRadius: 30,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          border: Border.all(color: _primary.withValues(alpha: 0.06)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: PageView(
                            controller: _pageController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildStep1(),
                              _buildStep2(),
                              _buildStep3(),
                              _buildStep4(),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom Buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: _buildBottomButtons(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Column(
      children: [
        // Shimmer Title
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
                    _textPrimary,
                    _primary,
                    _textPrimary,
                    _primary,
                    _textPrimary,
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
            'انضم لعائلة مدار',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: _textPrimary,
              letterSpacing: 1.2,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Spinning culinary diamond and pulsing divider line
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, _) {
            final lineWidth = 25 + (_pulseAnimation.value * 20);
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
                        _primary.withValues(alpha: 0.0),
                        _primary.withValues(alpha: _pulseAnimation.value * 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _shimmerController.value * 2 * math.pi,
                      child: Icon(
                        Icons.diamond_rounded,
                        size: 11,
                        color: _primary.withValues(alpha: 0.5 + (_pulseAnimation.value * 0.5)),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: lineWidth,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _primary.withValues(alpha: _pulseAnimation.value * 0.8),
                        _primary.withValues(alpha: 0.0),
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

  Widget _buildStepper() {
    return Column(
      children: [
        Row(
          children: List.generate(4, (i) {
            final isActive = i <= _currentStep;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 5,
                margin: EdgeInsets.only(left: i < 3 ? 6 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2.5),
                  color: isActive ? _primary : Colors.grey[300],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_stepIcons[_currentStep], color: _primary, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الخطوة ${_currentStep + 1} من 4',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: _textSecondary, fontWeight: FontWeight.bold),
                ),
                Text(
                  _stepTitles[_currentStep],
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _step1Key,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildLogoPicker(),
          const SizedBox(height: 24),
          _field(
            controller: _restaurantName,
            label: 'اسم المطعم/المنشأة',
            icon: Icons.restaurant_menu,
          ),
          const SizedBox(height: 16),
          _field(controller: _ownerName, label: 'اسم المالك', icon: Icons.person_outline),
          const SizedBox(height: 16),
          _buildTypeDropdown(),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _step2Key,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.contact_mail_rounded, color: _primary, size: 40),
            ),
          ),
          const SizedBox(height: 20),
          _field(
            controller: _email,
            label: 'البريد الإلكتروني للمطعم',
            icon: Icons.email_outlined,
            keyboard: TextInputType.emailAddress,
            validator: (v) {
              final val = (v ?? '').trim();
              if (val.isEmpty) return 'مطلوب';
              if (!val.contains('@')) return 'بريد غير صالح';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _field(
            controller: _phone,
            label: 'رقم هاتف المطعم للتواصل',
            icon: Icons.phone_outlined,
            keyboard: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _field(controller: _address, label: 'العنوان التفصيلي للمطعم', icon: Icons.map_outlined),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Form(
      key: _step3Key,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.map_rounded, color: _primary, size: 40),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'اختر منطقة العمل الجغرافية للمطعم',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: _textSecondary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          _buildGovernorateDropdown(),
          const SizedBox(height: 16),
          _buildRegionDropdown(),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return Form(
      key: _step4Key,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, color: _primary, size: 40),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'اختر كلمة مرور قوية لتأمين لوحة التحكم',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: _textSecondary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          _field(
            controller: _password,
            label: 'كلمة المرور',
            icon: Icons.lock_outline,
            obscure: _obscure1,
            validator: (v) {
              if ((v ?? '').isEmpty) return 'مطلوبة';
              if (v!.length < 6) return 'يجب 6 أحرف على الأقل';
              return null;
            },
            suffix: IconButton(
              onPressed: () => setState(() => _obscure1 = !_obscure1),
              icon: Icon(
                _obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: _primary.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _field(
            controller: _confirm,
            label: 'تأكيد كلمة المرور',
            icon: Icons.lock_outline,
            obscure: _obscure2,
            validator: (v) {
              if ((v ?? '').isEmpty) return 'مطلب إلزامي';
              if (v != _password.text) return 'كلمات المرور غير متطابقة';
              return null;
            },
            suffix: IconButton(
              onPressed: () => setState(() => _obscure2 = !_obscure2),
              icon: Icon(
                _obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: _primary.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    final isLast = _currentStep == 3;
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: _prevStep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: _primary.withValues(alpha: 0.3), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'السابق',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: _primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: isLast
                    ? [const Color(0xFF00C853), const Color(0xFF009624)]
                    : [_primary, _accent],
              ),
              boxShadow: [
                BoxShadow(
                  color: (isLast ? const Color(0xFF00C853) : _primary).withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _loading ? null : _nextStep,
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? 'إرسال طلب الانضمام' : 'التالي',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!isLast) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoPicker() {
    return Center(
      child: GestureDetector(
        onTap: _pickLogo,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF0F7F7),
            border: Border.all(
              color: _selectedLogoBytes != null ? _primary : _primary.withValues(alpha: 0.15),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
              if (_selectedLogoBytes != null)
                BoxShadow(
                  color: _primary.withValues(alpha: 0.15),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_selectedLogoBytes != null)
                ClipOval(
                  child: Image.memory(
                    _selectedLogoBytes!,
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: _primary.withValues(alpha: 0.6), size: 30),
                    const SizedBox(height: 4),
                    Text(
                      'شعار المنشأة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: _primary.withValues(alpha: 0.05)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        validator: validator ?? (v) => (v == null || v.trim().isEmpty) ? 'مطلب إلزامي' : null,
        style: const TextStyle(
          color: _textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: _primary,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: _textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(icon, color: _primary.withValues(alpha: 0.6), size: 20),
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.category_rounded, color: _primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'مجموعة وتصنيف المطعم في مدار:',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MadarRestaurantCategories.all.map((cat) {
            final isSelected = _selectedCategory.id == cat.id;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedCategory = cat;
                  // category selected
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? cat.accentColor.withValues(alpha: 0.12) : const Color(0xFFF0F7F7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? cat.accentColor : _primary.withValues(alpha: 0.15),
                    width: isSelected ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat.icon, color: isSelected ? cat.accentColor : _textSecondary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      cat.title,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? cat.accentColor : _textPrimary,
                      ),
                    ),
                    if (cat.badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected ? cat.accentColor : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          cat.badge!,
                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGovernorateDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('governorates')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        List<DropdownMenuItem<String>> items = [];
        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? '';
            items.add(DropdownMenuItem(
              value: '${doc.id}::$name',
              child: Text(name, style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            ));
          }
        }
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0F7F7),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: _primary.withValues(alpha: 0.05)),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedGovId != null ? '$_selectedGovId::$_selectedGovName' : null,
            dropdownColor: Colors.white,
            items: items,
            hint: const Text('اختر المحافظة', style: TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            onChanged: (v) {
              if (v != null) {
                final parts = v.split('::');
                setState(() {
                  _selectedGovId = parts[0];
                  _selectedGovName = parts[1];
                });
                _fetchRegions(parts[0]);
              }
            },
            decoration: InputDecoration(
              labelText: 'المحافظة',
              labelStyle: const TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
              prefixIcon: Icon(Icons.map_outlined, color: _primary.withValues(alpha: 0.6)),
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRegionDropdown() {
    if (_isLoadingRegions) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(color: _primary),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: _primary.withValues(alpha: 0.05)),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedRegId != null ? '$_selectedRegId::$_selectedRegName' : null,
        dropdownColor: Colors.white,
        items: _regions
            .map(
              (e) => DropdownMenuItem(
                value: '${e['id']}::${e['name']}',
                child: Text(e['name'] ?? '', style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            )
            .toList(),
        hint: const Text('اختر المنطقة الجغرافية', style: TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        onChanged: (v) {
          if (v != null) {
            final parts = v.split('::');
            setState(() {
              _selectedRegId = parts[0];
              _selectedRegName = parts[1];
            });
          }
        },
        decoration: InputDecoration(
          labelText: 'المنطقة',
          labelStyle: const TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
          prefixIcon: Icon(Icons.location_on_outlined, color: _primary.withValues(alpha: 0.6)),
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}
