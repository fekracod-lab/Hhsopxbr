import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import '../../domain/entities/store_dashboard_models.dart';

/// بطاقة منتج المتجر (Store Product Card Widget)
/// واجهة عرض صافية لبيانات المنتج وسعره وتصنيفه مع أزرار التعديل والحذف
class StoreProductCard extends StatelessWidget {
  final StoreProductEntity product;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const StoreProductCard({
    super.key,
    required this.product,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Product Image & Mini Actions ──
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16.r),
                    ),
                    color: isDark
                        ? Colors.white10
                        : Colors.grey.withValues(alpha: 0.08),
                  ),
                  child: product.imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16.r),
                          ),
                          child: Image.network(
                            product.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(
                                Icons.image_not_supported_rounded,
                                size: 36.sp,
                                color: Colors.grey.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.image_rounded,
                            size: 40.sp,
                            color: Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                ),
                // Actions overlay
                Positioned(
                  top: 6.h,
                  right: 6.w,
                  child: Column(
                    children: [
                      _buildMiniAction(
                        icon: Icons.edit_rounded,
                        color: Colors.blue,
                        onTap: onEdit,
                      ),
                      SizedBox(height: 6.h),
                      _buildMiniAction(
                        icon: Icons.delete_rounded,
                        color: Colors.red,
                        onTap: onDelete,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Product Info ──
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.all(10.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${product.price.toInt()} د.ع',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      if (product.category.isNotEmpty)
                        Flexible(
                          child: Text(
                            product.category,
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(6.r),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 14.sp),
      ),
    );
  }
}
