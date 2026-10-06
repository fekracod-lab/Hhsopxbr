import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/shop_category.dart';
import '../../data/services/products_firestore_service.dart';

/// نافذة إدارة أقسام وتصنيفات المتجر (Category Manager Dialog)
class CategoryManagerDialog extends StatefulWidget {
  final String storeId;
  final List<ShopCategory> categories;

  const CategoryManagerDialog({
    super.key,
    required this.storeId,
    required this.categories,
  });

  @override
  State<CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<CategoryManagerDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  bool _isAdding = false;

  Future<void> _handleAddCategory() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      await ProductsFirestoreService.instance.addCategory(widget.storeId, name);
      _nameCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إضافة القسم بنجاح!'), backgroundColor: ShopColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء إضافة القسم: $e'), backgroundColor: ShopColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _handleDeleteCategory(ShopCategory cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف القسم؟', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد من حذف قسم "${cat.name}"؟', style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ShopColors.danger),
            child: Text('حذف', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ProductsFirestoreService.instance.deleteCategory(widget.storeId, cat.id);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? ShopColors.darkSurface : ShopColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.category_rounded, color: ShopColors.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'إدارة أقسام وتصنيفات المتجر',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),

            // إضافة تصنيف جديد
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'اسم القسم الجديد',
                      hintText: 'مثال: ألبان وأجبان، منظفات...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (_) => _handleAddCategory(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _isAdding ? null : _handleAddCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ShopColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('إضافة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 18),

            Text('الأقسام المسجلة في المتجر:', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: widget.categories.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('لا توجد أقسام مسجلة حتى الآن', style: GoogleFonts.cairo(color: Colors.grey)),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: widget.categories.length,
                      separatorBuilder: (_, _i) => const SizedBox(height: 6),
                      itemBuilder: (ctx, i) {
                        final cat = widget.categories[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? ShopColors.darkCard : ShopColors.lightBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? ShopColors.darkBorder : ShopColors.lightBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.folder_outlined, size: 18, color: ShopColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(cat.name, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: ShopColors.danger, size: 18),
                                onPressed: () => _handleDeleteCategory(cat),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
