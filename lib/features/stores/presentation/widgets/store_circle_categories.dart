import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../utils/theme_constants.dart';
import '../../../../shared/icon_utils.dart';
import '../../domain/entities/store_dashboard_models.dart';

/// شريط تصنيفات وأقسام المتجر الدائرية (Store Circle Categories List)
class StoreCircleCategories extends StatelessWidget {
  final List<StoreCategoryEntity> categories;
  final String selectedCategory;
  final bool isAdmin;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<StoreCategoryEntity>? onCategoryLongPress;
  final VoidCallback? onAddCategoryTap;

  const StoreCircleCategories({
    super.key,
    required this.categories,
    required this.selectedCategory,
    this.isAdmin = false,
    required this.onCategorySelected,
    this.onCategoryLongPress,
    this.onAddCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // الفئة الافتراضية "الكل" دائماً في البداية
    final allCats = [
      const _CategoryItemData(
        id: 'all',
        name: 'الكل',
        icon: Icons.grid_view_rounded,
        color: Color(0xFFE3F2FD),
      ),
      ...categories.map((c) => _CategoryItemData(
            id: c.categoryId,
            name: c.name,
            icon: IconUtils.getIconByCode(c.iconCode),
            color: Color(c.colorValue),
            entity: c,
          )),
    ];

    return SizedBox(
      height: 110.h,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        scrollDirection: Axis.horizontal,
        itemCount: allCats.length + (isAdmin ? 1 : 0),
        itemBuilder: (context, index) {
          if (isAdmin && index == allCats.length) {
            return _buildAddCategoryButton(isDark);
          }

          final cat = allCats[index];
          final isSelected = cat.name == selectedCategory;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onCategorySelected(cat.name),
            onLongPress: () {
              if (isAdmin && cat.name != 'الكل' && cat.entity != null) {
                onCategoryLongPress?.call(cat.entity!);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: 78.w,
              margin: EdgeInsets.only(left: 12.w),
              padding: EdgeInsets.symmetric(vertical: 6.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white),
                borderRadius: BorderRadius.circular(20.r),
                border: isSelected
                    ? null
                    : Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      cat.icon,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white60 : Colors.black54),
                      size: 24.sp,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      cat.name,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white60 : Colors.grey.shade600),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              ),
            );
          },
      ),
    );
  }

  Widget _buildAddCategoryButton(bool isDark) {
    return Padding(
      padding: EdgeInsets.only(left: 12.w),
      child: GestureDetector(
        onTap: onAddCategoryTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 78.w,
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              width: 1.5,
              style: BorderStyle.solid,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: AppTheme.primaryColor, size: 24.sp),
                SizedBox(height: 4.h),
                Text(
                  'أضف قسم',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryItemData {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final StoreCategoryEntity? entity;

  const _CategoryItemData({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.entity,
  });
}
