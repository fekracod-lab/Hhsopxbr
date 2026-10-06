import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

/// ─── Glass Shimmer Base Wrapper ───
class GlassShimmer extends StatelessWidget {
  final Widget child;

  const GlassShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF132729) : Colors.grey.shade200,
      highlightColor: isDark
          ? app_colors.primaryColor.withValues(alpha: 0.15)
          : Colors.grey.shade50,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// ─── Stores & Restaurants Horizontal Shimmer ───
class StoresHorizontalShimmer extends StatelessWidget {
  final int count;

  const StoresHorizontalShimmer({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassShimmer(
      child: SizedBox(
        height: 185.h,
        child: ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          itemBuilder: (context, index) {
            return Container(
              width: 158.w,
              margin: EdgeInsetsDirectional.only(end: 12.w),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover Banner Shimmer
                  Container(
                    height: 84.h,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFE2EBE9),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(10.w, 18.h, 10.w, 8.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 90.w,
                          height: 12.h,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : const Color(0xFFE2EBE9),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Container(
                          width: 65.w,
                          height: 10.h,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : const Color(0xFFEEF2F1),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// ─── Featured Meals Horizontal Shimmer ───
class MealsHorizontalShimmer extends StatelessWidget {
  final int count;

  const MealsHorizontalShimmer({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassShimmer(
      child: SizedBox(
        height: 135.h,
        child: ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          itemBuilder: (context, index) {
            return Container(
              width: 90.w,
              margin: EdgeInsetsDirectional.only(end: 12.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Image Box
                  Container(
                    width: 68.w,
                    height: 68.w,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  // Meal Name Bar
                  Container(
                    width: 65.w,
                    height: 10.h,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  // Price Bar
                  Container(
                    width: 45.w,
                    height: 9.h,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E26) : Colors.white,
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
