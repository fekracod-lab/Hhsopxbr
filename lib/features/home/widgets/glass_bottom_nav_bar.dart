import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:flutter_screenutil/flutter_screenutil.dart';

class GlassBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const GlassBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
            blurRadius: 24.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
            decoration: BoxDecoration(
              color: isDark
                  ? app_colors.darkCard.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(32.r),
              border: Border.all(
                color: isDark ? app_colors.darkBorderSubtle : Colors.white.withValues(alpha: 0.7),
                width: 1.2,
              ),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    context,
                    isDark,
                    0,
                    Icons.home_rounded,
                    Icons.home_outlined,
                    'الرئيسية',
                  ),
                  _buildNavItem(
                    context,
                    isDark,
                    1,
                    Icons.search_rounded,
                    Icons.search_outlined,
                    'بحث',
                  ),
                  _buildNavItem(
                    context,
                    isDark,
                    2,
                    Icons.bookmark_rounded,
                    Icons.bookmark_border_rounded,
                    'المفضلة',
                  ),
                  _buildNavItem(
                    context,
                    isDark,
                    3,
                    Icons.person_rounded,
                    Icons.person_outline_rounded,
                    'حسابي',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    bool isDark,
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
  ) {
    final isSelected = selectedIndex == index;
    final activeColor = app_colors.primaryColor;
    final inactiveColor = isDark ? app_colors.darkSubText.withValues(alpha: 0.6) : app_colors.subTextColor;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16.w : 10.w,
          vertical: 6.h,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.18 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
          border: isSelected
              ? Border.all(
                  color: activeColor.withValues(alpha: 0.3),
                  width: 1,
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                key: ValueKey(isSelected),
                size: 24.r,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 10.5.sp,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
