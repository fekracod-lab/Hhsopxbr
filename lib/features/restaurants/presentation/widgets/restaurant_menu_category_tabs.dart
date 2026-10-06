import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/shared/icon_utils.dart';
import '../../domain/entities/restaurant_details_models.dart';

const Color _primary = Color(0xFF00BFA5);

/// شريط تبويبات تصنيفات المنيو التفاعلي الفاخر (Instagram Style Category Tabs)
class RestaurantMenuCategoryTabs extends StatelessWidget {
  final TabController? controller;
  final List<MenuCategoryEntity> categories;
  final bool isDark;
  final ValueChanged<int>? onTap;

  const RestaurantMenuCategoryTabs({
    super.key,
    required this.controller,
    required this.categories,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return SizedBox(height: 52.h);
    }

    return Container(
      height: 52.h,
      color: isDark ? const Color(0xFF0F1719) : Colors.white,
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        physics: const BouncingScrollPhysics(),
        indicatorColor: _primary,
        indicatorWeight: 3.2,
        indicatorPadding: EdgeInsets.symmetric(horizontal: 8.w),
        labelColor: _primary,
        unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        labelPadding: EdgeInsets.symmetric(horizontal: 14.w),
        onTap: onTap,
        tabs: categories.map((c) {
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(IconUtils.getIconByCode(c.iconCode), size: 16.sp),
                SizedBox(width: 6.w),
                Text(
                  c.name,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        dividerColor: isDark ? Colors.white10 : const Color(0xFFE2EBE9),
      ),
    );
  }
}
