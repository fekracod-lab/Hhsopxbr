import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/store_profile.dart';
import '../../domain/entities/shop_product.dart';
import '../../domain/entities/shop_category.dart';
import '../../data/services/products_firestore_service.dart';
import '../widgets/add_edit_product_dialog.dart';
import '../widgets/category_manager_dialog.dart';

/// صفحة إدارة المنتجات والمخزون والربط الفوري بتطبيق مدار (Products & Stock Management Page)
class ShopProductsPage extends StatefulWidget {
  final StoreProfile store;

  const ShopProductsPage({super.key, required this.store});

  @override
  State<ShopProductsPage> createState() => _ShopProductsPageState();
}

class _ShopProductsPageState extends State<ShopProductsPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  List<ShopProduct> _products = [];
  List<ShopCategory> _categories = [];
  String _selectedCategory = 'الكل';
  bool _onlyLowStock = false;
  bool _onlyFeatured = false;

  StreamSubscription<List<ShopProduct>>? _prodsSub;
  StreamSubscription<List<ShopCategory>>? _catsSub;

  @override
  void initState() {
    super.initState();
    _subscribeData();
  }

  void _subscribeData() {
    _prodsSub = ProductsFirestoreService.instance
        .watchProducts(widget.store.storeId)
        .listen((list) {
      if (mounted) setState(() => _products = list);
    });

    _catsSub = ProductsFirestoreService.instance
        .watchCategories(widget.store.storeId)
        .listen((list) {
      if (mounted) setState(() => _categories = list);
    });
  }

  @override
  void dispose() {
    _prodsSub?.cancel();
    _catsSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ShopProduct> get _filteredProducts {
    var list = _products;

    if (_selectedCategory != 'الكل') {
      list = list.where((p) => p.category == _selectedCategory).toList();
    }
    if (_onlyLowStock) {
      list = list.where((p) => p.isLowStock).toList();
    }
    if (_onlyFeatured) {
      list = list.where((p) => p.isFeatured).toList();
    }
    if (_searchCtrl.text.trim().isNotEmpty) {
      final q = _searchCtrl.text.trim().toLowerCase();
      list = list.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.barcode.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  void _openAddEditDialog([ShopProduct? product]) {
    showDialog(
      context: context,
      builder: (_) => AddEditProductDialog(
        storeId: widget.store.storeId,
        product: product,
        categories: _categories,
      ),
    );
  }

  void _openCategoryManager() {
    showDialog(
      context: context,
      builder: (_) => CategoryManagerDialog(
        storeId: widget.store.storeId,
        categories: _categories,
      ),
    );
  }

  Future<void> _handleDelete(ShopProduct product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف المنتج نهائياً؟', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text('هل ترغب في حذف "${product.name}" من متجرك وتطبيق مدار؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ShopColors.danger),
            child: Text('حذف المنتج', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ProductsFirestoreService.instance.deleteProduct(widget.store.storeId, product.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredProducts;
    final totalProducts = _products.length;
    final lowStockCount = _products.where((p) => p.isLowStock).length;
    final featuredCount = _products.where((p) => p.isFeatured).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Column(
          children: [
            // ── Top Stats Bar ──
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? ShopColors.darkSurface : Colors.white,
                border: Border(bottom: BorderSide(color: isDark ? ShopColors.darkBorder : ShopColors.lightBorder)),
              ),
              child: Row(
                children: [
                  _buildStatCard('إجمالي المنتجات', '$totalProducts', Icons.inventory_2_rounded, ShopColors.primary, isDark),
                  const SizedBox(width: 14),
                  _buildStatCard('منتجات مميزة في مدار', '$featuredCount', Icons.star_rounded, ShopColors.gold, isDark),
                  const SizedBox(width: 14),
                  _buildStatCard('تنبيه نقص المخزون', '$lowStockCount', Icons.warning_rounded, ShopColors.danger, isDark),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _openCategoryManager,
                    icon: const Icon(Icons.category_rounded, size: 18),
                    label: Text('إدارة الأقسام', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _openAddEditDialog(),
                    icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                    label: Text('إضافة منتج جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ShopColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),

            // ── Filters Bar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              color: isDark ? ShopColors.darkCard : ShopColors.lightBg,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'بحث باسم المنتج أو الباركود...',
                        hintStyle: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        filled: true,
                        fillColor: isDark ? ShopColors.darkSurface : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _selectedCategory,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem(value: 'الكل', child: Text('جميع الأقسام')),
                      ..._categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedCategory = v);
                    },
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: Text('المميز فقط ⭐', style: GoogleFonts.cairo(fontSize: 12)),
                    selected: _onlyFeatured,
                    onSelected: (val) => setState(() => _onlyFeatured = val),
                    selectedColor: ShopColors.gold.withValues(alpha: 0.25),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('ناقص المخزون فقط', style: GoogleFonts.cairo(fontSize: 12)),
                    selected: _onlyLowStock,
                    onSelected: (val) => setState(() => _onlyLowStock = val),
                    selectedColor: ShopColors.danger.withValues(alpha: 0.25),
                  ),
                ],
              ),
            ),

            // ── Products Table / List ──
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_rounded, size: 54, color: Colors.grey.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text('لا توجد منتجات مطابقة حالياً', style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) => _buildProductRow(context, filtered[idx], isDark),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? ShopColors.darkCard : ShopColors.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(count, style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
              Text(title, style: GoogleFonts.cairo(fontSize: 11, color: isDark ? Colors.white70 : Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(BuildContext context, ShopProduct product, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? ShopColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: product.isFeatured
              ? ShopColors.gold.withValues(alpha: 0.5)
              : (isDark ? ShopColors.darkBorder : ShopColors.lightBorder),
          width: product.isFeatured ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Image / Icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isDark ? ShopColors.darkCard : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: product.imageUrl.isNotEmpty
                  ? Image.network(product.imageUrl, fit: BoxFit.cover, errorBuilder: (_, _a, _b) => const Icon(Icons.inventory_2_rounded, size: 22))
                  : const Icon(Icons.inventory_2_rounded, size: 22),
            ),
          ),
          const SizedBox(width: 14),

          // Name & Barcode
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(product.name, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                    if (product.isFeatured) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: ShopColors.gold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'مميز في مدار ⭐',
                          style: GoogleFonts.cairo(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'الباركود: ${product.barcode.isEmpty ? 'بدون' : product.barcode} • القسم: ${product.category}',
                  style: GoogleFonts.cairo(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),

          // Price & Cost
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${product.price.toStringAsFixed(0)} د.ع',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: ShopColors.primary),
                ),
                if (product.costPrice > 0)
                  Text(
                    'التكلفة: ${product.costPrice.toStringAsFixed(0)} د.ع',
                    style: GoogleFonts.cairo(color: Colors.grey, fontSize: 11),
                  ),
              ],
            ),
          ),

          // Stock Badge
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (product.isLowStock ? ShopColors.danger : ShopColors.success).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'المخزون: ${product.stock} ${product.unit}',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: product.isLowStock ? ShopColors.danger : ShopColors.success,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Action Buttons
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: ShopColors.primary, size: 20),
            tooltip: 'تعديل بيانات المنتج',
            onPressed: () => _openAddEditDialog(product),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: ShopColors.danger, size: 20),
            tooltip: 'حذف المنتج',
            onPressed: () => _handleDelete(product),
          ),
        ],
      ),
    );
  }
}
