import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/restaurant_models.dart';

/// بطاقة عرض المطعم الفاخرة (Restaurant Showcase Card)
class RestaurantCard extends StatelessWidget {
  final RestaurantEntity restaurant;
  final bool isFavorite;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final Animation<double>? fadeAnimation;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.isFavorite,
    required this.isDark,
    required this.onTap,
    required this.onFavoriteToggle,
    this.fadeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final String coverImage = (restaurant.rawData['coverUrl'] ??
            restaurant.rawData['imageUrl'] ??
            restaurant.imageUrl)
        .toString();
    final String logoImage = restaurant.imageUrl;
    final bool isFreeDelivery = restaurant.deliveryFee == 0.0;

    final card = Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Top Cover Banner & Badges ──
          Expanded(
            flex: 6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(17.r)),
                  child: coverImage.isNotEmpty
                      ? Image.network(
                          coverImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholderBanner(isDark),
                        )
                      : _buildPlaceholderBanner(isDark),
                ),

                // Top Gradient Overlay
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(17.r)),
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
                  left: 6.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: const Color(0xFFFFB800), size: 11.sp),
                        SizedBox(width: 2.w),
                        Text(
                          restaurant.rating.toStringAsFixed(1),
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: Colors.white,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Open / Closed Badge (Top Right) ──
                Positioned(
                  top: 6.h,
                  right: 6.w,
                  child: RestaurantOpenBadge(isOpen: restaurant.isOpen),
                ),

                // ── Favorite Button (Bottom Left of Cover) ──
                Positioned(
                  bottom: 6.h,
                  left: 6.w,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onFavoriteToggle();
                    },
                    child: Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFavorite ? Colors.redAccent : Colors.white,
                        size: 13.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 2. Bottom Content Info ──
          Expanded(
            flex: 5,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Restaurant Name
                  Text(
                    restaurant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      height: 1.15,
                    ),
                  ),

                  // Category & Delivery Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Time
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 11.sp,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            restaurant.deliveryTime,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 9.sp,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      // Fee Tag
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                        decoration: BoxDecoration(
                          color: isFreeDelivery
                              ? const Color(0xFF00BFA5).withValues(alpha: 0.15)
                              : Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          isFreeDelivery ? 'مجاني' : '${restaurant.deliveryFee.toInt()} د.ع',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 8.5.sp,
                            fontWeight: FontWeight.w700,
                            color: isFreeDelivery
                                ? (isDark ? const Color(0xFF5EEAD4) : const Color(0xFF00897B))
                                : (isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: fadeAnimation != null
          ? FadeTransition(opacity: fadeAnimation!, child: card)
          : card,
    );
  }

  Widget _buildPlaceholderBanner(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF162E2E) : const Color(0xFFE0F2F1),
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 28.sp,
          color: isDark ? Colors.white24 : const Color(0xFF00BFA5).withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

/// شارة حالة المطعم مفتوح / معزل
class RestaurantOpenBadge extends StatelessWidget {
  final bool isOpen;

  const RestaurantOpenBadge({super.key, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: (isOpen ? const Color(0xFF059669) : const Color(0xFF64748B))
            .withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4.r,
            height: 4.r,
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
    );
  }
}
