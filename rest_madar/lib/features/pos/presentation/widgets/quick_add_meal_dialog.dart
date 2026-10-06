import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/madar_crash_guard.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_icon_helper.dart';
import '../../../../services/cloudinary_service.dart';
import '../../../../services/firestore_sync_service.dart';
import '../../../menu/presentation/widgets/category_manager_dialog.dart';

/// نافذة إضافة أو تعديل وجبة سريعة مع الصور والأقسام والأيقونات
/// — هوية مزدوجة (فاتح/داكن) + عرض مرن + رفع صورة عبر Firebase Storage
/// مع تراجع آمن إلى Cloudinary وحماية شاملة من الانهيار.
class QuickAddMealDialog extends StatefulWidget {
  final Map<String, dynamic>? initialMealData;
  final String? initialMealId;
  final VoidCallback? onMealSaved;

  const QuickAddMealDialog({
    super.key,
    this.initialMealData,
    this.initialMealId,
    this.onMealSaved,
  });

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? initialMealData,
    String? initialMealId,
    VoidCallback? onMealSaved,
  }) async {
    try {
      return await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => QuickAddMealDialog(
          initialMealData: initialMealData,
          initialMealId: initialMealId,
          onMealSaved: onMealSaved,
        ),
      );
    } catch (e, st) {
      debugPrint('[QuickAddMeal] showDialog failed: $e\n$st');
      if (context.mounted) {
        MadarCrashGuard.showErrorDialog(
          context,
          e,
          stackTrace: st,
          customTitle: 'تعذر فتح نافذة إضافة الوجبة',
        );
      }
    }
  }

  @override
  State<QuickAddMealDialog> createState() => _QuickAddMealDialogState();
}

