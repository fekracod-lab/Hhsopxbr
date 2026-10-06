import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_icon_helper.dart';

/// نافذة إدارة أقسام الوجبات وتحديد الأيقونات الخاصة بها
class CategoryManagerDialog extends StatefulWidget {
  final VoidCallback? onCategoriesUpdated;

  const CategoryManagerDialog({super.key, this.onCategoriesUpdated});

  static Future<void> show(BuildContext context, {VoidCallback? onUpdated}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CategoryManagerDialog(onCategoriesUpdated: onUpdated),
    );
  }

  @override
  State<CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<CategoryManagerDialog> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _effectiveRestaurantId = '';
  final TextEditingController _categoryNameController = TextEditingController();

  String get _activeId => _effectiveRestaurantId.isNotEmpty ? _effectiveRestaurantId : _uid;

  List<String> _categories = [];
  bool _isLoading = true;
  CategoryIconItem _selectedIconItem = CategoryIconHelper.availableIcons[2]; // Default burger

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      if (_uid.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final rId = (userDoc.data()!['restaurantId'] ?? userDoc.data()!['merchantId'] ?? userDoc.data()!['storeId'] ?? userDoc.data()!['branchId'])?.toString().trim() ?? '';
          if (rId.isNotEmpty) {
            _effectiveRestaurantId = rId;
          }
        }
      }

      final activeId = _activeId;
      final doc = await FirebaseFirestore.instance.collection('restaurants').doc(activeId).get();
      List<String> loaded = [];
      if (doc.exists && doc.data()?['categories'] != null) {
        loaded = List<String>.from(doc.data()!['categories']);
      }

      // فحص تصنيفات merchant_categories
      try {
        final mc = await FirebaseFirestore.instance.collection('merchant_categories').doc(activeId).collection('categories').get();
        for (var d in mc.docs) {
          final name = (d.data()['name'] ?? '').toString().trim();
          if (name.isNotEmpty && !loaded.contains(name)) {
            loaded.add(name);
          }
        }
      } catch (_) {}

      // أيضاً نفحص الأصناف المسجلة في المنتجات لإضافة أي تصنيفات موجودة مسبقاً
      try {
        final prods = await FirebaseFirestore.instance
            .collection('merchant_products')
            .doc(activeId)
            .collection('products')
            .get();

        for (var d in prods.docs) {
          final cat = (d.data()['category'] ?? '').toString().trim();
          if (cat.isNotEmpty && !loaded.contains(cat)) {
            loaded.add(cat);
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _categories = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addCategory() async {
    final name = _categoryNameController.text.trim();
    if (name.isEmpty) return;

    if (_categories.contains(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا القسم موجود بالفعل!'), backgroundColor: Colors.amber),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final updated = List<String>.from(_categories)..add(name);

    setState(() {
      _categories = updated;
      _categoryNameController.clear();
    });

    try {
      final activeId = _activeId;
      // حفظ في وثيقة المطعم
      await FirebaseFirestore.instance.collection('restaurants').doc(activeId).set({
        'categories': updated,
      }, SetOptions(merge: true));

      final catPayload = {
        'name': name,
        'iconKey': _selectedIconItem.key,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // حفظ في مجموعة merchant_products ومجموعة merchant_categories
      await FirebaseFirestore.instance
          .collection('merchant_products')
          .doc(activeId)
          .collection('categories')
          .doc(name)
          .set(catPayload);

      try {
        await FirebaseFirestore.instance
            .collection('merchant_categories')
            .doc(activeId)
            .collection('categories')
            .doc(name)
            .set(catPayload);
      } catch (_) {}

      widget.onCategoriesUpdated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تمت إضافة قسم "$name" بنجاح ✅'),
            backgroundColor: PosTheme.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding category: $e');
    }
  }

  Future<void> _deleteCategory(String cat) async {
    HapticFeedback.lightImpact();
    final updated = List<String>.from(_categories)..remove(cat);

    setState(() {
      _categories = updated;
    });

    try {
      final activeId = _activeId;
      await FirebaseFirestore.instance.collection('restaurants').doc(activeId).set({
        'categories': updated,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('merchant_products')
          .doc(activeId)
          .collection('categories')
          .doc(cat)
          .delete()
          .catchError((_) {});

      try {
        await FirebaseFirestore.instance
            .collection('merchant_categories')
            .doc(activeId)
            .collection('categories')
            .doc(cat)
            .delete();
      } catch (_) {}

      widget.onCategoriesUpdated?.call();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: PosTheme.surfaceDark,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: PosTheme.borderDark, width: 1.2),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width.clamp(320.0, 600.0),
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // الرأس
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PosTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.category_rounded, color: PosTheme.accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إدارة أقسام الوجبات والأيقونات',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: PosTheme.textLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'إضافة وتخصيص أقسام المنيو مع أيقوناتها المميزة',
                        style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textMuted, fontSize: 11.5),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: PosTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: PosTheme.borderDark, height: 1),
              const SizedBox(height: 16),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: PosTheme.primary))
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // حقل اسم القسم الجديد
                            Text(
                              'إضافة قسم جديد:',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: PosTheme.textLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _categoryNameController,
                                    style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textLight, fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: 'اكتب اسم القسم (مثال: شاورما، برجر، فطور...)...',
                                      hintStyle: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textDisabled, fontSize: 12),
                                      filled: true,
                                      fillColor: PosTheme.cardDark,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: PosTheme.borderDark),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: PosTheme.borderDark),
                                      ),
                                    ),
                                    onSubmitted: (_) => _addCategory(),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: _addCategory,
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: Text(
                                    'إضافة',
                                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12.5),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: PosTheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // اختيار أيقونة للقسم الجديد
                            Text(
                              'اختر أيقونة القسم:',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: PosTheme.textLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 100,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: PosTheme.cardDark,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: PosTheme.borderDark),
                              ),
                              child: GridView.builder(
                                scrollDirection: Axis.horizontal,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 0.8,
                                ),
                                itemCount: CategoryIconHelper.availableIcons.length - 1, // Skip 'all'
                                itemBuilder: (context, i) {
                                  final item = CategoryIconHelper.availableIcons[i + 1];
                                  final isSelected = _selectedIconItem.key == item.key;

                                  return InkWell(
                                    onTap: () {
                                      setState(() => _selectedIconItem = item);
                                      if (_categoryNameController.text.trim().isEmpty) {
                                        _categoryNameController.text = item.title;
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isSelected ? PosTheme.primary.withValues(alpha: 0.25) : PosTheme.bgDark,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected ? PosTheme.primary : PosTheme.borderDark,
                                          width: isSelected ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(item.icon, color: item.color, size: 17),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              item.title,
                                              style: GoogleFonts.ibmPlexSansArabic(
                                                color: isSelected ? PosTheme.textLight : PosTheme.textMuted,
                                                fontSize: 10.5,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),

                            // الأقسام الحالية
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'الأقسام الحالية في مطعمك (${_categories.length}):',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    color: PosTheme.textLight,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'انقر على علامة (✕) لحذف القسم',
                                  style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textDisabled, fontSize: 10.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            if (_categories.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Text(
                                    'لا توجد أقسام مسجلة حالياً، أضف قسماً جديداً أعلاه',
                                    style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textMuted, fontSize: 12),
                                  ),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _categories.map((cat) {
                                final icon = CategoryIconHelper.getIconForCategory(cat);
                                final color = CategoryIconHelper.getColorForCategory(cat);

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: PosTheme.cardDark,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: PosTheme.borderDark),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(icon, color: color, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        cat,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          color: PosTheme.textLight,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _deleteCategory(cat),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Padding(
                                          padding: const EdgeInsets.all(2),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 14,
                                            color: Colors.red.withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
              ),

              const SizedBox(height: 16),
              const Divider(color: PosTheme.borderDark, height: 1),
              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PosTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'تم وحفظ',
                    style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
