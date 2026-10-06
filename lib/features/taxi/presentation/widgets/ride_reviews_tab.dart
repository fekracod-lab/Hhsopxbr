// تبويب التقييمات والآراء (Ride Reviews Tab Widget)
// Clean Architecture — Presentation Layer: Reviews, Ratings & Moderation Actions

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import '../../domain/entities/ride_management_models.dart';

class RideReviewsTab extends StatelessWidget {
  final List<DriverReviewAdminEntity> reviews;
  final String selectedFilter;
  final String searchQuery;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<DriverReviewAdminEntity> onWarnDriver;
  final ValueChanged<DriverReviewAdminEntity> onPraiseDriver;
  final ValueChanged<DriverReviewAdminEntity> onDeleteReview;
  final bool isDark;

  const RideReviewsTab({
    super.key,
    required this.reviews,
    required this.selectedFilter,
    required this.searchQuery,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onWarnDriver,
    required this.onPraiseDriver,
    required this.onDeleteReview,
    this.isDark = false,
  });

  static const List<Map<String, String>> _filterOptions = [
    {'key': 'all', 'label': 'الكل'},
    {'key': '5_star', 'label': '5 نجوم'},
    {'key': '4_star', 'label': '4 نجوم'},
    {'key': 'low', 'label': 'منخفضة (1-3)'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // حقل البحث
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          color: isDark ? const Color(0xFF0C2428) : Colors.white,
          child: TextField(
            onChanged: onSearchChanged,
            style: TextStyle(fontSize: 12.sp, color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'بحث باسم الكابتن، الزبون، أو نص التعليق...',
              hintStyle: TextStyle(fontSize: 11.sp, color: Colors.grey),
              prefixIcon: Icon(Icons.search_rounded, color: const Color(0xFF00BFA5), size: 20.r),
              filled: true,
              fillColor: isDark ? const Color(0xFF133338) : const Color(0xFFF1F5F9),
              contentPadding: EdgeInsets.symmetric(vertical: 8.h),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
            ),
          ),
        ),

        // شريط فلاتر النجوم
        Container(
          height: 44.h,
          color: isDark ? const Color(0xFF0C2428) : Colors.white,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            itemCount: _filterOptions.length,
            separatorBuilder: (_, __) => SizedBox(width: 6.w),
            itemBuilder: (ctx, idx) {
              final opt = _filterOptions[idx];
              final isSelected = selectedFilter == opt['key'];
              return ChoiceChip(
                label: Text(
                  opt['label']!,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 10.5.sp,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF00BFA5),
                backgroundColor: isDark ? const Color(0xFF133338) : const Color(0xFFF1F5F9),
                onSelected: (_) => onFilterChanged(opt['key']!),
              );
            },
          ),
        ),
        SizedBox(height: 4.h),

        // قائمة التقييمات
        Expanded(
          child: reviews.isEmpty
              ? Center(
                  child: Text(
                    'ماكو تقييمات حالياً مطابقة للتصفية',
                    style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  itemCount: reviews.length,
                  itemBuilder: (ctx, idx) {
                    final rev = reviews[idx];
                    return _buildReviewCard(rev);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(DriverReviewAdminEntity rev) {
    final dateStr = rev.createdAt != null
        ? intl.DateFormat('yyyy/MM/dd - hh:mm a').format(rev.createdAt!)
        : 'تاريخ غير محدد';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
      color: isDark ? const Color(0xFF0C2428) : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14.r,
                      backgroundColor: Colors.amber.withValues(alpha: 0.15),
                      child: Icon(Icons.star_rounded, color: Colors.amber, size: 16.r),
                    ),
                    SizedBox(width: 8.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الزبون: ${rev.customerName} ←  الكابتن: ${rev.driverName}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5.sp,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(dateStr, style: TextStyle(fontSize: 9.sp, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber, size: 14.r),
                      SizedBox(width: 2.w),
                      Text(
                        '${rev.rating}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp, color: Colors.amber.shade900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (rev.comment.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF133338) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  ' "${rev.comment}"',
                  style: TextStyle(fontSize: 11.sp, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
            SizedBox(height: 8.h),

            // إجراءات الإدارة على التقييم
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => onWarnDriver(rev),
                  icon: Icon(Icons.warning_amber_rounded, size: 14.r, color: Colors.orange),
                  label: const Text('تنبيه الكابتن', style: TextStyle(color: Colors.orange, fontSize: 10.5)),
                ),
                SizedBox(width: 4.w),
                TextButton.icon(
                  onPressed: () => onPraiseDriver(rev),
                  icon: Icon(Icons.emoji_events_outlined, size: 14.r, color: const Color(0xFF00C853)),
                  label: const Text('شكر الكابتن', style: TextStyle(color: Color(0xFF00C853), fontSize: 10.5)),
                ),
                SizedBox(width: 4.w),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 16.r, color: Colors.redAccent),
                  tooltip: 'حذف التقييم',
                  onPressed: () => onDeleteReview(rev),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
