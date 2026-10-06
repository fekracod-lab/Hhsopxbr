import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import 'package:dalal_alqaim/pages/my_orders_page.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/store_dashboard_page.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/product_detail_page.dart';
import '../../domain/entities/store_dashboard_models.dart';
import '../../domain/entities/store_cart_item_entity.dart';
import '../../application/store_details_controller.dart';
import '../widgets/store_details_header.dart';
import '../widgets/store_promo_banner.dart';
import '../widgets/store_circle_categories.dart';
import '../widgets/store_product_grid_card.dart';
import '../widgets/store_cart_bottom_sheet.dart';
import '../widgets/store_checkout_details_sheet.dart';
import '../widgets/store_order_success_dialog.dart';
import '../widgets/store_customer_settings_sheet.dart';

/// صفحة تفاصيل المتجر والمنتجات والتسوق (Store Details Page Coordinator)
class StoreDetailsPage extends StatefulWidget {
  final String storeId;
  final Map<String, dynamic> storeData;
  final StoreDetailsController? controller;

  const StoreDetailsPage({
    super.key,
    required this.storeId,
    required this.storeData,
    this.controller,
  });

  @override
  State<StoreDetailsPage> createState() => _StoreDetailsPageState();
}

class _StoreDetailsPageState extends State<StoreDetailsPage> {
  late final StoreDetailsController _controller;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLocalController = false;

