import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/core/pricing/domain/services/iraqi_currency_formatter.dart';
import '../../domain/entities/restaurant_details_models.dart';

/// بطاقة الوجبة المقربة بأسلوب إنستغرام مع السعر بالأرقام العربية والتفقيط المكتوب
class RestaurantInstagramGridItemCard extends StatefulWidget {
  final MenuItemDetailsEntity item;
  final int quantity;
  final bool isDark;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onCustomize;

  const RestaurantInstagramGridItemCard({
    super.key,
    required this.item,
    required this.quantity,
    required this.isDark,
    required this.onAdd,
    required this.onRemove,
    required this.onCustomize,
  });

  @override
  State<RestaurantInstagramGridItemCard> createState() =>
      _RestaurantInstagramGridItemCardState();
}

class _RestaurantInstagramGridItemCardState
    extends State<RestaurantInstagramGridItemCard>
    with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  late AnimationController _heartAnimController;
  late Animation<double> _heartScaleAnimation;
  bool _showHeartPop = false;

  @override
  void initState() {
    super.initState();
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_heartAnimController);
  }

  @override
  void dispose() {
    _heartAnimController.dispose();
    super.dispose();
  }

  void _triggerDoubleTapLike() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isLiked = true;
      _showHeartPop = true;
    });
    _heartAnimController.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _showHeartPop = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double price = widget.item.price;
    final String name = widget.item.name.isNotEmpty ? widget.item.name : 'وجبة شهية';
    final String imageUrl = widget.item.imageUrl;
    final isDark = widget.isDark;

    final String arabicPriceDigits = IraqiCurrencyFormatter.format(price);
    final String arabicPriceWritten = IraqiCurrencyFormatter.formatWritten(price);

    return GestureDetector(
      onTap: widget.onCustomize,
      onDoubleTap: _triggerDoubleTapLike,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D20) : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isDark ? const Color(0xFF1F3538) : const Color(0xFFE2EBE9),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Hero Close-up Food Image ──
            Expanded(
              flex: 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(19.r)),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
                          )
                        : _buildPlaceholder(isDark),
                  ),

                  // Top Gradient Vignette
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(19.r)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.55),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.35),
                        ],
                      ),
                    ),
                  ),

                  // ── Price Tag Pill with Arabic Digits (Top Right) ──
                  Positioned(
                    top: 8.h,
                    right: 8.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.5.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA5),
                        borderRadius: BorderRadius.circular(14.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00BFA5).withValues(alpha: 0.45),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        arabicPriceDigits,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),

                  // ── Heart Favorite Button (Top Left) ──
                  Positioned(
                    top: 8.h,
                    left: 8.w,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isLiked = !_isLiked);
                      },
                      child: Container(
                        padding: EdgeInsets.all(5.r),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: _isLiked ? Colors.redAccent : Colors.white,
                          size: 14.sp,
                        ),
                      ),
                    ),
                  ),

                  // ── Double-Tap Heart Animation Overlay ──
                  if (_showHeartPop)
                    Center(
                      child: ScaleTransition(
                        scale: _heartScaleAnimation,
                        child: Icon(
                          Icons.favorite_rounded,
                          color: Colors.white.withValues(alpha: 0.95),
                          size: 48.sp,
                        ),
                      ),
                    ),

                  // ── Quick Add / Quantity Floating Button (Bottom Left) ──
                  Positioned(
                    bottom: 8.h,
                    left: 8.w,
                    child: widget.quantity > 0
                        ? Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: const Color(0xFF00BFA5), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    widget.onRemove();
                                  },
                                  child: Icon(Icons.remove, size: 14.sp, color: Colors.white),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                                  child: Text(
                                    IraqiCurrencyFormatter.format(widget.quantity, includeSymbol: false),
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.sp,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    widget.onAdd();
                                  },
                                  child: Icon(Icons.add, size: 14.sp, color: const Color(0xFF00BFA5)),
                                ),
                              ],
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              widget.onCustomize();
                            },
                            child: Container(
                              padding: EdgeInsets.all(6.r),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00BFA5),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00BFA5).withValues(alpha: 0.45),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 16.sp,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // ── 2. Bottom Information Strip with Written Price ──
            Expanded(
              flex: 7,
              child: Padding(
                padding: EdgeInsets.fromLTRB(10.w, 7.h, 10.w, 8.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Meal Name
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        height: 1.15,
                      ),
                    ),

                    // Written Price (تفقيط السعر كتابة)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 11.sp,
                            color: const Color(0xFF00BFA5),
                          ),
                          SizedBox(width: 4.w),
                          Flexible(
                            child: Text(
                              arabicPriceWritten,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFF5EEAD4) : const Color(0xFF00897B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Customize & Add prompt
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'تخصيص وإضافة',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF00BFA5),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9.sp,
                          color: const Color(0xFF00BFA5),
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
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1A2B2E) : const Color(0xFFE0F2F1),
      child: Center(
        child: Icon(
          Icons.fastfood_rounded,
          size: 32.sp,
          color: isDark ? Colors.white24 : const Color(0xFF00BFA5).withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
