import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import '../../domain/entities/store_dashboard_models.dart';
import 'store_product_card.dart';

/// قسم عرض وإدارة منتجات المتجر (Store Products Section)
/// يعرض زر الإضافة وشبكة المنتجات وحالات التحميل والفراغ
class StoreProductsSection extends StatelessWidget {
  final List<StoreProductEntity> products;
  final bool isLoading;
  final bool isDark;
  final VoidCallback onAddProduct;
  final Function(StoreProductEntity product) onEditProduct;
  final Function(String productId) onDeleteProduct;

  const StoreProductsSection({
    super.key,
    required this.products,
    this.isLoading = false,
    required this.isDark,
    required this.onAddProduct,
    required this.onEditProduct,
    required this.onDeleteProduct,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Add Product Button ──
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
          child: GestureDetector(
            onTap: onAddProduct,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
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
                    'إضافة منتج جديد',
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

        // ── Products Grid ──
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                    strokeWidth: 2,
                  ),
                )
              : products.isEmpty
                  ? _buildEmptyState(
                      Icons.inventory_2_outlined,
                      'ماكو منتجات حالياً — أضف منتجك الأول',
                    )
                  : GridView.builder(
                      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 100.h),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12.h,
                        crossAxisSpacing: 12.w,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return StoreProductCard(
                          product: product,
                          isDark: isDark,
                          onEdit: () => onEditProduct(product),
                          onDelete: () => onDeleteProduct(product.productId),
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
