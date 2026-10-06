// شريط رأس لوحة إدارة التكسي (Ride Management Header Widget)
// Clean Architecture — Presentation Layer: Header & App Bar

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class RideManagementHeader extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onRefresh;
  final bool isDark;

  const RideManagementHeader({
    super.key,
    this.onRefresh,
    this.isDark = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(60.h);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'غرفة التحكم والعمليات',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  'مباشر',
                  style: TextStyle(
                    color: const Color(0xFF00C853),
                    fontSize: 9.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'نظام مدار لإدارة وتوزيع أسطول التكسي الذكي',
            style: TextStyle(
              fontSize: 10.sp,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
      backgroundColor: isDark ? const Color(0xFF07181A) : Colors.white,
      elevation: 0.5,
      actions: [
        if (onRefresh != null)
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: const Color(0xFF00BFA5),
              size: 20.r,
            ),
            tooltip: 'تحديث البيانات',
            onPressed: onRefresh,
          ),
      ],
    );
  }
}
