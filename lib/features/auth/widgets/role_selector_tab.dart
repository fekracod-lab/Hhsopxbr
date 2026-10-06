import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

enum UserRole { customer, captain, restaurant, store, delivery }

extension UserRoleExtension on UserRole {
  String get title {
    switch (this) {
      case UserRole.customer:
        return 'زبون';
      case UserRole.captain:
        return 'كابتن تكسي';
      case UserRole.restaurant:
        return 'مطعم';
      case UserRole.store:
        return 'متجر';
      case UserRole.delivery:
        return 'مندوب توصيل';
    }
  }

  String get tagLine {
    switch (this) {
      case UserRole.customer:
        return 'خدمات الزبائن';
      case UserRole.captain:
        return 'مشاوير ونقل ركاب';
      case UserRole.restaurant:
        return 'شريك مطعم';
      case UserRole.store:
        return 'شريك متجر';
      case UserRole.delivery:
        return 'توصيل مرسال وطلبات';
    }
  }

  String get shortTag {
    switch (this) {
      case UserRole.customer:
        return 'شخصي';
      case UserRole.captain:
        return 'مشاوير';
      case UserRole.restaurant:
        return 'أطعمة';
      case UserRole.store:
        return 'مشتريات';
      case UserRole.delivery:
        return 'سريع';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.customer:
        return Icons.person_rounded;
      case UserRole.captain:
        return Icons.local_taxi_rounded;
      case UserRole.restaurant:
        return Icons.restaurant_rounded;
      case UserRole.store:
        return Icons.storefront_rounded;
      case UserRole.delivery:
        return Icons.delivery_dining_rounded;
    }
  }

  IconData get subIcon {
    switch (this) {
      case UserRole.customer:
        return Icons.verified_user_rounded;
      case UserRole.captain:
        return Icons.speed_rounded;
      case UserRole.restaurant:
        return Icons.local_fire_department_rounded;
      case UserRole.store:
        return Icons.shopping_bag_rounded;
      case UserRole.delivery:
        return Icons.bolt_rounded;
    }
  }

  List<Color> get gradientColors {
    switch (this) {
      case UserRole.customer:
        return const [Color(0xFF00B4D8), Color(0xFF0077B6)]; // Ocean Teal / Cyan
      case UserRole.captain:
        return const [Color(0xFFFFB703), Color(0xFFFB8500)]; // Radiant Taxi Amber
      case UserRole.restaurant:
        return const [Color(0xFFFF5722), Color(0xFFD84315)]; // Deep Flame Coral
      case UserRole.store:
        return const [Color(0xFF9C27B0), Color(0xFF6A1B9A)]; // Royal Purple
      case UserRole.delivery:
        return const [Color(0xFF10B981), Color(0xFF047857)]; // Logistics Emerald Mint
    }
  }

  Color get roleColor => gradientColors.first;
}

class RoleSelectorTab extends StatelessWidget {
  final UserRole selectedRole;
  final ValueChanged<UserRole> onRoleSelected;

