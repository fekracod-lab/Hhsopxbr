import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:dalal_alqaim/features/trip/presentation/trip_design.dart';
import 'package:dalal_alqaim/features/restaurants/data/datasources/restaurant_remote_datasource.dart';
import 'package:dalal_alqaim/features/restaurants/data/repositories/restaurant_repository.dart';
import 'package:dalal_alqaim/features/restaurants/application/restaurant_details_controller.dart';
import 'package:dalal_alqaim/features/restaurants/domain/entities/restaurant_details_models.dart';
import 'package:dalal_alqaim/features/restaurants/presentation/widgets/restaurant_details_header.dart';
import 'package:dalal_alqaim/features/restaurants/presentation/widgets/restaurant_menu_category_tabs.dart';
import 'package:dalal_alqaim/features/restaurants/presentation/widgets/restaurant_menu_item_card.dart';
import 'package:dalal_alqaim/features/restaurants/presentation/widgets/restaurant_instagram_grid_item_card.dart';
import 'package:dalal_alqaim/features/restaurants/presentation/widgets/restaurant_reviews_section.dart';
import 'package:dalal_alqaim/core/pricing/domain/services/iraqi_currency_formatter.dart';
import 'package:dalal_alqaim/shared/icon_utils.dart';
import 'restaurant_meal_details_page.dart';
import 'cart_page.dart';

const Color _primaryColor = Color(0xFF00BFA5);
const Color _darkBackground = Color(0xFF0B1416);
const Color _darkSurface = Color(0xFF132023);

class RestaurantDetailsPage extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final String imageUrl;
  final RestaurantDetailsController? controller;

  const RestaurantDetailsPage({
    super.key,
    required this.restaurantId,
    this.restaurantName = 'مطعم القائم المميز',
    this.imageUrl = 'https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=800',
    this.controller,
  });

  @override
  State<RestaurantDetailsPage> createState() => _RestaurantDetailsPageState();
}

