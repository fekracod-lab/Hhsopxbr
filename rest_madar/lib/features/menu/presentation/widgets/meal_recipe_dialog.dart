import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/pos_constants.dart';
import '../../../../core/theme/app_theme.dart';

/// بطاقة/نافذة ربط وصفة الوجبة بمكونات المخزون لحساب التكلفة والخصم التلقائي
class MealRecipeDialog extends StatefulWidget {
  final String restaurantId;
  final String mealId;
  final String mealName;
  final double mealPrice;

  const MealRecipeDialog({
    super.key,
    required this.restaurantId,
    required this.mealId,
    required this.mealName,
    required this.mealPrice,
  });

  static Future<void> show(
    BuildContext context, {
    required String restaurantId,
    required String mealId,
    required String mealName,
    required double mealPrice,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MealRecipeDialog(
        restaurantId: restaurantId,
        mealId: mealId,
        mealName: mealName,
        mealPrice: mealPrice,
      ),
    );
  }

  @override
  State<MealRecipeDialog> createState() => _MealRecipeDialogState();
}

class _MealRecipeDialogState extends State<MealRecipeDialog> {
  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _inventoryItems = [];
  final List<_RecipeIngredient> _ingredients = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. جلب مواد المخزون المتاحة
      final invSnap = await FirebaseFirestore.instance
          .collection('merchant_inventory')
          .doc(widget.restaurantId)
          .collection('items')
          .get();

