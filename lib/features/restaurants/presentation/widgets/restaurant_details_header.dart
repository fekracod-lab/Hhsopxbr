import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/core/pricing/domain/services/iraqi_currency_formatter.dart';

/// هيدر تفاصيل المطعم بأسلوب إنستغرام الفاخر (Instagram Style Restaurant Profile Header)
class RestaurantDetailsHeader extends StatelessWidget {
  final String restaurantName;
  final String imageUrl;
  final String cuisine;
  final double rating;
  final int totalMeals;
  final String deliveryTime;
  final double deliveryFee;
  final bool isDark;
  final VoidCallback? onBack;
  final VoidCallback? onSearch;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onCall;

  const RestaurantDetailsHeader({
    super.key,
    required this.restaurantName,
    required this.imageUrl,
    required this.cuisine,
    this.rating = 4.9,
    this.totalMeals = 24,
    this.deliveryTime = '25 - 35 دقيقة',
    this.deliveryFee = 0.0,
    required this.isDark,
    this.onBack,
    this.onSearch,
    this.onFavorite,
    this.onShare,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFreeDelivery = deliveryFee == 0.0;

    return SliverToBoxAdapter(
      child: Container(
        color: isDark ? const Color(0xFF0F1719) : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Top Cover Banner & Navigation Bar ──
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Cover Image
                Container(
                  height: 190.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B2A2D) : const Color(0xFFE2EBE9),
                  ),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholderCover(isDark),
                        )
                      : _buildPlaceholderCover(isDark),
                ),

                // Top Dark Gradient Overlay
                Container(
                  height: 190.h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.4),
                      ],
                    ),
                  ),
                ),

                // Top Action Bar
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildCircleButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: onBack ?? () => Navigator.pop(context),
                        ),
                        Row(
                          children: [
                            if (onSearch != null)
                              _buildCircleButton(
                                icon: Icons.search_rounded,
                                onTap: onSearch!,
                              ),
                            SizedBox(width: 8.w),
                            _buildCircleButton(
                              icon: Icons.share_rounded,
                              onTap: onShare ?? () {
                                HapticFeedback.lightImpact();
                              },
                            ),
                            SizedBox(width: 8.w),
                            _buildCircleButton(
                              icon: Icons.favorite_border_rounded,
                              onTap: onFavorite ?? () {
                                HapticFeedback.lightImpact();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 2. Instagram Story Gradient Avatar ──
                Positioned(
                  bottom: -40.h,
                  right: 18.w,
                  child: Container(
                    padding: EdgeInsets.all(3.5.r),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFF58529),
                          Color(0xFFDD2A7B),
                          Color(0xFF8134AF),
                          Color(0xFF00BFA5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: EdgeInsets.all(2.5.r),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF0F1719) : Colors.white,
                      ),
                      child: ClipOval(
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                width: 72.r,
                                height: 72.r,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(Icons.storefront_rounded, size: 36.sp, color: const Color(0xFF00BFA5)),
                              )
                            : Icon(Icons.storefront_rounded, size: 36.sp, color: const Color(0xFF00BFA5)),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── 3. Profile Stats & Bio Info ──
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 48.h, 16.w, 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Restaurant Name & Verified Badge
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          restaurantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            height: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Icon(
                        Icons.verified_rounded,
                        color: const Color(0xFF0095F6),
                        size: 18.sp,
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5.r,
                              height: 5.r,
                              decoration: const BoxDecoration(
                                color: Color(0xFF059669),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'مفتوح الآن',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 4.h),

                  // Bio / Cuisine Info
                  Text(
                    cuisine.isNotEmpty ? cuisine : 'أشهى المأكولات والمطابخ بأعلى معايير الجودة • خدمة توصيل مدار السريعة',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11.5.sp,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),

                  SizedBox(height: 14.h),

                  // ── 4. Instagram Style Quick Stats Strip ──
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF142023) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1F3538) : const Color(0xFFE2EBE9),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          label: 'التقييم',
                          value: '${rating.toStringAsFixed(1)} ',
                          isDark: isDark,
                        ),
                        _buildDivider(isDark),
                        _buildStatItem(
                          label: 'وقت التوصيل',
                          value: deliveryTime,
                          isDark: isDark,
                        ),
                        _buildDivider(isDark),
                        _buildStatItem(
                          label: 'التوصيل',
                          value: isFreeDelivery ? 'مجاني' : IraqiCurrencyFormatter.format(deliveryFee),
                          valueColor: isFreeDelivery ? const Color(0xFF00BFA5) : null,
                          isDark: isDark,
                        ),
                      ],
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

  Widget _buildStatItem({
    required String label,
    required String value,
    Color? valueColor,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 12.sp,
            fontWeight: FontWeight.w900,
            color: valueColor ?? (isDark ? Colors.white : const Color(0xFF1E293B)),
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 9.5.sp,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 24.h,
      color: isDark ? Colors.white12 : const Color(0xFFE2EBE9),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
        child: Icon(icon, color: Colors.white, size: 16.sp),
      ),
    );
  }

  Widget _buildPlaceholderCover(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF132A2D), const Color(0xFF0C191B)]
              : [const Color(0xFFCCFBF1), const Color(0xFF99F6E4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 48.sp,
          color: isDark ? Colors.white24 : const Color(0xFF00BFA5).withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
