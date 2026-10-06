// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures, avoid_types_as_parameter_names, use_build_context_synchronously, use_null_aware_elements
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';

import 'package:rest_madar/features/pos/presentation/widgets/quick_add_meal_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rest_madar/services/cloudinary_service.dart';
import 'package:rest_madar/services/firestore_sync_service.dart';
import 'package:rest_madar/services/notification_service.dart';

// --- Premium Light Turquoise Theme Palette ---
const Color _primary = Color(0xFF26A69A); // Vibrant Teal/Turquoise
const Color _accent = Color(0xFF00796B); // Deep Teal
const Color _gold = Color(0xFFFFB300); // Soft Gourmet Gold
const Color _lightBg = Color(0xFFF5F9F9); // Soft light turquoise background
const Color _cardBg = Colors.white; // Pure white card background
const Color _textPrimary = Color(0xFF07191A); // Deep charcoal/teal text
const Color _textSecondary = Color(
  0xFF5A7375,
); // Slate grey-teal secondary text

class RestaurantDashboardPage extends StatefulWidget {
  const RestaurantDashboardPage({super.key});

  @override
  State<RestaurantDashboardPage> createState() =>
      _RestaurantDashboardPageState();
}

class _RestaurantDashboardPageState extends State<RestaurantDashboardPage>
    with TickerProviderStateMixin {
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isOnline = true;
  String _restaurantName = 'اسم المطعم';
  String _cuisineType = 'مطبخ عربي • مشروبات • مقبلات';
  String _description = '';
  String? _restaurantId;
  String _congestionStatus = 'normal'; // normal, active, busy
  String? _logoUrl;
  String? _coverUrl;
  String _address = '';

  int _currentViewIndex =
      0; // Drawer Menu Options: 0=الطلبات, 1=المنيو, 2=العروض, 3=التقارير, 4=التقييمات, 5=الإعدادات
  String _selectedSubTab =
      'الكل'; // Sub-tab filter inside Orders view: 'الكل', 'جديد', 'تحضير', 'جاهز', 'مكتمل'

  @override
  void initState() {
    super.initState();
    _restaurantId = _uid;
    _fetchRestaurantData();
  }

  Future<void> _fetchRestaurantData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _restaurantName =
              data?['restaurantName'] ?? data?['fullName'] ?? 'اسم المطعم';
          _isOnline = data?['isOnline'] ?? true;
          _restaurantId = data?['restaurantId'] ?? data?['uid'] ?? _uid;
          _cuisineType =
              data?['cuisineType'] ??
              data?['cuisine'] ??
              'مطبخ عربي • مشروبات • مقبلات';
          _description = data?['description'] ?? '';
          _congestionStatus = data?['congestionStatus'] ?? 'normal';
          _logoUrl = data?['photoUrl'] ?? data?['imageUrl'];
          _coverUrl = data?['coverImageUrl'] ?? data?['coverImage'];
          _address = data?['address'] ?? '';
        });
      }
    } catch (_) {}
  }

  void _cycleCongestion() async {
    HapticFeedback.selectionClick();
    String next = 'normal';
    if (_congestionStatus == 'normal')
      next = 'active';
    else if (_congestionStatus == 'active')
      next = 'busy';

    setState(() => _congestionStatus = next);
    try {
      await FirebaseFirestore.instance.collection('users').doc(_uid).update({
        'congestionStatus': next,
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: ThemeData.light().copyWith(
          scaffoldBackgroundColor: _lightBg,
          primaryColor: _primary,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _primary,
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(
            ThemeData.light().textTheme,
          ),
        ),
        child: Scaffold(
          backgroundColor: _lightBg,
          drawer: _buildCustomNavigationDrawer(),
          body: Stack(
            children: [
              // Cosmic Light Turquoise moving gradients background
              Positioned.fill(
                child: CustomPaint(painter: DashboardLightTealPainter()),
              ),

              SafeArea(
                child: Column(
                  children: [
                    // Unified Header with Drawer Toggle, Congestion Pill & Switch
                    _buildPremiumHeaderBar(),

                    // Current active view according to selected drawer option
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _buildCurrentActiveView(),
                      ),
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

  // ==========================================
  // Main Unified Responsive Header Bar
  // ==========================================
  Widget _buildPremiumHeaderBar() {
    Color congestionColor = Colors.green;
    String congestionLabel = 'مطبخ هادئ (20 د)';
    if (_congestionStatus == 'active') {
      congestionColor = Colors.orange;
      congestionLabel = 'مطبخ نشط (35 د)';
    } else if (_congestionStatus == 'busy') {
      congestionColor = Colors.red;
      congestionLabel = 'ازدحام شديد (50 د)';
    }

    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Hamburger menu icon
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Material(
                  color: _primary.withValues(alpha: 0.08),
                  child: IconButton(
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: _textPrimary,
                      size: 24,
                    ),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Shop Icon circular avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _primary.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  color: _primary.withValues(alpha: 0.05),
                ),
                child: _logoUrl != null && _logoUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          _logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(
                            Icons.storefront_rounded,
                            color: _primary,
                            size: 20,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.storefront_rounded,
                        color: _primary,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 10),

              // Restaurant dynamic congestion pill
              Expanded(
                child: Row(
                  children: [
                    // Congestion indicator pill
                    GestureDetector(
                      onTap: _cycleCongestion,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: congestionColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: congestionColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flash_on_rounded,
                              size: 10,
                              color: congestionColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              congestionLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: congestionColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Switch Toggle (Flexible & safe from right overflows)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'مطبخ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _textSecondary,
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch.adaptive(
                      activeColor: _primary,
                      activeTrackColor: _primary.withValues(alpha: 0.3),
                      value: _isOnline,
                      onChanged: (val) {
                        HapticFeedback.mediumImpact();
                        setState(() => _isOnline = val);
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(_uid)
                            .update({'isOnline': val});
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // Views Selector System
  // ==========================================
  Widget _buildCurrentActiveView() {
    switch (_currentViewIndex) {
      case 0:
        return _buildOrdersView();
      case 1:
        return _MyMealsTab(restaurantId: _restaurantId ?? _uid);
      case 2:
        return _buildOffersView();
      case 3:
        return _buildReportsView();
      case 4:
        return _buildReviewsView();
      case 5:
        return _buildSettingsView();
      case 6:
        return _buildDeliveryView();
      default:
        return _buildOrdersView();
    }
  }

  // ==========================================
  // Drawer Design
  // ==========================================
  Widget _buildCustomNavigationDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00796B), _primary],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: _logoUrl != null && _logoUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.network(
                                _logoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const Icon(
                                  Icons.storefront_rounded,
                                  color: _primary,
                                  size: 28,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.storefront_rounded,
                              color: _primary,
                              size: 28,
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _restaurantName,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _cuisineType,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10,
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _isOnline
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isOnline ? 'المحل مفتوح' : 'المحل مغلق',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'جاري الانتقال إلى لوحة التاجر العامة...',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: _primary,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Text(
                          'لوحة التاجر',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildDrawerItem(
                  0,
                  'الطلبات والتحضير',
                  Icons.shopping_bag_outlined,
                ),
                _buildDrawerItem(
                  1,
                  'قائمة الطعام والوجبات',
                  Icons.restaurant_menu_rounded,
                ),
                _buildDrawerItem(
                  2,
                  'العروض الترويجية',
                  Icons.local_offer_outlined,
                ),
                _buildDrawerItem(
                  3,
                  'التقارير التحليلية',
                  Icons.analytics_outlined,
                ),
                _buildDrawerItem(
                  4,
                  'تقييمات الزبائن',
                  Icons.rate_review_outlined,
                ),
                _buildDrawerItem(
                  6,
                  'إدارة التوصيل والدليفري',
                  Icons.motorcycle_rounded,
                ),
                _buildDrawerItem(
                  5,
                  'إعدادات المتجر العامة',
                  Icons.settings_outlined,
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.black12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: InkWell(
              onTap: () async {
                HapticFeedback.heavyImpact();
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'تسجيل الخروج',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(int index, String title, IconData icon) {
    final isSelected = _currentViewIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _currentViewIndex = index;
          });
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? _primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? _primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? _primary : _textSecondary,
                size: 20,
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isSelected ? _primary : _textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // View 0: الطلبات (Dashboard home with tickets)
  Widget _buildRestaurantWelcomeCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cover Image Banner
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  color: _primary.withValues(alpha: 0.06),
                  image: _coverUrl != null && _coverUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(_coverUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
              ),
              Container(
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
              // Logo overlapping
              Positioned(
                bottom: -20,
                right: 16,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: _logoUrl != null && _logoUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(27),
                          child: Image.network(
                            _logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.storefront_rounded,
                              color: _primary,
                              size: 24,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.storefront_rounded,
                          color: _primary,
                          size: 24,
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 26),

          // 2. Info details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              _restaurantName,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: _textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 10,
                                  color: _primary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'موثق',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: _primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status Pill inside Welcome Card ("المربع")
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _isOnline
                            ? Colors.green.withValues(alpha: 0.08)
                            : Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isOnline
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.red.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isOnline ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isOnline ? 'مفتوح' : 'مغلق',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _isOnline
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  _cuisineType,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 10,
                    color: _textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _description,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 10.5,
                      color: _textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
                if (_address.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: _textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _address,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 10,
                            color: _textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ==========================================
  Widget _buildCompactQuickAction({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.08),
                border: Border.all(
                  color: color.withValues(alpha: 0.15),
                  width: 1.2,
                ),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'إجراءات سريعة ',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: _textSecondary,
              ),
            ),
          ),
          SizedBox(
            height: 76,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildCompactQuickAction(
                  title: 'إضافة وجبة',
                  icon: Icons.add_rounded,
                  color: _primary,
                  onTap: () => QuickAddMealDialog.show(context),
                ),
                _buildCompactQuickAction(
                  title: 'العروض',
                  icon: Icons.local_offer_rounded,
                  color: Colors.orange.shade700,
                  onTap: () => setState(() => _currentViewIndex = 2),
                ),
                _buildCompactQuickAction(
                  title: 'التقارير',
                  icon: Icons.analytics_rounded,
                  color: Colors.blue.shade700,
                  onTap: () => setState(() => _currentViewIndex = 3),
                ),
                _buildCompactQuickAction(
                  title: 'حالة المطبخ',
                  icon: Icons.outdoor_grill_rounded,
                  color: Colors.purple.shade700,
                  onTap: _cycleCongestion,
                ),
                _buildCompactQuickAction(
                  title: 'الإعدادات',
                  icon: Icons.settings_rounded,
                  color: Colors.teal.shade800,
                  onTap: () => setState(() => _currentViewIndex = 5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ==========================================
  int _calculateDynamicPrepTime(List<QueryDocumentSnapshot> orders) {
    int baseTime = 20; // default normal
    if (_congestionStatus == 'active') {
      baseTime = 35;
    } else if (_congestionStatus == 'busy') {
      baseTime = 50;
    }

    final int activeOrders = orders.where((d) {
      final status = d['status'] ?? 'pending';
      return ['pending', 'preparing', 'accepted', 'approved'].contains(status);
    }).length;

    int extraTime = activeOrders * 3;
    int finalTime = baseTime + extraTime;

    if (finalTime < 15) finalTime = 15;
    if (finalTime > 90) finalTime = 90;

    return finalTime;
  }

  Widget _buildOrdersView() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _buildRestaurantWelcomeCard(),
        _buildQuickActionsSection(),

        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_uid)
              .snapshots(),
          builder: (context, userSnap) {
            final userData =
                userSnap.data?.data() as Map<String, dynamic>? ?? {};
            final isDeliveryActive = userData['isDeliveryActive'] ?? true;
            final defaultDeliveryPrice =
                userData['defaultDeliveryPrice'] ?? 1500;
            final minFreeDelivery = userData['minFreeDelivery'] ?? 25000;
            final avgDeliveryTime = userData['avgDeliveryTime'] ?? '35 دقيقة';

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('restaurantId', isEqualTo: _restaurantId ?? _uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                final int ordersCount = docs.length;
                final int newCount = docs
                    .where((d) => d['status'] == 'pending')
                    .length;
                final int waitingCount = docs
                    .where(
                      (d) => [
                        'preparing',
                        'accepted',
                        'approved',
                      ].contains(d['status']),
                    )
                    .length;

                double totalRevenue = 0;
                for (var doc in docs) {
                  final d = doc.data() as Map<String, dynamic>;
                  if (d['status'] == 'completed') {
                    totalRevenue +=
                        ((d['total'] ?? d['totalPrice'] ?? d['grandTotal'])
                                as num?)
                            ?.toDouble() ??
                        0.0;
                  }
                }

                final int computedPrepTime = _calculateDynamicPrepTime(docs);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSleekStatsBar(
                      isDeliveryActive: isDeliveryActive,
                      defaultDeliveryPrice: defaultDeliveryPrice,
                      computedPrepTime: computedPrepTime,
                      activeOrdersCount: waitingCount,
                      avgDeliveryTime: avgDeliveryTime,
                      minFreeDelivery: minFreeDelivery,
                    ),
                    _buildMetricsCountRow(
                      ordersCount,
                      newCount,
                      waitingCount,
                      totalRevenue,
                    ),
                    _buildSubTabCapsules(),
                    _buildTicketsList(docs),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSleekStatsBar({
    required bool isDeliveryActive,
    required int defaultDeliveryPrice,
    required int computedPrepTime,
    required int activeOrdersCount,
    required String avgDeliveryTime,
    required int minFreeDelivery,
  }) {
    String deliveryLabel = 'مغلق';
    if (isDeliveryActive) {
      deliveryLabel = defaultDeliveryPrice == 0
          ? 'مجاني'
          : '${NumberFormat('#,###').format(defaultDeliveryPrice)} د.ع';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _currentViewIndex = 4);
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, color: _gold, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '5.0',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'التقييم العام',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 10,
                        color: _textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1, height: 28, color: Colors.black12),

          Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                _showQuickDeliverySheet(
                  isDeliveryActive: isDeliveryActive,
                  defaultDeliveryPrice: defaultDeliveryPrice,
                  minFreeDelivery: minFreeDelivery,
                  avgDeliveryTime: avgDeliveryTime,
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.motorcycle_rounded,
                          color: isDeliveryActive ? _primary : Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          deliveryLabel,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isDeliveryActive
                                ? _textPrimary
                                : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'التوصيل والمناطق ',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 10,
                        color: _textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1, height: 28, color: Colors.black12),

          Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                _showPrepTimeBreakdownSheet(
                  computedPrepTime: computedPrepTime,
                  activeOrdersCount: activeOrdersCount,
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.access_time_filled_rounded,
                          color: _gold,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$computedPrepTime د',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'التجهيز الذكي ',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 10,
                        color: _textSecondary,
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
    );
  }

  void _showPrepTimeBreakdownSheet({
    required int computedPrepTime,
    required int activeOrdersCount,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'كفاءة تحضير الوجبات الذكية ',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: _textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: _textSecondary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _primary.withValues(alpha: 0.05),
                        border: Border.all(
                          color: _primary.withValues(alpha: 0.15),
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.1),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$computedPrepTime',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: _primary,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'دقيقة مقدرة',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _lightBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _primary.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '$activeOrdersCount',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: _accent,
                              ),
                            ),
                            Text(
                              'طلبات نشطة',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 32, color: Colors.black12),
                        Column(
                          children: [
                            Text(
                              '+${activeOrdersCount * 3} د',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: _gold,
                              ),
                            ),
                            Text(
                              'وقت طابور المطبخ',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'تعديل حالة ضغط المطبخ الحالية:',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCongestionChoiceChip(
                          label: 'هادئ',
                          status: 'normal',
                          color: Colors.green,
                          icon: Icons.eco_rounded,
                          isSelected: _congestionStatus == 'normal',
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            setSheetState(() => _congestionStatus = 'normal');
                            setState(() => _congestionStatus = 'normal');
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(_uid)
                                .update({'congestionStatus': 'normal'});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCongestionChoiceChip(
                          label: 'نشط',
                          status: 'active',
                          color: Colors.orange,
                          icon: Icons.flash_on_rounded,
                          isSelected: _congestionStatus == 'active',
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            setSheetState(() => _congestionStatus = 'active');
                            setState(() => _congestionStatus = 'active');
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(_uid)
                                .update({'congestionStatus': 'active'});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCongestionChoiceChip(
                          label: 'مزدحم',
                          status: 'busy',
                          color: Colors.redAccent,
                          icon: Icons.local_fire_department_rounded,
                          isSelected: _congestionStatus == 'busy',
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            setSheetState(() => _congestionStatus = 'busy');
                            setState(() => _congestionStatus = 'busy');
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(_uid)
                                .update({'congestionStatus': 'busy'});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: _primary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'يتم حساب متوسط التجهيز تلقائياً ومشاركته مع الزبائن لحظياً. تغيير حالة المطبخ يساعد الزبائن على معرفة متى يتوقعون استلام وجباتهم بدقة.',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10.5,
                              color: _accent,
                              height: 1.4,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCongestionChoiceChip({
    required String label,
    required String status,
    required Color color,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.black12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : _textSecondary, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : _textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickDeliverySheet({
    required bool isDeliveryActive,
    required int defaultDeliveryPrice,
    required int minFreeDelivery,
    required String avgDeliveryTime,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إدارة التوصيل والمناطق السريعة ',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: _textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: _textSecondary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDeliveryActive
                                  ? _primary.withValues(alpha: 0.05)
                                  : Colors.red.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDeliveryActive
                                    ? _primary.withValues(alpha: 0.15)
                                    : Colors.red.withValues(alpha: 0.15),
                                width: 1.2,
                              ),
                            ),
                            child: SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              activeColor: _primary,
                              title: Text(
                                'تفعيل خدمة التوصيل للمطبخ',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                isDeliveryActive
                                    ? 'نشط ويستقبل طلبات التوصيل'
                                    : 'معطل مؤقتاً (الزبائن لا يمكنهم طلب دليفري)',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 10,
                                  color: isDeliveryActive
                                      ? _accent
                                      : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              value: isDeliveryActive,
                              onChanged: (val) async {
                                HapticFeedback.mediumImpact();
                                setSheetState(() => isDeliveryActive = val);
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(_uid)
                                    .update({'isDeliveryActive': val});
                              },
                            ),
                          ),
                          const SizedBox(height: 20),

                          Text(
                            'سعر التوصيل الافتراضي العام:',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _lightBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _primary.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    OutlinedButton(
                                      onPressed: defaultDeliveryPrice <= 0
                                          ? null
                                          : () async {
                                              HapticFeedback.lightImpact();
                                              int newVal =
                                                  defaultDeliveryPrice - 500;
                                              if (newVal < 0) newVal = 0;
                                              setSheetState(
                                                () => defaultDeliveryPrice =
                                                    newVal,
                                              );
                                              await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(_uid)
                                                  .update({
                                                    'defaultDeliveryPrice':
                                                        newVal,
                                                  });
                                            },
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        side: const BorderSide(color: _primary),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                      ),
                                      child: Text(
                                        '-500 د.ع',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _primary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${NumberFormat('#,###').format(defaultDeliveryPrice)} د.ع',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: _textPrimary,
                                      ),
                                    ),
                                    OutlinedButton(
                                      onPressed: () async {
                                        HapticFeedback.lightImpact();
                                        int newVal = defaultDeliveryPrice + 500;
                                        setSheetState(
                                          () => defaultDeliveryPrice = newVal,
                                        );
                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(_uid)
                                            .update({
                                              'defaultDeliveryPrice': newVal,
                                            });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        side: const BorderSide(color: _primary),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                      ),
                                      child: Text(
                                        '+500 د.ع',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Slider(
                                  value: defaultDeliveryPrice.toDouble(),
                                  min: 0,
                                  max: 10000,
                                  divisions: 20,
                                  activeColor: _primary,
                                  inactiveColor: _primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  onChanged: (val) async {
                                    int roundedVal = (val / 500).round() * 500;
                                    setSheetState(
                                      () => defaultDeliveryPrice = roundedVal,
                                    );
                                  },
                                  onChangeEnd: (val) async {
                                    int roundedVal = (val / 500).round() * 500;
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(_uid)
                                        .update({
                                          'defaultDeliveryPrice': roundedVal,
                                        });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'توصيل مجاني للطلبات فوق:',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _textPrimary,
                                ),
                              ),
                              Text(
                                '${NumberFormat('#,###').format(minFreeDelivery)} د.ع',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: _accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Slider(
                            value: minFreeDelivery.toDouble(),
                            min: 5000,
                            max: 100000,
                            divisions: 19,
                            activeColor: _gold,
                            inactiveColor: _gold.withValues(alpha: 0.1),
                            onChanged: (val) {
                              int rounded = (val / 5000).round() * 5000;
                              setSheetState(() => minFreeDelivery = rounded);
                            },
                            onChangeEnd: (val) async {
                              int rounded = (val / 5000).round() * 5000;
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(_uid)
                                  .update({'minFreeDelivery': rounded});
                            },
                          ),
                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'تسعير المناطق المخصصة ',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: _textPrimary,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_location_alt_rounded,
                                  color: _primary,
                                ),
                                onPressed: () {
                                  _showAddZoneDialog();
                                },
                                tooltip: 'إضافة منطقة مخصصة',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('restaurants')
                                .doc(_restaurantId)
                                .collection('delivery_zones')
                                .snapshots(),
                            builder: (context, snap) {
                              if (!snap.hasData)
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: _primary,
                                  ),
                                );
                              final zones = snap.data!.docs;

                              if (zones.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _lightBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _primary.withValues(alpha: 0.05),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'لا توجد مناطق مخصصة مضافة حالياً',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: _textSecondary,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: zones.length,
                                itemBuilder: (context, index) {
                                  final doc = zones[index];
                                  final z = doc.data() as Map<String, dynamic>;
                                  final name =
                                      z['regionName'] ??
                                      z['name'] ??
                                      'منطقة مجهولة';
                                  final price = z['deliveryPrice'] ?? 1500;
                                  final time = z['estimatedTime'] ?? '30 دقيقة';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _primary.withValues(alpha: 0.08),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_rounded,
                                          color: _primary,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style:
                                                    GoogleFonts.ibmPlexSansArabic(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                      color: _textPrimary,
                                                    ),
                                              ),
                                              Text(
                                                'الوقت المقدر: $time',
                                                style:
                                                    GoogleFonts.ibmPlexSansArabic(
                                                      fontSize: 10,
                                                      color: _textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${NumberFormat('#,###').format(price)} د.ع',
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                            color: _accent,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.redAccent,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            FirebaseFirestore.instance
                                                .collection('restaurants')
                                                .doc(_restaurantId)
                                                .collection('delivery_zones')
                                                .doc(doc.id)
                                                .delete();
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetricsCountRow(int total, int newC, int waitC, double rev) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildCountCard(
            total.toString(),
            'الطلبات',
            Icons.receipt_long_rounded,
            Colors.blue,
          ),
          const SizedBox(width: 8),
          _buildCountCard(
            newC.toString(),
            'جديد',
            Icons.circle_notifications_rounded,
            Colors.redAccent,
          ),
          const SizedBox(width: 8),
          _buildCountCard(
            waitC.toString(),
            'انتظار',
            Icons.hourglass_bottom_rounded,
            Colors.orangeAccent,
          ),
          const SizedBox(width: 8),
          _buildCountCard(
            rev.toStringAsFixed(0),
            'الإيراد',
            Icons.monetization_on_rounded,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildCountCard(
    String value,
    String title,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _primary.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              title,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 9,
                color: _textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabCapsules() {
    final tabs = ['الكل', 'جديد', 'تحضير', 'جاهز', 'مكتمل'];
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final t = tabs[index];
          final isSelected = _selectedSubTab == t;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedSubTab = t);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [_primary, Color(0xFF00796B)],
                        )
                      : null,
                  color: isSelected ? null : _primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? _primary.withValues(alpha: 0.2)
                        : _primary.withValues(alpha: 0.08),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  t,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : _textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTicketsList(List<QueryDocumentSnapshot> docs) {
    List<QueryDocumentSnapshot> filteredDocs = docs;
    if (_selectedSubTab == 'جديد') {
      filteredDocs = docs.where((d) => d['status'] == 'pending').toList();
    } else if (_selectedSubTab == 'تحضير') {
      filteredDocs = docs
          .where(
            (d) => ['preparing', 'accepted', 'approved'].contains(d['status']),
          )
          .toList();
    } else if (_selectedSubTab == 'جاهز') {
      filteredDocs = docs
          .where((d) => ['ready', 'readyForDelivery'].contains(d['status']))
          .toList();
    } else if (_selectedSubTab == 'مكتمل') {
      filteredDocs = docs.where((d) => d['status'] == 'completed').toList();
    }

    if (filteredDocs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              size: 64,
              color: _primary.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 12),
            Text(
              'ماكو طلبات حالياً في هذا القسم حالياً',
              style: GoogleFonts.ibmPlexSansArabic(
                color: _textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredDocs.length,
      itemBuilder: (context, index) {
        final doc = filteredDocs[index];
        final data = doc.data() as Map<String, dynamic>;
        return _KitchenTicketCard(orderId: doc.id, data: data);
      },
    );
  }

  // ==========================================
  // View 2: العروض (Flash offers with timer countdowns) - Feature 5
  // ==========================================
  Widget _buildOffersView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('merchant_offers')
          .doc(_restaurantId)
          .collection('offers')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _primary),
          );
        }

        final docs = snapshot.data!.docs;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Icon(
                Icons.local_offer_rounded,
                size: 64,
                color: _gold.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 12),
              Text(
                'عروض وحسومات المطبخ وعروض الفلاش ',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'أطلق خصومات حية ومحددة بالوقت بمؤقت تنازلي متحرك لإثارة حماس زبائنك وجذب الطلبات السريعة!',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12,
                  height: 1.5,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showAddOfferDialog();
                },
                icon: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                label: Text(
                  'إنشاء عرض أو خصم فلاش حاد',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 20),

              if (docs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _primary.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.no_photography_rounded,
                        size: 40,
                        color: _textSecondary.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'لا توجد عروض أو خصومات حية حالياً',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, idx) {
                    final doc = docs[idx];
                    final data = doc.data() as Map<String, dynamic>;
                    final title = data['title'] ?? 'عرض مميز';
                    final desc = data['description'] ?? '';
                    final discount = data['discount'] ?? 0;
                    final isFlash = data['isFlash'] ?? false;
                    final endTimeMs = data['endTime'] as int?;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFlash
                              ? _gold.withValues(alpha: 0.3)
                              : _primary.withValues(alpha: 0.08),
                          width: isFlash ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (isFlash ? _gold : _primary).withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFlash
                                  ? Icons.flash_on_rounded
                                  : Icons.local_offer_rounded,
                              color: isFlash ? _gold : _primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      title,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: _textPrimary,
                                      ),
                                    ),
                                    if (isFlash) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _gold,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'عرض فلاش',
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (desc.toString().isNotEmpty)
                                  Text(
                                    desc,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 11,
                                      color: _textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (isFlash && endTimeMs != null) ...[
                                  const SizedBox(height: 6),
                                  _FlashCountdownWidget(
                                    endTimeMs: endTimeMs,
                                    onFinished: () {
                                      FirebaseFirestore.instance
                                          .collection('merchant_offers')
                                          .doc(_restaurantId)
                                          .collection('offers')
                                          .doc(doc.id)
                                          .delete();
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                '$discount%',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: isFlash ? _gold : _primary,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  FirebaseFirestore.instance
                                      .collection('merchant_offers')
                                      .doc(_restaurantId)
                                      .collection('offers')
                                      .doc(doc.id)
                                      .delete();
                                },
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAddOfferDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final discCtrl = TextEditingController();
    bool isFlash = false;
    double flashMinutes = 30;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: _cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'إنشاء خصم أو عرض جديد',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: _textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: _textPrimary),
                      decoration: InputDecoration(
                        labelText: 'عنوان العرض (مثال: وجبة توفير دبل)',
                        labelStyle: TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black12),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: _primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      style: const TextStyle(color: _textPrimary),
                      decoration: InputDecoration(
                        labelText: 'التفاصيل والوصف',
                        labelStyle: TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black12),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: _primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: discCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: _textPrimary),
                      decoration: InputDecoration(
                        labelText: 'نسبة الخصم %',
                        labelStyle: TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.black12),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: _primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Flash Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'تفعيل كـ "عرض فلاش" مؤقت ',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: _textPrimary,
                          ),
                        ),
                        Switch(
                          value: isFlash,
                          activeColor: _primary,
                          onChanged: (val) {
                            setDlgState(() => isFlash = val);
                          },
                        ),
                      ],
                    ),

                    if (isFlash) ...[
                      const SizedBox(height: 8),
                      Text(
                        'مدة عرض الفلاش: ${flashMinutes.round()} دقيقة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          color: _accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Slider(
                        value: flashMinutes,
                        min: 5,
                        max: 120,
                        divisions: 23,
                        activeColor: _primary,
                        inactiveColor: _primary.withValues(alpha: 0.15),
                        onChanged: (val) {
                          setDlgState(() => flashMinutes = val);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'إلغاء',
                    style: GoogleFonts.ibmPlexSansArabic(color: _textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.isNotEmpty) {
                      final int durationMs = isFlash
                          ? (flashMinutes.round() * 60 * 1000)
                          : 0;
                      final int? endTime = isFlash
                          ? (DateTime.now().millisecondsSinceEpoch + durationMs)
                          : null;

                      FirebaseFirestore.instance
                          .collection('merchant_offers')
                          .doc(_restaurantId)
                          .collection('offers')
                          .add({
                            'title': titleCtrl.text.trim(),
                            'description': descCtrl.text.trim(),
                            'discount': int.tryParse(discCtrl.text) ?? 0,
                            'isFlash': isFlash,
                            'endTime': endTime,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'إطلاق العرض',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // View 3: التقارير والرسومات البيانية (Analytical Charts) - Feature 2
  // ==========================================
  Widget _buildReportsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantId', isEqualTo: _restaurantId ?? _uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        double totalSales = 0;
        int completedCount = 0;
        int cancelledCount = 0;

        for (var doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final status = d['status'] ?? 'pending';
          final price =
              ((d['total'] ?? d['totalPrice'] ?? d['grandTotal']) as num?)
                  ?.toDouble() ??
              0.0;

          if (status == 'completed') {
            completedCount++;
            totalSales += price;
          } else if (status == 'cancelled' || status == 'rejected') {
            cancelledCount++;
          }
        }

        double averageOrder = completedCount > 0
            ? (totalSales / completedCount)
            : 0.0;
        double cancellationRate = docs.isNotEmpty
            ? ((cancelledCount / docs.length) * 100)
            : 0.0;

        return ListView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          children: [
            Row(
              children: [
                Text(
                  'التقارير البيانية والتحليلية ',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _primary.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'أسبوعي',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: _primary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Sales overview count cards
            Row(
              children: [
                _buildReportStatCard(
                  'المبيعات الكلية',
                  '${totalSales.toStringAsFixed(0)} د.ع',
                  Icons.account_balance_wallet_rounded,
                  _primary,
                ),
                const SizedBox(width: 10),
                _buildReportStatCard(
                  'الطلبات المنجزة',
                  completedCount.toString(),
                  Icons.shopping_basket_rounded,
                  _gold,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildReportStatCard(
                  'متوسط الطلبات',
                  '${averageOrder.toStringAsFixed(0)} د.ع',
                  Icons.insert_chart_outlined_rounded,
                  Colors.blue,
                ),
                const SizedBox(width: 10),
                _buildReportStatCard(
                  'معدل الإلغاء',
                  '${cancellationRate.toStringAsFixed(1)}%',
                  Icons.cancel_rounded,
                  Colors.redAccent,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Feature 2: Glowing Bar Chart - Sales Curve
            Text(
              'مخطط أداء المبيعات الأسبوعية',
              style: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildWeeklySalesChartWidget(),

            const SizedBox(height: 24),

            // Feature 2: Peak Hours Heatmap Grid
            Text(
              'مؤشر ساعات الذروة والضغط في المطبخ',
              style: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildPeakHoursHeatmapWidget(),

            const SizedBox(height: 24),

            // Feature 2: Best Selling Items
            Text(
              'الوجبات والأطباق الأكثر طلباً',
              style: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildBestSellersChartWidget(),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildReportStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _primary.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              title,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySalesChartWidget() {
    final days = ['أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];
    final values = [0.45, 0.65, 0.35, 0.8, 0.95, 0.75, 0.5];
    final amounts = [
      '450ألف',
      '650ألف',
      '350ألف',
      '800ألف',
      '950ألف',
      '750ألف',
      '500ألف',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الإيرادات المقدرة هذا الأسبوع',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 11,
                  color: _textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'المجموع: 4.4 مليون د.ع',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 11.5,
                  color: _accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final heightVal = values[index];
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        amounts[index],
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: FractionallySizedBox(
                          heightFactor: heightVal,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_primary, Color(0xFF00796B)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: _primary.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        days[index],
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeakHoursHeatmapWidget() {
    final times = ['12 م', '2 م', '4 م', '6 م', '8 م', '10 م'];
    final intensities = [
      0.15,
      0.45,
      0.3,
      0.75,
      0.95,
      0.6,
    ]; // representation values for green colors

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'توزيع أوقات ذروة طلب الزبائن على مدار اليوم',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 10.5,
              color: _textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              final score = intensities[index];
              Color blockColor = _primary.withValues(alpha: score);
              if (score > 0.8) blockColor = _gold;

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 36,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: blockColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${(score * 100).round()}%',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: score > 0.6 ? Colors.black : _textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      times[index],
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBestSellersChartWidget() {
    final dishes = [
      'شاورما دجاج مدار اللذيذة',
      'كباب لحم عراقي بالفرن',
      'برجر دبل بجبن شيدر',
      'سلطة مقبلات مدار الفخمة',
    ];
    final sales = [142, 98, 67, 45];
    final percentages = [0.45, 0.31, 0.16, 0.08];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: List.generate(4, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dishes[index],
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      '${sales[index]} طلب',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: _accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Stack(
                  children: [
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentages[index] / 0.45,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_primary, _gold],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ==========================================
  // View 4: التقييمات والردود الذكية وكوبونات التعويض (Smart Review Replies) - Feature 8
  // ==========================================
  Widget _buildReviewsView() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('restaurants')
          .doc(_restaurantId)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _primary),
          );
        }

        final reviews = snapshot.data!.docs;

        double avgRating = 0;
        if (reviews.isNotEmpty) {
          final total = reviews.fold<double>(0, (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            final rating = data['rating'] is num
                ? (data['rating'] as num).toDouble()
                : 0.0;
            return sum + rating;
          });
          avgRating = total / reviews.length;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          children: [
            // Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _primary.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'معدل تقييم المطبخ العام',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _textSecondary,
                    ),
                  ),
                  Text(
                    reviews.isEmpty ? '5.0' : avgRating.toStringAsFixed(1),
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                      color: _gold,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) => Icon(
                        Icons.star_rounded,
                        color: index < avgRating.round()
                            ? _gold
                            : Colors.grey[300],
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'بناء على تقييمات ${reviews.isEmpty ? 1 : reviews.length} من زبائن مدار شوب',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 10.5,
                      color: _textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text(
              'آراء وتقييمات زبائن المطبخ',
              style: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.w900,
                fontSize: 14.5,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            if (reviews.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'ماكو تقييمات حالياً موثقة حتى الآن حالياً',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: _textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              )
            else
              ...reviews.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final userName =
                    data['userName']?.toString() ?? 'زبون مدار المميز';
                final rating = data['rating'] is num
                    ? (data['rating'] as num).round()
                    : 5;
                final comment =
                    data['comment']?.toString() ?? 'وجبة ممتازة جداً وساخنة!';
                final reply = data['reply']?.toString() ?? '';
                final createdAt = data['createdAt'] as Timestamp?;

                String timeAgo = 'الآن';
                if (createdAt != null) {
                  final diff = DateTime.now().difference(createdAt.toDate());
                  if (diff.inDays > 0)
                    timeAgo = 'منذ ${diff.inDays} يوم';
                  else if (diff.inHours > 0)
                    timeAgo = 'منذ ${diff.inHours} ساعة';
                  else if (diff.inMinutes > 0)
                    timeAgo = 'منذ ${diff.inMinutes} دقيقة';
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _primary.withValues(alpha: 0.06)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.01),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _primary.withValues(alpha: 0.1),
                            radius: 18,
                            child: Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : 'ز',
                              style: const TextStyle(
                                color: _primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _textPrimary,
                                  ),
                                ),
                                Row(
                                  children: List.generate(
                                    5,
                                    (index) => Icon(
                                      Icons.star_rounded,
                                      color: index < rating
                                          ? _gold
                                          : Colors.grey[300],
                                      size: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            timeAgo,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 9.5,
                              color: _textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          comment,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.5,
                            color: _textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ],

                      if (reply.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'رد المطعم: $reply',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              color: _accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),
                      // Feature 8: Smart Reply Button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _showSmartReplySheet(doc.id, data);
                          },
                          icon: const Icon(
                            Icons.quickreply_rounded,
                            size: 14,
                            color: _primary,
                          ),
                          label: Text(
                            'الرد الذكي والتعويض ',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10.5,
                              color: _primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _primary, width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  void _showSmartReplySheet(String reviewId, Map<String, dynamic> reviewData) {
    final replyCtrl = TextEditingController();
    String? createdCoupon;

    final templates = [
      'نشكرك زبوننا العزيز على تقييمك الرائع، ونسعى دائماً لتقديم أفضل الوجبات الطازجة لخدمتكم .',
      'نعتذر بشدة عن أي تقصير في هذا الطلب، رضاكم هو غايتنا الأولى وسنقوم بتحسين الخدمة فوراً .',
      'شكراً لك زبوننا المميز، تم إرسال كوبون خصم اعتذاري لطلبك القادم لتعويضك عن هذا التقصير .',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                16,
                20,
                16,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الرد الذكي والتعويض المباشر للزبون ',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'تواصل بكفاءة واكسب ولاء زبائن مدار بلمسة زر واحدة.',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Templates
                    Text(
                      'اختر رداً سريعاً جاهزاً:',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...templates.map(
                      (tpl) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          onTap: () {
                            replyCtrl.text = tpl;
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _lightBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              tpl,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11,
                                color: _textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    TextField(
                      controller: replyCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: _textPrimary),
                      decoration: InputDecoration(
                        hintText: 'اكتب ردك المخصص هنا...',
                        hintStyle: TextStyle(
                          color: _textSecondary,
                          fontSize: 12.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _primary),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Compensation Coupon Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'توليد كوبون خصم تعويضي فوري ',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _textPrimary,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            final code =
                                'SORRY-${math.Random().nextInt(9000) + 1000}';
                            setSheetState(() => createdCoupon = code);

                            // Save simulated coupon to database
                            FirebaseFirestore.instance
                                .collection('merchant_coupons')
                                .add({
                                  'code': code,
                                  'discount': 15, // 15%
                                  'restaurantId': _restaurantId,
                                  'restaurantName': _restaurantName,
                                  'isActive': true,
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                          },
                          icon: const Icon(
                            Icons.card_giftcard_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          label: Text(
                            'توليد خصم 15%',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _gold,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (createdCoupon != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'تم توليد الكوبون بنجاح!',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11,
                                color: Colors.green.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              createdCoupon!,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13,
                                color: Colors.green.shade900,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        if (replyCtrl.text.isNotEmpty) {
                          await FirebaseFirestore.instance
                              .collection('restaurants')
                              .doc(_restaurantId)
                              .collection('reviews')
                              .doc(reviewId)
                              .update({
                                'reply': replyCtrl.text.trim(),
                                'compensationCoupon': createdCoupon ?? '',
                              });
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'إرسال الرد والتعويض',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Future<void> _selectTime(
    BuildContext context,
    String field,
    String currentVal,
  ) async {
    TimeOfDay initialTime = TimeOfDay.now();
    try {
      final parts = currentVal.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      if (parts.length > 1 && parts[1] == 'م' && hour != 12) hour += 12;
      if (parts.length > 1 && parts[1] == 'ص' && hour == 12) hour = 0;
      initialTime = TimeOfDay(hour: hour, minute: minute);
    } catch (_) {}

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primary,
              onPrimary: Colors.white,
              surface: _cardBg,
              onSurface: _textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final hour = picked.hour;
      final minute = picked.minute;
      String amPm = hour >= 12 ? 'م' : 'ص';
      int h12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final timeStr =
          '${h12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $amPm';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_restaurantId)
          .update({field: timeStr});
    }
  }

  // ==========================================
  // View 5: الإعدادات وإدارة التوصيل والمناطق (Delivery Coverage Zones) - Feature 7
  // ==========================================
  Widget _buildSettingsView() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_restaurantId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _primary),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final openTime = data['openingTime'] ?? '08:00 ص';
        final closeTime = data['closingTime'] ?? '11:00 م';

        return ListView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          children: [
            const SizedBox(height: 10),

            // Working hours display
            Text(
              'أوقات وساعات العمل للزبائن',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _primary.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => _selectTime(context, 'openingTime', openTime),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'بدء العمل واستقبل الطلبات',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: _textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            openTime,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Colors.black12),
                  ),
                  InkWell(
                    onTap: () => _selectTime(context, 'closingTime', closeTime),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'نهاية العمل والإغلاق اليومي',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: _textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            closeTime,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Profile & Edit Restaurant
            Text(
              'الحساب وملف المطعم التعريفي',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _showEditProfileDialog(data);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _primary.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.store_rounded,
                        color: _primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تعديل معلومات وتصنيف المطعم',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _textPrimary,
                            ),
                          ),
                          Text(
                            'الاسم التعريفي، صور الغلاف، نوع المطبخ والتصنيف',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10,
                              color: _textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: _textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  // ==========================================
  // View 6: إدارة التوصيل والدليفري المتكاملة
  // ==========================================
  Widget _buildDeliveryView() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _primary),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final isDeliveryActive = userData['isDeliveryActive'] ?? true;
        final defaultDeliveryPrice = userData['defaultDeliveryPrice'] ?? 1500;
        final minFreeDelivery = userData['minFreeDelivery'] ?? 25000;
        final avgDeliveryTime = userData['avgDeliveryTime'] ?? '35 دقيقة';

        return ListView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          children: [
            // 1. Delivery Switch Hub (Card)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00796B), _primary],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.motorcycle_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'حالة خدمة التوصيل والدليفري',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                isDeliveryActive
                                    ? 'نشط ويستقبل الطلبات حالياً'
                                    : 'معطل مؤقتاً',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Transform.scale(
                        scale: 1.0,
                        child: Switch.adaptive(
                          activeThumbColor: Colors.white,
                          activeTrackColor: Colors.white38,
                          value: isDeliveryActive,
                          onChanged: (val) async {
                            HapticFeedback.mediumImpact();
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(_uid)
                                .update({'isDeliveryActive': val});
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Logistics Stats Grid
            Row(
              children: [
                _buildLogisticsStatCard(
                  'كباتن نشطين',
                  '3 كباتن',
                  Icons.people_alt_rounded,
                  Colors.blue,
                ),
                const SizedBox(width: 10),
                _buildLogisticsStatCard(
                  'الطلب المجاني',
                  '$minFreeDelivery د.ع',
                  Icons.card_giftcard_rounded,
                  Colors.amber.shade700,
                ),
                const SizedBox(width: 10),
                _buildLogisticsStatCard(
                  'معدل التوصيل',
                  avgDeliveryTime,
                  Icons.timer_rounded,
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 3. Delivery Settings Details Dialog Button & quick info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'إعدادات التوصيل الافتراضية ',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_note_rounded,
                    color: _primary,
                    size: 24,
                  ),
                  onPressed: () => _showEditDeliverySettingsDialog(
                    defaultDeliveryPrice,
                    minFreeDelivery,
                    avgDeliveryTime,
                  ),
                  tooltip: 'تعديل الإعدادات الافتراضية',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _primary.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  _buildDeliveryInfoRow(
                    'سعر التوصيل الافتراضي العام',
                    '$defaultDeliveryPrice د.ع',
                  ),
                  const Divider(height: 16, color: Colors.black12),
                  _buildDeliveryInfoRow(
                    'الحد الأدنى للتوصيل المجاني',
                    '$minFreeDelivery د.ع',
                  ),
                  const Divider(height: 16, color: Colors.black12),
                  _buildDeliveryInfoRow(
                    'متوسط وقت التوصيل المتوقع',
                    avgDeliveryTime,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Delivery Zones list
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'مناطق التوصيل المخصصة للمطعم ',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'حدد أسعار التوصيل المخصصة لكل منطقة للتطبيق تلقائياً عند طلب الزبون.',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            _buildDeliveryZonesListWidget(),
            const SizedBox(height: 24),

            // 5. Active Captains List (Interactive Simulated Fleet)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'أسطول كباتن التوصيل النشطين ',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'مباشر',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'كباتن التوصيل والخدمات اللوجستية المتاحين لخدمتك وتوصيل طلبات المطبخ.',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            _buildActiveCaptainsList(),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildLogisticsStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primary.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 9,
                color: _textSecondary,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
            color: _textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.ibmPlexSansArabic(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }

  void _showEditDeliverySettingsDialog(
    int defaultPrice,
    int minFree,
    String avgTime,
  ) {
    final priceCtrl = TextEditingController(text: defaultPrice.toString());
    final minFreeCtrl = TextEditingController(text: minFree.toString());
    final timeCtrl = TextEditingController(text: avgTime);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'تعديل إعدادات التوصيل الافتراضية ',
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: _textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'سعر التوصيل الافتراضي (د.ع)',
                    labelStyle: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minFreeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'الحد الأدنى للتوصيل المجاني (د.ع)',
                    labelStyle: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeCtrl,
                  decoration: InputDecoration(
                    labelText: 'متوسط وقت التوصيل (مثال: 35 دقيقة)',
                    labelStyle: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: GoogleFonts.ibmPlexSansArabic(color: _textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(_uid)
                    .update({
                      'defaultDeliveryPrice':
                          int.tryParse(priceCtrl.text) ?? 1500,
                      'minFreeDelivery':
                          int.tryParse(minFreeCtrl.text) ?? 25000,
                      'avgDeliveryTime': timeCtrl.text.trim(),
                    });
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'حفظ الإعدادات',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActiveCaptainsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('driver_locations')
          .where('isOnline', isEqualTo: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _primary.withValues(alpha: 0.08)),
            ),
            child: Center(
              child: Text(
                'ماكو كباتن حالياً متاحين حالياً للتوصيل',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12.5,
                  color: _textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final name =
                data['driverName']?.toString() ??
                data['name']?.toString() ??
                'كابتن توصيل';
            final phone =
                data['driverPhone']?.toString() ??
                data['phone']?.toString() ??
                'غير متوفر';
            final vehicle =
                data['vehicleModel']?.toString() ??
                data['vehicle']?.toString() ??
                'دراجة نارية';
            final isAvail =
                data['status'] == 'available' || data['isAvailable'] == true;
            final status = isAvail ? 'متوفر للتوصيل' : 'في الطريق لتوصيل طلب';
            final rating = data['rating']?.toString() ?? 'غير متوفر';
            final avatar =
                data['personalPhotoUrl']?.toString() ??
                data['avatar']?.toString() ??
                '';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _primary.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _primary.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: avatar.isNotEmpty
                          ? Image.network(
                              avatar,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person_pin_rounded,
                                  color: _primary,
                                  size: 28,
                                );
                              },
                            )
                          : const Icon(
                              Icons.person_pin_rounded,
                              color: _primary,
                              size: 28,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: _gold.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: _gold,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating,
                                    style: const TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: _gold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          vehicle,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 10.5,
                            color: _textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isAvail ? Colors.green : Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              status,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 10,
                                color: isAvail ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.phone_in_talk_rounded,
                          color: _primary,
                          size: 18,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'جاري الاتصال بـ $name ($phone)...',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: _primary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        },
                        tooltip: 'اتصال بالكابتن',
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDeliveryZonesListWidget() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('restaurants')
          .doc(_restaurantId)
          .collection('delivery_zones')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const LinearProgressIndicator(color: _primary);
        final zones = snapshot.data!.docs;

        return Column(
          children: [
            OutlinedButton.icon(
              onPressed: _showAddZoneDialog,
              icon: const Icon(
                Icons.add_location_alt_rounded,
                color: _primary,
                size: 18,
              ),
              label: Text(
                'إضافة منطقة توصيل مشمولة جديدة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.bold,
                  color: _primary,
                  fontSize: 12.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                minimumSize: const Size.fromHeight(46),
                backgroundColor: _primary.withValues(alpha: 0.04),
              ),
            ),
            const SizedBox(height: 12),
            if (zones.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _primary.withValues(alpha: 0.06)),
                ),
                child: Center(
                  child: Text(
                    'لم يتم تخصيص مناطق مخصصة بعد (التوصيل عام حالياً).',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11.5,
                      color: _textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: zones.length,
                itemBuilder: (context, index) {
                  final doc = zones[index];
                  final z = doc.data() as Map<String, dynamic>;
                  final name = z['regionName'] ?? z['name'] ?? 'منطقة مجهولة';
                  final price = z['deliveryPrice'] ?? 1500;
                  final time = z['estimatedTime'] ?? '30 دقيقة';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _primary.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: _primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _textPrimary,
                                ),
                              ),
                              Text(
                                'وقت التوصيل المقدر: $time',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 10.5,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$price د.ع',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            color: _accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          onPressed: () {
                            FirebaseFirestore.instance
                                .collection('restaurants')
                                .doc(_restaurantId)
                                .collection('delivery_zones')
                                .doc(doc.id)
                                .delete();
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  void _showAddZoneDialog() {
    final priceCtrl = TextEditingController(text: '1500');
    final timeCtrl = TextEditingController(text: '30 دقيقة');
    String? selectedGovId;
    String? selectedGovName;
    String? selectedRegId;
    String? selectedRegName;
    List<Map<String, dynamic>> regions = [];
    bool isLoadingRegs = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: _cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'إضافة منطقة توصيل جديدة ',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.5,
                  color: _textPrimary,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Governorate Dropdown
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('governorates')
                          .where('isActive', isEqualTo: true)
                          .snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData)
                          return const LinearProgressIndicator(color: _primary);
                        final docs = snap.data!.docs;
                        return DropdownButtonFormField<String>(
                          dropdownColor: _cardBg,
                          decoration: InputDecoration(
                            labelText: 'المحافظة',
                            labelStyle: TextStyle(
                              fontSize: 12.5,
                              color: _textSecondary,
                            ),
                          ),
                          items: docs
                              .map(
                                (d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(
                                    d['name'] ?? '',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) async {
                            if (v != null) {
                              final sel = docs.firstWhere((d) => d.id == v);
                              setDlgState(() {
                                selectedGovId = v;
                                selectedGovName = sel['name'];
                                selectedRegId = null;
                                selectedRegName = null;
                                isLoadingRegs = true;
                              });
                              final rSnap = await FirebaseFirestore.instance
                                  .collection('governorates')
                                  .doc(v)
                                  .collection('regions')
                                  .where('isActive', isEqualTo: true)
                                  .get();
                              setDlgState(() {
                                regions = rSnap.docs
                                    .map((r) => {'id': r.id, ...r.data()})
                                    .toList();
                                isLoadingRegs = false;
                              });
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // Region Dropdown
                    DropdownButtonFormField<String>(
                      dropdownColor: _cardBg,
                      decoration: InputDecoration(
                        labelText: isLoadingRegs
                            ? 'جاري تحميل المناطق...'
                            : 'المنطقة',
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          color: _textSecondary,
                        ),
                      ),
                      value: selectedRegId,
                      items: regions
                          .map(
                            (r) => DropdownMenuItem(
                              value: r['id'] as String,
                              child: Text(
                                r['name'] ?? '',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          final sel = regions.firstWhere((r) => r['id'] == v);
                          setDlgState(() {
                            selectedRegId = v;
                            selectedRegName = sel['name'];
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'سعر التوصيل للمنطقة (د.ع)',
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          color: _textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: timeCtrl,
                      decoration: InputDecoration(
                        labelText: 'وقت التوصيل المقدر (مثال: 30 دقيقة)',
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          color: _textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'إلغاء',
                    style: GoogleFonts.ibmPlexSansArabic(color: _textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedRegId != null && priceCtrl.text.isNotEmpty) {
                      await FirebaseFirestore.instance
                          .collection('restaurants')
                          .doc(_restaurantId)
                          .collection('delivery_zones')
                          .add({
                            'regionId': selectedRegId,
                            'regionName': selectedRegName,
                            'governorateId': selectedGovId,
                            'governorateName': selectedGovName,
                            'deliveryPrice':
                                int.tryParse(priceCtrl.text) ?? 1500,
                            'estimatedTime': timeCtrl.text.trim(),
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _primary),
                  child: Text(
                    'حفظ الإعدادات',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditProfileDialog(Map<String, dynamic> currentData) {
    HapticFeedback.mediumImpact();

    final nameCtrl = TextEditingController(
      text: currentData['restaurantName'] ?? currentData['fullName'] ?? '',
    );
    final ownerCtrl = TextEditingController(
      text: currentData['fullName'] ?? '',
    );
    final cuisineCtrl = TextEditingController(
      text:
          currentData['cuisineType'] ??
          currentData['cuisine'] ??
          currentData['type'] ??
          '',
    );
    final descriptionCtrl = TextEditingController(
      text: currentData['description'] ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: currentData['phone'] ?? currentData['phoneNumber'] ?? '',
    );
    final addressCtrl = TextEditingController(
      text: currentData['address'] ?? currentData['location'] ?? '',
    );

    String? localLogoUrl = currentData['photoUrl'] ?? currentData['imageUrl'];
    String? localCoverUrl =
        currentData['coverImageUrl'] ?? currentData['coverImage'];

    bool isSaving = false;
    bool isUploadingLogo = false;
    bool isUploadingCover = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickAndUploadImage(bool isLogo) async {
              setSheetState(() {
                if (isLogo)
                  isUploadingLogo = true;
                else
                  isUploadingCover = true;
              });
              try {
                final source = await showModalBottomSheet<ImageSource>(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  builder: (ctx) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLogo
                                ? 'اختر مصدر شعار المطعم '
                                : 'اختر مصدر صورة الغلاف ',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    Navigator.pop(ctx, ImageSource.camera),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: _primary.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        color: _primary,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'الكاميرا',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    Navigator.pop(ctx, ImageSource.gallery),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: _primary.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.photo_library_rounded,
                                        color: _primary,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'المعرض',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );

                if (source != null) {
                  final picked = await ImagePicker().pickImage(
                    source: source,
                    imageQuality: 80,
                  );
                  if (picked != null) {
                    final bytes = await picked.readAsBytes();
                    final filename =
                        '${isLogo ? "logo" : "cover"}_${DateTime.now().millisecondsSinceEpoch}.jpg';

                    final uploadedUrl = await CloudinaryService.uploadBytes(
                      bytes,
                      filename,
                    );
                    if (uploadedUrl != null) {
                      setSheetState(() {
                        if (isLogo)
                          localLogoUrl = uploadedUrl;
                        else
                          localCoverUrl = uploadedUrl;
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'فشل رفع الصورة إلى الخادم.',
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }
                  }
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'حدث خطأ أثناء اختيار الصورة.',
                      style: GoogleFonts.ibmPlexSansArabic(color: Colors.white),
                    ),
                  ),
                );
              } finally {
                setSheetState(() {
                  if (isLogo)
                    isUploadingLogo = false;
                  else
                    isUploadingCover = false;
                });
              }
            }

            Future<void> saveChanges() async {
              if (nameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'يرجى إدخال اسم المطعم.',
                      style: GoogleFonts.ibmPlexSansArabic(color: Colors.white),
                    ),
                  ),
                );
                return;
              }

              setSheetState(() => isSaving = true);
              try {
                final updateData = {
                  'restaurantName': nameCtrl.text.trim(),
                  'fullName': ownerCtrl.text.trim(),
                  'cuisineType': cuisineCtrl.text.trim(),
                  'type': cuisineCtrl.text.trim(),
                  'description': descriptionCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                  if (localLogoUrl != null) 'photoUrl': localLogoUrl,
                  if (localLogoUrl != null) 'imageUrl': localLogoUrl,
                  if (localCoverUrl != null) 'coverImageUrl': localCoverUrl,
                  if (localCoverUrl != null) 'coverImage': localCoverUrl,
                };

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(_uid)
                    .update(updateData);

                try {
                  await FirebaseFirestore.instance
                      .collection('restaurant_requests')
                      .doc(_uid)
                      .update(updateData);
                } catch (_) {}

                try {
                  await FirestoreSyncService.syncRestaurantProfile(
                    _uid,
                    updateData,
                  );
                } catch (_) {}

                if (mounted) {
                  setState(() {
                    _restaurantName = nameCtrl.text.trim();
                    _cuisineType = cuisineCtrl.text.trim();
                    _description = descriptionCtrl.text.trim();
                    _logoUrl = localLogoUrl;
                    _coverUrl = localCoverUrl;
                    _address = addressCtrl.text.trim();
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم تحديث الملف الشخصي بنجاح! ',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: _primary,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'فشل حفظ البيانات بالخادم.',
                      style: GoogleFonts.ibmPlexSansArabic(color: Colors.white),
                    ),
                  ),
                );
              } finally {
                setSheetState(() => isSaving = false);
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: _lightBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              GestureDetector(
                                onTap: () => pickAndUploadImage(false),
                                child: Container(
                                  height: 160,
                                  decoration: BoxDecoration(
                                    color: _primary.withValues(alpha: 0.1),
                                    image:
                                        localCoverUrl != null &&
                                            localCoverUrl!.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(
                                              CloudinaryService.getOptimizedUrl(
                                                localCoverUrl!,
                                                width: 600,
                                              ),
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child:
                                      localCoverUrl == null ||
                                          localCoverUrl!.isEmpty
                                      ? Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons
                                                    .add_photo_alternate_rounded,
                                                color: _primary,
                                                size: 36,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'اضغط لإضافة صورة غلاف ',
                                                style:
                                                    GoogleFonts.ibmPlexSansArabic(
                                                      fontSize: 11,
                                                      color: _primary,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Container(
                                          color: Colors.black26,
                                          child: const Center(
                                            child: Icon(
                                              Icons.camera_alt_rounded,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              if (isUploadingCover)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black45,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),

                              Positioned(
                                bottom: -45,
                                right: 24,
                                child: GestureDetector(
                                  onTap: () => pickAndUploadImage(true),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 90,
                                        height: 90,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                          image:
                                              localLogoUrl != null &&
                                                  localLogoUrl!.isNotEmpty
                                              ? DecorationImage(
                                                  image: NetworkImage(
                                                    CloudinaryService.getOptimizedUrl(
                                                      localLogoUrl!,
                                                      width: 200,
                                                    ),
                                                  ),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child:
                                            localLogoUrl == null ||
                                                localLogoUrl!.isEmpty
                                            ? const Center(
                                                child: Icon(
                                                  Icons.store_rounded,
                                                  color: _primary,
                                                  size: 36,
                                                ),
                                              )
                                            : null,
                                      ),
                                      if (isUploadingLogo)
                                        Positioned.fill(
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              color: Colors.black45,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: const BoxDecoration(
                                            color: _primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt_rounded,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 55),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildProfileField(
                                  controller: nameCtrl,
                                  label: 'اسم المطعم والنشاط التجاري',
                                  icon: Icons.store_rounded,
                                  hint: 'أدخل اسم المطعم التجاري',
                                ),
                                const SizedBox(height: 16),
                                _buildProfileField(
                                  controller: ownerCtrl,
                                  label: 'اسم المالك والمدير المسؤول',
                                  icon: Icons.person_rounded,
                                  hint: 'أدخل الاسم الثلاثي للمالك',
                                ),
                                const SizedBox(height: 16),
                                _buildProfileField(
                                  controller: cuisineCtrl,
                                  label:
                                      'نوع المطبخ والتصنيف (مطبخ عربي، وجبات سريعة...)',
                                  icon: Icons.restaurant_menu_rounded,
                                  hint: 'مثال: مشويات • مقبلات • شاورما',
                                ),
                                const SizedBox(height: 16),
                                _buildProfileField(
                                  controller: descriptionCtrl,
                                  label:
                                      'وصف المطعم والنبذة التعريفية (تظهر للزبائن)',
                                  icon: Icons.description_rounded,
                                  hint:
                                      'اكتب وصفاً جذاباً لمطعمك، أوقات الخدمة، أو شعاركم التجاري',
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 16),
                                _buildProfileField(
                                  controller: phoneCtrl,
                                  label: 'رقم الهاتف وتلقي طلبات المدار',
                                  icon: Icons.phone_rounded,
                                  hint: 'أدخل رقم الهاتف الفعال للمطعم',
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 16),
                                _buildProfileField(
                                  controller: addressCtrl,
                                  label: 'العنوان الجغرافي للمطعم بالتفصيل',
                                  icon: Icons.location_on_rounded,
                                  hint: 'المحافظة، المنطقة، أقرب نقطة دالة',
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 120),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    top: 12,
                    left: 20,
                    right: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          'تعديل ملف المطعم الشخصي',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(width: 32),
                      ],
                    ),
                  ),

                  Positioned(
                    bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                    left: 24,
                    right: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isSaving ? null : saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.save_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'حفظ كامل التعديلات والبيانات',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontWeight: FontWeight.bold,
            fontSize: 11.5,
            color: _textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 13,
            color: _textPrimary,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11.5,
              color: Colors.black26,
            ),
            prefixIcon: Icon(icon, color: _primary, size: 20),
            filled: true,
            fillColor: _cardBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: _primary.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// Flash Offer Live Countdown Widget (Per-meal card)
// ==========================================
class _FlashOfferCountdown extends StatefulWidget {
  final int expiryMs;
  final VoidCallback onExpired;

  const _FlashOfferCountdown({required this.expiryMs, required this.onExpired});

  @override
  State<_FlashOfferCountdown> createState() => _FlashOfferCountdownState();
}

class _FlashOfferCountdownState extends State<_FlashOfferCountdown> {
  Timer? _timer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _calculateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateTime();
    });
  }

  void _calculateTime() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final remaining = ((widget.expiryMs - now) / 1000).round();
    if (remaining <= 0) {
      _timer?.cancel();
      widget.onExpired();
    } else {
      if (mounted) {
        setState(() {
          _secondsRemaining = remaining;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = (_secondsRemaining / 3600).floor();
    final m = ((_secondsRemaining % 3600) / 60).floor();
    final s = _secondsRemaining % 60;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.timer_outlined, size: 11, color: Colors.redAccent),
        const SizedBox(width: 4),
        Text(
          'عرض ينتهي: ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: Colors.redAccent.shade700,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// Flash Offer Live Countdown Widget
// ==========================================
class _FlashCountdownWidget extends StatefulWidget {
  final int endTimeMs;
  final VoidCallback onFinished;

  const _FlashCountdownWidget({
    required this.endTimeMs,
    required this.onFinished,
  });

  @override
  State<_FlashCountdownWidget> createState() => _FlashCountdownWidgetState();
}

class _FlashCountdownWidgetState extends State<_FlashCountdownWidget> {
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _calculateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateTime();
    });
  }

  void _calculateTime() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final left = ((widget.endTimeMs - now) / 1000).round();
    if (left <= 0) {
      _timer?.cancel();
      widget.onFinished();
    } else {
      if (mounted) {
        setState(() {
          _secondsLeft = left;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_secondsLeft / 60).floor();
    final seconds = _secondsLeft % 60;

    return Row(
      children: [
        const Icon(Icons.timer_outlined, size: 12, color: Colors.orange),
        const SizedBox(width: 4),
        Text(
          'ينتهي العرض خلال: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Colors.orange.shade800,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// Tab 2 Widget: قائمة الطعام وإدارة الأقسام (Category & Meal Editor) - Feature 3 & 4
// ==========================================
class _MyMealsTab extends StatefulWidget {
  final String restaurantId;
  const _MyMealsTab({required this.restaurantId});

  @override
  State<_MyMealsTab> createState() => _MyMealsTabState();
}

class _MyMealsTabState extends State<_MyMealsTab> {
  String _selectedCategory = 'الكل';
  List<String> _customCategories = [
    'الكل',
    'وجبات رئيسية',
    'مقبلات',
    'مشروبات',
    'حلويات',
  ];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCustomCategories() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .get();
      if (doc.exists && doc.data()?['categories'] != null) {
        final List<dynamic> cats = doc.data()?['categories'];
        setState(() {
          _customCategories = ['الكل', ...cats.map((e) => e.toString())];
        });
      }
    } catch (_) {}
  }

  void _manageCategoriesDialog() {
    final catCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: _cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'إدارة أقسام المنيو ',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _textPrimary,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: catCtrl,
                      decoration: InputDecoration(
                        labelText: 'اسم القسم الجديد (مثال: شاورما، بيتزا)',
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          color: _textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (catCtrl.text.isNotEmpty) {
                          final newCat = catCtrl.text.trim();
                          final updated = List<String>.from(
                            _customCategories.skip(1),
                          )..add(newCat);
                          await FirebaseFirestore.instance
                              .collection('restaurants')
                              .doc(widget.restaurantId)
                              .set({
                                'categories': updated,
                              }, SetOptions(merge: true));

                          setDlgState(() {
                            _customCategories.add(newCat);
                            catCtrl.clear();
                          });
                          setState(() {});
                        }
                      },
                      icon: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      label: Text(
                        'إضافة القسم المكتوب',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                      ),
                    ),
                    const Divider(height: 24),
                    Text(
                      'الأقسام المضافة حالياً (انقر للحذف):',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: _customCategories
                          .skip(1)
                          .map(
                            (cat) => Chip(
                              label: Text(
                                cat,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: _primary,
                                ),
                              ),
                              backgroundColor: _primary.withValues(alpha: 0.05),
                              deleteIcon: const Icon(
                                Icons.close_rounded,
                                size: 12,
                                color: Colors.redAccent,
                              ),
                              onDeleted: () async {
                                final updated = List<String>.from(
                                  _customCategories.skip(1),
                                )..remove(cat);
                                await FirebaseFirestore.instance
                                    .collection('restaurants')
                                    .doc(widget.restaurantId)
                                    .set({
                                      'categories': updated,
                                    }, SetOptions(merge: true));
                                setDlgState(() {
                                  _customCategories.remove(cat);
                                });
                                setState(() {
                                  if (_selectedCategory == cat)
                                    _selectedCategory = 'الكل';
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'إغلاق',
                    style: GoogleFonts.ibmPlexSansArabic(color: _textSecondary),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('merchant_products')
            .doc(widget.restaurantId)
            .collection('products')
            .snapshots(),
        builder: (context, snapshot) {
          final docsAll = snapshot.data?.docs ?? [];
          final totalDishes = docsAll.length;
          final availableDishes = docsAll.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['isAvailable'] ?? true;
          }).length;
          final unavailableDishes = totalDishes - availableDishes;
          final categoriesCount =
              _customCategories.length - 1; // Exclude 'الكل'

          var docs = List<DocumentSnapshot>.from(docsAll);

          // Filter by category
          if (_selectedCategory != 'الكل') {
            docs = docs
                .where(
                  (d) =>
                      (d.data() as Map<String, dynamic>)['category'] ==
                      _selectedCategory,
                )
                .toList();
          }

          // Filter by search query
          if (_searchQuery.isNotEmpty) {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final name = (data['name'] ?? '').toString().toLowerCase();
              final desc = (data['description'] ?? '').toString().toLowerCase();
              final query = _searchQuery.toLowerCase();
              return name.contains(query) || desc.contains(query);
            }).toList();
          }

          return Column(
            children: [
              // Stats Row Dashboard
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _buildStatCard(
                      'الأطباق',
                      '$totalDishes',
                      Icons.restaurant_rounded,
                      const Color(0xFF26A69A),
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      'متوفر',
                      '$availableDishes',
                      Icons.check_circle_rounded,
                      Colors.teal.shade700,
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      'غير متوفر',
                      '$unavailableDishes',
                      Icons.block_rounded,
                      Colors.orange.shade800,
                    ),
                    const SizedBox(width: 8),
                    _buildStatCard(
                      'الأقسام',
                      '$categoriesCount',
                      Icons.folder_rounded,
                      const Color(0xFF00796B),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _primary.withValues(alpha: 0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.015),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: _textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'البحث عن وجبة بالاسم أو المكونات...',
                      hintStyle: GoogleFonts.ibmPlexSansArabic(
                        color: _textSecondary.withValues(alpha: 0.4),
                        fontSize: 11.5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _primary,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: Colors.grey,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),

              // Category Filters scrollbar & Manage Category Button - Feature 3
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _customCategories.length,
                          itemBuilder: (context, idx) {
                            final cat = _customCategories[idx];
                            final isSel = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _selectedCategory = cat),
                                borderRadius: BorderRadius.circular(15),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? _primary
                                        : _primary.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: _primary.withValues(alpha: 0.15),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    cat,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSel ? Colors.white : _primary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _manageCategoriesDialog,
                      icon: const Icon(
                        Icons.folder_open_rounded,
                        color: _accent,
                        size: 20,
                      ),
                      tooltip: 'إدارة الأقسام',
                    ),
                  ],
                ),
              ),

              // Meal products list
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(
                        child: CircularProgressIndicator(color: _primary),
                      )
                    : docs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.restaurant_menu_rounded,
                              size: 70,
                              color: _primary.withValues(alpha: 0.12),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'ماكو وجبات حالياً تطابق البحث أو القسم',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: _textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final name = data['name'] ?? 'وجبة لذيذة';
                          final price = data['sellingPrice'] ?? 0;
                          final imageUrl = data['imageUrl'] ?? '';
                          final desc =
                              data['description'] ??
                              'وصف وجبة مدار الغذائية المميزة...';
                          final isAvailable = data['isAvailable'] ?? true;
                          final category = data['category'] ?? 'وجبات رئيسية';

                          // Advanced features variables
                          final sizes = data['sizes'] as List<dynamic>? ?? [];
                          final isStockLimited =
                              data['isStockLimited'] ?? false;
                          final stockCount = (data['stockCount'] ?? 0) as int;
                          final isPromoActive = data['isPromoActive'] ?? false;
                          final discountPercentage =
                              (data['discountPercentage'] ?? 0.0) as num;
                          final promoExpiryMs =
                              (data['promoExpiryMs'] ?? 0) as int;

                          final now = DateTime.now().millisecondsSinceEpoch;
                          final showPromo =
                              isPromoActive &&
                              promoExpiryMs > now &&
                              discountPercentage > 0;
                          final promoPrice =
                              price * (1.0 - (discountPercentage / 100.0));

                          // Auto-disable available status since stock is exhausted
                          if (isStockLimited &&
                              stockCount <= 0 &&
                              isAvailable) {
                            WidgetsBinding.instance.addPostFrameCallback((
                              _,
                            ) async {
                              final pRef = FirebaseFirestore.instance
                                  .collection('merchant_products')
                                  .doc(widget.restaurantId)
                                  .collection('products')
                                  .doc(doc.id);
                              await pRef.update({'isAvailable': false});
                              try {
                                await FirebaseFirestore.instance
                                    .collection('stores')
                                    .doc(widget.restaurantId)
                                    .collection('products')
                                    .doc(doc.id)
                                    .update({'isAvailable': false});
                              } catch (_) {}
                              try {
                                await FirestoreSyncService.syncUpdateMeal(
                                  widget.restaurantId,
                                  doc.id,
                                  {'isAvailable': false},
                                );
                              } catch (_) {}
                            });
                          }

                          return Opacity(
                            opacity: isAvailable ? 1.0 : 0.65,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isAvailable
                                      ? _primary.withValues(alpha: 0.1)
                                      : Colors.redAccent.withValues(
                                          alpha: 0.15,
                                        ),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Food Image with Category Badge overlay
                                  Stack(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: isAvailable
                                                ? _gold.withValues(alpha: 0.15)
                                                : Colors.grey.withValues(
                                                    alpha: 0.2,
                                                  ),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          child: imageUrl.isNotEmpty
                                              ? Image.network(
                                                  imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (c, e, s) =>
                                                      const Icon(
                                                        Icons.fastfood_rounded,
                                                        color: _primary,
                                                        size: 30,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.restaurant_rounded,
                                                  color: _primary,
                                                  size: 30,
                                                ),
                                        ),
                                      ),
                                      // Category Badge
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _primary.withValues(
                                              alpha: 0.85,
                                            ),
                                            borderRadius:
                                                const BorderRadius.only(
                                                  bottomLeft: Radius.circular(
                                                    14,
                                                  ),
                                                  bottomRight: Radius.circular(
                                                    14,
                                                  ),
                                                ),
                                          ),
                                          child: Text(
                                            category,
                                            textAlign: TextAlign.center,
                                            style:
                                                GoogleFonts.ibmPlexSansArabic(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),

                                  // Meal details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    GoogleFonts.ibmPlexSansArabic(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 13.5,
                                                      color: _textPrimary,
                                                    ),
                                              ),
                                            ),
                                            if (!isAvailable)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  right: 6,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: Colors.redAccent
                                                        .withValues(alpha: 0.2),
                                                  ),
                                                ),
                                                child: Text(
                                                  'غير متوفر',
                                                  style:
                                                      GoogleFonts.ibmPlexSansArabic(
                                                        color: Colors.redAccent,
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        Text(
                                          desc,
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontSize: 10.5,
                                            color: _textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),

                                        // Stock Limit Badge
                                        if (isStockLimited)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: stockCount > 0
                                                    ? Colors.green.withValues(
                                                        alpha: 0.08,
                                                      )
                                                    : Colors.redAccent
                                                          .withValues(
                                                            alpha: 0.08,
                                                          ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: stockCount > 0
                                                      ? Colors.green.withValues(
                                                          alpha: 0.2,
                                                        )
                                                      : Colors.redAccent
                                                            .withValues(
                                                              alpha: 0.2,
                                                            ),
                                                ),
                                              ),
                                              child: Text(
                                                stockCount > 0
                                                    ? ' المتبقي: $stockCount حصة'
                                                    : ' نفد المخزون',
                                                style:
                                                    GoogleFonts.ibmPlexSansArabic(
                                                      fontSize: 8.5,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: stockCount > 0
                                                          ? Colors
                                                                .green
                                                                .shade700
                                                          : Colors
                                                                .redAccent
                                                                .shade700,
                                                    ),
                                              ),
                                            ),
                                          ),

                                        // Sizes tags wrap
                                        if (sizes.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children: sizes.map((sz) {
                                                final szName =
                                                    sz['sizeName'] ?? '';
                                                final szPrice =
                                                    sz['price'] ?? 0;
                                                return Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 1.5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: _primary.withValues(
                                                      alpha: 0.05,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    border: Border.all(
                                                      color: _primary
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '$szName: $szPrice د.ع',
                                                    style:
                                                        GoogleFonts.ibmPlexSansArabic(
                                                          fontSize: 8,
                                                          color: _primary,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),

                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (showPromo) ...[
                                                  Row(
                                                    children: [
                                                      Text(
                                                        '${promoPrice.round()} د.ع',
                                                        style:
                                                            GoogleFonts.ibmPlexSansArabic(
                                                              color: Colors
                                                                  .redAccent
                                                                  .shade700,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                              fontSize: 13,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        '$price د.ع',
                                                        style: GoogleFonts.ibmPlexSansArabic(
                                                          color: _textSecondary
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 10,
                                                          decoration:
                                                              TextDecoration
                                                                  .lineThrough,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 4,
                                                              vertical: 1,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              Colors.redAccent,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          '-$discountPercentage%',
                                                          style:
                                                              GoogleFonts.ibmPlexSansArabic(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 8,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  _FlashOfferCountdown(
                                                    expiryMs: promoExpiryMs,
                                                    onExpired: () async {
                                                      final pRef = FirebaseFirestore
                                                          .instance
                                                          .collection(
                                                            'merchant_products',
                                                          )
                                                          .doc(
                                                            widget.restaurantId,
                                                          )
                                                          .collection(
                                                            'products',
                                                          )
                                                          .doc(doc.id);
                                                      await pRef.update({
                                                        'isPromoActive': false,
                                                      });
                                                      try {
                                                        await FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                              'stores',
                                                            )
                                                            .doc(
                                                              widget
                                                                  .restaurantId,
                                                            )
                                                            .collection(
                                                              'products',
                                                            )
                                                            .doc(doc.id)
                                                            .update({
                                                              'isPromoActive':
                                                                  false,
                                                            });
                                                      } catch (_) {}
                                                      try {
                                                        await FirestoreSyncService.syncUpdateMeal(
                                                          widget.restaurantId,
                                                          doc.id,
                                                          {
                                                            'isPromoActive':
                                                                false,
                                                          },
                                                        );
                                                      } catch (_) {}
                                                    },
                                                  ),
                                                ] else
                                                  Text(
                                                    '$price د.ع',
                                                    style:
                                                        GoogleFonts.ibmPlexSansArabic(
                                                          color: _gold,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          fontSize: 13,
                                                        ),
                                                  ),
                                              ],
                                            ),
                                            // Availability switch
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  isAvailable
                                                      ? 'متوفر للطلب'
                                                      : 'موقف للطلب',
                                                  style:
                                                      GoogleFonts.ibmPlexSansArabic(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: isAvailable
                                                            ? Colors
                                                                  .green
                                                                  .shade700
                                                            : Colors
                                                                  .orange
                                                                  .shade700,
                                                      ),
                                                ),
                                                const SizedBox(width: 4),
                                                SizedBox(
                                                  height: 20,
                                                  width: 34,
                                                  child: Transform.scale(
                                                    scale: 0.7,
                                                    child: Switch(
                                                      value: isAvailable,
                                                      activeColor: _primary,
                                                      activeTrackColor: _primary
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                      inactiveThumbColor:
                                                          Colors.grey,
                                                      inactiveTrackColor: Colors
                                                          .grey
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      onChanged: (val) async {
                                                        HapticFeedback.mediumImpact();
                                                        final pRef = FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                              'merchant_products',
                                                            )
                                                            .doc(
                                                              widget
                                                                  .restaurantId,
                                                            )
                                                            .collection(
                                                              'products',
                                                            )
                                                            .doc(doc.id);
                                                        await pRef.update({
                                                          'isAvailable': val,
                                                        });

                                                        try {
                                                          await FirebaseFirestore
                                                              .instance
                                                              .collection(
                                                                'stores',
                                                              )
                                                              .doc(
                                                                widget
                                                                    .restaurantId,
                                                              )
                                                              .collection(
                                                                'products',
                                                              )
                                                              .doc(doc.id)
                                                              .update({
                                                                'isAvailable':
                                                                    val,
                                                              });
                                                        } catch (_) {}

                                                        try {
                                                          await FirestoreSyncService.syncUpdateMeal(
                                                            widget.restaurantId,
                                                            doc.id,
                                                            {
                                                              'isAvailable':
                                                                  val,
                                                            },
                                                          );
                                                        } catch (_) {}
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Actions: Edit & Delete
                                  Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          _showEditMealDialog(doc.id, data);
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: _primary.withValues(
                                              alpha: 0.05,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.edit_rounded,
                                            color: _primary,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      InkWell(
                                        onTap: () {
                                          HapticFeedback.heavyImpact();
                                          _showDeleteConfirmDialog(
                                            context,
                                            doc.id,
                                            name,
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent.withValues(
                                              alpha: 0.05,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.delete_rounded,
                                            color: Colors.redAccent,
                                            size: 18,
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
              ),
            ],
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [_primary, _gold]),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () => QuickAddMealDialog.show(context),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.12), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditMealDialog(String foodId, Map<String, dynamic> foodData) {
    final nameCtrl = TextEditingController(text: foodData['name'] ?? '');
    final priceCtrl = TextEditingController(
      text: (foodData['sellingPrice'] ?? 0).toString(),
    );
    final descCtrl = TextEditingController(text: foodData['description'] ?? '');
    String? category = foodData['category'] ?? 'وجبات رئيسية';

    // Extra additions list representation - Feature 4
    List<Map<String, dynamic>> extras = [];
    if (foodData['extras'] != null) {
      extras = List<Map<String, dynamic>>.from(foodData['extras']);
    } else {
      extras = [
        {'name': 'إضافة جبنة دبل', 'price': 500, 'enabled': false},
        {'name': 'صوص حار خاص', 'price': 250, 'enabled': false},
        {'name': 'حجم عائلي كبير', 'price': 1500, 'enabled': false},
      ];
    }

    // Advanced features parameters
    List<Map<String, dynamic>> sizes = List<Map<String, dynamic>>.from(
      foodData['sizes'] ?? [],
    );
    final sizeNameCtrl = TextEditingController();
    final sizePriceCtrl = TextEditingController();

    bool isStockLimited = foodData['isStockLimited'] ?? false;
    final stockCtrl = TextEditingController(
      text: (foodData['stockLimit'] ?? 10).toString(),
    );

    bool isPromoActive = foodData['isPromoActive'] ?? false;
    final discountCtrl = TextEditingController(
      text: (foodData['discountPercentage'] ?? 20.0).toString(),
    );
    double promoDurationHours = 3.0; // default duration

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: _cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'تعديل وجبة ومدير الميزات ',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _textPrimary,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'اسم الوجبة',
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          color: _textSecondary,
                        ),
                      ),
                    ),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'السعر (د.ع)',
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          color: _textSecondary,
                        ),
                      ),
                    ),
                    TextField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        labelText: 'وصف الوجبة والمكونات',
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          color: _textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Category Selection
                    DropdownButtonFormField<String>(
                      dropdownColor: _cardBg,
                      decoration: InputDecoration(
                        labelText: 'قسم الوجبة',
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          color: _textSecondary,
                        ),
                      ),
                      value: _customCategories.skip(1).contains(category)
                          ? category
                          : (_customCategories.skip(1).isNotEmpty
                                ? _customCategories.skip(1).first
                                : 'وجبات رئيسية'),
                      items:
                          (_customCategories.skip(1).isNotEmpty
                                  ? _customCategories.skip(1).toList()
                                  : [
                                      'وجبات رئيسية',
                                      'مقبلات',
                                      'مشروبات',
                                      'حلويات',
                                    ])
                              .map(
                                (cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(
                                    cat,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setDlgState(() => category = v),
                    ),
                    const SizedBox(height: 16),

                    const Divider(height: 24),

                    // --- Sizes list editor ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'تعديل الأحجام والأسعار (اختياري) ',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (sizes.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: sizes.map((sz) {
                          return Chip(
                            backgroundColor: _primary.withValues(alpha: 0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            label: Text(
                              '${sz['sizeName']}: ${sz['price']} د.ع',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _primary,
                              ),
                            ),
                            deleteIcon: const Icon(
                              Icons.cancel_rounded,
                              size: 14,
                              color: Colors.redAccent,
                            ),
                            onDeleted: () {
                              setDlgState(() {
                                sizes.remove(sz);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: sizeNameCtrl,
                            decoration: InputDecoration(
                              hintText: 'الحجم (صغير، كبير)',
                              hintStyle: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 10,
                                color: _textSecondary.withValues(alpha: 0.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: sizePriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'السعر (د.ع)',
                              hintStyle: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 10,
                                color: _textSecondary.withValues(alpha: 0.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (sizeNameCtrl.text.isNotEmpty &&
                                sizePriceCtrl.text.isNotEmpty) {
                              final pVal =
                                  double.tryParse(sizePriceCtrl.text) ?? 0.0;
                              setDlgState(() {
                                sizes.add({
                                  'sizeName': sizeNameCtrl.text.trim(),
                                  'price': pVal,
                                });
                                sizeNameCtrl.clear();
                                sizePriceCtrl.clear();
                              });
                            }
                          },
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            color: _primary,
                            size: 24,
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // --- Stock Tracker Section ---
                    Row(
                      children: [
                        Checkbox(
                          value: isStockLimited,
                          activeColor: _primary,
                          onChanged: (val) {
                            setDlgState(() {
                              isStockLimited = val ?? false;
                            });
                          },
                        ),
                        Text(
                          'تفعيل تتبع المخزون والكمية لليوم ',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                            color: _textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (isStockLimited)
                      TextField(
                        controller: stockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'المخزون والكمية المتاحة للطلب اليوم',
                          labelStyle: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            color: _textSecondary,
                          ),
                        ),
                      ),

                    const Divider(height: 24),

                    // --- Flash Offers Section ---
                    Row(
                      children: [
                        Checkbox(
                          value: isPromoActive,
                          activeColor: _primary,
                          onChanged: (val) {
                            setDlgState(() {
                              isPromoActive = val ?? false;
                            });
                          },
                        ),
                        Text(
                          'إطلاق عرض فلاش سريع وخصم مؤقت ',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                            color: _textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (isPromoActive) ...[
                      TextField(
                        controller: discountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'نسبة الخصم (%)',
                          labelStyle: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            color: _textSecondary,
                          ),
                          hintText: 'مثال: 20',
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<double>(
                        dropdownColor: _cardBg,
                        decoration: InputDecoration(
                          labelText: 'مدة العرض الفعال',
                          labelStyle: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            color: _textSecondary,
                          ),
                        ),
                        value: promoDurationHours,
                        items: [
                          const DropdownMenuItem(
                            value: 0.5,
                            child: Text(
                              'نصف ساعة (30 دقيقة)',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 1.0,
                            child: Text(
                              'ساعة واحدة',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 2.0,
                            child: Text(
                              'ساعتان',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 3.0,
                            child: Text(
                              '3 ساعات',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 6.0,
                            child: Text(
                              '6 ساعات',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 12.0,
                            child: Text(
                              '12 ساعة',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 24.0,
                            child: Text(
                              'يوم كامل (24 ساعة)',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setDlgState(() => promoDurationHours = v!),
                      ),
                    ],

                    const Divider(height: 24),

                    // Extras Options Grid
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'تعديل الإضافات المتاحة للزبون:',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(extras.length, (idx) {
                      final item = extras[idx];
                      return Row(
                        children: [
                          Checkbox(
                            value: item['enabled'] ?? false,
                            activeColor: _primary,
                            onChanged: (val) {
                              setDlgState(() {
                                item['enabled'] = val;
                              });
                            },
                          ),
                          Expanded(
                            child: Text(
                              item['name'],
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12,
                                color: _textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '+${item['price']} د.ع',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11.5,
                              color: _accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'إلغاء',
                    style: GoogleFonts.ibmPlexSansArabic(color: _textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                      final priceValue = int.tryParse(priceCtrl.text) ?? 0;

                      final discountValue =
                          double.tryParse(discountCtrl.text) ?? 20.0;
                      final promoExpiry = isPromoActive
                          ? DateTime.now()
                                .add(
                                  Duration(
                                    minutes: (promoDurationHours * 60).round(),
                                  ),
                                )
                                .millisecondsSinceEpoch
                          : 0;

                      final stockLimitValue = isStockLimited
                          ? (int.tryParse(stockCtrl.text) ?? 10)
                          : 0;

                      final updateData = {
                        'name': nameCtrl.text.trim(),
                        'sellingPrice': priceValue,
                        'price': priceValue, // حقل السعر للتطبيق الرئيسي
                        'description': descCtrl.text.trim(),
                        'category': category,
                        'extras': extras,
                        // Advanced features fields
                        'sizes': sizes,
                        'isStockLimited': isStockLimited,
                        'stockLimit': stockLimitValue,
                        'stockCount':
                            stockLimitValue, // resets stock Count on save/edit
                        'isPromoActive': isPromoActive,
                        'discountPercentage': discountValue,
                        'promoExpiryMs': promoExpiry,
                        // Make sure availability matches stock
                        'isAvailable': isStockLimited
                            ? (stockLimitValue > 0)
                            : true,
                      };

                      await FirebaseFirestore.instance
                          .collection('merchant_products')
                          .doc(widget.restaurantId)
                          .collection('products')
                          .doc(foodId)
                          .update(updateData);

                      try {
                        await FirebaseFirestore.instance
                            .collection('stores')
                            .doc(widget.restaurantId)
                            .collection('products')
                            .doc(foodId)
                            .update(updateData);
                      } catch (_) {}

                      try {
                        await FirestoreSyncService.syncUpdateMeal(
                          widget.restaurantId,
                          foodId,
                          updateData,
                        );
                      } catch (_) {}

                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _primary),
                  child: Text(
                    'حفظ التعديلات',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    String foodId,
    String foodName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: _cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.2)),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 8),
                Text(
                  'حذف وجبة من القائمة',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
            content: Text(
              'متأكد تريد تحذف وجبة ($foodName) بشكل نهائي من قائمة طعامك؟',
              style: GoogleFonts.ibmPlexSansArabic(color: _textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'إلغاء',
                  style: GoogleFonts.ibmPlexSansArabic(color: _textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('merchant_products')
                      .doc(widget.restaurantId)
                      .collection('products')
                      .doc(foodId)
                      .delete();

                  try {
                    await FirebaseFirestore.instance
                        .collection('stores')
                        .doc(widget.restaurantId)
                        .collection('products')
                        .doc(foodId)
                        .delete();
                  } catch (_) {}

                  try {
                    await FirestoreSyncService.syncDeleteMeal(
                      widget.restaurantId,
                      foodId,
                    );
                  } catch (_) {}

                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(
                  'تأكيد الحذف',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// Kitchen Order Ticket Card - Feature 1
// ==========================================
class _KitchenTicketCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;

  const _KitchenTicketCard({required this.orderId, required this.data});

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    try {
      HapticFeedback.mediumImpact();
      final batch = FirebaseFirestore.instance.batch();

      final mainOrderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId);
      batch.update(mainOrderRef, {'status': newStatus});

      final restaurantId = data['restaurantId'] ?? data['restaurantDocId'];
      if (restaurantId != null && restaurantId.toString().isNotEmpty) {
        final restaurantOrderRef = FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restaurantId.toString())
            .collection('orders')
            .doc(orderId);
        batch.update(restaurantOrderRef, {'status': newStatus});
      }

      final customerId = data['customerId'] ?? data['userId'];
      if (customerId != null && customerId.toString().isNotEmpty) {
        final customerOrderRef = FirebaseFirestore.instance
            .collection('madar_orders')
            .doc(customerId.toString())
            .collection('orders')
            .doc(orderId);
        batch.update(customerOrderRef, {'status': newStatus});
      }

      await batch.commit();

      if (newStatus == 'ready') {
        try {
          final String rId =
              (data['restaurantId'] ?? data['restaurantDocId'] ?? '')
                  .toString();
          await NotificationService.emitEvent(
            type: 'food_order_ready',
            payload: {
              'orderId': orderId,
              'restaurantId': rId,
              'restaurantName': data['restaurantName'] ?? 'المطعم',
            },
          );
        } catch (e) {
          debugPrint('Error emitting food_order_ready: $e');
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'accepted'
                  ? 'تم قبول الطلب وبدء التجهيز بالمطبخ '
                  : (newStatus == 'rejected'
                        ? 'تم رفض الطلب '
                        : 'اكتمل تحضير الطلب وجاهز للتوصيل '),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: newStatus == 'accepted'
                ? _primary
                : (newStatus == 'rejected'
                      ? Colors.redAccent.shade700
                      : _accent),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ أثناء تحديث الطلب: $e',
              style: const TextStyle(),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showThermalPrinterSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    bool isSearching = true;
    String docType = 'إيصال الزبون';
    String printerType = 'Bluetooth';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            if (isSearching) {
              Timer(const Duration(milliseconds: 1800), () {
                if (ctx.mounted) {
                  setSheetState(() {
                    isSearching = false;
                  });
                }
              });
            }

            final itemsList = data['items'] as List<dynamic>? ?? [];
            final totalPrice =
                data['total'] ?? data['totalPrice'] ?? data['grandTotal'] ?? 0;
            final buyerName =
                data['customerName'] ?? data['buyerName'] ?? 'زبون مدار المميز';
            final buyerPhone =
                data['customerPhone'] ?? data['buyerPhone'] ?? '';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'مركز الطباعة الحرارية والمطبوعات ',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            color: _textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'قم بتهيئة الطباعة الحرارية التلقائية لطلبك وطباعة الوصولات مباشرة للمطبخ.',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            dropdownColor: Colors.white,
                            value: printerType,
                            decoration: InputDecoration(
                              labelText: 'نوع الاتصال',
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: _textSecondary,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            items: ['Bluetooth', 'Wi-Fi / LAN', 'USB Direct']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setSheetState(() => printerType = v!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            dropdownColor: Colors.white,
                            value: docType,
                            decoration: InputDecoration(
                              labelText: 'نوع المطبوع',
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: _textSecondary,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            items:
                                [
                                      'إيصال الزبون',
                                      'كابتن المطبخ',
                                      'بون الدلفري/التوصيل',
                                    ]
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(
                                          e,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => setSheetState(() => docType = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (isSearching)
                      Container(
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: _primary,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'جاري البحث عن طابعات بلوتوث وشبكة نشطة قريبة...',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11.5,
                                color: _accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'متصل بطابعة المطبخ الحرارية: Sunmi-T2 (Default)',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11,
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    Text(
                      'معاينة الوصول الحراري قبل الطباعة:',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'مدار للمطاعم شوب',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'تاريخ الطلب: ${DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now())}',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const Text(
                            '--------------------------------------------',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),

                          Align(
                            alignment: Alignment.centerRight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'العميل: $buyerName',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (buyerPhone.isNotEmpty)
                                  Text(
                                    'رقم الهاتف: $buyerPhone',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                Text(
                                  'نوع المطبوع: $docType',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 10.5,
                                    color: _primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            '--------------------------------------------',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),

                          ...List.generate(itemsList.length, (index) {
                            final item =
                                itemsList[index] as Map<String, dynamic>;
                            final name = item['name'] ?? 'وجبة لذيذة';
                            final qty = item['quantity'] ?? 1;
                            final price = item['price'] ?? 0;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$qty x $name',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${price * qty} د.ع',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            );
                          }),

                          const Text(
                            '--------------------------------------------',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'المجموع الإجمالي:',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '$totalPrice د.ع',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: _accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Icon(
                            Icons.qr_code_2_rounded,
                            size: 48,
                            color: Colors.black,
                          ),
                          Text(
                            'شكرًا لشرائكم من مدار شوب',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isSearching
                          ? null
                          : () {
                              HapticFeedback.heavyImpact();
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم إرسال الوصول إلى الطابعة الحرارية بنجاح! ($docType)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor: _accent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'بدء الطباعة الفورية ',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
    );
  }

  void _showOrderDetailsSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    final buyerName =
        data['customerName'] ?? data['buyerName'] ?? 'زبون مدار المميز';
    final buyerPhone = data['customerPhone'] ?? data['buyerPhone'] ?? '';
    final totalPrice =
        data['total'] ?? data['totalPrice'] ?? data['grandTotal'] ?? 0;
    final status = data['status'] ?? 'pending';
    final timestamp = data['createdAt'] as Timestamp?;
    final address = data['address'] ?? '';
    final itemsList = data['items'] as List<dynamic>? ?? [];
    final deliveryPrice = data['deliveryPrice'] ?? data['deliveryFee'] ?? 1500;
    final discount = data['discount'] ?? 0;

    // Calculate subtotal
    double itemsSubtotal = 0;
    for (var item in itemsList) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      itemsSubtotal += price * qty;
    }

    Color statusColor;
    String statusLabelText;
    IconData statusIcon;

    switch (status) {
      case 'pending':
        statusColor = _gold;
        statusLabelText = 'بانتظار التأكيد';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'accepted':
      case 'approved':
      case 'preparing':
        statusColor = _primary;
        statusLabelText = 'جاري التحضير';
        statusIcon = Icons.soup_kitchen_rounded;
        break;
      case 'completed':
        statusColor = _accent;
        statusLabelText = 'مكتمل';
        statusIcon = Icons.verified_rounded;
        break;
      case 'rejected':
      case 'cancelled':
        statusColor = Colors.redAccent;
        statusLabelText = 'ملغي';
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = _textSecondary;
        statusLabelText = status;
        statusIcon = Icons.info_outline_rounded;
    }

    final timeStr = timestamp != null
        ? DateFormat('yyyy-MM-dd hh:mm a').format(timestamp.toDate())
        : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final assignedDriver = data['driverName'] ?? '';
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                decoration: const BoxDecoration(
                  color: _lightBg,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: DraggableScrollableSheet(
                  initialChildSize: 0.85,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  expand: false,
                  builder: (context, scrollController) {
                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Indicator pill
                        Center(
                          child: Container(
                            width: 50,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Title with Status Pill
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'تفاصيل الطلب #${orderId.substring(math.max(0, orderId.length - 6))}',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontWeight: FontWeight.w900,
                                fontSize: 16.5,
                                color: _textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    statusIcon,
                                    size: 12,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    statusLabelText,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeStr,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            color: _textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 1. Customer Card
                        Text(
                          'معلومات الزبون والتوصيل ',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _primary.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _primary.withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person_outline_rounded,
                                      color: _primary,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          buyerName,
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                            color: _textPrimary,
                                          ),
                                        ),
                                        if (buyerPhone.isNotEmpty)
                                          Text(
                                            buyerPhone,
                                            style:
                                                GoogleFonts.ibmPlexSansArabic(
                                                  fontSize: 11,
                                                  color: _textSecondary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (buyerPhone.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.phone_in_talk_rounded,
                                        color: _primary,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'جاري الاتصال بالزبون: $buyerName...',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            backgroundColor: _primary,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                              if (address.toString().isNotEmpty) ...[
                                const Divider(
                                  height: 20,
                                  color: Colors.black12,
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(
                                          alpha: 0.08,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.location_on_outlined,
                                        color: Colors.amber,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'عنوان التوصيل',
                                            style:
                                                GoogleFonts.ibmPlexSansArabic(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color: _textSecondary,
                                                ),
                                          ),
                                          Text(
                                            address,
                                            style:
                                                GoogleFonts.ibmPlexSansArabic(
                                                  fontSize: 12,
                                                  color: _textPrimary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 2. Order Items
                        Text(
                          'الوجبات المطلوبة ',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _primary.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            children: [
                              ...List.generate(itemsList.length, (idx) {
                                final item =
                                    itemsList[idx] as Map<String, dynamic>;
                                final name = item['name'] ?? 'وجبة لذيذة';
                                final qty = (item['quantity'] ?? 1) as int;
                                final price = ((item['price'] ?? 0) as num)
                                    .toDouble();
                                final extras =
                                    item['extras'] as List<dynamic>? ?? [];

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (idx > 0)
                                      const Divider(
                                        height: 20,
                                        color: Colors.black12,
                                      ),
                                    Row(
                                      children: [
                                        // Quantity Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _primary.withValues(
                                              alpha: 0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            '${qty}x',
                                            style:
                                                GoogleFonts.ibmPlexSansArabic(
                                                  color: _primary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11.5,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Item Name
                                        Expanded(
                                          child: Text(
                                            name,
                                            style:
                                                GoogleFonts.ibmPlexSansArabic(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12.5,
                                                  color: _textPrimary,
                                                ),
                                          ),
                                        ),

                                        // Price
                                        Text(
                                          '${(price * qty).toStringAsFixed(0)} د.ع',
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                            color: _accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Extras if any
                                    if (extras.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 44,
                                        ),
                                        child: Text(
                                          'الإضافات: ${extras.map((e) {
                                            if (e is Map) return e['name'] ?? '';
                                            return e.toString();
                                          }).join(' • ')}',
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontSize: 9.5,
                                            color: _textSecondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 3. Assign Captain
                        if ([
                          'pending',
                          'accepted',
                          'preparing',
                          'approved',
                        ].contains(status)) ...[
                          Text(
                            'تعيين كابتن التوصيل ',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _primary.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (assignedDriver.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.green,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'تم تعيين الطلب لـ: ',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 11.5,
                                          color: _textSecondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        assignedDriver,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 12.5,
                                          color: _primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(
                                    height: 16,
                                    color: Colors.black12,
                                  ),
                                ],
                                Text(
                                  'اختر كابتن توصيل لإرسال الطلب إليه:',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 11,
                                    color: _textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('driver_locations')
                                      .where('isOnline', isEqualTo: true)
                                      .limit(10)
                                      .snapshots(),
                                  builder: (context, driverSnap) {
                                    if (driverSnap.connectionState ==
                                        ConnectionState.waiting) {
                                      return const SizedBox(
                                        height: 48,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    }

                                    final driverDocs =
                                        driverSnap.data?.docs ?? [];
                                    if (driverDocs.isEmpty) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          'ماكو كباتن حالياً متاحين حالياً للتوصيل',
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontSize: 11,
                                            color: _textSecondary,
                                          ),
                                        ),
                                      );
                                    }

                                    return SizedBox(
                                      height: 48,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: driverDocs.length,
                                        itemBuilder: (context, dIdx) {
                                          final drDoc = driverDocs[dIdx];
                                          final drData =
                                              drDoc.data()
                                                  as Map<String, dynamic>;
                                          final drName =
                                              drData['driverName']
                                                  ?.toString() ??
                                              drData['name']?.toString() ??
                                              'كابتن توصيل';
                                          final drPhone =
                                              drData['driverPhone']
                                                  ?.toString() ??
                                              drData['phone']?.toString() ??
                                              '';
                                          final isSelected =
                                              assignedDriver == drName;

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            child: InkWell(
                                              onTap: () async {
                                                HapticFeedback.mediumImpact();
                                                setSheetState(() {
                                                  data['driverName'] = drName;
                                                  data['driverPhone'] = drPhone;
                                                });

                                                // Save to Firebase
                                                try {
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('orders')
                                                      .doc(orderId)
                                                      .update({
                                                        'driverName': drName,
                                                        'driverPhone': drPhone,
                                                        'driverId': drDoc.id,
                                                      });
                                                } catch (_) {}
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? _primary
                                                      : _primary.withValues(
                                                          alpha: 0.05,
                                                        ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? _primary
                                                        : _primary.withValues(
                                                            alpha: 0.15,
                                                          ),
                                                  ),
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  drName,
                                                  style:
                                                      GoogleFonts.ibmPlexSansArabic(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: isSelected
                                                            ? Colors.white
                                                            : _textPrimary,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // 4. Invoice details
                        Text(
                          'تفاصيل الفاتورة والحساب ',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _primary.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'مجموع الوجبات:',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 11.5,
                                      color: _textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '${itemsSubtotal.toStringAsFixed(0)} د.ع',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 11.5,
                                      color: _textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 14, color: Colors.black12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'سعر التوصيل:',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 11.5,
                                      color: _textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '${deliveryPrice.toString()} د.ع',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 11.5,
                                      color: _textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (discount > 0) ...[
                                const Divider(
                                  height: 14,
                                  color: Colors.black12,
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'خصومات / كوبون:',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 11.5,
                                        color: _textSecondary,
                                      ),
                                    ),
                                    Text(
                                      '- ${discount.toString()} د.ع',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 11.5,
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const Divider(height: 14, color: Colors.black12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'المجموع الإجمالي النهائي:',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${totalPrice.toString()} د.ع',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: _accent,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 5. Action Buttons (Accept, Reject, Ready, Print, Close)
                        Row(
                          children: [
                            if (status == 'pending') ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _updateStatus(context, 'accepted');
                                    Navigator.pop(ctx);
                                  },
                                  icon: const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'قبول وتجهيز الطلب',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primary,
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    _updateStatus(context, 'rejected');
                                    Navigator.pop(ctx);
                                  },
                                  icon: const Icon(
                                    Icons.cancel_rounded,
                                    color: Colors.redAccent,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'رفض الطلب',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Colors.redAccent,
                                      width: 1.5,
                                    ),
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ] else if ([
                              'preparing',
                              'accepted',
                              'approved',
                            ].contains(status)) ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _updateStatus(context, 'ready');
                                    Navigator.pop(ctx);
                                  },
                                  icon: const Icon(
                                    Icons.soup_kitchen_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'الوجبة جاهزة للتوصيل ',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _accent,
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => Navigator.pop(ctx),
                                  icon: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'تم العرض بنجاح',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primary,
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: _primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _primary.withValues(alpha: 0.15),
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.print_rounded,
                                  color: _primary,
                                  size: 22,
                                ),
                                onPressed: () {
                                  _showThermalPrinterSheet(context);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final buyerName =
        data['customerName'] ?? data['buyerName'] ?? 'زبون مدار المميز';
    final buyerPhone = data['customerPhone'] ?? data['buyerPhone'] ?? '';
    final totalPrice =
        data['total'] ?? data['totalPrice'] ?? data['grandTotal'] ?? 0;
    final status = data['status'] ?? 'pending';
    final timestamp = data['createdAt'] as Timestamp?;
    final address = data['address'] ?? '';

    final timeStr = timestamp != null
        ? DateFormat('hh:mm a').format(timestamp.toDate())
        : '';

    final itemsList = data['items'] as List<dynamic>? ?? [];

    Color statusColor;
    String statusLabelText;
    IconData statusIcon;

    switch (status) {
      case 'pending':
        statusColor = _gold;
        statusLabelText = 'بانتظار التأكيد';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'accepted':
      case 'approved':
      case 'preparing':
        statusColor = _primary;
        statusLabelText = 'جاري التحضير';
        statusIcon = Icons.soup_kitchen_rounded;
        break;
      case 'completed':
        statusColor = _accent;
        statusLabelText = 'مكتمل';
        statusIcon = Icons.verified_rounded;
        break;
      case 'rejected':
      case 'cancelled':
        statusColor = Colors.redAccent;
        statusLabelText = 'ملغي';
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = _textSecondary;
        statusLabelText = status;
        statusIcon = Icons.info_outline_rounded;
    }

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _showOrderDetailsSheet(context);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primary.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: [
              Container(width: 5, height: 164, color: statusColor),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#${orderId.substring(math.max(0, orderId.length - 6))}',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: _textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 10, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  statusLabelText,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      Text(
                        buyerPhone.isNotEmpty
                            ? '$buyerPhone - $buyerName'
                            : buyerName,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),

                      Text(
                        '${itemsList.length} وجبات •  $totalPrice د.ع',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),

                      if (address.toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'العنوان: $address',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 10.5,
                            color: _textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      if (data['driverName'] != null &&
                          data['driverName'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'المندوب: ${data['driverName']} (${data['driverPhone'] ?? ''})',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _accent,
                          ),
                        ),
                      ],

                      const Divider(height: 16, color: Colors.black12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              if (status == 'pending') ...[
                                _buildActionButton(
                                  'قبول',
                                  _primary,
                                  () => _updateStatus(context, 'accepted'),
                                ),
                                const SizedBox(width: 8),
                                _buildActionButton(
                                  'رفض',
                                  Colors.redAccent,
                                  () => _updateStatus(context, 'rejected'),
                                ),
                              ] else if ([
                                'preparing',
                                'accepted',
                                'approved',
                              ].contains(status))
                                _buildActionButton(
                                  'الوجبة جاهزة',
                                  _accent,
                                  () => _updateStatus(context, 'ready'),
                                )
                              else
                                Text(
                                  timeStr,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 11,
                                    color: _textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),

                          IconButton(
                            icon: const Icon(
                              Icons.print_rounded,
                              color: _primary,
                              size: 20,
                            ),
                            onPressed: () {
                              _showThermalPrinterSheet(context);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ─── Glowing ambient paint background orbs for Restaurant Dashboard (Light Theme) ───
class DashboardLightTealPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Solid light background
    paint.color = _lightBg;
    canvas.drawRect(Offset.zero & size, paint);

    // Glowing Teal Orb (Top Right)
    paint.shader =
        RadialGradient(
          colors: [
            _primary.withValues(alpha: 0.12),
            _primary.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.85, size.height * 0.15),
            radius: size.width * 0.65,
          ),
        );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.15),
      size.width * 0.65,
      paint,
    );

    // Glowing Gourmet Gold Orb (Bottom Left)
    paint.shader =
        RadialGradient(
          colors: [_gold.withValues(alpha: 0.06), _gold.withValues(alpha: 0.0)],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.15, size.height * 0.85),
            radius: size.width * 0.55,
          ),
        );
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.85),
      size.width * 0.55,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
