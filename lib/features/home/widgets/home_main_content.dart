import 'package:dalal_alqaim/pages/restaurant_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Feature Specific
import 'package:dalal_alqaim/features/taxi/presentation/taxi_request_screen.dart';
import 'package:dalal_alqaim/pages/restaurants_page.dart';
import 'package:dalal_alqaim/pages/all_sections_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_page.dart';
import 'package:dalal_alqaim/pages/section_user_view_page.dart';
import 'package:dalal_alqaim/shared/section_utils.dart';
import 'package:dalal_alqaim/widgets/app_tour_widget.dart';
import 'package:dalal_alqaim/features/home/widgets/draggable_services_row.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/madar_stores_page.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/store_details_page.dart';

// Shared
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:dalal_alqaim/shared/app_constants.dart';
import 'package:dalal_alqaim/features/home/widgets/home_shimmer_loaders.dart';
import 'package:dalal_alqaim/features/home/widgets/madar_3d_service_graphics.dart';
import 'package:dalal_alqaim/features/home/pages/search_page.dart';
import 'package:dalal_alqaim/core/automation/smart_assistant_fab.dart';

// ─────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────

class _ServiceItem {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final String? defaultBgAsset;
  final VoidCallback onTap;
  final bool isLive;

  const _ServiceItem({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
    this.defaultBgAsset,
    this.isLive = false,
  });
}

// ─────────────────────────────────────────────
// HomeMainContent
// ─────────────────────────────────────────────

class HomeMainContent extends StatefulWidget {
  const HomeMainContent({super.key});

  @override
  State<HomeMainContent> createState() => _HomeMainContentState();
}

