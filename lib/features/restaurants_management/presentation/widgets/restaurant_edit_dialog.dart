import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../services/cloudinary_service.dart';
import '../../domain/entities/restaurant_management_models.dart';

/// نافذة تعديل بيانات المطعم ورفع الشعار (Restaurant Edit Dialog)
class RestaurantEditDialog extends StatefulWidget {
  final RestaurantRecord restaurant;
  final Future<bool> Function({
    required RestaurantRecord restaurant,
    required String name,
    required String imageUrl,
    required String status,
  }) onSave;

  const RestaurantEditDialog({
    super.key,
    required this.restaurant,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required RestaurantRecord restaurant,
    required Future<bool> Function({
      required RestaurantRecord restaurant,
      required String name,
      required String imageUrl,
      required String status,
    }) onSave,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RestaurantEditDialog(restaurant: restaurant, onSave: onSave),
    );
  }

  @override
  State<RestaurantEditDialog> createState() => _RestaurantEditDialogState();
}

class _RestaurantEditDialogState extends State<RestaurantEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _imageController;
  late final TextEditingController _statusController;

  Uint8List? _localImageBytes;
  String? _localImageFilename;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.restaurant.name);
    _imageController = TextEditingController(text: widget.restaurant.imageUrl);
    _statusController = TextEditingController(text: widget.restaurant.status);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imageController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit, color: Colors.teal),
          ),
          const SizedBox(width: 12),
          Text(
            'تعديل بيانات المطعم',
            style: TextStyle(fontSize: 18, color: textColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image Picker Section
            GestureDetector(
              onTap: _isSaving
                  ? null
                  : () async {
                      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1000);
                      if (picked != null) {
                        final bytes = await picked.readAsBytes();
                        setState(() {
                          _localImageBytes = bytes;
                          _localImageFilename = picked.name;
                        });
                      }
                    },
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.teal.withValues(alpha: 0.3), width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _localImageBytes != null
                          ? Image.memory(
                              _localImageBytes!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            )
                          : (_imageController.text.isNotEmpty
                              ? Image.network(
                                  _imageController.text,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.storefront_rounded,
                                    size: 50,
                                    color: Colors.grey.shade400,
                                  ),
                                )
                              : Icon(
                                  Icons.add_a_photo_rounded,
                                  size: 40,
                                  color: Colors.teal.shade400,
                                )),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.6),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: const Text(
                          'تغيير الشعار',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              enabled: !_isSaving,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'اسم المطعم',
                labelStyle: const TextStyle(),
                prefixIcon: const Icon(Icons.restaurant, color: Colors.teal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _imageController,
              enabled: !_isSaving,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'رابط الشعار (تحديث تلقائي عند رفع صورة)',
                labelStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.link, color: Colors.teal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _statusController,
              enabled: !_isSaving,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'الحالة',
                labelStyle: const TextStyle(),
                prefixIcon: const Icon(Icons.info_outline, color: Colors.teal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              ),
            ),
            if (_isSaving) ...[
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: Colors.teal),
              const SizedBox(height: 8),
              const Text(
                'جاري رفع الصورة وحفظ التعديلات...',
                style: TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle()),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('حفظ التعديلات', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      String finalImageUrl = _imageController.text.trim();
      if (_localImageBytes != null && _localImageFilename != null) {
        final uploadedUrl = await CloudinaryService.uploadBytes(
          _localImageBytes!,
          _localImageFilename!,
        );
        if (uploadedUrl != null) {
          finalImageUrl = uploadedUrl;
        }
      }

      final success = await widget.onSave(
        restaurant: widget.restaurant,
        name: _nameController.text.trim(),
        imageUrl: finalImageUrl,
        status: _statusController.text.trim(),
      );

      if (!mounted) return;
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('تم تعديل بيانات المطعم بنجاح!', style: TextStyle()),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.fixed,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء حفظ التعديلات: $e', style: const TextStyle()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
