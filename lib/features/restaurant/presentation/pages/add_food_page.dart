import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dalal_alqaim/services/cloudinary_service.dart';
import 'package:dalal_alqaim/services/firestore_sync_service.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class AddFoodPage extends StatefulWidget {
  final String? foodDocId;
  final Map<String, dynamic>? initialData;

  const AddFoodPage({
    super.key,
    this.foodDocId,
    this.initialData,
  });

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _sizeNameController = TextEditingController();
  final TextEditingController _sizePriceController = TextEditingController();
  final TextEditingController _addonNameController = TextEditingController();
  final TextEditingController _addonPriceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  String _selectedAddonIcon = '';

  Uint8List? _pickedImageBytes;
  String? _pickedImageFilename;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isPickingImage = false;

  List<String> _categories = [];
  String _selectedCategory = '';

  // Advanced features
  List<Map<String, dynamic>> _sizes = [];
  List<Map<String, dynamic>> _addons = [];
  bool _isStockLimited = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final d = widget.initialData!;
      _nameController.text = (d['name'] ?? '').toString();
      _descController.text = (d['description'] ?? '').toString();
      _priceController.text = (d['sellingPrice'] ?? d['price'] ?? '').toString();
      _existingImageUrl = (d['imageUrl'] ?? '').toString();
      _selectedCategory = (d['category'] ?? '').toString();
      if (d['sizes'] is List) {
        _sizes = List<Map<String, dynamic>>.from(d['sizes']);
      }
      if (d['addons'] is List) {
        _addons = List<Map<String, dynamic>>.from(d['addons']);
      }
      _isStockLimited = d['isStockLimited'] ?? false;
      if (d['stockLimit'] != null || d['stockCount'] != null) {
        _stockController.text = (d['stockLimit'] ?? d['stockCount']).toString();
      }
    }
    _loadCustomCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _sizeNameController.dispose();
    _sizePriceController.dispose();
    _addonNameController.dispose();
    _addonPriceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomCategories() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance.collection('restaurants').doc(uid).get();
      if (doc.exists && doc.data()?['categories'] != null) {
        final List<dynamic> cats = doc.data()?['categories'];
        if (cats.isNotEmpty && mounted) {
          setState(() {
            _categories = cats.map((e) => e.toString()).toList();
            if (_selectedCategory.isEmpty || !_categories.contains(_selectedCategory)) {
              _selectedCategory = _categories.first;
            }
          });
        }
      }
    } catch (_) {}
  }

  void _showQuickAddCategoryDialog() {
    final catCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = isDark ? app_colors.darkCard : Colors.white;
        final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;

        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.folder_copy_rounded, color: app_colors.primaryColor),
              const SizedBox(width: 8),
              Text(
                'إضافة قسم جديد للمنيو',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          content: TextField(
            controller: catCtrl,
            autofocus: true,
            style: GoogleFonts.ibmPlexSansArabic(color: textPrimary),
            decoration: InputDecoration(
              hintText: 'اكتب اسم القسم (مثال: بركر، مشاوي، كص)',
              hintStyle: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12,
                color: isDark ? app_colors.darkSubText : app_colors.subTextColor,
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'إلغاء',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? app_colors.darkSubText : app_colors.subTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newCat = catCtrl.text.trim();
                if (newCat.isNotEmpty) {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    final updated = List<String>.from(_categories);
                    if (!updated.contains(newCat)) {
                      updated.add(newCat);
                      await FirebaseFirestore.instance
                          .collection('restaurants')
                          .doc(uid)
                          .set({'categories': updated}, SetOptions(merge: true));

                      setState(() {
                        _categories = updated;
                        _selectedCategory = newCat;
                      });
                    }
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: app_colors.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'ضيف القسم',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickFoodImage(ImageSource source) async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    HapticFeedback.lightImpact();

    try {
      final XFile? picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _pickedImageBytes = bytes;
          _pickedImageFilename = picked.name.isNotEmpty
              ? picked.name
              : 'meal_${DateTime.now().millisecondsSinceEpoch}.jpg';
        });
      }
    } catch (_) {
      _showError('عذراً، فشل التقاط أو تحديد صورة الأكلة.');
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _showImagePickerSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? app_colors.darkCard : Colors.white;
    final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'اختار صورة للأكلة',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _pickFoodImage(ImageSource.camera);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: app_colors.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: app_colors.primaryColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.camera_alt_rounded,
                                color: app_colors.primaryColor,
                                size: 30,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'طق صورة بالكاميرا',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _pickFoodImage(ImageSource.gallery);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: app_colors.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: app_colors.primaryColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.photo_library_rounded,
                                color: app_colors.primaryColor,
                                size: 30,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'اختار من الاستوديو',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.ibmPlexSansArabic(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _submitMeal() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory.trim().isEmpty) {
      _showError('اختار أو ضيف قسم للأكلة أولاً');
      return;
    }

    if (_pickedImageBytes == null && (_existingImageUrl == null || _existingImageUrl!.isEmpty)) {
      _showError('لازم تختار صورة للأكلة من الاستوديو أو الكاميرا');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw 'سجّل دخولك أولاً';

      String? finalImageUrl = _existingImageUrl;
      if (_pickedImageBytes != null) {
        final filename = _pickedImageFilename ?? 'meal_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final uploadedUrl = await CloudinaryService.uploadBytes(_pickedImageBytes!, filename);
        if (uploadedUrl == null) {
          throw 'فشل رفع صورة الأكلة. يرجى التحقق من اتصال الإنترنت.';
        }
        finalImageUrl = uploadedUrl;
      }

      final price = double.tryParse(_priceController.text) ?? 0.0;
      final stockValue = _isStockLimited ? (int.tryParse(_stockController.text) ?? 10) : 0;

      final mealData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'wholesalePrice': 0.0,
        'sellingPrice': price,
        'price': price,
        'category': _selectedCategory,
        'isAvailable': widget.initialData?['isAvailable'] ?? true,
        if (finalImageUrl != null && finalImageUrl.isNotEmpty) 'imageUrl': finalImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
        'sizes': _sizes,
        'addons': _addons,
        'isStockLimited': _isStockLimited,
        'stockLimit': stockValue,
        'stockCount': stockValue,
      };

      String targetFoodId = widget.foodDocId ?? '';

      if (widget.foodDocId != null) {
        await FirebaseFirestore.instance
            .collection('merchant_products')
            .doc(uid)
            .collection('products')
            .doc(widget.foodDocId)
            .update(mealData);
      } else {
        mealData['createdAt'] = FieldValue.serverTimestamp();
        final docRef = await FirebaseFirestore.instance
            .collection('merchant_products')
            .doc(uid)
            .collection('products')
            .add(mealData);
        targetFoodId = docRef.id;
      }

      // Sync with customer stores collection
      try {
        await FirebaseFirestore.instance
            .collection('stores')
            .doc(uid)
            .collection('products')
            .doc(targetFoodId)
            .set(mealData, SetOptions(merge: true));
      } catch (e) {
        debugPrint('خطأ مزامنة مع المتجر: $e');
      }

      // Sync with sections/items/menu
      try {
        if (widget.foodDocId != null) {
          await FirestoreSyncService.syncUpdateMeal(uid, targetFoodId, mealData);
        } else {
          await FirestoreSyncService.syncAddOrSetMeal(uid, targetFoodId, mealData);
        }
      } catch (e) {
        debugPrint('خطأ مزامنة مع الأقسام: $e');
      }

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.foodDocId != null ? 'تعدّلت بيانات الأكلة بنجاح!' : 'انضافت الأكلة للمنيو وعاشت إيدك!',
            style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      _showError('حدث خطأ: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? app_colors.darkBackground : const Color(0xFFF6FAF9);
    final cardBg = isDark ? app_colors.darkCard : Colors.white;
    final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;
    final textSecondary = isDark ? app_colors.darkSubText : app_colors.subTextColor;
    final isEditing = widget.foodDocId != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: cardBg,
          elevation: 0.5,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isEditing ? 'تعديل الأكلة بالمنيو' : 'إضافة أكلة جديدة للمنيو',
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: textPrimary,
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            physics: const BouncingScrollPhysics(),
            children: [
              // 1. Hero Image Uploader Card
              _buildImageUploaderCard(cardBg, textPrimary, textSecondary, isDark),
              const SizedBox(height: 16),

              // 2. Primary Meal Details Card
              _buildSectionCard(
                cardBg: cardBg,
                isDark: isDark,
                title: 'معلومات وتفاصيل الأكلة',
                textPrimary: textPrimary,
                children: [
                  _buildInputField(
                    controller: _nameController,
                    label: 'اسم الأكلة / الوجبة',
                    hint: 'مثال: كص لحم دبل، كباب عراقي، بركر مشوي',
                    icon: Icons.restaurant_rounded,
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'اكتب اسم الأكلة أولاً' : null,
                  ),
                  const SizedBox(height: 14),

                  _buildInputField(
                    controller: _priceController,
                    label: 'السعر للزبون (د.ع)',
                    hint: 'مثال: 7000',
                    icon: Icons.payments_rounded,
                    isNumeric: true,
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'اكتب السعر للزبون';
                      if (double.tryParse(v) == null) return 'اكتب رقم السعر بصورة صحيحة';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Category Selector + Add Category Button
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF2F7F6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.5),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          child: _categories.isEmpty
                              ? InkWell(
                                  onTap: _showQuickAddCategoryDialog,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.category_rounded, color: app_colors.primaryColor, size: 20),
                                        const SizedBox(width: 10),
                                        Text(
                                          'دوس هنا وضيف أول قسم للمنيو',
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            color: app_colors.primaryColor,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : DropdownButtonFormField<String>(
                                  dropdownColor: cardBg,
                                  initialValue: _categories.contains(_selectedCategory)
                                      ? _selectedCategory
                                      : (_categories.isNotEmpty ? _categories.first : null),
                                  decoration: InputDecoration(
                                    labelText: 'قسم الأكلة بالمنيو',
                                    labelStyle: GoogleFonts.ibmPlexSansArabic(
                                      color: textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    prefixIcon: const Icon(Icons.category_rounded, color: app_colors.primaryColor, size: 20),
                                    border: InputBorder.none,
                                  ),
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    color: textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                  items: _categories
                                      .map((cat) => DropdownMenuItem(
                                            value: cat,
                                            child: Text(cat, style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _selectedCategory = v);
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _showQuickAddCategoryDialog,
                        icon: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: app_colors.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: app_colors.primaryColor.withValues(alpha: 0.25)),
                          ),
                          child: const Icon(Icons.add_rounded, color: app_colors.primaryColor, size: 22),
                        ),
                        tooltip: 'ضيف قسم جديد',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildInputField(
                    controller: _descController,
                    label: 'شنو مكونات وتفاصيل الأكلة؟',
                    hint: 'اكتب للزبون شنو يجي وية الأكلة وتفاصيل التحضير...',
                    icon: Icons.description_rounded,
                    maxLines: 3,
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Portion Sizes & Options Card
              _buildSectionCard(
                cardBg: cardBg,
                isDark: isDark,
                title: 'أحجام الوجبة وأسعارها (اختياري)',
                textPrimary: textPrimary,
                children: [
                  Text(
                    'اختر أو اكتب الحجم والسعر الإضافي (تظهر فقط إذا أضفتها هنا)',
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: textSecondary),
                  ),
                  const SizedBox(height: 8),

                  // Quick presets for sizes
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        'وسط',
                        'كبير',
                        'عائلي',
                        'نفر',
                        'نفر ونصف',
                        'كيلو كامل',
                        'وجبة دبل',
                      ].map((presetName) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ActionChip(
                            backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2EBE9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            label: Text(
                              '+ $presetName',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _sizeNameController.text = presetName;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_sizes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _sizes.map((sz) {
                          final sName = sz['sizeName'] ?? sz['name'] ?? 'حجم';
                          final sPrice = sz['price'] ?? sz['extra'] ?? 0;
                          return Chip(
                            backgroundColor: app_colors.primaryColor.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: app_colors.primaryColor.withValues(alpha: 0.2)),
                            label: Text(
                              '$sName: +$sPrice د.ع',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: app_colors.primaryColor,
                              ),
                            ),
                            deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
                            onDeleted: () {
                              setState(() => _sizes.remove(sz));
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF2F7F6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TextField(
                            controller: _sizeNameController,
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'الحجم (مثال: كبير، عائلي)',
                              hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: textSecondary.withValues(alpha: 0.6)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF2F7F6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TextField(
                            controller: _sizePriceController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'السعر الإضافي (د.ع)',
                              hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: textSecondary.withValues(alpha: 0.6)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (_sizeNameController.text.trim().isNotEmpty && _sizePriceController.text.trim().isNotEmpty) {
                            final pVal = double.tryParse(_sizePriceController.text.trim()) ?? 0.0;
                            setState(() {
                              _sizes.add({
                                'name': _sizeNameController.text.trim(),
                                'sizeName': _sizeNameController.text.trim(),
                                'price': pVal,
                                'extra': pVal,
                              });
                              _sizeNameController.clear();
                              _sizePriceController.clear();
                            });
                            HapticFeedback.lightImpact();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: app_colors.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. Popular & Custom Add-ons Section (إضافات اختيارية شهيرة ومخصصة)
              _buildSectionCard(
                cardBg: cardBg,
                isDark: isDark,
                title: 'إضافات اختيارية شهيرة ومخصصة (تظهر للزبون عند الطلب)',
                textPrimary: textPrimary,
                children: [
                  Text(
                    'انقر على الإضافات الشهيرة الجاهزة أو أضف إضافتك المخصصة بالسعر:',
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: textSecondary),
                  ),
                  const SizedBox(height: 10),

                  // Quick Popular Add-on Chips Presets
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        {'name': 'جبن إضافي ذائب', 'price': 1000.0, 'icon': ''},
                        {'name': 'صوص خاص', 'price': 500.0, 'icon': ''},
                        {'name': 'مشروب غازي بارد', 'price': 1000.0, 'icon': ''},
                        {'name': 'بطاطا ومقبلات', 'price': 1500.0, 'icon': ''},
                        {'name': 'خبز تنور حار', 'price': 500.0, 'icon': ''},
                        {'name': 'شيش كباب إضافي', 'price': 3500.0, 'icon': ''},
                        {'name': 'سرفيس مقبلات وحمص', 'price': 1500.0, 'icon': ''},
                        {'name': 'لبن أربيل رائب', 'price': 1000.0, 'icon': ''},
                        {'name': 'شوكولاتة نوتيلا', 'price': 1000.0, 'icon': ''},
                        {'name': 'آيس كريم فانيلا', 'price': 1000.0, 'icon': ''},
                      ].map((preset) {
                        final isAlreadyAdded = _addons.any((a) => a['name'] == preset['name']);
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ActionChip(
                            backgroundColor: isAlreadyAdded
                                ? app_colors.primaryColor.withValues(alpha: 0.15)
                                : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: BorderSide(
                              color: isAlreadyAdded ? app_colors.primaryColor : Colors.transparent,
                            ),
                            label: Text(
                              '${preset['icon']} ${preset['name']} (+${(preset['price'] as double).toInt()} د.ع)',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isAlreadyAdded ? app_colors.primaryColor : textPrimary,
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                if (isAlreadyAdded) {
                                  _addons.removeWhere((a) => a['name'] == preset['name']);
                                } else {
                                  _addons.add(Map<String, dynamic>.from(preset));
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Display Added Add-ons
                  if (_addons.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _addons.map((ad) {
                          final aName = ad['name']?.toString() ?? 'إضافة';
                          final aPrice = (ad['price'] as num?)?.toDouble() ?? 0.0;
                          final aIcon = ad['icon']?.toString() ?? '';

                          return Chip(
                            backgroundColor: app_colors.primaryColor.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: app_colors.primaryColor.withValues(alpha: 0.25)),
                            label: Text(
                              '$aIcon $aName: +${aPrice.toInt()} د.ع',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: app_colors.primaryColor,
                              ),
                            ),
                            deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
                            onDeleted: () {
                              setState(() => _addons.remove(ad));
                            },
                          );
                        }).toList(),
                      ),
                    ),

                  // Custom Add-on input
                  Row(
                    children: [
                      // Emoji dropdown/button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          final emojis = ['', '', '', '', '', '', '', '', '', '', '', '', ''];
                          final nextIdx = (emojis.indexOf(_selectedAddonIcon) + 1) % emojis.length;
                          setState(() => _selectedAddonIcon = emojis[nextIdx]);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF2F7F6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(_selectedAddonIcon, style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF2F7F6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TextField(
                            controller: _addonNameController,
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'اسم الإضافة الخاصة',
                              hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: textSecondary.withValues(alpha: 0.6)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF2F7F6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TextField(
                            controller: _addonPriceController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'السعر (د.ع)',
                              hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: textSecondary.withValues(alpha: 0.6)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () {
                          if (_addonNameController.text.trim().isNotEmpty && _addonPriceController.text.trim().isNotEmpty) {
                            final pVal = double.tryParse(_addonPriceController.text.trim()) ?? 0.0;
                            setState(() {
                              _addons.add({
                                'name': _addonNameController.text.trim(),
                                'price': pVal,
                                'icon': _selectedAddonIcon,
                              });
                              _addonNameController.clear();
                              _addonPriceController.clear();
                            });
                            HapticFeedback.lightImpact();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: app_colors.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. Daily Stock Tracking Card
              _buildSectionCard(
                cardBg: cardBg,
                isDark: isDark,
                title: 'تحديد عدد الوجبات المتوفرة لليوم',
                textPrimary: textPrimary,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: app_colors.primaryColor,
                    value: _isStockLimited,
                    onChanged: (val) => setState(() => _isStockLimited = val),
                    title: Text(
                      'أكلة بعدد وحصص محدودة لليوم',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'راح يوكف الطلب عليها تلقائياً من تخلص الكمية',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: textSecondary),
                    ),
                  ),
                  if (_isStockLimited) ...[
                    const SizedBox(height: 8),
                    _buildInputField(
                      controller: _stockController,
                      label: 'شكد وجبات متوفرة لليوم؟',
                      hint: 'مثال: 25 وجبة',
                      icon: Icons.inventory_2_rounded,
                      isNumeric: true,
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 28),

              // 5. Submit Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitMeal,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                label: Text(
                  _isLoading
                      ? 'جاي نحفظ الأكلة بالمنيو...'
                      : (isEditing ? 'حفظ تعديلات الأكلة' : 'ثبّت الأكلة بالمنيو هسة'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: app_colors.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 2,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageUploaderCard(Color cardBg, Color textPrimary, Color textSecondary, bool isDark) {
    final hasImage = _pickedImageBytes != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'صورة الأكلة / الطبق',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textPrimary,
                ),
              ),
              if (hasImage)
                TextButton.icon(
                  onPressed: _showImagePickerSheet,
                  icon: const Icon(Icons.edit_rounded, size: 16, color: app_colors.primaryColor),
                  label: Text(
                    'بدّل الصورة',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: app_colors.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _showImagePickerSheet,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 190,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF2F7F6),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: app_colors.primaryColor.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _pickedImageBytes != null
                    ? Image.memory(
                        _pickedImageBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty
                        ? Image.network(
                            _existingImageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (c, e, s) => _buildPlaceholderPrompt(textSecondary),
                          )
                        : _buildPlaceholderPrompt(textSecondary)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderPrompt(Color textSecondary) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: app_colors.primaryColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add_a_photo_rounded, size: 36, color: app_colors.primaryColor),
        ),
        const SizedBox(height: 10),
        Text(
          'دوس هنا حتى تختار صورة تفتح النفس للأكلة',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: app_colors.primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'من الاستوديو أو طق صورة بالكاميرا',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 11,
            color: textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required Color cardBg,
    required bool isDark,
    required String title,
    required Color textPrimary,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    bool isNumeric = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF2F7F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
        maxLines: maxLines,
        style: GoogleFonts.ibmPlexSansArabic(
          color: textPrimary,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.ibmPlexSansArabic(
            color: textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          hintText: hint,
          hintStyle: GoogleFonts.ibmPlexSansArabic(
            color: textSecondary.withValues(alpha: 0.5),
            fontSize: 11.5,
          ),
          prefixIcon: Icon(icon, color: app_colors.primaryColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
