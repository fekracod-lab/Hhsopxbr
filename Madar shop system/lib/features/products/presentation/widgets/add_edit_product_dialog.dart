import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/shop_product.dart';
import '../../domain/entities/shop_category.dart';
import '../../data/services/products_firestore_service.dart';

/// نافذة إضافة أو تعديل منتج المتجر مع ربط فوري بتطبيق مدار الرئيسي (Add/Edit Product Dialog)
class AddEditProductDialog extends StatefulWidget {
  final String storeId;
  final ShopProduct? product;
  final List<ShopCategory> categories;

  const AddEditProductDialog({
    super.key,
    required this.storeId,
    this.product,
    required this.categories,
  });

  @override
  State<AddEditProductDialog> createState() => _AddEditProductDialogState();
}

class _AddEditProductDialogState extends State<AddEditProductDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _minAlertCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _imageUrlCtrl;

  late String _selectedCategory;
  late bool _isAvailable;
  late bool _isFeatured; // ⭐ حقل التمييز الفوري في تطبيق مدار
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _priceCtrl = TextEditingController(text: p != null ? p.price.toStringAsFixed(0) : '');
    _costCtrl = TextEditingController(text: p != null && p.costPrice > 0 ? p.costPrice.toStringAsFixed(0) : '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _stockCtrl = TextEditingController(text: p?.stock.toString() ?? '100');
    _minAlertCtrl = TextEditingController(text: p?.minAlertLevel.toString() ?? '5');
    _unitCtrl = TextEditingController(text: p?.unit ?? 'قطعة');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _imageUrlCtrl = TextEditingController(text: p?.imageUrl ?? '');

    _selectedCategory = p?.category ?? (widget.categories.isNotEmpty ? widget.categories.first.name : 'عام');
    _isAvailable = p?.isAvailable ?? true;
    _isFeatured = p?.isFeatured ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _barcodeCtrl.dispose();
    _stockCtrl.dispose();
    _minAlertCtrl.dispose();
    _unitCtrl.dispose();
    _descCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  void _generateRandomBarcode() {
    final rand = Random();
    final code = '628${rand.nextInt(899999999) + 100000000}';
    setState(() => _barcodeCtrl.text = code);
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameCtrl.text.trim();
      final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
      final cost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;
      final barcode = _barcodeCtrl.text.trim();
      final stock = int.tryParse(_stockCtrl.text.trim()) ?? 100;
      final minAlert = int.tryParse(_minAlertCtrl.text.trim()) ?? 5;
      final unit = _unitCtrl.text.trim();
      final desc = _descCtrl.text.trim();
      final imageUrl = _imageUrlCtrl.text.trim();

      final updated = ShopProduct(
        id: widget.product?.id ?? '',
        name: name,
        price: price,
        costPrice: cost,
        description: desc,
        category: _selectedCategory,
        imageUrl: imageUrl,
        isAvailable: _isAvailable,
        isFeatured: _isFeatured, // ⭐ الحفظ في فايربيس يجعله مميزاً فوراً في التطبيق
        barcode: barcode,
        stock: stock,
        minAlertLevel: minAlert,
        unit: unit.isEmpty ? 'قطعة' : unit,
      );

      if (widget.product == null) {
        await ProductsFirestoreService.instance.addProduct(widget.storeId, updated);
      } else {
        await ProductsFirestoreService.instance.updateProduct(widget.storeId, updated);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFeatured
                  ? 'تم حفظ المنتج ونشره كمنتج مميز في تطبيق مدار ⭐'
                  : 'تم حفظ وتحديث المنتج بنجاح!',
            ),
            backgroundColor: _isFeatured ? ShopColors.goldDark : ShopColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الحفظ: $e'), backgroundColor: ShopColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.product != null;

    return Dialog(
      backgroundColor: isDark ? ShopColors.darkSurface : ShopColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(26),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ShopColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEditing ? Icons.edit_note_rounded : Icons.add_business_rounded,
                        color: ShopColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'تعديل بيانات المنتج' : 'إضافة منتج جديد لمتجر مدار',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            'سيظهر المنتج مباشرة في تطبيق مدار للزبائن ومستخدمي التطبيق',
                            style: GoogleFonts.cairo(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 26),

                // ── Row 1: Name & Category ──
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'اسم المنتج *',
                          hintText: 'مثال: حليب المراعي 1 لتر',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'يرجى إدخال اسم المنتج' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: widget.categories.any((c) => c.name == _selectedCategory)
                            ? _selectedCategory
                            : (widget.categories.isNotEmpty ? widget.categories.first.name : 'عام'),
                        decoration: InputDecoration(
                          labelText: 'القسم / التصنيف',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: [
                          if (widget.categories.isEmpty)
                            const DropdownMenuItem(value: 'عام', child: Text('عام')),
                          ...widget.categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedCategory = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Row 2: Price & Cost Price & Unit ──
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'سعر البيع للزبون (د.ع) *',
                          suffixText: 'د.ع',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'أدخل سعراً صالحاً';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _costCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'سعر التكلفة (د.ع)',
                          suffixText: 'د.ع',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _unitCtrl,
                        decoration: InputDecoration(
                          labelText: 'الوحدة (قطعة/كغم)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Row 3: Barcode ──
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _barcodeCtrl,
                        decoration: InputDecoration(
                          labelText: 'الباركود (Barcode / SKU)',
                          hintText: 'امسح بالماسح أو اكتب الكود',
                          prefixIcon: const Icon(Icons.qr_code_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _generateRandomBarcode,
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                      label: Text('توليد باركود', style: GoogleFonts.cairo(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Row 4: Stock & Min Alert ──
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'كمية المخزون المتوفرة',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _minAlertCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'حد تنبيه انخفاض المخزون',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Row 5: Image URL & Description ──
                TextFormField(
                  controller: _imageUrlCtrl,
                  decoration: InputDecoration(
                    labelText: 'رابط صورة المنتج (URL)',
                    hintText: 'https://...',
                    prefixIcon: const Icon(Icons.image_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'وصف المنتج وملاحظاته',
                    hintText: 'تفاصيل إضافية عن المنتج...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                // ── ⭐⭐⭐ ميزة التمييز الذهبي في تطبيق مدار الرئيسي ⭐⭐⭐ ──
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isFeatured
                        ? ShopColors.gold.withValues(alpha: 0.12)
                        : (isDark ? ShopColors.darkCard : ShopColors.lightBg),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isFeatured
                          ? ShopColors.gold
                          : (isDark ? ShopColors.darkBorder : ShopColors.lightBorder),
                      width: _isFeatured ? 1.5 : 1,
                    ),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isFeatured ? ShopColors.gold : Colors.grey.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        color: _isFeatured ? Colors.black87 : Colors.grey,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'عرض كمنتج مميز في تطبيق مدار الرئيسي ⭐',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _isFeatured ? ShopColors.goldDark : null,
                      ),
                    ),
                    subtitle: Text(
                      'عند تفعيل هذا الخيار، سيحصل المنتج على إطار ذهبي وشارة "مميز" في واجهة تطبيق مدار للمستخدمين لزيادة المبيعات والظهور!',
                      style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
                    ),
                    value: _isFeatured,
                    activeThumbColor: ShopColors.gold,
                    onChanged: (val) => setState(() => _isFeatured = val),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Save Button ──
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ShopColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                  label: Text(
                    _isSaving ? 'جاري الحفظ والمزامنة مع مدار...' : 'حفظ المنتج ونشره في مدار',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
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
