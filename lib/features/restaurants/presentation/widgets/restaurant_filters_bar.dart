import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _primary = Color(0xFF26A69A);
const Color _darkCard = Color(0xFF113033);
const Color _darkSubText = Color(0xFF80CBC4);
const Color _subText = Color(0xFF616161);

/// شريط الفلاتر السريعة للمطاعم (Quick Filters Bar Widget)
class RestaurantFiltersBar extends StatelessWidget {
  final bool onlyFreeDelivery;
  final bool onlyOpen;
  final bool sortByRating;
  final bool sortByDeliveryTime;
  final bool isDark;
  final VoidCallback onToggleFreeDelivery;
  final VoidCallback onToggleOnlyOpen;
  final VoidCallback onToggleSortByRating;
  final VoidCallback onToggleSortByDeliveryTime;

  const RestaurantFiltersBar({
    super.key,
    required this.onlyFreeDelivery,
    required this.onlyOpen,
    required this.sortByRating,
    required this.sortByDeliveryTime,
    required this.isDark,
    required this.onToggleFreeDelivery,
    required this.onToggleOnlyOpen,
    required this.onToggleSortByRating,
    required this.onToggleSortByDeliveryTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38.h,
      margin: EdgeInsets.only(bottom: 12.h),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        children: [
          RestaurantFilterChip(
            label: 'توصيل بلاش',
            isSelected: onlyFreeDelivery,
            isDark: isDark,
            onTap: onToggleFreeDelivery,
          ),
          SizedBox(width: 8.w),
          RestaurantFilterChip(
            label: 'فاتح هسة',
            isSelected: onlyOpen,
            isDark: isDark,
            onTap: onToggleOnlyOpen,
          ),
          SizedBox(width: 8.w),
          RestaurantFilterChip(
            label: 'أعلى تقييم',
            isSelected: sortByRating,
            isDark: isDark,
            onTap: onToggleSortByRating,
          ),
          SizedBox(width: 8.w),
          RestaurantFilterChip(
            label: 'أسرع توصيل',
            isSelected: sortByDeliveryTime,
            isDark: isDark,
            onTap: onToggleSortByDeliveryTime,
          ),
        ],
      ),
    );
  }
}

/// رقاقة الفلتر التفاعلية (Filter Chip Item)
class RestaurantFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const RestaurantFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? _primary : (isDark ? _darkCard : Colors.white),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? Colors.white10 : _primary.withValues(alpha: 0.18)),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
            fontSize: 11.5.sp,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? _darkSubText : _subText),
          ),
        ),
      ),
    );
  }
}
