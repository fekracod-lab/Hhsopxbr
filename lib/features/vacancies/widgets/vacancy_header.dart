import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import '../services/vacancy_service.dart';

class VacancyHeader extends StatelessWidget {
  final bool isDark;
  final int currentTab;
  final String searchQuery;
  final bool hasAdvancedFilter;
  final ValueChanged<int> onTabChange;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onOpenFilter;
  final VoidCallback onOpenAddOptions;

  const VacancyHeader({
    super.key,
    required this.isDark,
    required this.currentTab,
    required this.searchQuery,
    required this.hasAdvancedFilter,
    required this.onTabChange,
    required this.onSearchChanged,
    required this.onOpenFilter,
    required this.onOpenAddOptions,
  });

  @override
  Widget build(BuildContext context) {
    final user = VacancyService().currentUser;
    final photoUrl = user?.photoURL;
    final displayName = user?.displayName;

    return Container(
      color: isDark ? app_colors.darkSurface : Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.search_rounded, color: isDark ? app_colors.primaryColor : app_colors.accentColor, size: 24.r),
                onPressed: () => onTabChange(2),
              ),
              IconButton(
                icon: Icon(Icons.work_rounded, color: isDark ? app_colors.primaryColor : app_colors.accentColor, size: 24.r),
                onPressed: onOpenAddOptions,
              ),
              const Spacer(),
              Text(
                'فرص عمل',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20.sp,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => onTabChange(4),
                child: CircleAvatar(
                  radius: 18.r,
                  backgroundColor: app_colors.primaryColor.withValues(alpha: 0.15),
                  backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                      ? NetworkImage(photoUrl)
                      : null,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? Text(
                          (displayName != null && displayName.isNotEmpty)
                              ? displayName[0].toUpperCase()
                              : '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                            color: app_colors.primaryColor,
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Container(
            height: 48.h,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.tune_rounded,
                    color: hasAdvancedFilter ? app_colors.accentColor : Colors.grey.shade600,
                    size: 20.r,
                  ),
                  onPressed: onOpenFilter,
                ),
                Container(
                  width: 1.w,
                  height: 20.h,
                  color: Colors.grey.shade400,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: TextField(
                      onChanged: onSearchChanged,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن وظائف، شركات، أو مرشحين...',
                        hintStyle: TextStyle(
                          fontSize: 12.sp,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20.r),
                SizedBox(width: 12.w),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
