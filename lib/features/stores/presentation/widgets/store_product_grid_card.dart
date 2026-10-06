import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../utils/theme_constants.dart';
import '../../domain/entities/store_dashboard_models.dart';

/// بطاقة عرض المنتج في شبكة المنتجات (Store Product Grid Card)
class StoreProductGridCard extends StatelessWidget {
  final StoreProductEntity product;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;
  final VoidCallback? onDelete;

  const StoreProductGridCard({
    super.key,
    required this.product,
    this.isAdmin = false,
    required this.onTap,
    required this.onAddToCart,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = product.name.isNotEmpty ? product.name : 'منتج غير معروف';
    final price = product.price.toInt();
    final imageUrl = product.imageUrl;
    final category = product.category;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D26) : Colors.white,
          borderRadius: BorderRadius.circular(22.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Image Section ──
                Expanded(
                  child: Container(
                    margin: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : const Color(0xFFF8F8FC),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.r),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: SizedBox(
                                    width: 20.r,
                                    height: 20.r,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(
                                  Icons.image_rounded,
                                  color: Colors.grey.shade300,
                                  size: 36.sp,
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.image_rounded,
                                color: Colors.grey.shade300,
                                size: 36.sp,
                              ),
                            ),
                    ),
                  ),
                ),

                // ── Content Section ──
                Flexible(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(50.w, 2.h, 14.w, 14.h),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (category.isNotEmpty && category != 'الكل')
                            Container(
                              margin: EdgeInsets.only(bottom: 4.h),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF1A1D26),
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            '$price د.ع',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Admin Delete Button (Top Left) ──
            if (isAdmin && onDelete != null)
              Positioned(
                top: 6.h,
                left: 6.w,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 14.sp, color: Colors.white),
                  ),
                ),
              ),

            // ── Add to Cart Button (Bottom Left) ──
            Positioned(
              bottom: 12.h,
              left: 10.w,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey('add_to_cart_${product.productId}'),
                  borderRadius: BorderRadius.circular(12.r),
                  onTap: onAddToCart,
                  child: Container(
                    padding: EdgeInsets.all(9.r),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add_shopping_cart_rounded,
                      color: Colors.white,
                      size: 18.sp,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