class _RestaurantDetailsPageState extends State<RestaurantDetailsPage>
    with SingleTickerProviderStateMixin {
  late final RestaurantDetailsController _controller;
  TabController? _tabController;
  final ScrollController _scrollController = ScrollController();
  int _lastCategoryCount = 0;
  bool _ownsController = false;
  bool _isGridView = true; // Close-up grid is default!

  String? get _currentUserId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  String? get _currentUserName {
    try {
      return FirebaseAuth.instance.currentUser?.displayName;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = RestaurantDetailsController(
        repository: RestaurantRepository(remoteDatasource: RestaurantRemoteDatasource()),
        restaurantId: widget.restaurantId,
        restaurantName: widget.restaurantName,
        imageUrl: widget.imageUrl,
      );
      _ownsController = true;
    }

    _controller.addListener(_syncTabController);

    final uid = _currentUserId ?? 'guest';
    _controller.initialize(uid: uid);
  }

  void _syncTabController() {
    if (!mounted) return;
    final catCount = _controller.categories.length;
    if (catCount != _lastCategoryCount && catCount > 0) {
      _lastCategoryCount = catCount;
      _tabController?.dispose();
      _tabController = TabController(length: catCount, vsync: this);
      _tabController?.addListener(() {
        if (!(_tabController?.indexIsChanging ?? true) && mounted) {
          final index = _tabController?.index ?? 0;
          if (index < _controller.categories.length) {
            _controller.selectCategory(_controller.categories[index].name);
          }
        }
      });
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_syncTabController);
    _tabController?.dispose();
    _scrollController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _openMealDetails(
    BuildContext context,
    MenuItemDetailsEntity item,
    bool isDark,
  ) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantMealDetailsPage(
          item: item,
          restaurantName: widget.restaurantName,
          restaurantImageUrl: widget.imageUrl,
          isDark: isDark,
          onAddToCart: (finalPrice, size, options, notes, qty) async {
            final messenger = ScaffoldMessenger.of(context);
            final success = await _controller.addItem(
              id: item.id,
              price: finalPrice,
              name: item.name,
              imageUrl: item.imageUrl,
              quantity: qty,
              size: size,
              options: options,
              notes: notes,
              addedByName: _currentUserName,
            );
            if (success && mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'تمت إضافة ${item.name} إلى السلة',
                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
                  ),
                  backgroundColor: _primaryColor,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _showAddReviewDialog(BuildContext context, bool isDark) {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RestaurantAddReviewSheet(
        isDark: isDark,
        onSubmit: (rating, comment) async {
          final uid = _currentUserId;
          if (uid == null) {
            Navigator.pop(ctx);
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'سجّل دخولك أولاً',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
                ),
              ),
            );
            return;
          }

          final success = await _controller.submitReview(
            userId: uid,
            userName: _currentUserName ?? 'مستخدم مدار',
            rating: rating,
            comment: comment,
          );

          if (mounted) {
            navigator.pop();
            if (success) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'شكراً لتقييمك!',
                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
                  ),
                  backgroundColor: _primaryColor,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _confirmDeleteReview(String reviewId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'حذف التعليق',
          style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'متأكد تريد تحذف هذا التعليق؟',
          style: GoogleFonts.ibmPlexSansArabic(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إلغاء',
              style: GoogleFonts.ibmPlexSansArabic(),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _controller.deleteReview(reviewId);
            },
            child: Text(
              'حذف',
              style: GoogleFonts.ibmPlexSansArabic(
                color: Colors.redAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: isDark ? _darkBackground : const Color(0xFFF8FAFC),
          body: Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── 1. Profile Header ──
                  RestaurantDetailsHeader(
                    restaurantName: widget.restaurantName,
                    imageUrl: widget.imageUrl,
                    cuisine: _controller.cuisine,
                    isDark: isDark,
                    totalMeals: _controller.menuItems.length,
                    onBack: () => Navigator.pop(context),
                  ),

                  // ── 2. Dynamic Category Story Highlights (From Restaurant Owner) ──
                  SliverToBoxAdapter(
                    child: _buildDynamicCategoryStoryHighlights(isDark),
                  ),

                  // ── 3. Category Tabs & View Switcher ──
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        RestaurantMenuCategoryTabs(
                          controller: _tabController,
                          categories: _controller.categories,
                          isDark: isDark,
                          onTap: (index) {
                            if (index < _controller.categories.length) {
                              _controller.selectCategory(_controller.categories[index].name);
                            }
                          },
                        ),
                        _buildViewSwitcherBar(isDark),
                      ],
                    ),
                  ),

                  // ── 4. Main Menu Showcase (Close-Up Grid or List) ──
                  _controller.loadingCategories || _controller.loadingMenuItems
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 60.h),
                            child: const Center(
                              child: CircularProgressIndicator(color: _primaryColor),
                            ),
                          ),
                        )
                      : _controller.selectedCategory == 'التقييمات'
                          ? SliverToBoxAdapter(
                              child: RestaurantReviewsSection(
                                reviews: _controller.reviews,
                                statistics: _controller.reviewStatistics,
                                isDark: isDark,
                                isLoading: _controller.loadingReviews,
                                currentUserId: _currentUserId,
                                onAddReview: () => _showAddReviewDialog(context, isDark),
                                onDeleteReview: _confirmDeleteReview,
                              ),
                            )
                          : _isGridView
                              ? _buildCloseUpGrid(isDark)
                              : _buildDetailedListView(isDark),

                  SliverToBoxAdapter(
                    child: SizedBox(height: 120.h),
                  ),
                ],
              ),

              // ── Floating Bottom Cart Bar ──
              if (_controller.totalCount > 0)
                Positioned(
                  bottom: 20.h,
                  left: 16.w,
                  right: 16.w,
                  child: _buildFloatingCartSummary(isDark),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─── Dynamic Story Highlights (Added by Restaurant Owner) ───────────────
  Widget _buildDynamicCategoryStoryHighlights(bool isDark) {
    final categories = _controller.categories
        .where((c) => c.name != 'التقييمات')
        .toList();

    if (categories.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 96.h,
      margin: EdgeInsets.only(top: 8.h, bottom: 4.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _controller.selectedCategory == cat.name ||
              (cat.name == 'الكل' && _controller.selectedCategory.isEmpty);

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _controller.selectCategory(cat.name);
              if (_tabController != null) {
                final catIdx = _controller.categories.indexWhere((c) => c.name == cat.name);
                if (catIdx != -1) _tabController?.animateTo(catIdx);
              }
            },
            child: Container(
              width: 68.w,
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(2.5.r),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF00BFA5), Color(0xFF5EEAD4)],
                            )
                          : const LinearGradient(
                              colors: [
                                Color(0xFF00BFA5),
                                Color(0xFF00897B),
                                Color(0xFF26A69A),
                              ],
                            ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00BFA5).withValues(alpha: 0.35),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: Container(
                      width: 48.r,
                      height: 48.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? _darkBackground : Colors.white,
                      ),
                      child: Center(
                        child: Icon(
                          IconUtils.getIconByCode(cat.iconCode),
                          size: 22.sp,
                          color: isSelected ? _primaryColor : (isDark ? Colors.white70 : const Color(0xFF334155)),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    cat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 10.sp,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? _primaryColor
                          : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── View Switcher Bar (Grid vs List) ──────────────────────────────────
  Widget _buildViewSwitcherBar(bool isDark) {
    if (_controller.selectedCategory == 'التقييمات') return const SizedBox.shrink();

    final count = _controller.menuItems.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'قائمة الوجبات (${IraqiCurrencyFormatter.format(count, includeSymbol: false)})',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          Container(
            padding: EdgeInsets.all(3.r),
            decoration: BoxDecoration(
              color: isDark ? _darkSurface : const Color(0xFFE2EBE9),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                _buildToggleIcon(
                  icon: Icons.grid_view_rounded,
                  isSelected: _isGridView,
                  tooltip: 'العرض الشبكي للأطباق',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isGridView = true);
                  },
                ),
                _buildToggleIcon(
                  icon: Icons.view_list_rounded,
                  isSelected: !_isGridView,
                  tooltip: 'عرض القائمة التفصيلية',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isGridView = false);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleIcon({
    required IconData icon,
    required bool isSelected,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(9.r),
        ),
        child: Icon(
          icon,
          size: 16.sp,
          color: isSelected ? Colors.white : Colors.grey.shade600,
        ),
      ),
    );
  }

  // ─── Close-Up Grid Showcase (2-Columns) ────────────────────────────────
  Widget _buildCloseUpGrid(bool isDark) {
    final items = _controller.menuItems;
    if (items.isEmpty) return _buildEmptyState(isDark);

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 40.h),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14.h,
          crossAxisSpacing: 12.w,
          childAspectRatio: 0.80,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            final qty = _controller.cartItems[item.id] ?? 0;

            return AnimationConfiguration.staggeredGrid(
              position: index,
              duration: const Duration(milliseconds: 320),
              columnCount: 2,
              child: ScaleAnimation(
                child: FadeInAnimation(
                  child: RestaurantInstagramGridItemCard(
                    item: item,
                    quantity: qty,
                    isDark: isDark,
                    onAdd: () => _controller.addItem(
                      id: item.id,
                      price: item.price,
                      name: item.name,
                      imageUrl: item.imageUrl,
                    ),
                    onRemove: () => _controller.removeItem(item.id),
                    onCustomize: () => _openMealDetails(context, item, isDark),
                  ),
                ),
              ),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }

  // ─── Detailed List View ──────────────────────────────────────────────────
  Widget _buildDetailedListView(bool isDark) {
    final items = _controller.menuItems;
    if (items.isEmpty) return _buildEmptyState(isDark);

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 40.h),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            final qty = _controller.cartItems[item.id] ?? 0;

            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 320),
              child: SlideAnimation(
                verticalOffset: 40.0,
                child: FadeInAnimation(
                  child: RestaurantMenuItemCard(
                    item: item,
                    quantity: qty,
                    isDark: isDark,
                    onAdd: () => _controller.addItem(
                      id: item.id,
                      price: item.price,
                      name: item.name,
                      imageUrl: item.imageUrl,
                    ),
                    onRemove: () => _controller.removeItem(item.id),
                    onCustomize: () => _openMealDetails(context, item, isDark),
                  ),
                ),
              ),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 50.h),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.no_meals_rounded,
                size: 56.sp,
                color: isDark ? Colors.white24 : Colors.grey.shade400,
              ),
              SizedBox(height: 12.h),
              Text(
                'ماكو وجبات حالياً في هذا التصنيف حالياً',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Floating Bottom Cart Bar ───────────────────────────────────────────
  Widget _buildFloatingCartSummary(bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => const CartPage()),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22.r),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32.r,
              height: 32.r,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  IraqiCurrencyFormatter.format(_controller.totalCount, includeSymbol: false),
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: const Color(0xFF00897B),
                    fontWeight: FontWeight.w900,
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'شاهد سلة الطلبات',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.w900,
                      fontSize: 13.sp,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    IraqiCurrencyFormatter.formatWritten(_controller.totalPrice),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.w600,
                      fontSize: 9.5.sp,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              IraqiCurrencyFormatter.format(_controller.totalPrice),
              style: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.w900,
                fontSize: 14.5.sp,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
