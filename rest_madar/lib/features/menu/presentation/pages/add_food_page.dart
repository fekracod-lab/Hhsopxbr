import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../services/cloudinary_service.dart';
import '../../../../services/firestore_sync_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

// --- Premium Light Turquoise Theme Palette ---
const Color _primary = Color(0xFF26A69A); // Vibrant Teal/Turquoise
const Color _accent = Color(0xFF00796B); // Deep Teal
const Color _lightBg = Color(0xFFF5F9F9); // Soft light turquoise background
const Color _textPrimary = Color(0xFF07191A); // Deep charcoal/teal text
const Color _textSecondary = Color(0xFF5A7375); // Slate grey-teal secondary text
const Color _cardBg = Colors.white; // Pure white card background

class AddFoodPage extends StatefulWidget {
  const AddFoodPage({super.key});

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  Uint8List? _pickedImageBytes;
  String? _pickedImageFilename;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isPickingImage = false;

  List<String> _categories = [];
  String _selectedCategory = '';

  // Advanced features state
  final List<Map<String, dynamic>> _sizes = [];
  final TextEditingController _sizeNameController = TextEditingController();
  final TextEditingController _sizePriceController = TextEditingController();

  bool _isStockLimited = false;
  final TextEditingController _stockController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomCategories();
  }

  Future<void> _loadCustomCategories() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      String activeId = uid;
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final rId = (userDoc.data()!['restaurantId'] ?? userDoc.data()!['merchantId'] ?? userDoc.data()!['storeId'] ?? userDoc.data()!['branchId'])?.toString().trim() ?? '';
          if (rId.isNotEmpty) activeId = rId;
        }
      } catch (_) {}

      final List<String> loaded = [];
      final doc = await FirebaseFirestore.instance.collection('restaurants').doc(activeId).get();
      if (doc.exists && doc.data()?['categories'] != null) {
        final List<dynamic> cats = doc.data()?['categories'];
        for (var c in cats) {
          final s = c.toString().trim();
          if (s.isNotEmpty && !loaded.contains(s)) loaded.add(s);
        }
      }

      try {
        final mc = await FirebaseFirestore.instance.collection('merchant_categories').doc(activeId).collection('categories').get();
        for (var d in mc.docs) {
          final s = (d.data()['name'] ?? '').toString().trim();
          if (s.isNotEmpty && !loaded.contains(s)) loaded.add(s);
        }
      } catch (_) {}

      try {
        final mp = await FirebaseFirestore.instance.collection('merchant_products').doc(activeId).collection('categories').get();
        for (var d in mp.docs) {
          final s = (d.data()['name'] ?? '').toString().trim();
          if (s.isNotEmpty && !loaded.contains(s)) loaded.add(s);
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _categories = loaded;
          if (_selectedCategory.isEmpty || !_categories.contains(_selectedCategory)) {
            _selectedCategory = _categories.isNotEmpty ? _categories.first : '';
          }
        });
      }
    } catch (_) {}
  }

  void _showQuickAddCategoryDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة قسم جديد للمنيو'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'اسم القسم (مثلاً: مشاوي، برغر، مقبلات)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                setState(() {
                  if (!_categories.contains(val)) _categories.add(val);
                  _selectedCategory = val;
                });
                try {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    await FirebaseFirestore.instance.collection('restaurants').doc(uid).set({
                      'categories': FieldValue.arrayUnion([val]),
                    }, SetOptions(merge: true));
                  }
                } catch (_) {}
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }


  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _imageController.dispose();
    _sizeNameController.dispose();
    _sizePriceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickFoodImage() async {
    if (_isPickingImage) return;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'صورة الوجبة/الطبق',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _sourceButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'الكاميرا',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromSource(ImageSource.camera);
                    },
                  ),
                  _sourceButton(
                    icon: Icons.photo_library_rounded,
                    label: 'المعرض',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromSource(ImageSource.gallery);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _primary.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, color: _primary, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    setState(() => _isPickingImage = true);
    try {
      final XFile? picked = await _picker.pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _pickedImageBytes = bytes;
          _pickedImageFilename = picked.name.isNotEmpty
              ? picked.name
              : 'meal_${DateTime.now().millisecondsSinceEpoch}.jpg';
          _imageController.text = ''; // clear manual URL
        });
      }
    } catch (_) {
      _showError('عذراً، فشل التقاط أو تحديد صورة الوجبة.');
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw 'سجّل دخولك أولاً';

      String? imageUrlToUse;
      if (_pickedImageBytes != null) {
        final bytes = _pickedImageBytes!;
        final filename = _pickedImageFilename ?? 'meal_${DateTime.now().millisecondsSinceEpoch}.jpg';

        // Direct Cloudinary Upload
        imageUrlToUse = await CloudinaryService.uploadBytes(bytes, filename);
        if (imageUrlToUse == null) {
          throw 'فشل رفع صورة الوجبة إلى خادم الصور. يرجى التحقق من اتصال الإنترنت.';
        }
      }
      imageUrlToUse ??= _imageController.text.isNotEmpty ? _imageController.text.trim() : null;

      if (imageUrlToUse == null) {
        throw 'يرجى اختيار صورة للوجبة أو إدخال رابط صورة';
      }

      final price = double.tryParse(_priceController.text) ?? 0.0;
      final stockValue = _isStockLimited ? (int.tryParse(_stockController.text) ?? 10) : 0;

      final mealData = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'wholesalePrice': 0.0, // Added directly by merchant
        'sellingPrice': price,
        'price': price, // حقل السعر الذي يقرأه التطبيق الرئيسي
        'category': _selectedCategory, // القسم المختار
        'isAvailable': true, // متوفر تلقائياً عند الإضافة
        'imageUrl': imageUrlToUse,
        'createdAt': FieldValue.serverTimestamp(),
        // Advanced fields
        'sizes': _sizes,
        'isStockLimited': _isStockLimited,
        'stockLimit': stockValue,
        'stockCount': stockValue,
        'isPromoActive': false,
        'discountPercentage': 0.0,
        'promoExpiryMs': 0,
      };

      // Add to Firestore merchant_products
      final docRef = await FirebaseFirestore.instance
          .collection('merchant_products')
          .doc(uid)
          .collection('products')
          .add(mealData);

      // Sync to main customer stores collection
      try {
        await FirebaseFirestore.instance
            .collection('stores')
            .doc(uid)
            .collection('products')
            .doc(docRef.id)
            .set(mealData);
      } catch (e) {
        debugPrint('خطأ في المزامنة مع المتجر: $e');
      }

      // Sync to sections/{sectionId}/items/{itemId}/menu
      try {
        await FirestoreSyncService.syncAddOrSetMeal(uid, docRef.id, mealData);
      } catch (e) {
        debugPrint('خطأ في المزامنة مع قسم المطاعم: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إضافة الوجبة بنجاح إلى قائمتك!',
            style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ: $error',
            style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: ThemeData.light().copyWith(
          textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(ThemeData.light().textTheme),
        ),
        child: Scaffold(
          backgroundColor: _lightBg,
          appBar: AppBar(
            backgroundColor: _cardBg,
            elevation: 0.5,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'إضافة وجبة جديدة',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 18, color: _textPrimary),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            physics: const BouncingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Preview
                  Center(
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _primary.withValues(alpha: 0.15), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.04),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: (_pickedImageBytes != null)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.memory(
                                _pickedImageBytes!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : (_imageController.text.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.network(
                                    _imageController.text,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Icon(
                                      Icons.image_not_supported,
                                      size: 50,
                                      color: _textSecondary,
                                    ),
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_a_photo_rounded, size: 40, color: _primary),
                                    const SizedBox(height: 8),
                                    Text(
                                      'اختر صورة من المعرض/الكاميرا أو أدخل رابطًا أدناه',
                                      style: GoogleFonts.ibmPlexSansArabic(color: _textSecondary, fontSize: 12.5, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                )),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Pick Image Buttons
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isPickingImage ? null : _pickFoodImage,
                        icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 18),
                        label: Text('اختيار صورة الطبق', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          elevation: 1.5,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_pickedImageBytes != null)
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _pickedImageBytes = null;
                            });
                          },
                          icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                          label: Text('إزالة', style: GoogleFonts.ibmPlexSansArabic(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildTextField(
                    controller: _nameController,
                    label: 'اسم الوجبة/الطبق',
                    hint: 'مثال: شاورما لحم دبل',
                    icon: Icons.fastfood_rounded,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _priceController,
                    label: 'السعر للزبون (د.ع)',
                    hint: 'مثال: 6000',
                    icon: Icons.attach_money_rounded,
                    isNumeric: true,
                  ),
                  const SizedBox(height: 16),

                  // Category Selector Dropdown
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7F7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _primary.withValues(alpha: 0.05)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            dropdownColor: _cardBg,
                            initialValue: _categories.contains(_selectedCategory) ? _selectedCategory : (_categories.isNotEmpty ? _categories.first : null),
                            hint: Text(
                              _categories.isEmpty ? 'لا توجد أقسام مسجلة (انقر زر + للإضافة)' : 'اختر قسم الوجبة',
                              style: GoogleFonts.ibmPlexSansArabic(color: _textSecondary, fontSize: 13),
                            ),
                            decoration: InputDecoration(
                              labelText: 'قسم الوجبة',
                              labelStyle: GoogleFonts.ibmPlexSansArabic(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                              prefixIcon: const Icon(Icons.category_rounded, color: _primary, size: 20),
                              border: InputBorder.none,
                            ),
                      style: GoogleFonts.ibmPlexSansArabic(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                      items: _categories
                          .map((cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat, style: GoogleFonts.ibmPlexSansArabic(fontSize: 13.5)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _selectedCategory = v;
                          });
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: _primary),
                    tooltip: 'إضافة قسم جديد',
                    onPressed: _showQuickAddCategoryDialog,
                  ),
                ],
              ),
            ),
                  const SizedBox(height: 20),

                  // Sizes Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الأحجام والأوزان المتاحة (اختياري) ',
                        style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Display added sizes as small chips
                  if (_sizes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _sizes.map((sz) {
                          return Chip(
                            backgroundColor: _primary.withValues(alpha: 0.05),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: BorderSide(color: _primary.withValues(alpha: 0.12)),
                            label: Text(
                              '${sz['sizeName']}: ${sz['price']} د.ع',
                              style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: _primary),
                            ),
                            deleteIcon: const Icon(Icons.cancel_rounded, size: 14, color: Colors.redAccent),
                            onDeleted: () {
                              setState(() {
                                _sizes.remove(sz);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),

                  // Add Size Row input fields
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F7F7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _sizeNameController,
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: _textPrimary),
                            decoration: InputDecoration(
                              hintText: 'اسم الحجم (مثال: صغير)',
                              hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: _textSecondary.withValues(alpha: 0.5)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F7F7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _sizePriceController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: _textPrimary),
                            decoration: InputDecoration(
                              hintText: 'السعر (مثال: 3000)',
                              hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: _textSecondary.withValues(alpha: 0.5)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          if (_sizeNameController.text.isNotEmpty && _sizePriceController.text.isNotEmpty) {
                            final pVal = double.tryParse(_sizePriceController.text) ?? 0.0;
                            setState(() {
                              _sizes.add({
                                'sizeName': _sizeNameController.text.trim(),
                                'price': pVal,
                              });
                              _sizeNameController.clear();
                              _sizePriceController.clear();
                            });
                            HapticFeedback.lightImpact();
                          }
                        },
                        icon: const Icon(Icons.add_circle_rounded, color: _primary, size: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Stock Tracker Section
                  Row(
                    children: [
                      Checkbox(
                        value: _isStockLimited,
                        activeColor: _primary,
                        onChanged: (val) {
                          setState(() {
                            _isStockLimited = val ?? false;
                          });
                        },
                      ),
                      Text(
                        'وجبة ذات مخزون محدود لليوم ',
                        style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary),
                      ),
                    ],
                  ),
                  if (_isStockLimited)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F7F7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _primary.withValues(alpha: 0.05)),
                        ),
                        child: TextField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.ibmPlexSansArabic(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            labelText: 'المخزون والكمية المتاحة (عدد الحصص)',
                            labelStyle: GoogleFonts.ibmPlexSansArabic(color: _textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                            hintText: 'مثال: 15',
                            hintStyle: GoogleFonts.ibmPlexSansArabic(color: _textSecondary.withValues(alpha: 0.4), fontSize: 11.5),
                            prefixIcon: const Icon(Icons.inventory_2_rounded, color: _primary, size: 18),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _imageController,
                    label: 'رابط صورة الوجبة مباشر (اختياري)',
                    hint: 'https://example.com/image.jpg',
                    icon: Icons.link_rounded,
                    onChanged: (val) {
                      if (val.isNotEmpty && _pickedImageBytes != null) {
                        setState(() {
                          _pickedImageBytes = null;
                        });
                      } else {
                        setState(() {});
                      }
                    },
                    requiredField: false,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _descController,
                    label: 'الوصف والمكونات',
                    hint: 'اكتب تفاصيل ومكونات الوجبة هنا...',
                    icon: Icons.description_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 40),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: _isLoading
                            ? null
                            : const LinearGradient(colors: [_primary, _accent]),
                        color: _isLoading ? Colors.grey[300] : null,
                        boxShadow: _isLoading
                            ? null
                            : [
                                BoxShadow(
                                  color: _primary.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isLoading ? null : _submitData,
                          borderRadius: BorderRadius.circular(16),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: _primary,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    'إضافة الوجبة لقائمتي',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumeric = false,
    int maxLines = 1,
    bool requiredField = true,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: _primary.withValues(alpha: 0.05)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        onChanged: onChanged,
        validator: requiredField
            ? (v) => (v == null || v.isEmpty) ? 'هذا الحقل مطلوب إدخاله' : null
            : null,
        style: GoogleFonts.ibmPlexSansArabic(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
        cursorColor: _primary,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.ibmPlexSansArabic(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
          hintText: hint,
          hintStyle: GoogleFonts.ibmPlexSansArabic(color: _textSecondary.withValues(alpha: 0.4), fontSize: 12),
          prefixIcon: Icon(icon, color: _primary.withValues(alpha: 0.6), size: 20),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
        ),
      ),
    );
  }
}
