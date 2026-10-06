import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dalal_alqaim/services/cloudinary_service.dart';
import 'package:dalal_alqaim/services/user_service.dart';

// --- Palette Definition ---
const Color primaryColor = Color(0xFF26A69A);
const Color accentColor = Color(0xFF00796B);
const Color backgroundColor = Color(0xFFFFFFFF);
const Color textColor = Color(0xFF333333);
const Color hintColor = Color(0xFF9E9E9E);
const Color subTextColor = Color(0xFF757575);
const Color surfaceColor = Color(0xFFF8F9FA);

// Dark Theme Colors
const Color darkBackground = Color(0xFFF8FAFB);
const Color darkSurface = Color(0xFF0F2323);
const Color darkCard = Colors.white;
const Color darkText = Color(0xFF2C3E50);
const Color darkSubText = Color(0xFF7F8C8D);
const Color darkHint = Color(0xFFBDC3C7);

class DriverSettingsPage extends StatefulWidget {
  const DriverSettingsPage({super.key});

  @override
  State<DriverSettingsPage> createState() => _DriverSettingsPageState();
}

class _DriverSettingsPageState extends State<DriverSettingsPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _carNumberController = TextEditingController();
  final _carTypeController = TextEditingController();
  final _carColorController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String? _selectedImageFilename;
  String? _currentImageUrl;
  bool _isLoading = false;
  bool _isSaving = false;

  // إعدادات التنبيهات والقبول التلقائي
  bool _soundAlertEnabled = true;
  bool _vibrationAlertEnabled = true;
  bool _autoAcceptEnabled = false;
  double _autoAcceptMaxDistance = 1.5; // كم

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _carNumberController.dispose();
    _carTypeController.dispose();
    _carColorController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};

      final reqDoc = await FirebaseFirestore.instance.collection('driver_requests').doc(uid).get();
      final reqData = reqDoc.data() ?? {};

      final driverDoc = await FirebaseFirestore.instance.collection('drivers').doc(uid).get();
      final driverData = driverDoc.data() ?? {};

      final merged = {...userData, ...reqData, ...driverData};

      _nameController.text = (merged['fullName'] ?? merged['name'] ?? merged['driverName'] ?? merged['userName'] ?? '').toString();
      _phoneController.text = (merged['phone'] ?? merged['phoneNumber'] ?? merged['userPhone'] ?? '').toString();
      _carNumberController.text = (merged['carNumber'] ?? merged['car_number'] ?? merged['plateNumber'] ?? merged['plate_number'] ?? '').toString();
      
      final cType = (merged['carType'] ?? merged['car_type'] ?? '').toString();
      final cModel = (merged['carModel'] ?? merged['car_model'] ?? '').toString();
      _carTypeController.text = (cModel.isNotEmpty && !cType.contains(cModel)) ? '$cType $cModel'.trim() : cType;

      _carColorController.text = (merged['carColor'] ?? merged['car_color'] ?? '').toString();
      _currentImageUrl = (merged['photoUrl'] ?? merged['profileImage'] ?? merged['carImage'] ?? merged['imageUrl'])?.toString();

      _soundAlertEnabled = merged['soundAlertEnabled'] ?? true;
      _vibrationAlertEnabled = merged['vibrationAlertEnabled'] ?? true;
      _autoAcceptEnabled = merged['autoAcceptEnabled'] ?? false;
      _autoAcceptMaxDistance = (merged['autoAcceptMaxDistance'] as num?)?.toDouble() ?? 1.5;

      // Ensure drivers collection is populated with all registered details
      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
        'name': _nameController.text,
        'fullName': _nameController.text,
        'phone': _phoneController.text,
        'carNumber': _carNumberController.text,
        'carType': cType.isNotEmpty ? cType : _carTypeController.text,
        if (cModel.isNotEmpty) 'carModel': cModel,
        'carColor': _carColorController.text,
        if (_currentImageUrl != null) 'photoUrl': _currentImageUrl,
        if (_currentImageUrl != null) 'profileImage': _currentImageUrl,
        if (_currentImageUrl != null) 'carImage': _currentImageUrl,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error loading driver data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageFilename = pickedFile.name;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      String? imageUrl = _currentImageUrl;

      if (_selectedImageBytes != null) {
        final filename =
            _selectedImageFilename ?? 'driver_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final uploadedUrl = await CloudinaryService.uploadBytes(_selectedImageBytes!, filename);
        if (uploadedUrl != null) {
          imageUrl = uploadedUrl;
        }
      }

      final updatedData = {
        'name': _nameController.text.trim(),
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'carNumber': _carNumberController.text.trim(),
        'carType': _carTypeController.text.trim(),
        'carColor': _carColorController.text.trim(),
        'soundAlertEnabled': _soundAlertEnabled,
        'vibrationAlertEnabled': _vibrationAlertEnabled,
        'autoAcceptEnabled': _autoAcceptEnabled,
        'autoAcceptMaxDistance': _autoAcceptMaxDistance,
        if (imageUrl != null) 'photoUrl': imageUrl,
        if (imageUrl != null) 'profileImage': imageUrl,
        if (imageUrl != null) 'carImage': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await Future.wait([
        FirebaseFirestore.instance.collection('drivers').doc(uid).set(updatedData, SetOptions(merge: true)),
        FirebaseFirestore.instance.collection('users').doc(uid).set(updatedData, SetOptions(merge: true)),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ التغييرات بنجاح', style: TextStyle()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الحفظ: $e', style: const TextStyle()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('تسجيل الخروج', style: TextStyle()),
            content: const Text(
              'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
              style: TextStyle(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء', style: TextStyle()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('خروج', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? darkBackground : surfaceColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'حساب الكابتن',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? darkText : textColor,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              tooltip: 'تسجيل الخروج',
            ),
          ],
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryColor))
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildProfileHeader(isDark),
                        const SizedBox(height: 30),
                        _buildSettingsGroup(
                          title: 'المعلومات الشخصية',
                          isDark: isDark,
                          children: [
                            _buildTextField(
                              controller: _nameController,
                              label: 'الاسم الكامل',
                              icon: Icons.person_outline,
                              isDark: isDark,
                              validator: (v) => v!.isEmpty ? 'يرجى إدخال الاسم' : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _phoneController,
                              label: 'رقم الهاتف',
                              icon: Icons.phone_outlined,
                              isDark: isDark,
                              keyboardType: TextInputType.phone,
                              validator: (v) => v!.isEmpty ? 'يرجى إدخال رقم الهاتف' : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildSettingsGroup(
                          title: 'معلومات المركبة',
                          isDark: isDark,
                          children: [
                            _buildTextField(
                              controller: _carTypeController,
                              label: 'نوع السيارة',
                              icon: Icons.directions_car_outlined,
                              isDark: isDark,
                              validator: (v) => v!.isEmpty ? 'يرجى إدخال نوع السيارة' : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _carNumberController,
                              label: 'رقم السيارة',
                              icon: Icons.confirmation_number_outlined,
                              isDark: isDark,
                              validator: (v) => v!.isEmpty ? 'يرجى إدخال رقم السيارة' : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _carColorController,
                              label: 'لون السيارة',
                              icon: Icons.palette_outlined,
                              isDark: isDark,
                              validator: (v) => v!.isEmpty ? 'يرجى إدخال لون السيارة' : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ── مجموعة إعدادات التنبيهات والطلبات ──
                        _buildSettingsGroup(
                          title: 'إعدادات التنبيهات والمشاوير',
                          isDark: isDark,
                          children: [
                            SwitchListTile.adaptive(
                              title: const Text('نغمة رنين الطلب الجديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: const Text('تشغيل صوت تنبيه مستمر عند وصول طلب مشوار جديد', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              value: _soundAlertEnabled,
                              activeThumbColor: primaryColor,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) => setState(() => _soundAlertEnabled = v),
                            ),
                            const Divider(height: 16),
                            SwitchListTile.adaptive(
                              title: const Text('اهتزاز الهاتف القوي (Haptic)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: const Text('اهتزاز متكرر أثناء ظهور شاشة العد التنازلي للطلب', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              value: _vibrationAlertEnabled,
                              activeThumbColor: primaryColor,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) => setState(() => _vibrationAlertEnabled = v),
                            ),
                            const Divider(height: 16),
                            SwitchListTile.adaptive(
                              title: const Text('القبول التلقائي للمشاوير القريبة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: const Text('قبول الطلبات القريبة منك تلقائياً أثناء القيادة', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              value: _autoAcceptEnabled,
                              activeThumbColor: primaryColor,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) => setState(() => _autoAcceptEnabled = v),
                            ),
                            if (_autoAcceptEnabled) ...[
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('نطاق المسافة للقبول التلقائي:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  Text('${_autoAcceptMaxDistance.toStringAsFixed(1)} كم ', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 12)),
                                ],
                              ),
                              Slider(
                                value: _autoAcceptMaxDistance,
                                min: 0.5,
                                max: 5.0,
                                divisions: 9,
                                activeColor: primaryColor,
                                label: '${_autoAcceptMaxDistance.toStringAsFixed(1)} كم',
                                onChanged: (v) => setState(() => _autoAcceptMaxDistance = v),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 30),
                        _buildSaveButton(isDark),
                        const SizedBox(height: 16),
                        _buildLogoutButton(isDark),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isDark) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primaryColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipOval(
                child:
                    _selectedImageBytes != null
                        ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                        : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                        ? Image.network(_currentImageUrl!, fit: BoxFit.cover)
                        : Container(
                          color: isDark ? darkCard : Colors.white,
                          child: const Icon(Icons.person, size: 60, color: primaryColor),
                        ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _nameController.text,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? darkText : textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsGroup({
    required String title,
    required List<Widget> children,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? darkSubText : subTextColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: isDark ? darkText : textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? darkSubText : subTextColor),
        prefixIcon: Icon(icon, color: primaryColor, size: 22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor),
        ),
        filled: true,
        fillColor: isDark ? darkBackground.withValues(alpha: 0.3) : surfaceColor.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildSaveButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child:
            _isSaving
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                : const Text(
                  'حفظ التغييرات',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
    );
  }

  Widget _buildLogoutButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _confirmLogout,
        icon: const Icon(Icons.logout_rounded, color: Color(0xFFE53935), size: 20),
        label: const Text(
          'تسجيل الخروج من الحساب',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE53935),
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE53935), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج من حساب الكابتن؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await UserService.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}
