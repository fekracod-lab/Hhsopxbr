import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';

class ProductDetailPage extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;
  final String storeId;
  final String storeName;
  final Function(Map<String, dynamic> product)? onAddToCart;

  const ProductDetailPage({
    super.key,
    required this.productId,
    required this.productData,
    required this.storeId,
    required this.storeName,
    this.onAddToCart,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  int _quantity = 1;
  bool _addedToCart = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = widget.productData;
    final name = data['name'] ?? 'منتج';
    final price = data['price'] ?? 0;
    final priceNum = (price is num) ? price.toDouble() : (double.tryParse(price.toString()) ?? 0);
    final description = data['description'] ?? '';
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final category = data['category'] ?? '';
    final bgColor = isDark ? const Color(0xFF0F0F13) : const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Hero Image ──
              SliverAppBar(
                expandedHeight: 360.h,
                pinned: true,
                backgroundColor: isDark ? const Color(0xFF1A1D26) : Colors.white,
                leading: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: isDark ? const Color(0xFF1A1D26) : Colors.grey.shade100,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.primaryColor,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => Container(
                                color: isDark ? const Color(0xFF1A1D26) : Colors.grey.shade100,
                                child: Icon(Icons.image_rounded,
                                    size: 80.sp, color: Colors.grey.shade300),
                              ),
                            )
                          : Container(
                              color: isDark ? const Color(0xFF1A1D26) : Colors.grey.shade100,
                              child: Icon(Icons.image_rounded,
                                  size: 80.sp, color: Colors.grey.shade300),
                            ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              bgColor.withValues(alpha: 0.6),
                              bgColor,
                            ],
                            stops: const [0.0, 0.5, 0.85, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Product Info ──
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category badge
                          if (category.isNotEmpty && category != 'الكل')
                            Container(
                              margin: EdgeInsets.only(bottom: 12.h),
                              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.category_rounded,
                                      size: 14.sp, color: AppTheme.primaryColor),
                                  SizedBox(width: 6.w),
                                  Text(
                                    category.toString(),
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Product name
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF1A1D26),
                              height: 1.3,
                            ),
                          ),
                          SizedBox(height: 8.h),

                          // Store name
                          Row(
                            children: [
                              Icon(Icons.storefront_rounded,
                                  size: 16.sp, color: Colors.grey),
                              SizedBox(width: 6.w),
                              Text(
                                widget.storeName,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20.h),

                          // Price
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryColor.withValues(alpha: 0.08),
                                  AppTheme.primaryColor.withValues(alpha: 0.03),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'السعر',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${priceNum.toInt()} د.ع',
                                  style: TextStyle(
                                    fontSize: 22.sp,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Description
                          if (description.isNotEmpty) ...[
                            SizedBox(height: 28.h),
                            Text(
                              'وصف المنتج',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF1A1D26),
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16.r),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.grey.shade100,
                                ),
                              ),
                              child: Text(
                                description,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  height: 1.7,
                                ),
                              ),
                            ),
                          ],

                          // Quantity selector
                          SizedBox(height: 28.h),
                          Text(
                            'الكمية',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF1A1D26),
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildQtyButton(Icons.remove_rounded, () {
                                  if (_quantity > 1) setState(() => _quantity--);
                                }, isDark),
                                SizedBox(width: 24.w),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(scale: anim, child: child),
                                  child: Text(
                                    '$_quantity',
                                    key: ValueKey(_quantity),
                                    style: TextStyle(
                                      fontSize: 22.sp,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : const Color(0xFF1A1D26),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 24.w),
                                _buildQtyButton(Icons.add_rounded, () {
                                  setState(() => _quantity++);
                                }, isDark),
                              ],
                            ),
                          ),

                          // Total
                          SizedBox(height: 16.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'المجموع',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '${(priceNum * _quantity).toInt()} د.ع',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 120.h),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Bottom Add to Cart Bar ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 34.h),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D26) : Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Price summary
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'المجموع',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '${(priceNum * _quantity).toInt()} د.ع',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Add to cart button
                  SizedBox(width: 16.w),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () {
                        if (widget.onAddToCart != null) {
                          for (int i = 0; i < _quantity; i++) {
                            widget.onAddToCart!(widget.productData);
                          }
                          setState(() => _addedToCart = true);
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) setState(() => _addedToCart = false);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'تمت إضافة $_quantity × ${data['name']} للسلة',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: AppTheme.primaryColor,
                              behavior: SnackBarBehavior.fixed,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 56.h,
                        decoration: BoxDecoration(
                          gradient: _addedToCart
                              ? const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF43A047)])
                              : LinearGradient(colors: [
                                  AppTheme.primaryColor,
                                  AppTheme.primaryColor.withValues(alpha: 0.85),
                                ]),
                          borderRadius: BorderRadius.circular(18.r),
                          boxShadow: [
                            BoxShadow(
                              color: (_addedToCart ? Colors.green : AppTheme.primaryColor)
                                  .withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _addedToCart
                                  ? Icons.check_rounded
                                  : Icons.add_shopping_cart_rounded,
                              color: Colors.white,
                              size: 22.sp,
                            ),
                            SizedBox(width: 10.w),
                            Text(
                              _addedToCart ? 'تمت الإضافة' : 'أضف إلى السلة',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44.r,
        height: 44.r,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Icon(icon, color: AppTheme.primaryColor, size: 22.sp),
      ),
    );
  }
}
