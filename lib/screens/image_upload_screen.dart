import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/cloudinary_service.dart';

class ImageUploadScreen extends StatefulWidget {
  const ImageUploadScreen({super.key});

  @override
  State<ImageUploadScreen> createState() => _ImageUploadScreenState();
}

class _ImageUploadScreenState extends State<ImageUploadScreen> {
  Uint8List? _selectedImageBytes;
  String? _selectedImageFilename;
  bool _isUploading = false;
  String? _uploadedImageUrl;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageFilename = pickedFile.name.isNotEmpty ? pickedFile.name : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImageBytes == null) return;

    setState(() {
      _isUploading = true;
    });

    final bytes = _selectedImageBytes!;
    final filename = _selectedImageFilename ?? 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final imageUrl = await CloudinaryService.uploadBytes(bytes, filename);

    if (imageUrl != null) {
      setState(() {
        _uploadedImageUrl = imageUrl;
      });

      // حفظ الرابط في Firestore
      await FirebaseFirestore.instance.collection('images').add({
        'url': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم رفع الصورة وحفظ الرابط بنجاح')));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل رفع الصورة')));
      }
    }

    setState(() {
      _isUploading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('رفع صورة إلى Cloudinary')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_selectedImageBytes != null)
              SizedBox(height: 200, child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover))
            else
              const Text('لم يتم اختيار صورة بعد'),

            const SizedBox(height: 16),

            ElevatedButton(onPressed: _pickImage, child: const Text('اختيار صورة من المعرض')),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _isUploading ? null : _uploadImage,
              child:
                  _isUploading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('رفع الصورة'),
            ),

            const SizedBox(height: 24),

            if (_uploadedImageUrl != null)
              Column(
                children: [
                  const Text('الصورة المرفوعة:'),
                  const SizedBox(height: 8),
                  SizedBox(height: 200, child: Image.network(_uploadedImageUrl!)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