      _inventoryItems = invSnap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name': (data['name'] ?? 'مادة').toString(),
          'unit': (data['unit'] ?? 'كغم').toString(),
          'costPerUnit': (data['costPerUnit'] ?? 0.0).toDouble(),
          'currentQuantity': (data['currentQuantity'] ?? 0.0).toDouble(),
        };
      }).toList();

      // 2. جلب الوصفة الحالية إن وجدت
      final recipeDoc = await FirebaseFirestore.instance
          .collection('merchant_recipes')
          .doc(widget.restaurantId)
          .collection('recipes')
          .doc(widget.mealId)
          .get();

      List<dynamic> rawIngredients = [];
      if (recipeDoc.exists) {
        rawIngredients = (recipeDoc.data()?['ingredients'] as List<dynamic>?) ?? [];
      } else {
        // فحص الوجبة مباشرة في merchant_products
        final prodDoc = await FirebaseFirestore.instance
            .collection('merchant_products')
            .doc(widget.restaurantId)
            .collection('products')
            .doc(widget.mealId)
            .get();
        if (prodDoc.exists) {
          rawIngredients = (prodDoc.data()?['linkedIngredients'] as List<dynamic>?) ?? [];
        }
      }

      _ingredients.clear();
      for (final raw in rawIngredients) {
        if (raw is Map) {
          final itemId = (raw['inventoryItemId'] ?? '').toString();
          final invMatch = _inventoryItems.firstWhere(
            (i) => i['id'] == itemId,
            orElse: () => {
              'id': itemId,
              'name': (raw['inventoryItemName'] ?? 'مادة غير متوفرة').toString(),
              'unit': (raw['unit'] ?? 'كغم').toString(),
              'costPerUnit': (raw['costPerUnit'] ?? 0.0).toDouble(),
            },
          );

          _ingredients.add(
            _RecipeIngredient(
              inventoryItemId: itemId,
              inventoryItemName: invMatch['name'],
              unit: invMatch['unit'],
              usagePerUnit: (raw['usagePerUnit'] ?? 0.0).toDouble(),
              costPerUnit: (invMatch['costPerUnit'] ?? 0.0).toDouble(),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[MealRecipeDialog] Error loading recipe: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalCost {
    double total = 0.0;
    for (final ing in _ingredients) {
      total += ing.totalCost;
    }
    return total;
  }

  double get _profitMargin {
    if (widget.mealPrice <= 0) return 0.0;
    return ((widget.mealPrice - _totalCost) / widget.mealPrice) * 100;
  }

  Future<void> _saveRecipe() async {
    setState(() => _isSaving = true);
    try {
      final ingredientsPayload = _ingredients.map((i) => i.toMap()).toList();
      final totalCost = _totalCost;

      final batch = FirebaseFirestore.instance.batch();

      // حفظ في merchant_recipes
      final recipeRef = FirebaseFirestore.instance
          .collection('merchant_recipes')
          .doc(widget.restaurantId)
          .collection('recipes')
          .doc(widget.mealId);

      batch.set(recipeRef, {
        'mealId': widget.mealId,
        'mealName': widget.mealName,
        'ingredients': ingredientsPayload,
        'productionCost': totalCost,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // حفظ نسخة في merchant_products
      final prodRef = FirebaseFirestore.instance
          .collection('merchant_products')
          .doc(widget.restaurantId)
          .collection('products')
          .doc(widget.mealId);

      batch.update(prodRef, {
        'linkedIngredients': ingredientsPayload,
        'productionCost': totalCost,
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم حفظ وصفة "${widget.mealName}" وتحديث تكلفة الإنتاج بنجاح!',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
            ),
            backgroundColor: context.posColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء حفظ الوصفة: $e'),
            backgroundColor: context.posColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addIngredientRow() {
    if (_inventoryItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا توجد مواد أولية في المخزون. يرجى إضافة مواد إلى المخزون أولاً.',
            style: GoogleFonts.ibmPlexSansArabic(),
          ),
          backgroundColor: context.posColors.warning,
        ),
      );
      return;
    }

    final firstItem = _inventoryItems.first;
    setState(() {
      _ingredients.add(
        _RecipeIngredient(
          inventoryItemId: firstItem['id'],
          inventoryItemName: firstItem['name'],
          unit: firstItem['unit'],
          usagePerUnit: 1.0,
          costPerUnit: (firstItem['costPerUnit'] as num).toDouble(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.border),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SizedBox(
          width: MediaQuery.of(context).size.width.clamp(320.0, 680.0),
          child: _isLoading
              ? const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // رأس النافذة
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: c.background,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        border: Border(bottom: BorderSide(color: c.border)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: c.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.soup_kitchen_rounded, color: c.primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'مكونات ووصفة الوجبة: ${widget.mealName}',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'اربط المكونات لحساب تكلفة الإنتاج وخصم المخزون تلقائياً عند كل بيع',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 12,
                                    color: c.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close_rounded, color: c.textMuted),
                          ),
                        ],
                      ),
                    ),

                    // بطاقات مؤشرات التكلفة والربح
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          _buildCostCard(
                            c,
                            title: 'سعر البيع',
                            value: PosConstants.formatMoney(widget.mealPrice),
                            color: c.textPrimary,
                            bg: c.background,
                          ),
                          const SizedBox(width: 12),
                          _buildCostCard(
                            c,
                            title: 'تكلفة الإنتاج',
                            value: PosConstants.formatMoney(_totalCost),
                            color: _totalCost > widget.mealPrice ? c.danger : c.primary,
                            bg: (_totalCost > widget.mealPrice ? c.danger : c.primary).withValues(alpha: 0.08),
                          ),
                          const SizedBox(width: 12),
                          _buildCostCard(
                            c,
                            title: 'هامش الربح',
                            value: '${_profitMargin.toStringAsFixed(1)}%',
                            color: _profitMargin >= 30
                                ? c.success
                                : (_profitMargin > 0 ? c.warning : c.danger),
                            bg: (_profitMargin >= 30 ? c.success : c.warning).withValues(alpha: 0.08),
                          ),
                        ],
                      ),
                    ),

                    // جدول المكونات
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: _ingredients.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: c.background.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: c.border),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.inventory_2_outlined, size: 40, color: c.textDisabled),
                                      const SizedBox(height: 10),
                                      Text(
                                        'لم يتم ربط أي مكونات مخزنية بهذه الوجبة بعد',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: c.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'اضغط على زر "إضافة مادة أولية" أدناه للربط مع المخزون',
                                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: c.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: c.border),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _ingredients.length,
                                  separatorBuilder: (_, _) => Divider(color: c.border, height: 1),
                                  itemBuilder: (context, idx) {
                                    final ing = _ingredients[idx];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      child: Row(
                                        children: [
                                          // اختيار المادة من المخزون
                                          Expanded(
                                            flex: 4,
                                            child: DropdownButtonFormField<String>(
                                              initialValue: _inventoryItems.any((i) => i['id'] == ing.inventoryItemId)
                                                  ? ing.inventoryItemId
                                                  : null,
                                              decoration: InputDecoration(
                                                labelText: 'المادة الأولية',
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                              items: _inventoryItems.map((inv) {
                                                return DropdownMenuItem<String>(
                                                  value: inv['id'].toString(),
                                                  child: Text(
                                                    '${inv['name']} (${inv['unit']})',
                                                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5),
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (newId) {
                                                if (newId == null) return;
                                                final match = _inventoryItems.firstWhere((i) => i['id'] == newId);
                                                setState(() {
                                                  ing.inventoryItemId = newId;
                                                  ing.inventoryItemName = match['name'];
                                                  ing.unit = match['unit'];
                                                  ing.costPerUnit = (match['costPerUnit'] as num).toDouble();
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // الكمية المستهلكة لكل وجبة
                                          Expanded(
                                            flex: 2,
                                            child: TextFormField(
                                              initialValue: ing.usagePerUnit.toString(),
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: InputDecoration(
                                                labelText: 'الكمية (${ing.unit})',
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                              style: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
                                              onChanged: (val) {
                                                final parsed = double.tryParse(val.trim()) ?? 0.0;
                                                setState(() => ing.usagePerUnit = parsed);
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // التكلفة المحسوبة
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'التكلفة',
                                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: c.textMuted),
                                                ),
                                                Text(
                                                  PosConstants.formatMoney(ing.totalCost),
                                                  style: GoogleFonts.ibmPlexSansArabic(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: c.textPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // زر الحذف
                                          IconButton(
                                            icon: Icon(Icons.delete_outline_rounded, color: c.danger, size: 20),
                                            tooltip: 'إزالة المادة',
                                            onPressed: () {
                                              setState(() => _ingredients.removeAt(idx));
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ),

                    // أزرار الإضافة والحفظ
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _addIngredientRow,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              'إضافة مادة أولية',
                              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: c.primary,
                              side: BorderSide(color: c.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'إلغاء',
                              style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveRecipe,
                            icon: _isSaving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_circle_rounded, size: 18),
                            label: Text(
                              _isSaving ? 'جاري الحفظ...' : 'حفظ الوصفة والتكلفة',
                              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCostCard(
    PosColors c, {
    required String title,
    required String value,
    required Color color,
    required Color bg,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted)),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeIngredient {
  String inventoryItemId;
  String inventoryItemName;
  String unit;
  double usagePerUnit;
  double costPerUnit;

  _RecipeIngredient({
    required this.inventoryItemId,
    required this.inventoryItemName,
    required this.unit,
    required this.usagePerUnit,
    required this.costPerUnit,
  });

  double get totalCost => usagePerUnit * costPerUnit;

  Map<String, dynamic> toMap() {
    return {
      'inventoryItemId': inventoryItemId,
      'inventoryItemName': inventoryItemName,
      'unit': unit,
      'usagePerUnit': usagePerUnit,
      'costPerUnit': costPerUnit,
    };
  }
}
