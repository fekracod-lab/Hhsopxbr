import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import '../../domain/entities/store_dashboard_models.dart';

/// قسم تصنيفات وأقسام المتجر (Store Categories Section)
/// يعرض قائمة الأقسام مع تعداد المنتجات المحسوب بالذاكرة وزر الإضافة والحذف
class StoreCategoriesSection extends StatelessWidget {
  final List<StoreCategoryEntity> categories;
  final Map<String, int> productCounts;
  final bool isLoading;
  final bool isDark;
  final VoidCallback onAddCategory;
  final Function(String categoryId) onDeleteCategory;

  const StoreCategoriesSection({
    super.key,
    required this.categories,
    required this.productCounts,
    this.isLoading = false,
    required this.isDark,
    required this.onAddCategory,
    required this.onDeleteCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Add Category Button ──
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
          child: GestureDetector(
            onTap: onAddCategory,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6C63FF),
                    const Color(0xFF6C63FF).withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 22.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'إضافة قسم جديد',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Categories List ──
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                    strokeWidth: 2,
                  ),
                )
              : categories.isEmpty
                  ? _buildEmptyState(
                      Icons.category_outlined,
                      'لا توجد أقسام — أنشئ أول قسم',
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 100.h),
                      physics: const BouncingScrollPhysics(),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final count = productCounts[cat.name] ?? 0;
                        return Container(
                          margin: EdgeInsets.only(bottom: 10.h),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 14.h,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1D26) : Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.15 : 0.04,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10.r),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C63FF)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Icon(
                                  Icons.folder_rounded,
                                  color: const Color(0xFF6C63FF),
                                  size: 22.sp,
                                ),
                              ),
                              SizedBox(width: 14.w),
                              Expanded(
                                child: Text(
                                  cat.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.sp,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              // In-memory calculated product count badge
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  '$count منتج',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              GestureDetector(
                                onTap: () => onDeleteCategory(cat.categoryId),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.red.withValues(alpha: 0.6),
                                  size: 20.sp,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48.sp,
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