class _QuickAddMealDialogState extends State<QuickAddMealDialog> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _imageUrlController = TextEditingController();

  String _selectedCategory = 'برجر';
  List<String> _categories = [
    'وجبات رئيسية',
    'برجر',
    'بيتزا',
    'شاورما',
    'مشاوي',
    'دجاج',
    'مقبلات',
    'مشروبات',
    'حلويات',
  ];

  bool _isLoading = false;
  bool _isUploadingImage = false;
  Uint8List? _localImageBytes;

  // الأحجام
  final List<Map<String, dynamic>> _sizes = [];
  final _sizeNameCtrl = TextEditingController();
  final _sizePriceCtrl = TextEditingController();

  // الإضافات
  final List<Map<String, dynamic>> _addons = [];
  final _addonNameCtrl = TextEditingController();
  final _addonPriceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();

    if (widget.initialMealData != null) {
      final d = widget.initialMealData!;
      _nameController.text = d['name'] ?? '';
      _priceController.text = (d['price'] ?? 0).toString();
      _descController.text = d['description'] ?? '';
      _imageUrlController.text = d['imageUrl'] ?? d['photoUrl'] ?? '';
      _selectedCategory = d['category'] ?? 'برجر';

      if (d['sizes'] is List) {
        for (var s in d['sizes']) {
          if (s is Map) _sizes.add(Map<String, dynamic>.from(s));
        }
      }
      if (d['addons'] is List) {
        for (var a in d['addons']) {
          if (a is Map) _addons.add(Map<String, dynamic>.from(a));
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _imageUrlController.dispose();
    _sizeNameCtrl.dispose();
    _sizePriceCtrl.dispose();
    _addonNameCtrl.dispose();
    _addonPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final targetUid = _uid.isNotEmpty ? _uid : FirebaseAuth.instance.currentUser?.uid;
      if (targetUid == null || targetUid.isEmpty) return;

      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(targetUid)
          .get();
      if (doc.exists && doc.data()?['categories'] != null) {
        final dynamic rawCats = doc.data()?['categories'];

        // إزالة التكرار والأسماء الفارغة بشكل آمن 100%
        final cleaned = <String>[];
        if (rawCats is List) {
          for (final raw in rawCats) {
            if (raw == null) continue;
            final val = raw is Map
                ? (raw['name'] ?? raw['title'] ?? '').toString().trim()
                : raw.toString().trim();
            if (val.isNotEmpty && !cleaned.contains(val)) {
              cleaned.add(val);
            }
          }
        }

        if (cleaned.isNotEmpty && mounted) {
          setState(() {
            _categories = cleaned;
            if (!_categories.contains(_selectedCategory)) {
              _selectedCategory = _categories.first;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[QuickAddMeal] _loadCategories failed gracefully: $e');
    }
  }

  /// رفع الصورة عبر المحرك السحابي المزدوج (Firebase Storage مع تراجع إلى Cloudinary)
  Future<String?> _uploadImageBytes(Uint8List bytes, String filename) async {
    return await CloudinaryService.uploadBytes(bytes, filename);
  }

  Future<void> _pickImageFile() async {
    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      setState(() {
        _localImageBytes = bytes;
        _isUploadingImage = true;
      });

      // رفع إلى Firebase Storage (أو Cloudinary كبديل)
      final url = await _uploadImageBytes(bytes, file.name);
      if (!mounted) return;
      setState(() {
        _isUploadingImage = false;
        if (url != null && url.isNotEmpty) {
          _imageUrlController.text = url;
        }
      });
      if (url == null || url.isEmpty) {
        _showMessage(
          'فشل رفع الصورة إلى الخادم. تأكد من الإنترنت أو استخدم مكتبة الصور الجاهزة.',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('[QuickAddMeal] pick image error: $e');
      if (mounted) {
        setState(() => _isUploadingImage = false);
        _showMessage('تعذر اختيار الصورة من الجهاز.', isError: true);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    final c = context.posColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? c.danger : c.success,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  void _showPresetImagesModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.posColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final c = context.posColors;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            height: 500,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'مكتبة صور الطعام الجاهزة (اختيار سريع)',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: c.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: c.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'انقر على أي صورة لتطبيقها مباشرة على الوجبة بدون الحاجة للرفع',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: c.textMuted,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 160,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                    itemCount: CategoryIconHelper.presetFoodImages.length,
                    itemBuilder: (context, i) {
                      final item = CategoryIconHelper.presetFoodImages[i];
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _imageUrlController.text = item['url']!;
                            _localImageBytes = null;
                            if (_nameController.text.trim().isEmpty) {
                              _nameController.text = item['title']!;
                            }
                            if (_categories.contains(item['category'])) {
                              _selectedCategory = item['category']!;
                            }
                          });
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.border),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Image.network(
                                    item['url']!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Center(
                                      child: Icon(
                                        Icons.fastfood_rounded,
                                        color: c.accent,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    item['title']!,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      color: c.textPrimary,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveMeal() async {
    debugPrint('[QuickAddMeal] ▶ _saveMeal called');
    if (!_formKey.currentState!.validate()) {
      debugPrint('[QuickAddMeal] ✗ Form validation failed');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      MadarCrashGuard.showErrorDialog(
        context,
        'يرجى تسجيل الدخول أولاً بحساب المطعم لإضافة وحفظ الوجبات.',
        customTitle: 'جلسة الحساب غير مسجلة',
      );
      return;
    }

    // استخراج معرّف المطعم الحقيقي (قد يكون مخزناً داخل وثيقة المستخدم)
    String targetUid = user.uid;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final rId = (data['restaurantId'] ?? data['storeId'] ?? data['branchId'])?.toString().trim() ?? '';
        if (rId.isNotEmpty) targetUid = rId;
      }
    } catch (_) {}

    debugPrint('[QuickAddMeal] targetUid=$targetUid, user=${user.email}');

    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final imageUrl = _imageUrlController.text.trim();
    final desc = _descController.text.trim();
    final category = _selectedCategory.trim();

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}

      final isEditing = widget.initialMealId != null && widget.initialMealId!.isNotEmpty;
      final mealId = isEditing
          ? widget.initialMealId!
          : FirebaseFirestore.instance
              .collection('merchant_products')
              .doc(targetUid)
              .collection('products')
              .doc().id;

      final mealPayload = <String, dynamic>{
        'id': mealId,
        'productId': mealId,
        'restaurantId': targetUid,
        'name': name,
        'title': name,
        'price': price,
        'category': category,
        'description': desc,
        'imageUrl': imageUrl,
        'photoUrl': imageUrl,
        'isAvailable': true,
        'sizes': _sizes,
        'addons': _addons,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!isEditing) {
        mealPayload['createdAt'] = FieldValue.serverTimestamp();
      }

      debugPrint('[QuickAddMeal] Writing to merchant_products/$targetUid/products/$mealId');

      // 1. الكتابة الأساسية في merchant_products (مصدر الكاشير والمنيو)
      // يتم تنفيذها مباشرة حتى إذا حدث استثناء يُلتقط فوراً ويُعرض سببه للمستخدم
      await FirebaseFirestore.instance
          .collection('merchant_products')
          .doc(targetUid)
          .collection('products')
          .doc(mealId)
          .set(mealPayload, SetOptions(merge: true));

      debugPrint('[QuickAddMeal] ✓ merchant_products written successfully');

      // 2. المزامنة مع restaurants/{targetUid}/menu (لتطبيق الزبائن وقائمة الصالة)
      try {
        await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(targetUid)
            .collection('menu')
            .doc(mealId)
            .set(mealPayload, SetOptions(merge: true));
        debugPrint('[QuickAddMeal] ✓ restaurants/menu synced');
      } catch (e) {
        debugPrint('[QuickAddMeal] Note: restaurants sync warning: $e');
      }

      // 3. المزامنة مع stores/{targetUid}/products
      try {
        await FirebaseFirestore.instance
            .collection('stores')
            .doc(targetUid)
            .collection('products')
            .doc(mealId)
            .set(mealPayload, SetOptions(merge: true));
      } catch (_) {}

      // 4. المزامنة مع أقسام التطبيق المحمول (sections/{sectionId}/items/{itemId}/menu)
      try {
        await FirestoreSyncService.syncAddOrSetMeal(targetUid, mealId, mealPayload);
        debugPrint('[QuickAddMeal] ✓ Mobile app sections synced');
      } catch (e) {
        debugPrint('[QuickAddMeal] Note: Mobile sections sync warning: $e');
      }

      // 5. حفظ القسم تلقائياً في قائمة أقسام المطعم إذا لم يكن موجوداً
      try {
        await FirebaseFirestore.instance.collection('restaurants').doc(targetUid).set({
          'categories': FieldValue.arrayUnion([category]),
        }, SetOptions(merge: true));
      } catch (_) {}

      widget.onMealSaved?.call();

      if (!mounted) return;
      Navigator.pop(context);
      _showMessage('تم حفظ الوجبة "$name" وعرضها في المنيو بنجاح ✅');
      debugPrint('[QuickAddMeal] ✓ Save complete — dialog closed');
    } catch (e, st) {
      debugPrint('[QuickAddMeal] ✗✗ CRITICAL Save error: $e\n$st');
      if (!mounted) return;
      setState(() => _isLoading = false);
      MadarCrashGuard.showErrorDialog(
        context,
        e,
        stackTrace: st,
        customTitle: 'فشل حفظ الوجبة في قاعدة البيانات',
        onRetry: _saveMeal,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeCrashBoundary(
      child: _buildDialogContent(context),
    );
  }

  Widget _buildDialogContent(BuildContext context) {
    final c = context.posColors;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final dialogWidth = screenWidth < 720 ? (screenWidth - 24) : 680.0;
    final dialogMaxHeight = (screenHeight * 0.88).clamp(400.0, 800.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        backgroundColor: c.surface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.border, width: 1.2),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogWidth,
            maxHeight: dialogMaxHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Form(
              key: _formKey,
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
                        color: c.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.add_business_rounded,
                        color: c.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.initialMealId != null
                                ? 'تعديل الوجبة'
                                : 'إضافة وجبة جديدة للمنيو',
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: c.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'حدد اسم وصورة وقسم وسعر الوجبة لعرضها فوراً في الكاشير وتطبيق مدار',
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: c.textMuted,
                              fontSize: 11.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                const SizedBox(height: 16),
                Divider(color: c.border, height: 1),
                const SizedBox(height: 16),

                // المحتوى القابل للتمرير
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // معاينة واختيار الصورة
                        _buildImageSection(),
                        const SizedBox(height: 18),

                        // اسم الوجبة والسعر
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'اسم الوجبة *',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      color: c.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _nameController,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      color: c.textPrimary,
                                      fontSize: 13,
                                    ),
                                    decoration: _inputDecoration(
                                      c,
                                      hint:
                                          'مثال: برجر دبل تشيز، شاورما عربي...',
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'يرجى كتابة اسم الوجبة'
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'السعر (د.ع) *',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      color: c.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _priceController,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      color: c.gold,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    decoration: _inputDecoration(
                                      c,
                                      hint: 'مثال: 6000',
                                    ),
                                    validator: (v) =>
                                        (v == null ||
                                            double.tryParse(v) == null)
                                        ? 'أدخل سعراً صالحاً'
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // قسم الوجبة مع الأيقونة
                        _buildCategoryDropdown(),
                        const SizedBox(height: 18),

                        // الوصف والمكونات
                        Text(
                          'الوصف والمكونات (اختياري)',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: c.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descController,
                          maxLines: 2,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: c.textPrimary,
                            fontSize: 12.5,
                          ),
                          decoration: _inputDecoration(
                            c,
                            hint: 'اكتب وصفاً للوجبة أو مكوناتها...',
                          ),
                        ),
                        const SizedBox(height: 18),

                        // إضافات وخيارات الوجبة
                        _buildAddonsSection(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Divider(color: c.border, height: 1),
                const SizedBox(height: 16),

                // الأزرار السفلية
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'إلغاء',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: c.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveMeal,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        _isLoading ? 'جاري الحفظ...' : 'حفظ الوجبة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  InputDecoration _inputDecoration(
    PosColors c, {
    required String hint,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.ibmPlexSansArabic(
        color: c.textDisabled,
        fontSize: 12,
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: c.textMuted, size: 18)
          : null,
      filled: true,
      fillColor: c.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.accent, width: 1.5),
      ),
    );
  }

  Widget _buildImageSection() {
    final c = context.posColors;
    final currentUrl = _imageUrlController.text.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          // المعاينة
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _localImageBytes != null
                  ? Image.memory(_localImageBytes!, fit: BoxFit.cover)
                  : currentUrl.isNotEmpty
                  ? Image.network(
                      currentUrl,
                      fit: BoxFit.cover,
                      // فك ترميز الصورة بحجم المصغّر بدل الحجم الكامل
                      // لتجنّب تجمّد الواجهة عند فتح النافذة
                      cacheWidth: 220,
                      errorBuilder: (_, _, _) => Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: c.textDisabled,
                          size: 30,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        CategoryIconHelper.getIconForCategory(
                          _selectedCategory,
                        ),
                        color: c.primary.withValues(alpha: 0.6),
                        size: 38,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // خيارات إضافة الصورة
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'صورة الوجبة',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: c.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'الصورة الجذابة تزيد من مبيعات الوجبة في الكاشير وتطبيق مدار',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: c.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // زر اختيار من المعرض الجاهز
                    ElevatedButton.icon(
                      onPressed: _showPresetImagesModal,
                      icon: const Icon(Icons.photo_library_rounded, size: 16),
                      label: Text(
                        'صور جاهزة سريعة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary.withValues(alpha: 0.15),
                        foregroundColor: c.accent,
                        side: BorderSide(color: c.primary),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),

                    // زر رفع من الجهاز
                    ElevatedButton.icon(
                      onPressed: _isUploadingImage ? null : _pickImageFile,
                      icon: _isUploadingImage
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.upload_file_rounded, size: 16),
                      label: Text(
                        _isUploadingImage ? 'جاري الرفع...' : 'رفع من الحاسبة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.background,
                        foregroundColor: c.textPrimary,
                        side: BorderSide(color: c.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final c = context.posColors;
    final currentIcon = CategoryIconHelper.getIconForCategory(_selectedCategory);
    final currentColor = CategoryIconHelper.getColorForCategory(_selectedCategory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'قسم الوجبة (Category) *',
              style: GoogleFonts.ibmPlexSansArabic(
                color: c.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
            InkWell(
              onTap: () {
                CategoryManagerDialog.show(
                  context,
                  onUpdated: () => _loadCategories(),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, size: 14, color: c.accent),
                  const SizedBox(width: 4),
                  Text(
                    'إدارة كافة الأقسام 🏷️',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: c.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // بطاقة القسم الحالي النشط مع زر فتح القائمة
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.accent.withValues(alpha: 0.5), width: 1.4),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: currentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(currentIcon, color: currentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'القسم المختار للوجبة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: c.textDisabled,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      _selectedCategory,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'تغيير القسم من القائمة',
                color: c.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: c.border),
                ),
                onSelected: (val) {
                  setState(() => _selectedCategory = val);
                },
                itemBuilder: (context) {
                  return _categories.map((cat) {
                    final isSel = cat == _selectedCategory;
                    final icon = CategoryIconHelper.getIconForCategory(cat);
                    final col = CategoryIconHelper.getColorForCategory(cat);
                    return PopupMenuItem<String>(
                      value: cat,
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Row(
                          children: [
                            Icon(icon, color: col, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                cat,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: isSel ? c.accent : c.textPrimary,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            if (isSel)
                              Icon(Icons.check_rounded, color: c.accent, size: 16),
                          ],
                        ),
                      ),
                    );
                  }).toList();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'عرض الكل',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: c.accent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, color: c.accent, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // أزرار الاختيار السريع المباشر (Chips)
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ..._categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              final icon = CategoryIconHelper.getIconForCategory(cat);
              final color = CategoryIconHelper.getColorForCategory(cat);
              return InkWell(
                onTap: () => setState(() => _selectedCategory = cat),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? c.primary.withValues(alpha: 0.18) : c.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? c.accent : c.border,
                      width: isSelected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: isSelected ? c.accent : color, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        cat,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: isSelected ? c.accent : c.textMuted,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            // زر إضافة قسم مخصص سريعاً
            InkWell(
              onTap: _showAddQuickCategoryDialog,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.accent.withValues(alpha: 0.4), style: BorderStyle.solid),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline_rounded, color: c.accent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'قسم جديد +',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: c.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddQuickCategoryDialog() {
    final c = context.posColors;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          title: Text(
            'إضافة قسم طعام جديد',
            style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: _inputDecoration(c, hint: 'اسم القسم (مثال: ساندوتش، وجبات عائلية...)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final text = ctrl.text.trim();
                if (text.isNotEmpty && !_categories.contains(text)) {
                  setState(() {
                    _categories.add(text);
                    _selectedCategory = text;
                  });
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: c.primary),
              child: Text('إضافة', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddonsSection() {
    final c = context.posColors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF6366F1)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إضافات وخيارات الوجبة (Modifiers & Add-ons)',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: c.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'أضف إكسترا جبن، صوصات، نوع الخبز أو درجات الطهي لهذه الوجبة',
                      style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              // زر الجلب من خيارات المطعم المحفوظة
              OutlinedButton.icon(
                onPressed: _showSavedModifiersPickerModal,
                icon: const Icon(Icons.bolt_rounded, size: 15, color: Color(0xFFF59E0B)),
                label: Text(
                  'خيارات محفوظة ⚡',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD97706),
                  side: const BorderSide(color: Color(0xFFF59E0B)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // عرض الخيارات المضافة حالياً
          if (_addons.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: c.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: c.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لم تتم إضافة خيارات مخصصة بعد. أضف خياراً بالأسفل أو اختر من المقترحات السريعة.',
                      style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _addons.asMap().entries.map((entry) {
                final idx = entry.key;
                final addon = entry.value;
                final aName = (addon['name'] ?? '').toString();
                final aPrice = (addon['price'] ?? 0);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                      Text(
                        aName,
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold, color: c.textPrimary),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: aPrice > 0 ? const Color(0xFF10B981).withValues(alpha: 0.12) : c.card,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          aPrice > 0 ? '+$aPrice د.ع' : 'مجاني',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: aPrice > 0 ? const Color(0xFF10B981) : c.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => setState(() => _addons.removeAt(idx)),
                        child: const Icon(Icons.close_rounded, size: 15, color: Color(0xFFEF4444)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 14),

          // حقول إضافة خيار يدوي جديد
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _addonNameCtrl,
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'اسم الإضافة (مثال: جبن موزاريلا، صوص باربيكيو...)',
                    hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                    filled: true,
                    fillColor: c.background,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _addonPriceCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'السعر (0 للمجاني)',
                    hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                    filled: true,
                    fillColor: c.background,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  final name = _addonNameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final price = double.tryParse(_addonPriceCtrl.text.trim()) ?? 0.0;
                  setState(() {
                    _addons.add({
                      'name': name,
                      'price': price,
                      'isRequired': false,
                    });
                    _addonNameCtrl.clear();
                    _addonPriceCtrl.clear();
                  });
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('إضافة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // مقترحات سريعة بنقرة واحدة
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildAddonPresetChip('+ جبن شيدر ذائب', 1000),
              _buildAddonPresetChip('+ جبن موزاريلا', 1000),
              _buildAddonPresetChip('+ صوص رانش', 500),
              _buildAddonPresetChip('+ صوص باربيكيو', 500),
              _buildAddonPresetChip('+ خبز بريوش', 1000),
              _buildAddonPresetChip('+ هالبينو حار', 500),
              _buildAddonPresetChip('+ بيكون بقري', 2000),
              _buildAddonPresetChip('بدون بصل', 0),
              _buildAddonPresetChip('بدون مخلل', 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddonPresetChip(String name, double price) {
    final isAlreadyAdded = _addons.any((a) => a['name'] == name);

    return ActionChip(
      label: Text(
        name,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 10.5,
          fontWeight: isAlreadyAdded ? FontWeight.bold : FontWeight.normal,
          color: isAlreadyAdded ? const Color(0xFF6366F1) : null,
        ),
      ),
      backgroundColor: isAlreadyAdded ? const Color(0xFF6366F1).withValues(alpha: 0.12) : null,
      onPressed: () {
        if (!isAlreadyAdded) {
          setState(() {
            _addons.add({
              'name': name,
              'price': price,
              'isRequired': false,
            });
          });
        }
      },
    );
  }

  Future<void> _showSavedModifiersPickerModal() async {
    final targetUid = _uid.isNotEmpty ? _uid : FirebaseAuth.instance.currentUser?.uid ?? '';
    if (targetUid.isEmpty) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('merchant_modifiers')
          .doc(targetUid)
          .collection('modifiers')
          .get();

      if (!mounted) return;

      if (snap.docs.isEmpty) {
        _showMessage('لم يتم تسجيل خيارات عامة للمطعم بعد. يمكنك إضافة خيارات مباشرة هنا.');
        return;
      }

      final saved = snap.docs.map((d) {
        final data = d.data();
        return {
          'name': (data['name'] ?? '').toString(),
          'price': (data['price'] ?? 0).toDouble(),
          'groupName': (data['groupName'] ?? 'عام').toString(),
        };
      }).where((m) => m['name'].toString().isNotEmpty).toList();

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: context.posColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          final c = context.posColors;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: StatefulBuilder(
              builder: (ctx2, setModalState) {
                return Container(
                  height: 480,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'اختيار من خيارات وإضافات المطعم المحفوظة',
                              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 14, color: c.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'انقر على أي خيار لإضافته أو حذفه من هذه الوجبة فوراً:',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: saved.length,
                          itemBuilder: (context, i) {
                            final item = saved[i];
                            final name = item['name'] as String;
                            final price = item['price'] as double;
                            final group = item['groupName'] as String;
                            final isSelected = _addons.any((a) => a['name'] == name);

                            return CheckboxListTile(
                              value: isSelected,
                              activeColor: const Color(0xFF6366F1),
                              title: Text(name, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                              subtitle: Text('$group • ${price > 0 ? '+${price.toInt()} د.ع' : 'مجاني'}', style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted)),
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _addons.add({'name': name, 'price': price, 'isRequired': false});
                                  } else {
                                    _addons.removeWhere((a) => a['name'] == name);
                                  }
                                });
                                setModalState(() {});
                              },
                            );
                          },
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.primary,
                          minimumSize: const Size.fromHeight(42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('تم وتطبيق الخيارات', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
    } catch (_) {}
  }
}
