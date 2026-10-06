import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';

/// قسم إعدادات المتجر (Store Settings Section)
/// يعرض عناصر الإدارة ونقل الملكية والدعم الفني وحذف الحساب
class StoreSettingsSection extends StatelessWidget {
  final bool isDark;
  final VoidCallback onEditStoreInfo;
  final VoidCallback onTransferOwnership;
  final VoidCallback onHelpCenter;
  final VoidCallback onAboutStore;
  final VoidCallback onDeleteStore;

  const StoreSettingsSection({
    super.key,
    required this.isDark,
    required this.onEditStoreInfo,
    required this.onTransferOwnership,
    required this.onHelpCenter,
    required this.onAboutStore,
    required this.onDeleteStore,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(24.r),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildSectionTitle('إدارة المتجر'),
        SizedBox(height: 12.h),
        _buildSettingItem(
          icon: Icons.storefront_rounded,
          title: 'تعديل بيانات المتجر',
          sub: 'الاسم، الشعار، الغلاف',
          color: AppTheme.primaryColor,
          onTap: onEditStoreInfo,
        ),
        _buildSettingItem(
          icon: Icons.swap_horiz_rounded,
          title: 'نقل ملكية المتجر',
          sub: 'تحويل الصلاحيات لمستخدم آخر',
          color: Colors.orange,
          onTap: onTransferOwnership,
        ),
        SizedBox(height: 24.h),
        _buildSectionTitle('الدعم'),
        SizedBox(height: 12.h),
        _buildSettingItem(
          icon: Icons.help_outline_rounded,
          title: 'مركز المساعدة',
          sub: 'الأسئلة الشائعة والدعم الفني',
          color: Colors.blue,
          onTap: onHelpCenter,
        ),
        _buildSettingItem(
          icon: Icons.info_outline_rounded,
          title: 'حول المتجر',
          sub: 'معلومات المتجر والتطبيق',
          color: Colors.grey,
          onTap: onAboutStore,
        ),
        SizedBox(height: 24.h),
        _buildSectionTitle('منطقة الخطر'),
        SizedBox(height: 12.h),
        _buildSettingItem(
          icon: Icons.delete_forever_rounded,
          title: 'حذف المتجر نهائياً',
          sub: 'سيتم مسح جميع البيانات والمنتجات',
          color: Colors.red,
          onTap: onDeleteStore,
          isDestructive: true,
        ),
        SizedBox(height: 80.h),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String sub,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D26) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        leading: Container(
          padding: EdgeInsets.all(10.r),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(icon, color: color, size: 22.sp),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13.sp,
            color: isDestructive
                ? Colors.red
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
        subtitle: Text(
          sub,
          style: TextStyle(
            fontSize: 10.sp,
            color: Colors.grey,
          ),
        ),
        trailing: Icon(
          Icons.chevron_left_rounded,
          color: Colors.grey.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
