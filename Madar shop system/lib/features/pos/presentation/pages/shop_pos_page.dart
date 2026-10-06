import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../products/data/services/products_firestore_service.dart';
import '../../../products/domain/entities/shop_category.dart';
import '../../application/pos_controller.dart';
import '../widgets/shop_category_filter.dart';
import '../widgets/shop_product_grid.dart';
import '../widgets/shop_cart_sidebar.dart';

/// الشاشة الرئيسية لنقطة البيع والكاشير المباشر (Shop POS Main Screen)
class ShopPosPage extends StatefulWidget {
  final PosController controller;

  const ShopPosPage({super.key, required this.controller});

  @override
  State<ShopPosPage> createState() => _ShopPosPageState();
}

class _ShopPosPageState extends State<ShopPosPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _barcodeCtrl = TextEditingController();
  final FocusNode _barcodeFocus = FocusNode();

  List<ShopCategory> _categories = [];
  StreamSubscription<List<ShopCategory>>? _catsSub;

  @override
  void initState() {
    super.initState();
    _subscribeCategories();
  }

  void _subscribeCategories() {
    final store = widget.controller.activeStore;
    if (store != null) {
      _catsSub = ProductsFirestoreService.instance
          .watchCategories(store.storeId)
          .listen((cats) {
        if (mounted) setState(() => _categories = cats);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ShopPosPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.activeStore?.storeId != widget.controller.activeStore?.storeId) {
      _catsSub?.cancel();
      _subscribeCategories();
    }
  }

  @override
  void dispose() {
    _catsSub?.cancel();
    _searchCtrl.dispose();
    _barcodeCtrl.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  void _onBarcodeSubmitted(String barcode) {
    if (barcode.trim().isEmpty) return;
    final found = widget.controller.scanBarcode(barcode.trim());
    _barcodeCtrl.clear();
    _barcodeFocus.requestFocus();

    if (!found) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الباركود غير معرف: $barcode'),
          backgroundColor: ShopColors.danger,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final products = widget.controller.filteredProducts;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Row(
              children: [
                // ── 1. منطقة العمل والمنتجات (Products Area) ──
                Expanded(
                  child: Column(
                    children: [
                      // شريط البحث والباركود العلوي
                      _buildTopActionBar(isDark),

                      // تصنيفات المتجر
                      ShopCategoryFilter(
                        categories: _categories,
                        selectedCategory: widget.controller.selectedCategory,
                        onCategorySelected: (cat) => widget.controller.setCategory(cat),
                      ),

                      // شبكة المنتجات
                      Expanded(
                        child: ShopProductGrid(
                          products: products,
                          onProductSelected: (p) => widget.controller.addToCart(p),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 2. الشريط الجانبي لسلة المبيعات (Cart Sidebar) ──
                ShopCartSidebar(
                  controller: widget.controller,
                  onClear: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('مسح السلة بالكامل؟', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                        content: Text('هل ترغب حقاً في إفراغ جميع المواد المضافة إلى السلة؟', style: GoogleFonts.cairo()),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo())),
                          ElevatedButton(
                            onPressed: () {
                              widget.controller.clearCart();
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: ShopColors.danger),
                            child: Text('مسح السلة', style: GoogleFonts.cairo(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopActionBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? ShopColors.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? ShopColors.darkBorder : ShopColors.lightBorder),
        ),
      ),
      child: Row(
        children: [
          // ── حقل البحث السريع بالاسم ──
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'ابحث عن اسم المنتج، الوصف، أو السعر...',
                hintStyle: GoogleFonts.cairo(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.search_rounded, color: ShopColors.primary, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          widget.controller.setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                filled: true,
                fillColor: isDark ? ShopColors.darkCard : ShopColors.lightBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (q) => widget.controller.setSearchQuery(q),
            ),
          ),
          const SizedBox(width: 12),

          // ── حقل الباركود المباشر وقارئ الليزر ──
          Expanded(
            flex: 2,
            child: TextField(
              controller: _barcodeCtrl,
              focusNode: _barcodeFocus,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              onSubmitted: _onBarcodeSubmitted,
              decoration: InputDecoration(
                hintText: 'قارئ الباركود (Scan)...',
                hintStyle: GoogleFonts.cairo(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.qr_code_scanner_rounded, color: ShopColors.gold, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                filled: true,
                fillColor: isDark ? ShopColors.darkCard : ShopColors.lightBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: ShopColors.gold.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