  const RoleSelectorTab({
    super.key,
    required this.selectedRole,
    required this.onRoleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0C1D1F).withValues(alpha: 0.95)
            : const Color(0xFFF3F8F7),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isDark ? const Color(0xFF1D3E42) : const Color(0xFFD4E6E4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Header Bar with Live Indicator ──
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 4.h),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: EdgeInsets.all(5.r),
                  decoration: BoxDecoration(
                    color: selectedRole.roleColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 13.sp,
                    color: selectedRole.roleColor,
                  ),
                ),
                SizedBox(width: 7.w),
                Text(
                  'نوع الحساب:',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A3030),
                  ),
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.5.h),
                  decoration: BoxDecoration(
                    color: selectedRole.roleColor.withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: selectedRole.roleColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6.r,
                        height: 6.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selectedRole.roleColor,
                        ),
                      ),
                      SizedBox(width: 5.w),
                      Text(
                        selectedRole.title,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          color: selectedRole.roleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Divider(
              color: isDark ? const Color(0xFF183538) : const Color(0xFFE2EFEB),
              thickness: 1,
              height: 10.h,
            ),
          ),

          // ── Horizontal Role Selection Cards ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 10.h),
            child: Row(
              children: UserRole.values.map((role) {
                final isSelected = selectedRole == role;
                final gradients = role.gradientColors;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onRoleSelected(role);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedScale(
                    scale: isSelected ? 1.04 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      margin: EdgeInsets.symmetric(horizontal: 4.w),
                      padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 10.h),
                      constraints: BoxConstraints(
                        minWidth: 84.w,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? const Color(0xFF132B2E) : Colors.white)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.black.withValues(alpha: 0.015)),
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(
                          color: isSelected
                              ? gradients.first
                              : (isDark
                                  ? const Color(0xFF1E3A3D)
                                  : const Color(0xFFE0ECE9)),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: gradients.first.withValues(alpha: 0.28),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top Active Indicator Pill
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: isSelected ? 22.w : 0,
                            height: 3.5.h,
                            margin: EdgeInsets.only(bottom: 8.h),
                            decoration: BoxDecoration(
                              color: gradients.first,
                              borderRadius: BorderRadius.circular(3.r),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: gradients.first.withValues(alpha: 0.6),
                                        blurRadius: 6,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : [],
                            ),
                          ),

                          // 3D Realistic Icon Badge
                          _RoleIconBadge(
                            role: role,
                            isSelected: isSelected,
                            isDark: isDark,
                          ),

                          SizedBox(height: 8.h),

                          // Role Title Label
                          Text(
                            role.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11.5.sp,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? (isDark ? Colors.white : const Color(0xFF0F2424))
                                  : (isDark ? app_colors.darkSubText : app_colors.subTextColor),
                              height: 1.15,
                            ),
                          ),

                          SizedBox(height: 4.h),

                          // Category Subtitle Tag
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? gradients.first.withValues(alpha: isDark ? 0.22 : 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              role.shortTag,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 9.5.sp,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isSelected
                                    ? (isDark ? gradients.first : gradients.last)
                                    : (isDark ? Colors.white38 : const Color(0xFF8A9E9C)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleIconBadge extends StatelessWidget {
  final UserRole role;
  final bool isSelected;
  final bool isDark;

  const _RoleIconBadge({
    required this.role,
    required this.isSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final gradients = role.gradientColors;

    return SizedBox(
      width: 50.r,
      height: 50.r,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 1. Ambient Glow Halo (When Selected)
          if (isSelected)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 48.r,
              height: 48.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: gradients.first.withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),

          // 2. Primary 3D Squircle Base Container
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: isSelected ? 44.r : 40.r,
            height: isSelected ? 44.r : 40.r,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15.r),
              gradient: LinearGradient(
                colors: isSelected
                    ? gradients
                    : [
                        gradients.first.withValues(alpha: isDark ? 0.35 : 0.18),
                        gradients.last.withValues(alpha: isDark ? 0.22 : 0.1),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.85)
                    : gradients.first.withValues(alpha: isDark ? 0.4 : 0.25),
                width: isSelected ? 1.8 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: gradients.last.withValues(alpha: 0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Top Gloss Highlight reflection
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 18.r,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(14.r)),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: isSelected ? 0.4 : 0.18),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // Main Center Icon
                Icon(
                  role.icon,
                  size: isSelected ? 23.r : 21.r,
                  color: isSelected ? Colors.white : gradients.first,
                ),
              ],
            ),
          ),

          // 3. Floating Micro-Badge on bottom corner (3D Accent Icon)
          Positioned(
            bottom: -2.r,
            left: -2.r,
            child: AnimatedScale(
              scale: isSelected ? 1.05 : 0.95,
              duration: const Duration(milliseconds: 250),
              child: Container(
                width: 19.r,
                height: 19.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF132527) : Colors.white,
                  border: Border.all(
                    color: isSelected ? gradients.first : (isDark ? Colors.white24 : const Color(0xFFD0DFDC)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    role.subIcon,
                    size: 10.5.r,
                    color: gradients.first,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
