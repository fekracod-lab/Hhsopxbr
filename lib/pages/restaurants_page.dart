import 'dart:math' as math;
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_location_service.dart';
import '../widgets/app_tour_widget.dart';
import '../widgets/location_selector_widget.dart';
import 'cart_page.dart';
import 'my_orders_page.dart';
import 'restaurant_details_page.dart';
import 'restaurant_search_page.dart';

import '../features/restaurants/application/group_cart_controller.dart';
import '../features/restaurants/application/restaurant_controller.dart';
import '../features/restaurants/data/datasources/restaurant_remote_datasource.dart';
import '../features/restaurants/data/repositories/restaurant_repository.dart';
import '../features/restaurants/presentation/widgets/confetti_overlay_widget.dart';
import '../features/restaurants/presentation/widgets/group_cart_dialogs.dart';
import '../features/restaurants/presentation/widgets/restaurant_card.dart';
import '../features/restaurants/presentation/widgets/restaurant_cuisine_categories_bar.dart';
import '../features/restaurants/presentation/widgets/restaurant_filters_bar.dart';
import '../features/restaurants/presentation/widgets/restaurant_floating_cart_strip.dart';
import '../features/restaurants/presentation/widgets/restaurant_popular_meals.dart';
import '../features/restaurants/presentation/widgets/skozmy_wheel_dialog.dart';

export '../features/restaurants/domain/entities/restaurant_models.dart' show GroupCartManager;

// ─── Design System Palette ───────────────────────────────────────────────────
const Color _primary = Color(0xFF26A69A);
const Color _accent = Color(0xFF00796B);
const Color _lightBg = Color(0xFFF6F8FA);
const Color _darkBg = Color(0xFF0B1E20);
const Color _darkSurface = Color(0xFF193B3E);
const Color _darkCard = Color(0xFF113033);
const Color _darkText = Color(0xFFE0F2F1);
const Color _textColor = Color(0xFF1A1A1A);
const Color _darkSubText = Color(0xFF80CBC4);
const Color _subText = Color(0xFF616161);

/// منسق صفحة المطاعم والمأكولات الرئيسي (Restaurants Page Coordinator)
class RestaurantsPage extends StatefulWidget {
  final RestaurantController? customRestaurantController;
  final GroupCartController? customGroupCartController;
  final String? initialUid;
  final String? initialUserName;

  const RestaurantsPage({
    super.key,
    this.customRestaurantController,
    this.customGroupCartController,
    this.initialUid,
    this.initialUserName,
  });

  @override
  State<RestaurantsPage> createState() => _RestaurantsPageState();
}