  final List<IconData> _categoryIconOptions = [
    Icons.face_retouching_natural_rounded, Icons.content_cut_rounded, Icons.spa_rounded,
    Icons.auto_awesome_rounded, Icons.brush_rounded, Icons.palette_rounded,
    Icons.soup_kitchen_rounded, Icons.home_rounded, Icons.kitchen_rounded,
    Icons.deck_rounded, Icons.nightlight_rounded, Icons.weekend_rounded,
    Icons.eco_rounded, Icons.agriculture_rounded, Icons.local_grocery_store_rounded,
    Icons.local_shipping_rounded, Icons.shopping_cart_rounded, Icons.storefront_rounded,
    Icons.shopping_bag_rounded, Icons.local_offer_rounded, Icons.loyalty_rounded,
    Icons.card_giftcard_rounded, Icons.watch_rounded, Icons.checkroom_rounded,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      if (!_controller.isInitialized) {
        _controller.initialize();
      }
    } else {
      _isLocalController = true;
      _controller = StoreDetailsController(
        storeId: widget.storeId,
        initialStoreData: widget.storeData,
      );
      _controller.initialize();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    if (_isLocalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final storeName = _controller.storeName;
        final hasAdminAccess = _controller.hasAdminAccess;
        final cartCount = _controller.cartCount;
        final cartSubtotal = _controller.cartSubtotal;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: isDark ? const Color(0xFF13151B) : const Color(0xFFF9F9FC),
            body: RefreshIndicator(
              onRefresh: () async {
                await _controller.refresh();
              },
              color: AppTheme.primaryColor,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // 1. App Bar & Header
                  StoreDetailsHeader(
                    storeName: storeName,
                    searchController: _searchController,
                    onBack: () => Navigator.of(context).pop(),
                    onSearchChanged: (query) => _controller.setSearchQuery(query),
                  ),

                  // 2. Promotional Banners
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      child: StorePromoBanner(
                        banners: _controller.banners,
                        storeName: storeName,
                        onBannerTap: (banner) {},
                      ),
                    ),
                  ),

                  // 3. Category Circle Picker
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: StoreCircleCategories(
                        categories: _controller.categories,
                        selectedCategory: _controller.selectedCategory,
                        isAdmin: hasAdminAccess,
                        onCategorySelected: (cat) => _controller.setSelectedCategory(cat),
                        onCategoryLongPress: hasAdminAccess
                            ? (cat) => _showCategoryOptionsSheet(cat)
                            : null,
                        onAddCategoryTap: hasAdminAccess ? _showAddCategoryDialog : null,
                      ),
                    ),
                  ),

                  // 4. Products Section Title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _controller.selectedCategory == 'الكل'
                                  ? 'جميع المنتجات (${_controller.filteredProducts.length})'
                                  : '${_controller.selectedCategory} (${_controller.filteredProducts.length})',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              if (hasAdminAccess) ...[
                                IconButton(
                                  tooltip: 'لوحة التحكم',
                                  icon: Icon(Icons.dashboard_rounded, color: AppTheme.primaryColor),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => StoreDashboardPage(
                                          storeId: widget.storeId,
                                          storeData: widget.storeData,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  tooltip: 'إضافة إعلان',
                                  icon: Icon(Icons.add_photo_alternate_rounded, color: AppTheme.primaryColor),
                                  onPressed: _showAddBannerDialog,
                                ),
                                IconButton(
                                  tooltip: 'إضافة منتج',
                                  icon: const Icon(Icons.add_circle_rounded, color: Colors.green),
                                  onPressed: _showAddProductDialog,
                                ),
                              ],
                              IconButton(
                                tooltip: 'الإعدادات',
                                icon: const Icon(Icons.settings_outlined),
                                onPressed: _showCustomerSettings,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 5. Products Grid
                  if (_controller.isLoading && _controller.filteredProducts.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60.h),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    )
                  else if (_controller.filteredProducts.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60.h),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64.sp,
                                color: Colors.grey.withValues(alpha: 0.3),
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                'ماكو منتجات حالياً متوفرة حالياً',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 12.w,
                          mainAxisSpacing: 12.h,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = _controller.filteredProducts[index];
                            return StoreProductGridCard(
                              product: product,
                              isAdmin: hasAdminAccess,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProductDetailPage(
                                      productId: product.productId,
                                      productData: {
                                        'name': product.name,
                                        'price': product.price,
                                        'imageUrl': product.imageUrl,
                                        'category': product.category,
                                        'description': product.description,
                                      },
                                      storeId: widget.storeId,
                                      storeName: storeName,
                                      onAddToCart: (p) => _controller.addToCart(
                                        StoreCartItemEntity(
                                          productId: product.productId,
                                          name: product.name,
                                          price: product.price,
                                          quantity: 1,
                                          imageUrl: product.imageUrl,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              onAddToCart: () {
                                _controller.addToCart(
                                  StoreCartItemEntity(
                                    productId: product.productId,
                                    name: product.name,
                                    price: product.price,
                                    quantity: 1,
                                    imageUrl: product.imageUrl,
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('تمت إضافة ${product.name} إلى السلة',
                                        style: const TextStyle()),
                                    duration: const Duration(seconds: 1),
                                    backgroundColor: Colors.black87,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              onDelete: hasAdminAccess
                                  ? () => _confirmDeleteProduct(product)
                                  : null,
                            );
                          },
                          childCount: _controller.filteredProducts.length,
                        ),
                      ),
                    ),

                  SliverToBoxAdapter(
                    child: SizedBox(height: 100.h),
                  ),
                ],
              ),
            ),

            // Floating Quick Cart Bar
            bottomNavigationBar: cartCount > 0
                ? Container(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E222D) : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: _showCartBottomSheet,
                          borderRadius: BorderRadius.circular(16.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Row(
                              children: [
                                Badge(
                                  label: Text('$cartCount'),
                                  child: Icon(
                                    Icons.shopping_bag_outlined,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Text(
                                  '${cartSubtotal.toInt()} د.ع',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: SizedBox(
                            height: 52.h,
                            child: ElevatedButton(
                              onPressed: _showCartBottomSheet,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'عرض السلة ($cartCount)',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  // ── Modals & Dialogs ──

  void _showCustomerSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StoreCustomerSettingsSheet(
        onMyOrdersTap: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MyOrdersPage()),
          );
        },
        onChangePhoneTap: () {
          Navigator.pop(ctx);
          Navigator.pushNamed(context, '/phone_auth');
        },
      ),
    );
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => StoreCartBottomSheet(
          items: _controller.cartItems,
          subtotal: _controller.cartSubtotal,
          onRemoveItem: (id) => _controller.removeFromCart(id),
          onCheckoutTap: () {
            Navigator.pop(ctx);
            _showCheckoutBottomSheet();
          },
        ),
      ),
    );
  }

  void _showCheckoutBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StoreCheckoutDetailsSheet(
        initialName: _controller.userName,
        initialPhone: _controller.userPhone,
        initialAddress: _controller.userAddress,
        subtotal: _controller.cartSubtotal,
        deliveryFee: _controller.deliveryFee,
        userPoints: _controller.userPoints,
        userBalance: _controller.userBalance,
        onConfirmOrder: ({
          required String name,
          required String phone,
          required String address,
          required String notes,
          required bool usePoints,
          required bool useWallet,
        }) async {
          Navigator.pop(ctx);
          await _executeCheckout(
            customerName: name,
            customerPhone: phone,
            customerAddress: address,
            notes: notes,
            usePoints: usePoints,
            useWallet: useWallet,
          );
        },
      ),
    );
  }

  Future<void> _executeCheckout({
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String notes,
    required bool usePoints,
    required bool useWallet,
  }) async {
    // Show Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryColor),
              SizedBox(height: 16.h),
              const Text(
                'جاري تأكيد الطلب وحفظ البيانات...',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );

    final result = await _controller.placeOrder(
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      notes: notes,
      usePoints: usePoints,
      useWallet: useWallet,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

    if (result.success) {
      _showOrderSuccessDialog(result.orderId ?? '');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.errorMessage ?? 'حدث خطأ أثناء تنفيذ الطلب',
            style: const TextStyle(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showOrderSuccessDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StoreOrderSuccessDialog(
        orderId: orderId,
        storeName: _controller.storeName,
        onWhatsAppTap: () {
          final phone = _controller.storePhone;
          if (phone.isNotEmpty) {
            final formatted = phone.startsWith('0') ? '964${phone.substring(1)}' : phone;
            final url = 'whatsapp://send?phone=$formatted&text=${Uri.encodeComponent('مرحباً، أود متابعة طلبي رقم: #$orderId')}';
            launchUrl(Uri.parse(url));
          }
        },
        onMyOrdersTap: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MyOrdersPage()),
          );
        },
        onBackToStoreTap: () {
          Navigator.pop(ctx);
        },
      ),
    );
  }

  // ── Admin Operations (Products, Categories, Banners) ──

  void _showAddProductDialog([StoreProductEntity? editingProduct]) {
    final nameCtrl = TextEditingController(text: editingProduct?.name ?? '');
    final priceCtrl = TextEditingController(
        text: editingProduct != null ? editingProduct.price.toInt().toString() : '');
    String selectedCat = editingProduct?.category ??
        (_controller.categories.isNotEmpty ? _controller.categories.first.name : 'الكل');
    String imageUrl = editingProduct?.imageUrl ?? '';
    File? localImage;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
          title: Text(
            editingProduct != null ? 'تعديل المنتج' : 'إضافة منتج جديد',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery);
                    if (picked != null) {
                      setDialogState(() {
                        localImage = File(picked.path);
                      });
                    }
                  },
                  child: Container(
                    height: 120.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: localImage != null
                        ? Image.file(localImage!, fit: BoxFit.cover)
                        : (imageUrl.isNotEmpty
                            ? Image.network(imageUrl, fit: BoxFit.cover)
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 32.sp, color: Colors.grey),
                                  SizedBox(height: 4.h),
                                  const Text('صورة المنتج', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              )),
                  ),
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'اسم المنتج',
                    labelStyle: const TextStyle(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'السعر (د.ع)',
                    labelStyle: const TextStyle(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
                SizedBox(height: 12.h),
                DropdownButtonFormField<String>(
                  initialValue: _controller.categories.any((c) => c.name == selectedCat)
                      ? selectedCat
                      : (_controller.categories.isNotEmpty ? _controller.categories.first.name : null),
                  decoration: InputDecoration(
                    labelText: 'القسم',
                    labelStyle: const TextStyle(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  items: _controller.categories
                      .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name, style: const TextStyle())))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedCat = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle()),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) return;
                      setDialogState(() => isUploading = true);

                      String finalImageUrl = imageUrl;
                      if (localImage != null) {
                        final uploaded = await _controller.uploadImage(localImage!.path);
                        if (uploaded != null) finalImageUrl = uploaded;
                      }

                      final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                      if (editingProduct != null) {
                        await _controller.updateProduct(
                          productId: editingProduct.productId,
                          name: nameCtrl.text.trim(),
                          price: price,
                          category: selectedCat,
                          imageUrl: finalImageUrl,
                        );
                      } else {
                        await _controller.createProductDirect(
                          name: nameCtrl.text.trim(),
                          price: price,
                          category: selectedCat,
                          imageUrl: finalImageUrl,
                        );
                      }

                      if (context.mounted) Navigator.pop(ctx);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: isUploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(editingProduct != null ? 'حفظ' : 'إضافة', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteProduct(StoreProductEntity product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Text('حذف المنتج', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('متأكد تريد تحذف "${product.name}"؟', style: const TextStyle()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _controller.deleteProduct(product.productId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog([StoreCategoryEntity? editingCat]) {
    final nameCtrl = TextEditingController(text: editingCat?.name ?? '');
    int selectedIconCode = editingCat?.iconCode ?? Icons.shopping_basket_rounded.codePoint;
    int selectedColor = editingCat?.colorValue ?? 0xFFE3F2FD;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
          title: Text(
            editingCat != null ? 'تعديل القسم' : 'إضافة قسم جديد',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'اسم القسم',
                    labelStyle: const TextStyle(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
                SizedBox(height: 16.h),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('اختر أيقونة القسم:', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: _categoryIconOptions.map((icon) {
                    final isSelected = icon.codePoint == selectedIconCode;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedIconCode = icon.codePoint),
                      borderRadius: BorderRadius.circular(12.r),
                      child: Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? Colors.white : Colors.black87,
                          size: 20.sp,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                if (editingCat != null) {
                  await _controller.updateCategory(
                    categoryId: editingCat.categoryId,
                    name: nameCtrl.text.trim(),
                    iconCode: selectedIconCode,
                    colorValue: selectedColor,
                  );
                } else {
                  await _controller.createCategory(
                    nameCtrl.text.trim(),
                    iconCode: selectedIconCode,
                    colorValue: selectedColor,
                  );
                }
                if (context.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: Text(editingCat != null ? 'حفظ' : 'إضافة', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryOptionsSheet(StoreCategoryEntity cat) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('تعديل القسم', style: TextStyle()),
              onTap: () {
                Navigator.pop(ctx);
                _showAddCategoryDialog(cat);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('حذف القسم', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                await _controller.deleteCategory(cat.categoryId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBannerDialog() {
    File? bannerImage;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
          title: const Text('إضافة إعلان ترويجي', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    setDialogState(() => bannerImage = File(picked.path));
                  }
                },
                child: Container(
                  height: 140.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: bannerImage != null
                      ? Image.file(bannerImage!, fit: BoxFit.cover)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 40.sp, color: Colors.grey),
                            SizedBox(height: 8.h),
                            const Text('اضغط لاختيار صورة الإعلان', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle()),
            ),
            ElevatedButton(
              onPressed: (bannerImage == null || isUploading)
                  ? null
                  : () async {
                      setDialogState(() => isUploading = true);
                      final url = await _controller.uploadImage(bannerImage!.path);
                      if (url != null) {
                        await _controller.addBanner(url);
                      }
                      if (context.mounted) Navigator.pop(ctx);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: isUploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('نشر الإعلان', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
