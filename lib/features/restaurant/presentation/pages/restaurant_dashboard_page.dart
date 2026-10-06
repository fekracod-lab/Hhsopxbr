import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:dalal_alqaim/services/ringtone_manager.dart';
import 'package:dalal_alqaim/services/user_service.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/widgets/custom_painters.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/widgets/restaurant_header_bar.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/tabs/restaurant_orders_tab.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/tabs/restaurant_menu_tab.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/tabs/restaurant_offers_tab.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/tabs/restaurant_analytics_tab.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/tabs/restaurant_logistics_tab.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/tabs/restaurant_settings_tab.dart';

class RestaurantDashboardPage extends StatefulWidget {
  const RestaurantDashboardPage({super.key});

  @override
  State<RestaurantDashboardPage> createState() => _RestaurantDashboardPageState();
}

class _RestaurantDashboardPageState extends State<RestaurantDashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _isOnline = true;
  String _restaurantName = 'اسم المطعم';
  String _cuisineType = 'مطبخ عربي • وجبات سريعة';
  String? _restaurantId;
  String _congestionStatus = 'normal'; // normal, active, busy
  String? _logoUrl;

  int _currentIndex = 0;

  StreamSubscription<QuerySnapshot>? _pendingOrdersSubscription;
  final Set<String> _knownOrderIds = {};
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _restaurantId = _uid;
    _fetchRestaurantData();
    _setupPendingOrdersAlarm();
  }

  @override
  void dispose() {
    _pendingOrdersSubscription?.cancel();
    super.dispose();
  }

  void _setupPendingOrdersAlarm() {
    _pendingOrdersSubscription?.cancel();
    final targetId = _restaurantId ?? _uid;
    _pendingOrdersSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('restaurantId', isEqualTo: targetId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      if (_isInitialLoad) {
        for (var doc in snapshot.docs) {
          _knownOrderIds.add(doc.id);
        }
        _isInitialLoad = false;
        return;
      }

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          final orderId = doc.id;
          if (!_knownOrderIds.contains(orderId)) {
            _knownOrderIds.add(orderId);
            RingtoneManager.startAlarm('order_$orderId', autoStopSeconds: 30);

            if (mounted) {
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'وصلتك طلبية جديدة! فوت وافتح التحضير',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: app_colors.primaryColor,
                  duration: const Duration(seconds: 8),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              );
            }
          }
        }
      }
    });
  }

  Future<void> _fetchRestaurantData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _restaurantName = data?['restaurantName'] ?? data?['fullName'] ?? 'اسم المطعم';
          _isOnline = data?['isOnline'] ?? true;
          _restaurantId = data?['restaurantId'] ?? data?['uid'] ?? _uid;
          _cuisineType = data?['cuisineType'] ?? data?['cuisine'] ?? 'مطبخ عربي • وجبات سريعة';
          _congestionStatus = data?['congestionStatus'] ?? 'normal';
          _logoUrl = data?['photoUrl'] ?? data?['imageUrl'];
        });
      }

      // قراءة وثيقة المطعم في restaurants للتحقق من أي بيانات مخصصة للمطعم
      final restDoc = await FirebaseFirestore.instance.collection('restaurants').doc(_uid).get();
      if (restDoc.exists && mounted) {
        final rData = restDoc.data();
        setState(() {
          _restaurantName = rData?['name'] ?? rData?['restaurantName'] ?? _restaurantName;
          _isOnline = rData?['isOnline'] ?? _isOnline;
          _cuisineType = rData?['cuisineType'] ?? rData?['cuisine'] ?? _cuisineType;
          _logoUrl = rData?['logoUrl'] ?? rData?['imageUrl'] ?? _logoUrl;
        });
      }

      if (mounted) {
        _setupPendingOrdersAlarm();
      }
    } catch (_) {}
  }

  void _cycleCongestion() async {
    HapticFeedback.selectionClick();
    String next = 'normal';
    if (_congestionStatus == 'normal') {
      next = 'active';
    } else if (_congestionStatus == 'active') {
      next = 'busy';
    }

    setState(() => _congestionStatus = next);
    try {
      await FirebaseFirestore.instance.collection('users').doc(_uid).update({
        'congestionStatus': next,
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rId = _restaurantId ?? _uid;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildModernDrawer(isDark),
        body: Stack(
          children: [
            // Ambient Aesthetic Background Painter
            Positioned.fill(
              child: CustomPaint(
                painter: DashboardLightTealPainter(isDark: isDark),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Unified Interactive Header Bar
                  RestaurantHeaderBar(
                    restaurantName: _restaurantName,
                    cuisineType: _cuisineType,
                    logoUrl: _logoUrl,
                    isOnline: _isOnline,
                    congestionStatus: _congestionStatus,
                    onCycleCongestion: _cycleCongestion,
                    onToggleOnline: (val) {
                      setState(() => _isOnline = val);
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(_uid)
                          .update({'isOnline': val});
                    },
                    onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                  ),

                  // Active Tab Body
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _buildActiveTab(rId),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildModernBottomNavBar(isDark, rId),
      ),
    );
  }

  Widget _buildActiveTab(String rId) {
    switch (_currentIndex) {
      case 0:
        return RestaurantOrdersTab(
          restaurantId: rId,
          onNavigateToMenu: () => setState(() => _currentIndex = 1),
          onNavigateToOffers: () => setState(() => _currentIndex = 2),
        );
      case 1:
        return RestaurantMenuTab(restaurantId: rId);
      case 2:
        return RestaurantOffersTab(restaurantId: rId);
      case 3:
        return RestaurantAnalyticsTab(restaurantId: rId);
      case 4:
        return RestaurantLogisticsTab(restaurantId: rId);
      case 5:
        return RestaurantSettingsTab(restaurantId: rId);
      default:
        return RestaurantOrdersTab(
          restaurantId: rId,
          onNavigateToMenu: () => setState(() => _currentIndex = 1),
          onNavigateToOffers: () => setState(() => _currentIndex = 2),
        );
    }
  }

  Widget _buildModernBottomNavBar(bool isDark, String rId) {
    final cardBg = isDark ? app_colors.darkCard : Colors.white;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantId', isEqualTo: rId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data?.docs.length ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: cardBg.withValues(alpha: isDark ? 0.9 : 0.95),
            border: Border(
              top: BorderSide(
                color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.6),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) {
              HapticFeedback.selectionClick();
              setState(() => _currentIndex = idx);
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: app_colors.primaryColor.withValues(alpha: 0.15),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text(
                    pendingCount.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                  backgroundColor: app_colors.goldAccent,
                  textColor: Colors.black,
                  child: const Icon(Icons.receipt_long_rounded),
                ),
                selectedIcon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text(
                    pendingCount.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                  backgroundColor: app_colors.goldAccent,
                  textColor: Colors.black,
                  child: const Icon(Icons.receipt_long_rounded, color: app_colors.primaryColor),
                ),
                label: 'الطلبات',
              ),
              const NavigationDestination(
                icon: Icon(Icons.restaurant_menu_rounded),
                selectedIcon: Icon(Icons.restaurant_menu_rounded, color: app_colors.primaryColor),
                label: 'المنيو',
              ),
              const NavigationDestination(
                icon: Icon(Icons.local_offer_rounded),
                selectedIcon: Icon(Icons.local_offer_rounded, color: app_colors.primaryColor),
                label: 'العروض',
              ),
              const NavigationDestination(
                icon: Icon(Icons.analytics_rounded),
                selectedIcon: Icon(Icons.analytics_rounded, color: app_colors.primaryColor),
                label: 'التقارير',
              ),
              const NavigationDestination(
                icon: Icon(Icons.motorcycle_rounded),
                selectedIcon: Icon(Icons.motorcycle_rounded, color: app_colors.primaryColor),
                label: 'التوصيل',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_rounded),
                selectedIcon: Icon(Icons.settings_rounded, color: app_colors.primaryColor),
                label: 'الإعدادات',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernDrawer(bool isDark) {
    final drawerBg = isDark ? app_colors.darkBackground : Colors.white;

    return Drawer(
      backgroundColor: drawerBg,
      child: Column(
        children: [
          // Drawer Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00695C), app_colors.primaryColor],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: _logoUrl != null && _logoUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Image.network(
                                _logoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const Icon(
                                  Icons.storefront_rounded,
                                  color: app_colors.primaryColor,
                                  size: 28,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.storefront_rounded,
                              color: app_colors.primaryColor,
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
                              fontSize: 15,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _cuisineType,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isOnline ? Colors.green.shade700 : Colors.red.shade700,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
                        _isOnline ? 'المطعم مفتوح ويستقبل الطلبات' : 'المطعم مغلق حالياً',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Drawer Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildDrawerTile(0, 'الطلبيات وتجهيز المطبخ', Icons.receipt_long_rounded),
                _buildDrawerTile(1, 'المنيو وقائمة الأكلات', Icons.restaurant_menu_rounded),
                _buildDrawerTile(2, 'العروض والخصومات', Icons.local_offer_outlined),
                _buildDrawerTile(3, 'الوارد وحسابات المبيعات', Icons.analytics_outlined),
                _buildDrawerTile(4, 'التوصيل وأسطول الكباتن', Icons.motorcycle_rounded),
                _buildDrawerTile(5, 'إعدادات المطعم', Icons.settings_outlined),
              ],
            ),
          ),

          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: InkWell(
              onTap: () async {
                HapticFeedback.heavyImpact();
                await UserService.signOut();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
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

  Widget _buildDrawerTile(int index, String title, IconData icon) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = index);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? app_colors.primaryColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? app_colors.primaryColor.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? app_colors.primaryColor : app_colors.subTextColor,
                size: 22,
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isSelected ? app_colors.primaryColor : textPrimary,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
