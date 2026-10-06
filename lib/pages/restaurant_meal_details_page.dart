import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/core/pricing/domain/services/iraqi_currency_formatter.dart';
import 'package:dalal_alqaim/features/restaurants/domain/entities/restaurant_details_models.dart';
import 'package:dalal_alqaim/features/restaurants/domain/services/restaurant_details_calculator.dart';

const Color _primaryColor = Color(0xFF00BFA5);
const Color _darkBackground = Color(0xFF0B1416);
const Color _darkSurface = Color(0xFF132023);
const Color _darkCard = Color(0xFF1A2B2F);

/// صفحة العرض الفردية المقربة للوجبة والمنتج (Social Showcase & Customization Page)
class RestaurantMealDetailsPage extends StatefulWidget {
  final MenuItemDetailsEntity item;
  final String restaurantName;
  final String restaurantImageUrl;
  final bool isDark;
  final Function(double finalPrice, String size, String options, String notes, int qty) onAddToCart;

  const RestaurantMealDetailsPage({
    super.key,
    required this.item,
    required this.restaurantName,
    required this.restaurantImageUrl,
    required this.isDark,
    required this.onAddToCart,
  });

  @override
  State<RestaurantMealDetailsPage> createState() => _RestaurantMealDetailsPageState();
}

class _RestaurantMealDetailsPageState extends State<RestaurantMealDetailsPage>
    with SingleTickerProviderStateMixin {
  int _selectedSizeIndex = 0;
  late List<Map<String, dynamic>> _sizes;
  late List<Map<String, dynamic>> _availableAddons;

  final Set<String> _selectedAddons = {};
  final TextEditingController _notesController = TextEditingController();
  int _quantity = 1;
  bool _isLiked = false;
  int _likeCount = 348;
  bool _isSaved = false;

  late AnimationController _heartAnimController;
  late Animation<double> _heartScaleAnimation;
  bool _showHeartPop = false;

  @override
  void initState() {
    super.initState();
    // استخدام الأحجام والإضافات المحددة من صاحب المطعم ديناميكياً
    _sizes = widget.item.customSizes;
    _availableAddons = widget.item.customAddons;

    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.4), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_heartAnimController);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _heartAnimController.dispose();
    super.dispose();
  }

  double get _unitPrice {
    final extra = _sizes.isNotEmpty && _selectedSizeIndex < _sizes.length
        ? (_sizes[_selectedSizeIndex]['extra'] as num).toDouble()
        : 0.0;

    final addonPrices = _availableAddons
        .where((a) => _selectedAddons.contains(a['name']))
        .map((a) => (a['price'] as num).toDouble())
        .toList();

    return RestaurantDetailsCalculator.calculateItemPrice(
      basePrice: widget.item.price,
      sizeExtra: extra,
      addonPrices: addonPrices,
    );
  }

  double get _totalPrice {
    return RestaurantDetailsCalculator.calculateTotalPrice(
      unitPrice: _unitPrice,
      quantity: _quantity,
    );
  }

  void _triggerDoubleTapLike() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (!_isLiked) {
        _isLiked = true;
        _likeCount++;
      }
      _showHeartPop = true;
    });
    _heartAnimController.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _showHeartPop = false);
    });
  }

  void _showCommentsModal(bool isDark) {
    HapticFeedback.lightImpact();
    final TextEditingController commentInputCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.72,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: isDark ? _darkBackground : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: EdgeInsets.only(top: 12.h, bottom: 12.h),
                width: 44.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),

              // Title
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'التعليقات والآراء (١٨)',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Comments List
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  children: [
                    _buildCommentBubble('أحمد القيسي', 'عاشت إيدكم! الوجبة وصلت حارة واللحم ترف ويخبل', 'منذ ساعة', isDark),
                    _buildCommentBubble('سارة المهندس', 'أنصح بالصوص الخاص مع الوجبة طعمه سحري جداً', 'منذ 3 ساعات', isDark),
                    _buildCommentBubble('عمر الدليمي', 'توصيل مدار دائماً بالموعد والأكل جودته 10/10', 'منذ يوم', isDark),
                  ],
                ),
              ),

              // Input Bar
              Container(
                padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 14.h),
                decoration: BoxDecoration(
                  color: isDark ? _darkSurface : const Color(0xFFF1F5F9),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentInputCtrl,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5.sp,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        decoration: InputDecoration(
                          hintText: 'اكتب تعليقك اللطيف هنا...',
                          hintStyle: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.5.sp,
                            color: const Color(0xFF94A3B8),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (commentInputCtrl.text.trim().isNotEmpty) {
                          HapticFeedback.lightImpact();
                          commentInputCtrl.clear();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'شكراً لمشاركتك رأيك اللطيف!',
                                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
                              ),
                              backgroundColor: _primaryColor,
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Text(
                          'نشر',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5.sp,
                          ),
                        ),
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

  Widget _buildCommentBubble(String author, String text, String time, bool isDark) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16.r,
            backgroundColor: _primaryColor.withValues(alpha: 0.18),
            child: Text(
              author.substring(0, 1),
              style: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.w800,
                color: _primaryColor,
                fontSize: 12.sp,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      author,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.sp,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      time,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 9.5.sp,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3.h),
                Text(
                  text,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11.5.sp,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final item = widget.item;
    final imageUrl = item.imageUrl;

    final String arabicTotalDigits = IraqiCurrencyFormatter.format(_totalPrice);
    final String arabicTotalWritten = IraqiCurrencyFormatter.formatWritten(_totalPrice);
    final String arabicBaseDigits = IraqiCurrencyFormatter.format(item.price);
    final String arabicBaseWritten = IraqiCurrencyFormatter.formatWritten(item.price);

    return Scaffold(
      backgroundColor: isDark ? _darkBackground : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── 1. Top Navigation App Bar ──
              SliverAppBar(
                pinned: true,
                backgroundColor: isDark ? _darkBackground : Colors.white,
                elevation: 0,
                leading: Padding(
                  padding: EdgeInsets.all(8.r),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? _darkSurface : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        size: 16.sp,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  'تفاصيل الطبق',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                centerTitle: true,
                actions: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isSaved = !_isSaved);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isSaved ? 'تم حفظ الوجبة في المفضلة' : 'تمت الإزالة من المفضلة',
                              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
                            ),
                            backgroundColor: _primaryColor,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: isDark ? _darkSurface : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          color: _isSaved ? _primaryColor : (isDark ? Colors.white70 : Colors.black87),
                          size: 18.sp,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 12.w, top: 8.h, bottom: 8.h),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم نسخ رابط الطبق للمشاركة',
                              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
                            ),
                            backgroundColor: _primaryColor,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: isDark ? _darkSurface : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.share_rounded,
                          color: isDark ? Colors.white70 : Colors.black87,
                          size: 18.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── 2. Social Media Post Card (Publisher + 4:5 Media + Actions) ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 6.h, 14.w, 120.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Restaurant Publisher Bar ──
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: isDark ? _darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(18.r),
                          border: Border.all(
                            color: isDark ? Colors.white10 : const Color(0xFFE2EBE9),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(2.r),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Color(0xFF00BFA5), Color(0xFF5EEAD4)],
                                ),
                              ),
                              child: ClipOval(
                                child: widget.restaurantImageUrl.isNotEmpty
                                    ? Image.network(
                                        widget.restaurantImageUrl,
                                        width: 36.r,
                                        height: 36.r,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(Icons.storefront_rounded, size: 20.sp, color: _primaryColor),
                                      )
                                    : Icon(Icons.storefront_rounded, size: 20.sp, color: _primaryColor),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        widget.restaurantName,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      SizedBox(width: 4.w),
                                      Icon(Icons.verified_rounded, color: const Color(0xFF0095F6), size: 14.sp),
                                    ],
                                  ),
                                  Text(
                                    'القائم • خدمة مدار السريعة ',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 10.sp,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: _primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                item.category.isNotEmpty ? item.category : 'وجبة مميزة',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w800,
                                  color: _primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 10.h),

                      // ── 4:5 Large Vertical Media Showcase with Double-Tap ──
                      GestureDetector(
                        onDoubleTap: _triggerDoubleTapLike,
                        child: Container(
                          height: 350.h,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24.r),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1F3538) : const Color(0xFFE2EBE9),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(23.r),
                                child: imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
                                      )
                                    : _buildPlaceholder(isDark),
                              ),

                              // Gradient Overlays
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(23.r),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.45),
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.55),
                                    ],
                                  ),
                                ),
                              ),

                              // Double tap heart pop
                              if (_showHeartPop)
                                Center(
                                  child: ScaleTransition(
                                    scale: _heartScaleAnimation,
                                    child: Icon(
                                      Icons.favorite_rounded,
                                      color: Colors.white.withValues(alpha: 0.95),
                                      size: 88.sp,
                                    ),
                                  ),
                                ),

                              // Floating Price Badge (Top Right)
                              Positioned(
                                top: 12.h,
                                right: 12.w,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                  decoration: BoxDecoration(
                                    color: _primaryColor,
                                    borderRadius: BorderRadius.circular(16.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _primaryColor.withValues(alpha: 0.5),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    arabicBaseDigits,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 13.5.sp,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),

                              // Overlay Hint (Bottom Center)
                              Positioned(
                                bottom: 12.h,
                                right: 14.w,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.touch_app_rounded, color: Colors.white70, size: 12.sp),
                                      SizedBox(width: 4.w),
                                      Text(
                                        'انقر نقرتين للإعجاب',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 9.5.sp,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
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

                      SizedBox(height: 12.h),

                      // ── Social Actions Interaction Strip ──
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: isDark ? _darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(18.r),
                          border: Border.all(
                            color: isDark ? Colors.white10 : const Color(0xFFE2EBE9),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Like
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _isLiked = !_isLiked;
                                  _likeCount += _isLiked ? 1 : -1;
                                });
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: _isLiked ? Colors.redAccent : (isDark ? Colors.white70 : Colors.black87),
                                    size: 22.sp,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    IraqiCurrencyFormatter.format(_likeCount, includeSymbol: false),
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.sp,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(width: 18.w),

                            // Comments Button
                            GestureDetector(
                              onTap: () => _showCommentsModal(isDark),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    size: 20.sp,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    '١٨ تعليق',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5.sp,
                                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(),

                            // Written Price Pill
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: _primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Text(
                                arabicBaseWritten,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 10.5.sp,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFF5EEAD4) : const Color(0xFF00897B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 14.h),

                      // ── Meal Title & Caption & Badges ──
                      Text(
                        item.name,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          height: 1.25,
                        ),
                      ),

                      SizedBox(height: 6.h),

                      Text(
                        item.description.isNotEmpty
                            ? item.description
                            : 'طبق شهي ومميز ومحضر بأجود المكونات والبهارات الأصلية لتستمتع بألذ طعم.',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.sp,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          height: 1.45,
                        ),
                      ),

                      SizedBox(height: 10.h),

                      // Feature Badges
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 6.h,
                        children: [
                          _buildFeatureBadge('طازج يومياً', isDark),
                          _buildFeatureBadge('تحضير فوري', isDark),
                          _buildFeatureBadge('الأكثر تقييماً', isDark),
                          _buildFeatureBadge('توصيل ساخن', isDark),
                        ],
                      ),

                      SizedBox(height: 22.h),

                      // ── Section 1: Dynamic Sizes (From Restaurant Owner) ──
                      if (_sizes.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'اختر الحجم المطلوب',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'مخصص من الشيف',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 10.sp,
                                color: _primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        Row(
                          children: List.generate(_sizes.length, (idx) {
                            final size = _sizes[idx];
                            final isSelected = _selectedSizeIndex == idx;
                            final extra = (size['extra'] as num).toDouble();
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedSizeIndex = idx);
                                },
                                child: Container(
                                  margin: EdgeInsets.only(left: idx == _sizes.length - 1 ? 0 : 8.w),
                                  padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _primaryColor.withValues(alpha: 0.14)
                                        : (isDark ? _darkCard : Colors.white),
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                      color: isSelected ? _primaryColor : (isDark ? Colors.white10 : const Color(0xFFE2EBE9)),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        size['name'].toString(),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11.5.sp,
                                          color: isSelected
                                              ? _primaryColor
                                              : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                        ),
                                      ),
                                      if (extra > 0) ...[
                                        SizedBox(height: 2.h),
                                        Text(
                                          '+${IraqiCurrencyFormatter.format(extra)}',
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontSize: 9.5.sp,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected ? _primaryColor : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        SizedBox(height: 22.h),
                      ],

                      // ── Section 2: Dynamic Add-ons (From Restaurant Owner) ──
                      if (_availableAddons.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'إضافات اختيارية شهية',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'حسب الرغبة',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 10.sp,
                                color: _primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        ..._availableAddons.map((addon) {
                          final addonName = addon['name'].toString();
                          final isChecked = _selectedAddons.contains(addonName);
                          final price = (addon['price'] as num).toDouble();
                          final iconStr = addon['icon']?.toString() ?? '';

                          return Container(
                            margin: EdgeInsets.only(bottom: 8.h),
                            decoration: BoxDecoration(
                              color: isDark ? _darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: isChecked ? _primaryColor : (isDark ? Colors.white10 : const Color(0xFFE2EBE9)),
                                width: isChecked ? 1.5 : 1,
                              ),
                            ),
                            child: CheckboxListTile(
                              value: isChecked,
                              activeColor: _primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                              title: Row(
                                children: [
                                  Text(iconStr, style: TextStyle(fontSize: 16.sp)),
                                  SizedBox(width: 8.w),
                                  Text(
                                    addonName,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 12.5.sp,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '+${IraqiCurrencyFormatter.format(price)} (${IraqiCurrencyFormatter.formatWritten(price)})',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 10.sp,
                                  color: isChecked ? _primaryColor : const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onChanged: (val) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (val == true) {
                                    _selectedAddons.add(addonName);
                                  } else {
                                    _selectedAddons.remove(addonName);
                                  }
                                });
                              },
                            ),
                          );
                        }),
                        SizedBox(height: 20.h),
                      ],

                      // ── Section 3: Notes for the Chef ──
                      Text(
                        'ملاحظات خاصة للطلب (اختياري)',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5.sp,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        decoration: InputDecoration(
                          hintText: 'مثال: بدون بصل، صوص خارجي، تسوية ممتازة...',
                          hintStyle: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.5.sp,
                            color: const Color(0xFF94A3B8),
                          ),
                          filled: true,
                          fillColor: isDark ? _darkCard : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white10 : const Color(0xFFE2EBE9),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white10 : const Color(0xFFE2EBE9),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            borderSide: const BorderSide(color: _primaryColor, width: 1.5),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Sticky Bottom Bar: Quantity Selector & Add To Cart CTA ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16.w,
                12.h,
                16.w,
                MediaQuery.of(context).padding.bottom + 12.h,
              ),
              decoration: BoxDecoration(
                color: isDark ? _darkSurface : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Quantity Counter
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? _darkCard : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFE2EBE9),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _quantity > 1
                              ? () {
                                  HapticFeedback.lightImpact();
                                  setState(() => _quantity--);
                                }
                              : null,
                          icon: const Icon(Icons.remove, size: 18),
                          color: _quantity > 1 ? Colors.redAccent : Colors.grey,
                        ),
                        Text(
                          IraqiCurrencyFormatter.format(_quantity, includeSymbol: false),
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.w900,
                            fontSize: 15.sp,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() => _quantity++);
                          },
                          icon: const Icon(Icons.add, size: 18, color: _primaryColor),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 12.w),

                  // Big CTA Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        final sizeName = _sizes.isNotEmpty && _selectedSizeIndex < _sizes.length
                            ? _sizes[_selectedSizeIndex]['name'].toString()
                            : '';
                        final optionsStr = _selectedAddons.join('،');
                        final notesStr = _notesController.text.trim();

                        widget.onAddToCart(_unitPrice, sizeName, optionsStr, notesStr, _quantity);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                        elevation: 0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'إضافة للطلب ($arabicTotalDigits)',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5.sp,
                            ),
                          ),
                          Text(
                            '($arabicTotalWritten)',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.w600,
                              fontSize: 10.sp,
                              color: Colors.white.withValues(alpha: 0.9),
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
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(String label, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isDark ? _darkSurface : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2EBE9),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? _darkCard : const Color(0xFFE0F2F1),
      child: Center(
        child: Icon(
          Icons.fastfood_rounded,
          size: 60.sp,
          color: isDark ? Colors.white24 : _primaryColor.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
