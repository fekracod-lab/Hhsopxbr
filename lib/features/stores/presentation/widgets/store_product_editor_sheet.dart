import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import '../../domain/entities/store_dashboard_models.dart';

/// ورقة تعديل وإضافة المنتج (Store Product Editor Bottom Sheet)
/// نموذج إدخال نقي لإضافة أو تعديل منتج وتحديد تصنيفه وسعره وصورته
class StoreProductEditorSheet extends StatefulWidget {
  final StoreProductEntity? initialProduct;
  final List<StoreCategoryEntity> categories;
  final bool isDark;
  final Future<String?> Function()? onPickAndUploadImage;
  final Function({
    required String name,
    required double price,
    required String description,
    required String category,
    required String imageUrl,
    required bool isAvailable,
  }) onSave;

  const StoreProductEditorSheet({
    super.key,
    this.initialProduct,
    required this.categories,
    required this.isDark,
    this.onPickAndUploadImage,
    required this.onSave,
  });

  @override
  State<StoreProductEditorSheet> createState() => _StoreProductEditorSheetState();
}

class _StoreProductEditorSheetState extends State<StoreProductEditorSheet> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _descController;
  String? _selectedImageUrl;
  String? _selectedCategory;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProduct?.name ?? '');
    _priceController = TextEditingController(
      text: widget.initialProduct != null ? widget.initialProduct!.price.toInt().toString() : '',
    );
    _descController = TextEditingController(text: widget.initialProduct?.description ?? '');
    _selectedImageUrl = widget.initialProduct?.imageUrl;
    _selectedCategory = widget.initialProduct?.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleImagePick() async {
    if (widget.onPickAndUploadImage == null || _isUploadingImage) return;
    setState(() => _isUploadingImage = true);
    try {
      final url = await widget.onPickAndUploadImage!();
      if (url != null && mounted) {
        setState(() => _selectedImageUrl = url);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catNames = widget.categories.map((c) => c.name).toSet().toList();
    if (catNames.isEmpty) {
      catNames.add('عام');
    }

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1D26) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
      ),
      padding: EdgeInsets.fromLTRB(
        24.w,
        16.h,
        24.w,
        MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              widget.initialProduct == null ? 'إضافة منتج جديد' : 'تعديل المنتج',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18.sp,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 20.h),
            // Image Picker Box
            GestureDetector(
              onTap: _handleImagePick,
              child: Container(
                width: 100.r,
                height: 100.r,
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? Colors.white10
                      : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: _isUploadingImage
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                          strokeWidth: 2,
                        ),
                      )
                    : _selectedImageUrl != null && _selectedImageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20.r),
                            child: Image.network(
                              _selectedImageUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_rounded,
                                    color: Colors.grey,
                                    size: 28.sp,
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'صورة المنتج',
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
              ),
            ),
            SizedBox(height: 20.h),
            _buildTextField(
              controller: _nameController,
              label: 'اسم المنتج',
              icon: Icons.label_rounded,
            ),
            SizedBox(height: 12.h),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory != null &&
                      catNames.contains(_selectedCategory)
                  ? _selectedCategory
                  : (catNames.isNotEmpty ? catNames.first : null),
              items: catNames
                  .map(
                    (c) => DropdownMenuItem<String>(
                      value: c,
                      child: Text(
                        c,
                        style: const TextStyle(),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
              decoration: InputDecoration(
                labelText: 'القسم',
                labelStyle: const TextStyle(),
                prefixIcon: const Icon(Icons.category_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 14.h,
                ),
              ),
            ),
            SizedBox(height: 12.h),
            _buildTextField(
              controller: _priceController,
              label: 'السعر (د.ع)',
              icon: Icons.monetization_on_rounded,
              isNumber: true,
            ),
            SizedBox(height: 12.h),
            _buildTextField(
              controller: _descController,
              label: 'وصف المنتج (اختياري)',
              icon: Icons.description_rounded,
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: () {
                  if (_nameController.text.trim().isEmpty ||
                      _priceController.text.trim().isEmpty) {
                    return;
                  }
                  final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
                  widget.onSave(
                    name: _nameController.text.trim(),
                    price: price,
                    description: _descController.text.trim(),
                    category: _selectedCategory ?? (catNames.isNotEmpty ? catNames.first : 'عام'),
                    imageUrl: _selectedImageUrl ?? '',
                    isAvailable: widget.initialProduct?.isAvailable ?? true,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  widget.initialProduct == null ? 'إضافة المنتج' : 'حفظ التعديلات',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(),
        prefixIcon: Icon(icon, size: 20.sp),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r)),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      ),
    );
  }
}
