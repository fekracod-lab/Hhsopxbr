import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dalal_alqaim/services/cloudinary_service.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _vehicleController;
  
  String? _photoUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  File? _localImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _vehicleController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final reqDoc = await FirebaseFirestore.instance.collection('driver_requests').doc(user.uid).get();
      final driverDoc = await FirebaseFirestore.instance.collection('drivers').doc(user.uid).get();
      
      final userData = userDoc.data() ?? {};
      final reqData = reqDoc.data() ?? {};
      final driverData = driverDoc.data() ?? {};

      final merged = {...userData, ...reqData, ...driverData};

      if (mounted) {
        setState(() {
          _nameController.text = (merged['fullName'] ?? merged['name'] ?? merged['driverName'] ?? '').toString();
          _phoneController.text = (merged['phone'] ?? merged['phoneNumber'] ?? '').toString();
          _photoUrl = (merged['photoUrl'] ?? merged['profilePicture'] ?? merged['imageUrl'])?.toString();
          
          final vType = (merged['vehicleType'] ?? merged['carType'] ?? '').toString();
          final vModel = (merged['vehicleModel'] ?? merged['carModel'] ?? '').toString();
          final vPlate = (merged['plateNumber'] ?? merged['carNumber'] ?? '').toString();
          
          String vInfo = (merged['vehicleInfo'] ?? '').toString();
          if (vInfo.isEmpty) {
            vInfo = '$vType $vModel $vPlate'.trim();
          }
          _vehicleController.text = vInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() => _localImage = File(image.path));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      String? finalPhotoUrl = _photoUrl;

      // 1. Upload image if changed
      if (_localImage != null) {
        final bytes = await _localImage!.readAsBytes();
        final uploadedUrl = await CloudinaryService.uploadBytes(bytes, 'profile_${user.uid}');
        if (uploadedUrl != null) {
          finalPhotoUrl = uploadedUrl;
        }
      }

      final updatePayload = {
        'name': _nameController.text.trim(),
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        if (finalPhotoUrl != null) 'photoUrl': finalPhotoUrl,
        if (finalPhotoUrl != null) 'profilePicture': finalPhotoUrl,
        'vehicleInfo': _vehicleController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Update both Users and Drivers collection safely with merge
      await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(user.uid).set(updatePayload, SetOptions(merge: true)),
        FirebaseFirestore.instance.collection('drivers').doc(user.uid).set(updatePayload, SetOptions(merge: true)),
      ]);
      
      // Update Firebase Auth Display Name/Photo if possible
      await user.updateDisplayName(_nameController.text.trim());
      if (finalPhotoUrl != null) await user.updatePhotoURL(finalPhotoUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث الملف الشخصي بنجاح', style: TextStyle()), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e', style: const TextStyle()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تعديل الملف الشخصي', style: TextStyle()),
          centerTitle: true,
        ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Photo Upload Section
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                        image: _localImage != null 
                          ? DecorationImage(image: FileImage(_localImage!), fit: BoxFit.cover)
                          : (_photoUrl != null 
                              ? DecorationImage(image: NetworkImage(_photoUrl!), fit: BoxFit.cover)
                              : null),
                      ),
                      child: (_localImage == null && _photoUrl == null)
                          ? const Icon(Icons.person, size: 60, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildTextField(
                controller: _nameController,
                label: 'الاسم الكامل',
                icon: Icons.person_outline,
                validator: (v) => v!.isEmpty ? 'يرجى إدخال الاسم' : null,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _phoneController,
                label: 'رقم الهاتف',
                icon: Icons.phone_android_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'يرجى إدخال رقم الهاتف' : null,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _vehicleController,
                label: 'معلومات المركبة (نوع، لون، رقم)',
                icon: Icons.delivery_dining_outlined,
                validator: (v) => v!.isEmpty ? 'يرجى إدخال معلومات المركبة' : null,
              ),
              
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: _isSaving 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('حفظ التعديلات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      textAlign: TextAlign.right,
      style: const TextStyle(fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
        filled: true,
        fillColor: (Colors.grey[50] ?? Colors.grey).withValues(alpha: 0.5),
      ),
    );
  }
}
