import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../pages/restaurant_details_page.dart';

const Color _primary = Color(0xFF26A69A);
const Color _darkText = Color(0xFFE0F2F1);
const Color _textColor = Color(0xFF1A1A1A);
const Color _darkSubText = Color(0xFF80CBC4);
const Color _subText = Color(0xFF616161);

/// قسم وشبكة الوجبات الأكثر طلباً وشهرة (Popular Meals Section Widget)
class RestaurantPopularMealsSection extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> mealsFuture;
  final bool isDark;
  final VoidCallback onShowAll;
  final Animation<double>? fadeAnimation;

  const RestaurantPopularMealsSection({
    super.key,
    required this.mealsFuture,
    required this.isDark,
    required this.onShowAll,
    this.fadeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 12.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onShowAll();
                },
                child: Text(
                  'عرض الكل',
                  style: TextStyle(
                    fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                    fontSize: 12.sp,
                    color: _primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'شوف الأكلات واختار اللي يعجبك',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w900,
                    color: isDark ? _darkText : _textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: mealsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return _buildShimmerLoader(isDark);
            }
            final meals = snapshot.data!;
            if (meals.isEmpty) {
              return Padding(
                padding: EdgeInsets.all(20.r),
                child: Center(
                  child: Text(
                    'ماكو وجبات هسة',
                    style: TextStyle(
                      fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                      fontSize: 13.sp,
                      color: isDark ? _darkSubText : _subText,
                    ),
                  ),
                ),
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16.h,
                crossAxisSpacing: 12.w,
                childAspectRatio: 0.55,
              ),
              itemCount: meals.length,
              itemBuilder: (context, index) {
                return RestaurantMealCard(
                  meal: meals[index],
                  isDark: isDark,
                  fadeAnimation: fadeAnimation,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildShimmerLoader(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 12.w,
          childAspectRatio: 0.55,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey[200],
              borderRadius: BorderRadius.circular(14.r),
            ),
          );
        },
      ),
    );
  }
}

/// بطاقة الوجبة الفردية (Meal Card Widget)
class RestaurantMealCard extends StatelessWidget {
  final Map<String, dynamic> meal;
  final bool isDark;
  final Animation<double>? fadeAnimation;

  const RestaurantMealCard({
    super.key,
    required this.meal,
    required this.isDark,
    this.fadeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final mealName = meal['mealName']?.toString() ?? 'وجبة';
    final mealImage = meal['mealImage']?.toString() ?? '';
    final mealPrice = (meal['mealPrice'] as num?)?.toDouble() ?? 0.0;
    final restaurantName = meal['restaurantName']?.toString() ?? 'مطعم';
    final restaurantId = meal['restaurantId']?.toString() ?? '';
    final restaurantImageUrl = meal['restaurantImageUrl']?.toString() ?? '';

    final card = Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E26) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14.r),
                topRight: Radius.circular(14.r),
              ),
              child: SizedBox(
                width: double.infinity,
                child: mealImage.isNotEmpty
                    ? Image.network(
                        mealImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: isDark ? const Color(0xFF2A2A35) : Colors.grey[200],
                          child: Icon(Icons.fastfood_rounded, size: 24.sp, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: isDark ? const Color(0xFF2A2A35) : Colors.grey[200],
                        child: Icon(Icons.fastfood_rounded, size: 24.sp, color: Colors.grey),
                      ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    mealName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                      fontSize: 8.5.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF2C3E50),
                    ),
                  ),
                  Text(
                    restaurantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                      fontSize: 7.5.sp,
                      color: isDark ? _darkSubText : _subText,
                    ),
                  ),
                  if (mealPrice > 0)
                    Text(
                      '${mealPrice.toStringAsFixed(0)} د.ع',
                      style: TextStyle(
                        fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.w900,
                        color: _primary,
                      ),
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
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => RestaurantDetailsPage(
              restaurantId: restaurantId,
              restaurantName: restaurantName,
              imageUrl: restaurantImageUrl,
            ),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      },
      child: fadeAnimation != null
          ? FadeTransition(
              opacity: fadeAnimation!,
              child: card,
            )
          : card,
    );
  }
}