class _RestaurantsPageState extends State<RestaurantsPage>
    with TickerProviderStateMixin {
  late final RestaurantController _restaurantController;
  late final GroupCartController _groupCartController;
  late final bool _ownsRestaurantController;
  late final bool _ownsGroupCartController;

  late final AnimationController _wheelRotationController;
  late final AnimationController _breathingController;
  late final Animation<double> _breathingAnimation;

  final GlobalKey<ConfettiOverlayWidgetState> _confettiKey =
      GlobalKey<ConfettiOverlayWidgetState>();

  // Tour Target Keys
  final GlobalKey _locationKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _popularKey = GlobalKey();
  final GlobalKey _menuKey = GlobalKey();

  bool _showTour = false;

  @override
  void initState() {
    super.initState();
    _ownsRestaurantController = widget.customRestaurantController == null;
    _ownsGroupCartController = widget.customGroupCartController == null;

    final repo = RestaurantRepository(
      remoteDatasource: RestaurantRemoteDatasource(),
    );

    _groupCartController = widget.customGroupCartController ??
        GroupCartController(repository: repo);

    _restaurantController = widget.customRestaurantController ??
        RestaurantController(repository: repo);

    String uid = widget.initialUid ?? 'guest';
    String userName = widget.initialUserName ?? '';

    if (widget.initialUid == null) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          uid = user.uid;
          userName = user.displayName ?? '';
        }
      } catch (_) {
        // Fallback for widget test harnesses where Firebase is not initialized
      }
    }

    _groupCartController.initialize(uid: uid);
    _restaurantController.setCurrentUserName(userName);
    _restaurantController.initialize(
      uid: uid,
      effectiveCartId: _groupCartController.effectiveCartId,
    );

    // Sync group cart changes with restaurant cart stream
    _groupCartController.addListener(_onGroupCartChanged);

    _wheelRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    _checkTourStatus();
  }

  void _onGroupCartChanged() {
    _restaurantController.updateEffectiveCartId(
      _groupCartController.effectiveCartId,
    );
  }

  Future<void> _checkTourStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTour = prefs.getBool('app_tour_completed') ?? false;
    if (!hasSeenTour) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _showTour = true);
      });
    }
  }

  void _onTourComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_tour_completed', true);
    if (mounted) setState(() => _showTour = false);
  }

  @override
  void dispose() {
    _wheelRotationController.dispose();
    _breathingController.dispose();
    _groupCartController.removeListener(_onGroupCartChanged);
    if (_ownsRestaurantController) {
      _restaurantController.dispose();
    }
    if (_ownsGroupCartController) {
      _groupCartController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? _darkBg : _lightBg,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _restaurantController.refreshRestaurants,
              color: _primary,
              backgroundColor: isDark ? _darkSurface : Colors.white,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  _buildSliverHeader(isDark),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchBar(isDark),
                        ListenableBuilder(
                          listenable: _groupCartController,
                          builder: (context, _) => GroupCartBannerWidget(
                            groupCartCode: _groupCartController.groupCartCode ?? '',
                            hostName: _groupCartController.groupHostName ?? 'مضيف',
                            isHost: _groupCartController.isHost,
                            isDark: isDark,
                            onLeaveOrEnd: () {
                              _groupCartController.leaveGroupCart();
                            },
                          ),
                        ),

                        // ── شريط تصنيفات المطابخ التفاعلي ──
                        ListenableBuilder(
                          listenable: _restaurantController,
                          builder: (context, _) => RestaurantCuisineCategoriesBar(
                            selectedCategory: _restaurantController.selectedCategory,
                            isDark: isDark,
                            onSelectCategory: (cat) {
                              _restaurantController.setSelectedCategory(cat);
                            },
                          ),
                        ),

                        // ── شريط الفلاتر السريعة ──
                        ListenableBuilder(
                          listenable: _restaurantController,
                          builder: (context, _) => RestaurantFiltersBar(
                            onlyFreeDelivery: _restaurantController.onlyFreeDelivery,
                            onlyOpen: _restaurantController.onlyOpen,
                            sortByRating: _restaurantController.sortByRating,
                            sortByDeliveryTime: _restaurantController.sortByDeliveryTime,
                            isDark: isDark,
                            onToggleFreeDelivery: _restaurantController.toggleOnlyFreeDelivery,
                            onToggleOnlyOpen: _restaurantController.toggleOnlyOpen,
                            onToggleSortByRating: _restaurantController.toggleSortByRating,
                            onToggleSortByDeliveryTime: _restaurantController.toggleSortByDeliveryTime,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── 1. قسم الأعلى تقييماً (Top Rated) ──
                  _buildCuratedTopRatedSection(isDark),

                  // ── 2. قسم أقوى العروض والتوصيل المجاني (Best Deals) ──
                  _buildCuratedBestDealsSection(isDark),

                  // ── 3. كل المطاعم (شبكة البطاقات الكبيرة الفاخرة) ──
                  _buildFullMenuSection(isDark),

                  // ── 4. الوجبات الأكثر طلباً ──
                  SliverToBoxAdapter(
                    child: RestaurantPopularMealsSection(
                      key: _popularKey,
                      mealsFuture: _restaurantController.popularMealsFuture,
                      isDark: isDark,
                      onShowAll: _restaurantController.resetFilters,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 140)),
                ],
              ),
            ),
            if (_showTour)
              AppTourOverlay(
                onComplete: _onTourComplete,
                steps: [
                  TourStep(
                    targetKey: _locationKey,
                    title: 'تحديد منطقتك',
                    description: 'اختار منطقتك حتى نطلعلك المطاعم القريبة منك.',
                  ),
                  TourStep(
                    targetKey: _searchKey,
                    title: 'البحث السريع',
                    description: 'دوّر على مطعمك المفضل أو أكلتك اللي تشتهيها بسهولة.',
                  ),
                  TourStep(
                    targetKey: _popularKey,
                    title: 'الأكثر طلباً وشهرة',
                    description: 'شوف أشهر الوجبات والأكلات المتوفرة بمنطقتك.',
                  ),
                  TourStep(
                    targetKey: _menuKey,
                    title: 'كل المطاعم',
                    description: 'تصفح قائمة كل المطاعم المتوفرة واطلب منها مباشرة.',
                  ),
                ],
              ),
            ListenableBuilder(
              listenable: _restaurantController,
              builder: (context, _) => RestaurantFloatingCartStrip(
                itemCount: _restaurantController.cartSummary.totalCount,
                totalPrice: _restaurantController.cartSummary.totalPrice,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartPage()),
                  );
                },
              ),
            ),
            ListenableBuilder(
              listenable: _restaurantController,
              builder: (context, _) => Positioned(
                bottom: _restaurantController.cartSummary.totalCount > 0 ? 172.h : 95.h,
                left: 20.w,
                child: _buildWheelFAB(isDark),
              ),
            ),
            ConfettiOverlayWidget(key: _confettiKey),
          ],
        ),
      ),
    );
  }

  // ─── Sliver Header ──────────────────────────────────────────────────────────
  Widget _buildSliverHeader(bool isDark) {
    return SliverAppBar(
      toolbarHeight: 64.h,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: Center(
        child: GestureDetector(
          onTap: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              setState(() => _showTour = true);
            }
          },
          child: Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Icon(
              Navigator.canPop(context)
                  ? Icons.arrow_back_ios_new_rounded
                  : Icons.help_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
      title: ListenableBuilder(
        listenable: AppLocationService(),
        builder: (context, _) {
          final location = AppLocationService().currentLocation;
          return GestureDetector(
            key: _locationKey,
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const LocationSelectorWidget(),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'التوصيل لـ',
                  style: TextStyle(
                    fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                    fontSize: 8.5.sp,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 1.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      location.isAllIraq ? 'كل العراق' : location.displayName,
                      style: TextStyle(
                        fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      centerTitle: true,
      actions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildWheelIconHeader(),
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartPage()),
                );
              },
              child: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _showGroupCartOptions(isDark);
              },
              child: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Icon(
                  Icons.group_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            SizedBox(width: 20.w),
          ],
        ),
      ],
      flexibleSpace: ClipRRect(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24.r),
          bottomRight: Radius.circular(24.r),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [_darkSurface.withValues(alpha: 0.95), _darkBg.withValues(alpha: 0.92)]
                    : [_primary, _accent],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24.r),
                bottomRight: Radius.circular(24.r),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black38 : _primary.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWheelIconHeader() {
    return AnimatedBuilder(
      animation: _wheelRotationController,
      builder: (context, child) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            _openWheelDialog();
          },
          child: Container(
            padding: EdgeInsets.all(7.r),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF26A69A), Color(0xFFFF7043)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF7043)
                      .withValues(alpha: 0.3 * _breathingAnimation.value),
                  blurRadius: 6 * _breathingAnimation.value,
                  spreadRadius: 1,
                )
              ],
              border: Border.all(color: Colors.white38, width: 1.5),
            ),
            child: Transform.rotate(
              angle: _wheelRotationController.value * 2 * math.pi,
              child: Icon(
                Icons.toys_rounded,
                color: Colors.white,
                size: 20.r,
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar(bool isDark) {
    return GestureDetector(
      key: _searchKey,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RestaurantSearchPage()),
        );
      },
      child: Container(
        height: 48.h,
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isDark ? _darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.05)) : null,
        ),
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: isDark ? Colors.white70 : _textColor,
              size: 20,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                'دوّر على أطيب أكلة أو مطعم...',
                style: TextStyle(
                  fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7043), Color(0xFFD84315)],
                ),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.smart_toy_rounded, color: Colors.white, size: 13.r),
                  SizedBox(width: 4.w),
                  Text(
                    'سكوزمي',
                    style: TextStyle(
                      fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                      fontSize: 9.sp,
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
    );
  }

  // ─── Curated Discovery: Top Rated Section ─────────────────────────────
  Widget _buildCuratedTopRatedSection(bool isDark) {
    return SliverToBoxAdapter(
      child: ListenableBuilder(
        listenable: _restaurantController,
        builder: (context, _) {
          final topRated = _restaurantController.restaurants
              .where((r) => r.rating >= 4.7)
              .toList();

          if (topRated.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'الأعلى تقييماً في مدار',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'مميز',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF00BFA5),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 175.h,
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: topRated.length,
                  itemBuilder: (context, index) {
                    final rest = topRated[index];
                    return Container(
                      width: 156.w,
                      margin: EdgeInsetsDirectional.only(end: 12.w),
                      child: RestaurantCard(
                        restaurant: rest,
                        isFavorite: _restaurantController.isFavorite(rest.id),
                        isDark: isDark,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RestaurantDetailsPage(
                                restaurantId: rest.id,
                                restaurantName: rest.name,
                                imageUrl: rest.imageUrl,
                              ),
                            ),
                          );
                        },
                        onFavoriteToggle: () {
                          _restaurantController.toggleFavorite(rest.id);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Curated Discovery: Best Deals & Free Delivery ──────────────────────
  Widget _buildCuratedBestDealsSection(bool isDark) {
    return SliverToBoxAdapter(
      child: ListenableBuilder(
        listenable: _restaurantController,
        builder: (context, _) {
          final deals = _restaurantController.restaurants
              .where((r) => r.deliveryFee == 0.0)
              .toList();

          if (deals.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'عروض وتوصيل مجاني',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'خصم 0 د.ع توصيل',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 175.h,
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: deals.length,
                  itemBuilder: (context, index) {
                    final rest = deals[index];
                    return Container(
                      width: 156.w,
                      margin: EdgeInsetsDirectional.only(end: 12.w),
                      child: RestaurantCard(
                        restaurant: rest,
                        isFavorite: _restaurantController.isFavorite(rest.id),
                        isDark: isDark,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RestaurantDetailsPage(
                                restaurantId: rest.id,
                                restaurantName: rest.name,
                                imageUrl: rest.imageUrl,
                              ),
                            ),
                          );
                        },
                        onFavoriteToggle: () {
                          _restaurantController.toggleFavorite(rest.id);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Full Menu Section (2-Column Grid) ──────────────────────────────────────
  Widget _buildFullMenuSection(bool isDark) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            key: _menuKey,
            padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 12.h),
            child: ListenableBuilder(
              listenable: _restaurantController,
              builder: (context, _) {
                final count = _restaurantController.filteredRestaurants.length;
                final cat = _restaurantController.selectedCategory;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        cat == 'الكل' || cat.isEmpty
                            ? 'كل المطاعم'
                            : '$cat ($count) ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w900,
                          color: isDark ? _darkText : _textColor,
                        ),
                      ),
                    ),
                    if (cat != 'الكل' && cat.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _restaurantController.resetFilters,
                        child: Text(
                          'إلغاء الفلتر',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF00BFA5),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          ListenableBuilder(
            listenable: _restaurantController,
            builder: (context, _) {
              if (_restaurantController.isLoadingRestaurants) {
                return _buildShimmerLoaderVertical(isDark);
              }

              final restaurants = _restaurantController.filteredRestaurants;
              if (restaurants.isEmpty) {
                return _buildEmptyState(isDark);
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14.h,
                  crossAxisSpacing: 12.w,
                  childAspectRatio: 0.96,
                ),
                itemCount: restaurants.length,
                itemBuilder: (context, index) {
                  final rest = restaurants[index];
                  return RestaurantCard(
                    restaurant: rest,
                    isFavorite: _restaurantController.isFavorite(rest.id),
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RestaurantDetailsPage(
                            restaurantId: rest.id,
                            restaurantName: rest.name,
                            imageUrl: rest.imageUrl,
                          ),
                        ),
                      );
                    },
                    onFavoriteToggle: () {
                      _restaurantController.toggleFavorite(rest.id);
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Wheel Dialog & FAB ────────────────────────────────────────────────────
  void _openWheelDialog() {
    showDialog(
      context: context,
      builder: (_) => SkozmyWheelDialog(
        mealsFuture: _restaurantController.popularMealsFuture,
        onSearch: (q) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RestaurantSearchPage(initialQuery: q),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWheelFAB(bool isDark) {
    return AnimatedBuilder(
      animation: _wheelRotationController,
      builder: (context, child) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            _openWheelDialog();
          },
          child: Container(
            width: 58.r,
            height: 58.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF26A69A), Color(0xFFFF7043)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF7043)
                      .withValues(alpha: 0.3 * _breathingAnimation.value),
                  blurRadius: 12 * _breathingAnimation.value,
                  spreadRadius: 1 + (2 * _breathingAnimation.value),
                )
              ],
              border: Border.all(color: Colors.white, width: 2.0),
            ),
            child: Center(
              child: Transform.rotate(
                angle: _wheelRotationController.value * 2 * math.pi,
                child: Icon(
                  Icons.toys_rounded,
                  color: Colors.white,
                  size: 28.r,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Group Cart Options Sheet & Dialog ──────────────────────────────────────
  void _showGroupCartOptions(bool isDark) {
    GroupCartOptionsSheet.show(
      context: context,
      isDark: isDark,
      onCreateGroup: () async {
        final hostName = _restaurantController.currentUserName.isNotEmpty
            ? _restaurantController.currentUserName
            : 'مضيف';
        final hostId = _groupCartController.myUid ?? 'host';

        final code = await _groupCartController.createGroupCart(
          hostId: hostId,
          hostName: hostName,
        );

        if (!mounted) return;
        if (code != null) {
          _confettiKey.currentState?.trigger();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إنشاء سلة الربع برمز $code وتدلل عيوني!'),
              backgroundColor: _accent,
            ),
          );
        } else {
          final err = _groupCartController.errorMessage ?? 'تعذر إنشاء السلة';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
          );
        }
      },
      onJoinGroup: () {
        GroupCartJoinDialog.show(
          context: context,
          isDark: isDark,
          onJoin: (code) async {
            final success = await _groupCartController.joinGroupCart(code);
            if (!mounted) return;
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('انضميت لسلة الربع وتدلل!'),
                  backgroundColor: _accent,
                ),
              );
            } else {
              final err = _groupCartController.errorMessage ?? 'رمز السلة غير صحيح أو منتهية';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
              );
            }
          },
        );
      },
    );
  }

  // ─── Shimmer & Empty Loaders ───────────────────────────────────────────────
  Widget _buildShimmerLoaderVertical(bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14.h,
        crossAxisSpacing: 12.w,
        childAspectRatio: 0.96,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF162B2E) : Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE2EBE9),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFE2EBE9),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(17.r)),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: EdgeInsets.all(8.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Container(
                        width: 90.w,
                        height: 12.h,
                        color: isDark ? Colors.white12 : const Color(0xFFE2EBE9),
                      ),
                      Container(
                        width: 60.w,
                        height: 10.h,
                        color: isDark ? Colors.white10 : const Color(0xFFEEF2F1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 24.w),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 56.r,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            SizedBox(height: 14.h),
            Text(
              'ماكو مطاعم متوفرة بالتصنيف المختار',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? _darkSubText : _subText,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'جرّب تختار تصنيف ثاني أو اضغط هنا لعرض كل المطاعم وتدلل',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                fontSize: 11.5.sp,
                color: isDark
                    ? _darkSubText.withValues(alpha: 0.6)
                    : _subText.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _restaurantController.resetFilters();
                _restaurantController.refreshRestaurants();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
              label: Text(
                'عرض كل المطاعم',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.sp,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
