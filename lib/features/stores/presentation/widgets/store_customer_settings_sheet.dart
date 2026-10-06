import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../utils/theme_constants.dart';

/// نافذة إعدادات العميل السفلية (Store Customer Settings Sheet)
class StoreCustomerSettingsSheet extends StatelessWidget {
  final VoidCallback onMyOrdersTap;
  final VoidCallback onChangePhoneTap;

  const StoreCustomerSettingsSheet({
    super.key,
    required this.onMyOrdersTap,
    required this.onChangePhoneTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 40.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D26) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'الإعدادات',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24.h),
            _buildSettingTile(
              Icons.notifications_active_outlined,
              'الإشعارات',
              isDark,
              trailing: Switch.adaptive(
                value: true,
                activeThumbColor: AppTheme.primaryColor,
                activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                onChanged: (_) {},
              ),
            ),
            SizedBox(height: 12.h),
            _buildSettingTile(
              Icons.shopping_bag_outlined,
              'طلباتي',
              isDark,
              onTap: onMyOrdersTap,
            ),
            SizedBox(height: 12.h),
            _buildSettingTile(
              Icons.phone_iphone_rounded,
              'تغيير رقم الهاتف',
              isDark,
              onTap: onChangePhoneTap,
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    IconData icon,
    String label,
    bool isDark, {
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 22.sp),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null)
              trailing
            else
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14.sp,
                color: Colors.grey,
              ),
          ],
        ),
      ),
    );
  }
}