class _HomeMainContentState extends State<HomeMainContent>
    with TickerProviderStateMixin {
  String? _userName;
  String? _userPhone;
  bool _promptShown = true;
  bool _showTourOverlay = false;

  // Animation controllers
  late final AnimationController _headerController;
  late final AnimationController _quickController;
  late final AnimationController _mainController;

  final GlobalKey _locationKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _quickServicesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadUserContact();
    _checkTourStatus();
    _startEntryAnimations();
  }

  void _initAnimations() {
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _quickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  Future<void> _startEntryAnimations() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    _headerController.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    _quickController.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    _mainController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _quickController.dispose();
    _mainController.dispose();
    super.dispose();
  }

  // ── Data loading (unchanged logic) ──────────

  Future<void> _checkTourStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTour = prefs.getBool('app_tour_completed') ?? false;
    if (!hasSeenTour) {
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _showTourOverlay = true);
      });
    }
  }

  Future<void> _completeTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_tour_completed', true);
    if (mounted) setState(() => _showTourOverlay = false);
  }

  Future<void> _loadUserContact() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isRegistered = prefs.getBool('user_data_registered') ?? false;
      if (isRegistered) {
        if (mounted) {
          setState(() {
            _userName = prefs.getString('user_name') ?? 'مستخدم';
            _userPhone = prefs.getString('user_phone') ?? '';
            _promptShown = true;
          });
        }
        _checkLocationSet();
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
        if (doc.exists) {
          final data = doc.data();
          final name = data?['name']?.toString() ?? 'مستخدم';
          final phone = data?['phone']?.toString() ?? user.phoneNumber ?? '';

          await prefs.setString('user_name', name);
          await prefs.setString('user_phone', phone);
          await prefs.setBool('user_data_registered', true);
          if (mounted) {
            setState(() {
              _userName = name;
              _userPhone = phone;
              _promptShown = true;
            });
            _checkLocationSet();
          }
          return;
        }
      }
      // Never block users with mandatory dialog on home page
      if (mounted) {
        setState(() {
          _userName = 'مستخدم';
          _promptShown = true;
        });
        _checkLocationSet();
      }
    } catch (e) {
      debugPrint('Failed loading contact: $e');
    }
  }

  Future<void> _saveContact(String name, String phone) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': name,
          'phone': phone,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      await prefs.setString('user_phone', phone);
      await prefs.setBool('user_data_registered', true);
      if (mounted) {
        setState(() {
          _userName = name;
          _userPhone = phone;
          _promptShown = true;
        });
      }
    } catch (e) {
      debugPrint('Failed saving contact: $e');
    }
  }

  void _checkLocationSet() {
    // Disabled compulsory location selector modal on home page
  }

  Future<void> _promptForMandatoryContact() async {
    if (_promptShown && (_userName != null && _userPhone != null)) return;
    final nameController = TextEditingController(text: _userName ?? '');
    final phoneController = TextEditingController(text: _userPhone ?? '');
    final formKey = GlobalKey<FormState>();
    bool processing = false;

    if (!mounted) return;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'WelcomePrompt',
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (ctx, anim1, anim2) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: PopScope(
            canPop: false,
            child: StatefulBuilder(
              builder: (context, setState) {
                final isThemeDark = Theme.of(context).brightness == Brightness.dark;
                final primary = app_colors.primaryColor;

                return Scaffold(
                backgroundColor: Colors.transparent,
                resizeToAvoidBottomInset: true,
                body: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 28.w),
                      padding: EdgeInsets.all(28.r),
                      decoration: BoxDecoration(
                        color: isThemeDark ? const Color(0xFF0F1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(32.r),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ── Animated Header Container ──
                              Container(
                                padding: EdgeInsets.all(20.r),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [primary, const Color(0xFF00796B)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primary.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.handshake_rounded,
                                  color: Colors.white,
                                  size: 38.sp,
                                ),
                              ),
                              SizedBox(height: 24.h),
                              Text(
                                'مرحباً بك في ${AppConstants.appName}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w900,
                                  color: isThemeDark ? Colors.white : const Color(0xFF1A1A1A),
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'يرجى تزويدنا بمعلوماتك الأساسية لنتمكن من تقديم أفضل خدمة لك',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: isThemeDark ? Colors.white60 : Colors.grey.shade600,
                                ),
                              ),
                              SizedBox(height: 32.h),

                              // ── Name Field ──
                              _buildCustomField(
                                controller: nameController,
                                label: 'الاسم الكامل',
                                hint: 'ادخل اسمك هنا',
                                icon: Icons.person_outline_rounded,
                                isDark: isThemeDark,
                                primary: primary,
                                validator: (v) => (v == null || v.isEmpty) ? 'الاسم مطلوب' : null,
                              ),
                              SizedBox(height: 18.h),

                              // ── Phone Field ──
                              _buildCustomField(
                                controller: phoneController,
                                label: 'رقم الهاتف',
                                hint: '07XXXXXXXX',
                                icon: Icons.phone_iphone_rounded,
                                isDark: isThemeDark,
                                primary: primary,
                                keyboardType: TextInputType.phone,
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'رقم الهاتف مطلوب';
                                  if (v.length < 10) return 'رقم الهاتف غير صالح';
                                  return null;
                                },
                              ),
                              SizedBox(height: 36.h),

                              // ── Save Button ──
                              SizedBox(
                                width: double.infinity,
                                height: 56.h,
                                child: ElevatedButton(
                                  onPressed: processing
                                      ? null
                                      : () async {
                                          if (formKey.currentState!.validate()) {
                                            setState(() => processing = true);
                                            await _saveContact(
                                              nameController.text.trim(),
                                              phoneController.text.trim(),
                                            );
                                            if (ctx.mounted) Navigator.pop(ctx);
                                            _checkLocationSet();
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primary,
                                    foregroundColor: Colors.white,
                                    elevation: 8,
                                    shadowColor: primary.withValues(alpha: 0.4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18.r),
                                    ),
                                  ),
                                  child: processing
                                      ? SizedBox(
                                          height: 22.h,
                                          width: 22.h,
                                          child: const CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Text(
                                          'حفظ والمتابعة',
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.bold,
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
                ),
              );
            },
          ),
        ),
      );
    },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: anim1,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildCustomField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color primary,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(right: 4.w, bottom: 8.h),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            fontSize: 15.sp,
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13.sp,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
            prefixIcon: Icon(icon, color: primary, size: 20.sp),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(color: primary, width: 1.5),
            ),
            errorStyle: const TextStyle(),
          ),
        ),
      ],
    );
  }


  // ── Build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_promptShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_promptShown) {
          _promptForMandatoryContact();
          setState(() => _promptShown = true);
        }
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build service list (uses loaded config for images)
    final List<_ServiceItem> mainServices = [
      _ServiceItem(
        id: 'taxi',
        label: 'تكسي مدار',
        subtitle: 'رحلات سريعة',
        icon: Icons.local_taxi_rounded,
        bgColor: const Color(0xFF1A1A2E),
        iconColor: const Color(0xFFF59E0B),
        defaultBgAsset: 'assets/cars/3607759.jpg',
        isLive: true,
        onTap:
            () =>
                Navigator.push(context, _fadeRoute(const TaxiRequestScreen())),
      ),
      _ServiceItem(
        id: 'medical',
        label: 'الأقسام',
        subtitle: 'الخدمات الشاملة',
        icon: Icons.medical_services_rounded,
        bgColor: Colors.white,
        iconColor: app_colors.primaryColor,
        defaultBgAsset: 'imges/sections.png',
        onTap:
            () => Navigator.push(context, _fadeRoute(const AllSectionsPage())),
      ),
      _ServiceItem(
        id: 'restaurants',
        label: 'المطاعم',
        subtitle: 'أشهى الوجبات',
        icon: Icons.restaurant_rounded,
        bgColor: const Color(0xFF1F0A0A),
        iconColor: const Color(0xFFF87171),
        defaultBgAsset: 'imges/restaurants_cover.png',
        onTap: () => Navigator.push(context, _fadeRoute(const RestaurantsPage())),
      ),
      _ServiceItem(
        id: 'mersal',
        label: 'مرسال',
        subtitle: 'توصيل طلبات',
        icon: Icons.rocket_launch_rounded,
        bgColor: const Color(0xFF1A0A00),
        iconColor: const Color(0xFFFB923C),
        defaultBgAsset: 'imges/mersal_cover.png',
        onTap: () => Navigator.push(context, _fadeRoute(const DeliveryPage())),
      ),
      _ServiceItem(
        id: 'doctors',
        label: 'الأطباء',
        subtitle: 'دليل الأطباء',
        icon: Icons.health_and_safety_rounded,
        bgColor: const Color(0xFF0B1B1B),
        iconColor: const Color(0xFF14B8A6),
        defaultBgAsset: 'imges/doctors_cover.png',
        onTap: () => _navigateToDoctors(context),
      ),
      _ServiceItem(
        id: 'stores',
        label: 'متاجر مدار',
        subtitle: 'أفضل المتاجر',
        icon: Icons.shopping_bag_rounded,
        bgColor: const Color(0xFF0F172A),
        iconColor: const Color(0xFF2DD4BF),
        defaultBgAsset: 'imges/stores_cover.png',
        onTap:
            () =>
                Navigator.push(context, _fadeRoute(const MadarStoresPage())),
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── 1. Top Header (Logo + Iraqi Greeting + Search) ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 14.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44.r,
                              height: 44.r,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? app_colors.darkCard : Colors.white,
                                border: Border.all(
                                  color: app_colors.primaryColor.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: app_colors.primaryColor.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'imges/dala_alqaim_logo.png',
                                  cacheWidth: 120,
                                  cacheHeight: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'assets/images/logo.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.hub_rounded,
                                      size: 24.r,
                                      color: app_colors.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _userName != null && _userName!.isNotEmpty && _userName != 'مستخدم'
                                        ? 'يا هلا بيك، $_userName'
                                        : 'يا هلا بيك في مدار',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? app_colors.darkText : const Color(0xFF112525),
                                    ),
                                  ),
                                  Text(
                                    'شنو ببالك اليوم؟ اطلب وتدلل',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? app_colors.darkSubText : app_colors.subTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        // Search Pill
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SearchPage()),
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                            decoration: BoxDecoration(
                              color: isDark ? app_colors.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: isDark ? app_colors.darkBorder : const Color(0xFFE2EBE9),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded, size: 20.sp, color: app_colors.primaryColor),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: Text(
                                    'دور على مطعم، متجر، أو وجبة طيبة...',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 12.5.sp,
                                      color: isDark ? app_colors.darkSubText : app_colors.subTextColor,
                                    ),
                                  ),
                                ),
                                Icon(Icons.tune_rounded, size: 18.sp, color: isDark ? app_colors.darkSubText : Colors.grey.shade400),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 2. Quick Services ───────────────────
                SliverToBoxAdapter(
                  key: _quickServicesKey,
                  child: _SectionBlock(
                    controller: _quickController,
                    title: 'الخدمات السريعة',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'عرض المزيد',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: app_colors.primaryColor,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 11.sp,
                          color: app_colors.primaryColor,
                        ),
                      ],
                    ),
                    child: const DraggableServicesRow(),
                  ),
                ),

                // ── 3. Main Services ────────────────────
                SliverToBoxAdapter(
                  key: _featuresKey,
                  child: _SectionBlock(
                    controller: _mainController,
                    title: 'خدمات مدار الأساسية',
                    child: _MainServicesBento(
                      services: mainServices,
                      controller: _mainController,
                    ),
                  ),
                ),

                // ── 4. أشهر المحلات والمتاجر ──
                SliverToBoxAdapter(
                  child: _buildPopularStoresSection(isDark),
                ),

                // ── 5. أطيب المطاعم والوجبات ──
                SliverToBoxAdapter(
                  child: _buildPopularRestaurantsSection(isDark),
                ),

                // ── 6. وجبات مختارة الك وتدلل ──
                SliverToBoxAdapter(
                  child: _buildFeaturedProductsSection(isDark),
                ),

                SliverToBoxAdapter(child: SizedBox(height: 110.h)),
              ],
            ),

            // ── Tour Overlay ─────────────────────────
            if (_showTourOverlay)
              AppTourOverlay(
                steps: [
                  TourStep(
                    targetKey: _locationKey,
                    title: 'تحديد الموقع',
                    description:
                        'حدد موقعك الحالي لتصفح الخدمات والمتاجر القريبة منك.',
                  ),
                  TourStep(
                    targetKey: _quickServicesKey,
                    title: 'الوصول السريع',
                    description:
                        'مجموعة من الخدمات اليومية السريعة لتسهيل مهامك.',
                  ),
                  TourStep(
                    targetKey: _featuresKey,
                    title: 'الخدمات الرئيسية',
                    description:
                        'اطلب رحلتك، تصفح المطاعم، أو استعرض كافة الأقسام.',
                  ),
                ],
                onComplete: _completeTour,
              ),
          ],
        ),
      ),
    );
  }




  Future<void> _navigateToDoctors(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(app_colors.primaryColor),
        ),
      ),
    );

    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('sections').get();
      
      final doc = querySnapshot.docs.firstWhere(
        (doc) {
          final label = (doc.data()['label'] ?? '').toString();
          return label.contains('طبيب') || 
                 label.contains('أطباء') || 
                 label.contains('دكتور') || 
                 label.contains('عياد') || 
                 label.toLowerCase().contains('doctor') || 
                 label.toLowerCase().contains('clinic') || 
                 label.toLowerCase().contains('medical');
        },
      );

      if (context.mounted) Navigator.pop(context);

      final data = doc.data();
      final docId = doc.id;
      final label = data['label'] ?? 'الأطباء';
      final iconName = data['icon'] ?? 'medical_services';
      final iconColorStr = data['color'] ?? '0xFF06B6D4';

      Color secColor;
      try {
        if (iconColorStr.startsWith('0x')) {
          secColor = Color(int.parse(iconColorStr));
        } else if (iconColorStr.startsWith('#')) {
          secColor = Color(int.parse(iconColorStr.replaceFirst('#', '0xff')));
        } else {
          secColor = Color(int.parse('0xff$iconColorStr'));
        }
      } catch (_) {
        secColor = const Color(0xFF06B6D4);
      }

      if (context.mounted) {
        Navigator.push(
          context,
          _fadeRoute(
            SectionUserViewPage(
              sectionId: docId,
              sectionLabel: label,
              sectionIcon: sectionIconFromString(iconName),
              sectionColor: secColor,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      
      if (context.mounted) {
        Navigator.push(context, _fadeRoute(const AllSectionsPage()));
      }
    }
  }

  PageRouteBuilder _fadeRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder:
        (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
    transitionDuration: const Duration(milliseconds: 280),
  );

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    required VoidCallback onTapMore,
    required bool isDark,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 10.h),
      child: Row(
        children: [
          Container(
            width: 3.5.w,
            height: 18.h,
            decoration: BoxDecoration(
              gradient: app_colors.primaryGradient,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            title,
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w800,
              fontSize: 15.sp,
              color: isDark ? app_colors.darkText : const Color(0xFF112525),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onTapMore();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'شوف الكل',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: app_colors.primaryColor,
                  ),
                ),
                SizedBox(width: 4.w),
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 11.sp,
                  color: app_colors.primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularStoresSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context: context,
          title: 'أشهر المحلات والمتاجر',
          onTapMore: () => Navigator.push(context, _fadeRoute(const MadarStoresPage())),
          isDark: isDark,
        ),
        SizedBox(
          height: 185.h,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('stores').limit(10).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const StoresHorizontalShimmer();
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'ماكو متاجر حالياً متاحة حالياً',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.sp,
                      color: isDark ? app_colors.darkSubText : app_colors.subTextColor,
                    ),
                  ),
                );
              }

              final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
              sortedDocs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aRating = double.tryParse((aData['rating'] ?? 5.0).toString()) ?? 5.0;
                final bRating = double.tryParse((bData['rating'] ?? 5.0).toString()) ?? 5.0;
                return bRating.compareTo(aRating);
              });

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: sortedDocs.length,
                itemBuilder: (context, index) {
                  final doc = sortedDocs[index];
                  final storeData = doc.data() as Map<String, dynamic>;
                  final name = storeData['name']?.toString() ?? 'متجر مدار';
                  final String logoUrl = storeData['logoUrl']?.toString() ?? '';
                  final String coverUrl = storeData['coverUrl']?.toString() ?? storeData['imageUrl']?.toString() ?? '';
                  final double rating = double.tryParse((storeData['rating'] ?? 5.0).toString()) ?? 5.0;
                  final String category = storeData['category']?.toString() ?? storeData['categoryName']?.toString() ?? 'متجر معتمد';
                  final bool isOpen = storeData['isOpen'] == true || storeData['status'] == 'open' || storeData['status'] == 'active' || !storeData.containsKey('isOpen');

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StoreDetailsPage(
                            storeId: doc.id,
                            storeData: storeData,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 156.w,
                      margin: EdgeInsetsDirectional.only(end: 12.w),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131D20) : Colors.white,
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1F3538) : const Color(0xFFE2EBE9),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── 1. Top Cover Banner ──
                              ClipRRect(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(17.r)),
                                child: Container(
                                  height: 86.h,
                                  width: double.infinity,
                                  color: isDark ? const Color(0xFF1B2A2D) : const Color(0xFFE6F2F0),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (coverUrl.isNotEmpty)
                                        Image.network(
                                          coverUrl,
                                          fit: BoxFit.cover,
                                          cacheWidth: 480,
                                          cacheHeight: 280,
                                          filterQuality: FilterQuality.medium,
                                          errorBuilder: (_, __, ___) => _buildStorePlaceholderBanner(isDark),
                                        )
                                      else
                                        _buildStorePlaceholderBanner(isDark),

                                      // Subtle Top Gradient Overlay
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.black.withValues(alpha: 0.45),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),

                                      // ── Rating Badge (Top Left) ──
                                      Positioned(
                                        top: 6.h,
                                        left: 8.w,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.65),
                                            borderRadius: BorderRadius.circular(20.r),
                                            border: Border.all(color: Colors.white24, width: 0.8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.star_rounded, color: const Color(0xFFFFB800), size: 12.sp),
                                              SizedBox(width: 2.w),
                                              Text(
                                                rating.toStringAsFixed(1),
                                                style: GoogleFonts.ibmPlexSansArabic(
                                                  color: Colors.white,
                                                  fontSize: 9.5.sp,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // ── Status Badge (Top Right) ──
                                      Positioned(
                                        top: 6.h,
                                        right: 8.w,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: (isOpen ? const Color(0xFF059669) : const Color(0xFF64748B)).withValues(alpha: 0.88),
                                            borderRadius: BorderRadius.circular(20.r),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 5.r,
                                                height: 5.r,
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              SizedBox(width: 3.w),
                                              Text(
                                                isOpen ? 'مفتوح' : 'مغلق',
                                                style: GoogleFonts.ibmPlexSansArabic(
                                                  color: Colors.white,
                                                  fontSize: 8.5.sp,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // ── 2. Bottom Content Info ──
                              Padding(
                                padding: EdgeInsets.fromLTRB(10.w, 18.h, 10.w, 8.h),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Store Name
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                                        height: 1.2,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),

                                    // Category / Specialty
                                    Text(
                                      category,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 9.5.sp,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        height: 1.15,
                                      ),
                                    ),
                                    SizedBox(height: 6.h),

                                    // Delivery Feature Tag
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.bolt_rounded,
                                          size: 13.sp,
                                          color: const Color(0xFFF59E0B),
                                        ),
                                        SizedBox(width: 2.w),
                                        Expanded(
                                          child: Text(
                                            'توصيل مدار السريع',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.ibmPlexSansArabic(
                                              fontSize: 9.sp,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0D9488),
                                              height: 1.1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // ── 3. Overlaid Floating Logo Avatar ──
                          Positioned(
                            top: 68.h,
                            right: 10.w,
                            child: Container(
                              width: 36.r,
                              height: 36.r,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF142427) : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF1F3538) : Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: logoUrl.isNotEmpty
                                    ? Image.network(
                                        logoUrl,
                                        fit: BoxFit.contain,
                                        cacheWidth: 140,
                                        cacheHeight: 140,
                                        filterQuality: FilterQuality.medium,
                                        errorBuilder: (_, __, ___) => Icon(Icons.storefront_rounded, size: 18.sp, color: app_colors.primaryColor),
                                      )
                                    : Icon(Icons.storefront_rounded, size: 18.sp, color: app_colors.primaryColor),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStorePlaceholderBanner(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B), const Color(0xFF0F766E)]
              : [const Color(0xFFCCFBF1), const Color(0xFF99F6E4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          size: 32.sp,
          color: isDark ? Colors.white24 : const Color(0xFF0D9488).withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Widget _buildPopularRestaurantsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context: context,
          title: 'أطيب المطاعم والوجبات',
          onTapMore: () => Navigator.push(context, _fadeRoute(const RestaurantsPage())),
          isDark: isDark,
        ),
        SizedBox(
          height: 185.h,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('restaurants').limit(10).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const StoresHorizontalShimmer();
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: Text(
                      'ما قدرنا نحمل المطاعم حالياً',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              final List<Map<String, dynamic>> restaurantsList = [];

              if (docs.isNotEmpty) {
                for (var doc in docs) {
                  final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
                  data['id'] = doc.id;
                  restaurantsList.add(data);
                }
              }

              if (restaurantsList.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: Text(
                      'ماكو مطاعم حالياً متاحة حالياً',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: restaurantsList.length,
                itemBuilder: (context, index) {
                  final data = restaurantsList[index];
                  final restId = data['id']?.toString() ?? 'rest_$index';
                  final name = data['name']?.toString() ?? 'مطعم مدار';
                  final String logoUrl = data['logoUrl']?.toString() ?? data['imageUrl']?.toString() ?? '';
                  final String coverUrl = data['coverUrl']?.toString() ?? data['imageUrl']?.toString() ?? '';
                  final double rating = double.tryParse((data['rating'] ?? 5.0).toString()) ?? 5.0;
                  final String category = data['category']?.toString() ?? data['type']?.toString() ?? 'مطعم معتمد';
                  final bool isOpen = data['isOpen'] == true || data['status'] == 'open' || data['status'] == 'active' || !data.containsKey('isOpen');

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RestaurantDetailsPage(
                            restaurantId: restId,
                            restaurantName: name,
                            imageUrl: logoUrl,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 156.w,
                      margin: EdgeInsetsDirectional.only(end: 12.w),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131D20) : Colors.white,
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1F3538) : const Color(0xFFE2EBE9),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── 1. Top Cover Banner ──
                              ClipRRect(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(17.r)),
                                child: Container(
                                  height: 86.h,
                                  width: double.infinity,
                                  color: isDark ? const Color(0xFF1B2A2D) : const Color(0xFFE6F2F0),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (coverUrl.isNotEmpty)
                                        Image.network(
                                          coverUrl,
                                          fit: BoxFit.cover,
                                          cacheWidth: 480,
                                          cacheHeight: 280,
                                          filterQuality: FilterQuality.medium,
                                          errorBuilder: (_, __, ___) => _buildRestaurantPlaceholderBanner(isDark),
                                        )
                                      else
                                        _buildRestaurantPlaceholderBanner(isDark),

                                      // Subtle Top Gradient Overlay
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.black.withValues(alpha: 0.45),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),

                                      // ── Rating Badge (Top Left) ──
                                      Positioned(
                                        top: 6.h,
                                        left: 8.w,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.65),
                                            borderRadius: BorderRadius.circular(20.r),
                                            border: Border.all(color: Colors.white24, width: 0.8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.star_rounded, color: const Color(0xFFFFB800), size: 12.sp),
                                              SizedBox(width: 2.w),
                                              Text(
                                                rating.toStringAsFixed(1),
                                                style: GoogleFonts.ibmPlexSansArabic(
                                                  color: Colors.white,
                                                  fontSize: 9.5.sp,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // ── Status Badge (Top Right) ──
                                      Positioned(
                                        top: 6.h,
                                        right: 8.w,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: (isOpen ? const Color(0xFF059669) : const Color(0xFF64748B)).withValues(alpha: 0.88),
                                            borderRadius: BorderRadius.circular(20.r),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 5.r,
                                                height: 5.r,
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              SizedBox(width: 3.w),
                                              Text(
                                                isOpen ? 'مفتوح' : 'مغلق',
                                                style: GoogleFonts.ibmPlexSansArabic(
                                                  color: Colors.white,
                                                  fontSize: 8.5.sp,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // ── 2. Bottom Content Info ──
                              Padding(
                                padding: EdgeInsets.fromLTRB(10.w, 18.h, 10.w, 8.h),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Restaurant Name
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                                        height: 1.2,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),

                                    // Category / Specialty
                                    Text(
                                      category,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 9.5.sp,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        height: 1.15,
                                      ),
                                    ),
                                    SizedBox(height: 6.h),

                                    // Delivery Feature Tag
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.delivery_dining_rounded,
                                          size: 14.sp,
                                          color: const Color(0xFF00BFA5),
                                        ),
                                        SizedBox(width: 2.w),
                                        Expanded(
                                          child: Text(
                                            'توصيل طلبات مدار',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.ibmPlexSansArabic(
                                              fontSize: 9.sp,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0D9488),
                                              height: 1.1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // ── 3. Overlaid Floating Logo Avatar ──
                          Positioned(
                            top: 68.h,
                            right: 10.w,
                            child: Container(
                              width: 36.r,
                              height: 36.r,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF142427) : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF1F3538) : Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: logoUrl.isNotEmpty
                                    ? Image.network(
                                        logoUrl,
                                        fit: BoxFit.cover,
                                        cacheWidth: 140,
                                        cacheHeight: 140,
                                        filterQuality: FilterQuality.medium,
                                        errorBuilder: (_, __, ___) => Icon(Icons.restaurant_rounded, size: 18.sp, color: app_colors.primaryColor),
                                      )
                                    : Icon(Icons.restaurant_rounded, size: 18.sp, color: app_colors.primaryColor),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantPlaceholderBanner(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E3A3A), const Color(0xFF0F766E)]
              : [const Color(0xFFFFEDD5), const Color(0xFFFED7AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 32.sp,
          color: isDark ? Colors.white24 : const Color(0xFFEA580C).withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchFeaturedMeals() async {
    final List<Map<String, dynamic>> allMeals = [];
    try {
      final fb = FirebaseFirestore.instance;
      // Find the restaurant section exactly like in RestaurantsPage
      final secQ = await fb.collection('sections').where('label', isEqualTo: 'مطاعم').limit(1).get();
      if (secQ.docs.isEmpty) return allMeals;

      final sectionId = secQ.docs.first.id;
      final itemsSnap = await fb.collection('sections').doc(sectionId).collection('items').get();

      final futures = itemsSnap.docs.map((itemDoc) async {
        final itemData = itemDoc.data();
        final restaurantName = itemData['pageName']?.toString() ?? itemData['name']?.toString() ?? 'مطعم';
        final restaurantId = itemData['ownerId']?.toString() ?? itemDoc.id;

        try {
          final restFuture = fb.collection('restaurants').doc(restaurantId).get();
          final menuFuture = itemDoc.reference.collection('menu').limit(3).get();

          final results = await Future.wait([restFuture, menuFuture]);
          final restDoc = results[0] as DocumentSnapshot;
          final menuSnap = results[1] as QuerySnapshot;

          String restaurantImageUrl = '';
          if (restDoc.exists) {
            final restData = restDoc.data() as Map<String, dynamic>?;
            restaurantImageUrl = (restData?['imageUrl'] ?? '').toString();
          }

          final List<Map<String, dynamic>> restaurantMeals = [];
          for (var mealDoc in menuSnap.docs) {
            final mealData = mealDoc.data() as Map<String, dynamic>? ?? {};
            restaurantMeals.add({
              'mealId': mealDoc.id,
              'mealName': mealData['name']?.toString() ?? 'وجبة',
              'mealImage': mealData['imageUrl']?.toString() ?? mealData['image']?.toString() ?? '',
              'mealPrice': (mealData['price'] as num?)?.toDouble() ?? 0,
              'restaurantName': restaurantName,
              'restaurantId': restaurantId,
              'restaurantImageUrl': restaurantImageUrl,
            });
          }
          return restaurantMeals;
        } catch (e) {
          return <Map<String, dynamic>>[];
        }
      });

      final results = await Future.wait(futures);
      for (var meals in results) {
        allMeals.addAll(meals);
      }
      
      allMeals.shuffle();
      if (allMeals.length > 10) {
        return allMeals.sublist(0, 10);
      }
      return allMeals;
    } catch (e) {
      debugPrint('Error fetching featured meals: $e');
      return allMeals;
    }
  }

  Widget _buildFeaturedProductsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context: context,
          title: 'وجبات مختارة إلك وتدلل',
          onTapMore: () => Navigator.push(context, _fadeRoute(const RestaurantsPage())),
          isDark: isDark,
        ),
        SizedBox(
          height: 135.h,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchFeaturedMeals(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const MealsHorizontalShimmer();
              }
              
              final meals = snapshot.data ?? [];
              if (meals.isEmpty) {
                return Center(
                  child: Text(
                    'ماكو وجبات مضافة هسّه',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.sp,
                      color: isDark ? app_colors.darkSubText : app_colors.subTextColor,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: meals.length,
                itemBuilder: (context, index) {
                  final meal = meals[index];
                  final name = meal['mealName']?.toString() ?? 'وجبة';
                  final String imageUrl = meal['mealImage']?.toString() ?? '';
                  final restaurantId = meal['restaurantId']?.toString() ?? '';
                  final restaurantName = meal['restaurantName']?.toString() ?? 'مطعم';
                  final restaurantImageUrl = meal['restaurantImageUrl']?.toString() ?? '';
                  final mealPrice = (meal['mealPrice'] as num?)?.toDouble() ?? 0.0;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (restaurantId.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RestaurantDetailsPage(
                              restaurantId: restaurantId,
                              restaurantName: restaurantName,
                              imageUrl: restaurantImageUrl,
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RestaurantsPage(),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 90.w,
                      margin: EdgeInsetsDirectional.only(end: 12.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 68.w,
                            height: 68.w,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18.r),
                              border: Border.all(
                                color: isDark ? Colors.white12 : const Color(0xFFE2EBE9),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(17.r),
                              child: imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      cacheWidth: 240,
                                      cacheHeight: 240,
                                      filterQuality: FilterQuality.medium,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: isDark ? const Color(0xFF1E1E26) : const Color(0xFFF5F5F5),
                                        child: Icon(
                                          Icons.fastfood_rounded,
                                          color: isDark ? Colors.white24 : Colors.black26,
                                          size: 28.sp,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: isDark ? const Color(0xFF1E1E26) : const Color(0xFFF5F5F5),
                                      child: Icon(
                                        Icons.fastfood_rounded,
                                        color: isDark ? Colors.white24 : Colors.black26,
                                        size: 28.sp,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5.sp,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '${mealPrice.toStringAsFixed(0)} د.ع',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.w900,
                              fontSize: 11.sp,
                              color: app_colors.primaryColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }


}

// ─────────────────────────────────────────────
// _SectionBlock (header + animated child)
// ─────────────────────────────────────────────

class _SectionBlock extends StatelessWidget {
  final AnimationController controller;
  final String title;
  final Widget? trailing;
  final Widget child;

  const _SectionBlock({
    required this.controller,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final fade = CurvedAnimation(parent: controller, curve: Curves.easeOut);
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 12.h),
              child: Row(
                children: [
                  Container(
                    width: 3.w,
                    height: 18.h,
                    decoration: BoxDecoration(
                      color: app_colors.primaryColor,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.sp,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _MainServicesBento (خدمات مدار الأساسية ثلاثية الأبعاد)
// ─────────────────────────────────────────────

class _MainServicesBento extends StatelessWidget {
  final List<_ServiceItem> services;
  final AnimationController controller;

  const _MainServicesBento({
    required this.services,
    required this.controller,
  });

  _ServiceItem? _findService(String id) {
    try {
      return services.firstWhere((element) => element.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taxi = _findService('taxi');
    final restaurants = _findService('restaurants');
    final stores = _findService('stores');
    final mersal = _findService('mersal');
    final doctors = _findService('doctors');
    final medical = _findService('medical');

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    final List<_ServiceItem> orderedServices = [
      if (taxi != null) taxi,
      if (restaurants != null) restaurants,
      if (stores != null) stores,
      if (mersal != null) mersal,
      if (doctors != null) doctors,
      if (medical != null) medical,
    ];

    if (isDesktop) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Wrap(
          spacing: 16.w,
          runSpacing: 16.h,
          alignment: WrapAlignment.start,
          children: orderedServices.map((service) {
            return SizedBox(
              width: (screenWidth - 300) / 6,
              child: _BentoCard(
                item: service,
                isCompact: true,
              ),
            );
          }).toList(),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          // ── Row 1: تكسي مدار | المطاعم | متاجر مدار ──
          Row(
            children: [
              if (taxi != null)
                Expanded(
                  child: _BentoCard(
                    item: taxi,
                    badgeText: 'مباشر',
                    gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                    accentColor: const Color(0xFFFBBF24),
                  ),
                ),
              if (taxi != null && restaurants != null) SizedBox(width: 8.w),
              if (restaurants != null)
                Expanded(
                  child: _BentoCard(
                    item: restaurants,
                    badgeText: 'خصومات',
                    gradient: const [Color(0xFFEF4444), Color(0xFFDC2626)],
                    accentColor: const Color(0xFFF87171),
                  ),
                ),
              if (restaurants != null && stores != null) SizedBox(width: 8.w),
              if (stores != null)
                Expanded(
                  child: _BentoCard(
                    item: stores,
                    badgeText: 'عروض',
                    gradient: const [Color(0xFF00BFA5), Color(0xFF00897B)],
                    accentColor: const Color(0xFF26A69A),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16.h),
          // ── Row 2: مرسال | الأطباء | الأقسام ──
          Row(
            children: [
              if (mersal != null)
                Expanded(
                  child: _BentoCard(
                    item: mersal,
                    badgeText: 'فوري',
                    gradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    accentColor: const Color(0xFFA78BFA),
                  ),
                ),
              if (mersal != null && doctors != null) SizedBox(width: 8.w),
              if (doctors != null)
                Expanded(
                  child: _BentoCard(
                    item: doctors,
                    badgeText: 'أطباء',
                    gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                    accentColor: const Color(0xFF34D399),
                  ),
                ),
              if (doctors != null && medical != null) SizedBox(width: 8.w),
              if (medical != null)
                Expanded(
                  child: _BentoCard(
                    item: medical,
                    badgeText: 'شامل',
                    gradient: const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                    accentColor: const Color(0xFF38BDF8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _BentoCard (Floating 3D Super App Service Tile)
// ─────────────────────────────────────────────

class _BentoCard extends StatefulWidget {
  final _ServiceItem item;
  final bool isCompact;
  final String? badgeText;
  final List<Color>? gradient;
  final Color? accentColor;

  const _BentoCard({
    required this.item,
    this.isCompact = false,
    this.badgeText,
    this.gradient,
    this.accentColor,
  });

  @override
  State<_BentoCard> createState() => _BentoCardState();
}

class _BentoCardState extends State<_BentoCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = widget.item.label;
    final subtitle = widget.item.subtitle;
    final gradient = widget.gradient ?? [app_colors.primaryColor, const Color(0xFF00796B)];

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press.forward(),
        onTapUp: (_) {
          _press.reverse();
          HapticFeedback.lightImpact();
          widget.item.onTap();
        },
        onTapCancel: () => _press.reverse(),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131D20) : const Color(0xFFF7FAF9),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: isDark ? const Color(0xFF1F3538) : const Color(0xFFE2EBE9),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.03),
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Floating 3D Graphic ──
              SizedBox(
                height: 64.h,
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Madar3DServiceGraphic(
                        serviceType: widget.item.id,
                        size: 58.r,
                      ),

                      // Mini Badge / Tag on top-corner of the 3D graphic
                      if (widget.badgeText != null)
                        PositionedDirectional(
                          top: -3.h,
                          end: -4.w,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: gradient),
                              borderRadius: BorderRadius.circular(6.r),
                              boxShadow: [
                                BoxShadow(
                                  color: gradient[0].withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.badgeText!,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 7.5.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 6.h),

              // ── Label (IBM Plex Sans Arabic) ──
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF112525),
                  height: 1.18,
                ),
              ),
              SizedBox(height: 2.h),
              // ── Subtitle (IBM Plex Sans Arabic) ──
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _ServiceChip (unified chip used everywhere)
// ─────────────────────────────────────────────

class _ServiceChip extends StatefulWidget {
  final _ServiceItem item;

  /// true = main grid (larger), false = quick row (compact)
  final bool isLarge;

  const _ServiceChip({
    required this.item,
    required this.isLarge,
  });

  @override
  State<_ServiceChip> createState() => _ServiceChipState();
}

class _ServiceChipState extends State<_ServiceChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.90,
    ).animate(CurvedAnimation(parent: _press, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconSize = widget.isLarge ? 88.r : 58.r;
    final iconInnerSize = widget.isLarge ? 30.sp : 22.sp;
    final borderRadius = widget.isLarge ? 22.r : 16.r;
    final label = widget.item.label;
    final hasBg = widget.item.defaultBgAsset != null && widget.isLarge;

    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        widget.item.onTap();
      },
      onTapCancel: () => _press.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Icon / Image Box ──────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: widget.isLarge ? double.infinity : iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: widget.item.bgColor,
                    borderRadius: BorderRadius.circular(borderRadius),
                    image: hasBg
                        ? DecorationImage(
                            image: ResizeImage(
                              AssetImage(widget.item.defaultBgAsset!),
                              width: 480,
                              height: 300,
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: widget.item.iconColor.withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: hasBg
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Container( // Overlay to darken the image slightly for text contrast
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(borderRadius),
                              ),
                            ),
                            Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4.w),
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(color: widget.item.iconColor, blurRadius: 10, offset: const Offset(0, 0)),
                                      const Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 2)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Icon(
                          widget.item.icon,
                          color: widget.item.iconColor,
                          size: iconInnerSize,
                        ),
                ),

                // Live Badge
                if (widget.item.isLive)
                  Positioned(top: -4, left: -4, child: _LiveBadge()),
              ],
            ),

            SizedBox(height: widget.isLarge ? 6.h : 6.h),

            // ── Label ─────────────────────────
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: widget.isLarge ? 12.sp : 11.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),

            // Subtitle (large only)
            if (widget.isLarge)
              Text(
                widget.item.subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _LiveBadge (pulsing green dot + label)
// ─────────────────────────────────────────────

class _LiveBadge extends StatefulWidget {
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder:
                (_, __) => Opacity(
                  opacity: _pulseAnim.value,
                  child: Container(
                    width: 5.r,
                    height: 5.r,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
          ),
          SizedBox(width: 3.w),
          Text(
            'مباشر',
            style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}




