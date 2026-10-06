import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dalal_alqaim/services/cloudinary_service.dart';
import 'package:dalal_alqaim/services/onesignal_service.dart';
import 'package:dalal_alqaim/features/auth/widgets/iraqi_phone_input_field.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/delivery_registration_status_page.dart';
import 'package:dalal_alqaim/features/auth/widgets/otp_verification_dialog.dart';
import 'package:dalal_alqaim/services/ahyxi_otp_service.dart';
import 'package:dalal_alqaim/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dalal_alqaim/constants/iraq_geography.dart';

class DeliveryRegisterPage extends StatefulWidget {
  const DeliveryRegisterPage({super.key});

  @override
  State<DeliveryRegisterPage> createState() => _DeliveryRegisterPageState();
}

class _DeliveryRegisterPageState extends State<DeliveryRegisterPage> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // Form Keys
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();
  final _step4Key = GlobalKey<FormState>();

  // Controllers Step 1: Personal Info
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoFilename;
  bool _isVerifyingPhone = false;
  bool _isPhoneVerified = false;
  String? _verifiedPhone;

  // Controllers Step 2: Vehicle & Delivery Info
  String? _selectedVehicleType = 'دراجة نارية (موتور)';
  final _vehicleModelController = TextEditingController();
  final _plateNumberController = TextEditingController();

  // Controllers Step 3: Location
  String? _selectedGovId;
  String? _selectedGovName;
  String? _selectedRegId;
  String? _selectedRegName;
  List<Map<String, dynamic>> _governorates = [];
  List<Map<String, dynamic>> _regions = [];
  bool _isLoadingLocations = true;

  // Controllers Step 4: Security
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreeToTerms = false;
  bool _isSubmitting = false;

  final Color _primary = const Color(0xFF10B981); // Emerald Logistics Green

  @override
  void initState() {
    super.initState();
    _loadGovernorates();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleModelController.dispose();
    _plateNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadGovernorates() async {
    List<Map<String, dynamic>> list = [];
    try {
      final snap = await FirebaseFirestore.instance.collection('governorates').get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final name = (data['name'] ?? data['title'] ?? doc.id).toString().trim();
        if (name.isNotEmpty) {
          list.add({'id': doc.id, 'name': name});
        }
      }
    } catch (_) {}

    if (list.isEmpty) {
      list = kIraqiGovernorates.map((g) => {'id': g, 'name': g}).toList();
    }

    if (mounted) {
      setState(() {
        _governorates = list;
        _isLoadingLocations = false;
        if (_selectedGovId == null && list.isNotEmpty) {
          final defaultGov = list.any((g) => g['name'] == 'الأنبار')
              ? list.firstWhere((g) => g['name'] == 'الأنبار')
              : list.first;
          _selectedGovId = defaultGov['id'].toString();
          _selectedGovName = defaultGov['name'].toString();
          _loadRegions(_selectedGovId!);
        }
      });
    }
  }

  Future<void> _loadRegions(String govId) async {
    List<Map<String, dynamic>> list = [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('governorates')
          .doc(govId)
          .collection('regions')
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final name = (data['name'] ?? data['title'] ?? doc.id).toString().trim();
        if (name.isNotEmpty) {
          list.add({'id': doc.id, 'name': name});
        }
      }
    } catch (_) {}

    if (list.isEmpty) {
      final defaults = getRegionsForGovernorate(_selectedGovName ?? govId);
      list = defaults.map((r) => {'id': r, 'name': r}).toList();
    }

    if (mounted) {
      setState(() {
        _regions = list;
        if (list.isNotEmpty) {
          _selectedRegId = list.first['id'].toString();
          _selectedRegName = list.first['name'].toString();
        } else {
          _selectedRegId = null;
          _selectedRegName = null;
        }
      });
    }
  }

  Future<bool> _verifyPhoneOtp() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty || rawPhone.length < 10) {
      _showError('يرجى إدخال رقم هاتف عراقي صالح للإكمال');
      return false;
    }

    final formattedPhone = AhyxiOtpService.formatIraqiPhoneNumber(rawPhone);

    if (_isPhoneVerified && _verifiedPhone == formattedPhone) {
      return true;
    }

    setState(() => _isVerifyingPhone = true);

    try {
      final check = await UserService.checkPhoneRegistration(formattedPhone);
      if (check != null && check['exists'] == true) {
        setState(() => _isVerifyingPhone = false);
        _showError('رقم الهاتف مسجل بالفعل مسبقاً في منصة مدار، سجّل دخولك أولاً أو استخدام رقم آخر.');
        return false;
      }

      final sendRes = await AhyxiOtpService.sendOtp(phoneNumber: formattedPhone);
      setState(() => _isVerifyingPhone = false);

      if (!sendRes.isSuccess) {
        _showError(sendRes.message.isNotEmpty ? sendRes.message : 'ما قدرنا نرسل رمز التحقق حالياً');
        return false;
      }

      if (!mounted) return false;

      final verified = await OtpVerificationDialog.show(
        context: context,
        phoneNumber: formattedPhone,
        userName: _nameController.text.trim(),
        userRole: 'delivery',
      );

      if (verified == true) {
        if (!mounted) return true;
        setState(() {
          _isPhoneVerified = true;
          _verifiedPhone = formattedPhone;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم التحقق من رقم الهاتف بنجاح', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
          ),
        );
        return true;
      }
      return false;
    } catch (e) {
      setState(() => _isVerifyingPhone = false);
      _showError('حدث خطأ أثناء التحقق: $e');
      return false;
    }
  }

  Future<void> _nextStep() async {
    if (_validateCurrentStep()) {
      if (_currentStep == 0) {
        final formattedPhone = AhyxiOtpService.formatIraqiPhoneNumber(_phoneController.text.trim());
        if (!_isPhoneVerified || _verifiedPhone != formattedPhone) {
          final verified = await _verifyPhoneOtp();
          if (!verified) return;
        }
      }

      if (_currentStep < 3) {
        setState(() => _currentStep++);
        _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      } else {
        _submitRegistration();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_selectedPhotoBytes == null) {
          _showError('يرجى تحميل الصورة الشخصية لمندوب التوصيل (إجباري) *');
          return false;
        }
        return _step1Key.currentState?.validate() ?? false;
      case 1:
        if (_selectedVehicleType == null) {
          _showError('يرجى تحديد نوع وسيلة التوصيل');
          return false;
        }
        return _step2Key.currentState?.validate() ?? false;
      case 2:
        if (_selectedGovId == null) {
          _showError('يرجى اختيار المحافظة');
          return false;
        }
        if (_selectedRegId == null) {
          _showError('يرجى اختيار المنطقة');
          return false;
        }
        return _step3Key.currentState?.validate() ?? false;
      case 3:
        if (!_agreeToTerms) {
          _showError('يرجى الموافقة على الشروط والأحكام للإكمال');
          return false;
        }
        return _step4Key.currentState?.validate() ?? false;
      default:
        return true;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle()),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedPhotoBytes = bytes;
          _selectedPhotoFilename = picked.name;
        });
      }
    } catch (e) {
      _showError('حدث خطأ أثناء اختيار الصورة: $e');
    }
  }

  Future<void> _submitRegistration() async {
    setState(() => _isSubmitting = true);

    try {
      // 1. Clean Phone
      final rawPhone = _phoneController.text.trim();
      final formattedPhone = AhyxiOtpService.formatIraqiPhoneNumber(rawPhone);
      final email = 'delivery_${formattedPhone.replaceAll("+", "")}@dalal-alqaim.com';
      final password = _passwordController.text.trim();

      // 2. Create Auth Account
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;

      // 3. Upload Photo to Cloudinary
      String photoUrl = '';
      if (_selectedPhotoBytes != null) {
        photoUrl = await CloudinaryService.uploadBytes(
              _selectedPhotoBytes!,
              _selectedPhotoFilename ?? 'delivery_profile.jpg',
            ) ??
            '';
      }

      // 4. Save User Profile in `users` Collection
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': _nameController.text.trim(),
        'fullName': _nameController.text.trim(),
        'phone': formattedPhone,
        'isPhoneVerified': true,
        'email': email,
        'role': 'delivery',
        'subRole': 'delivery',
        'isDelivery': true,
        'isDriver': false,
        'status': 'pending',
        'isApproved': false,
        'profilePicture': photoUrl,
        'photoUrl': photoUrl,
        'vehicleType': _selectedVehicleType,
        'vehicleModel': _vehicleModelController.text.trim(),
        'plateNumber': _plateNumberController.text.trim(),
        'governorateId': _selectedGovId,
        'governorateName': _selectedGovName,
        'regionId': _selectedRegId,
        'regionName': _selectedRegName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5. Save Record in `drivers` / Delivery Captains Collection
      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
        'driverId': uid,
        'uid': uid,
        'name': _nameController.text.trim(),
        'fullName': _nameController.text.trim(),
        'phone': formattedPhone,
        'isPhoneVerified': true,
        'role': 'delivery',
        'isDelivery': true,
        'isDriver': false,
        'status': 'pending',
        'isApproved': false,
        'isOnline': false,
        'photoUrl': photoUrl,
        'vehicleType': _selectedVehicleType,
        'vehicleModel': _vehicleModelController.text.trim(),
        'plateNumber': _plateNumberController.text.trim(),
        'governorateName': _selectedGovName,
        'regionName': _selectedRegName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 6. Save Record in `delivery_boys` Collection
      await FirebaseFirestore.instance.collection('delivery_boys').doc(uid).set({
        'uid': uid,
        'boyId': uid,
        'name': _nameController.text.trim(),
        'fullName': _nameController.text.trim(),
        'phone': formattedPhone,
        'isPhoneVerified': true,
        'role': 'delivery',
        'isDelivery': true,
        'status': 'pending',
        'isApproved': false,
        'isOnline': false,
        'photoUrl': photoUrl,
        'profilePicture': photoUrl,
        'vehicleType': _selectedVehicleType,
        'vehicleModel': _vehicleModelController.text.trim(),
        'plateNumber': _plateNumberController.text.trim(),
        'governorateId': _selectedGovId,
        'governorateName': _selectedGovName,
        'regionId': _selectedRegId,
        'regionName': _selectedRegName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentUserRole_$uid', 'delivery');
        await prefs.setString('currentUserRole', 'delivery');
        await prefs.setString('currentUserId', uid);
        await prefs.setBool('user_data_registered', true);
      } catch (_) {}

      await OneSignalService.syncUserRole(uid);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DeliveryRegistrationStatusPage()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showError('رقم الهاتف مسجل بالفعل مسبقاً، سجّل دخولك أولاً.');
      } else {
        _showError(e.message ?? 'حدث خطأ أثناء التسجيل.');
      }
    } catch (e) {
      _showError('فشل إنشاء الحساب: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'تسجيل مندوب توصيل جديد',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _prevStep,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step Progress Indicator
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(4, (index) {
                  final isDone = index < _currentStep;
                  final isCurrent = index == _currentStep;
                  return Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 6.h,
                            decoration: BoxDecoration(
                              color: isDone || isCurrent
                                  ? _primary
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(3.r),
                            ),
                          ),
                        ),
                        if (index < 3) SizedBox(width: 6.w),
                      ],
                    ),
                  );
                }),
              ),
            ),

            // Step Label Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الخطوة ${_currentStep + 1} من 4',
                    style: TextStyle(fontSize: 12.sp, color: _primary, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _getStepTitle(_currentStep),
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            // Main Wizard Page View
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1PersonalInfo(cardBg, inputBg, isDark),
                  _buildStep2VehicleInfo(cardBg, inputBg, isDark),
                  _buildStep3LocationInfo(cardBg, inputBg, isDark),
                  _buildStep4SecurityInfo(cardBg, inputBg, isDark),
                ],
              ),
            ),

            // Bottom Action Navigation Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: cardBg,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -3)),
                ],
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _prevStep,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          side: BorderSide(color: _primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        ),
                        child: Text(
                          'السابق',
                          style: TextStyle(fontWeight: FontWeight.bold, color: _primary),
                        ),
                      ),
                    ),
                  if (_currentStep > 0) SizedBox(width: 12.w),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _nextStep,
                      icon: _isSubmitting
                          ? SizedBox(width: 20.r, height: 20.r, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Icon(_currentStep == 3 ? Icons.check_circle_rounded : Icons.arrow_back_rounded, size: 20.sp),
                      label: Text(
                        _currentStep == 3 ? 'إرسال طلب التسجيل' : 'التالي',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'البيانات والصورة الشخصية';
      case 1:
        return 'وسيلة ورخصة التوصيل';
      case 2:
        return 'المحافظة والمنطقة';
      case 3:
        return 'كلمة المرور والأمان';
      default:
        return '';
    }
  }

  // ━━━━ 1. Step 1: Personal Info & Mandatory Photo ━━━━
  Widget _buildStep1PersonalInfo(Color cardBg, Color inputBg, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.r),
      child: Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mandatory Photo Upload Badge
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    Container(
                      width: 95.r,
                      height: 95.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF2C3840) : const Color(0xFFE8F5E9),
                        border: Border.all(color: _primary, width: 2.5),
                      ),
                      child: ClipOval(
                        child: _selectedPhotoBytes != null
                            ? Image.memory(_selectedPhotoBytes!, fit: BoxFit.cover)
                            : Icon(Icons.person_rounded, size: 45.r, color: _primary),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(color: _primary, shape: BoxShape.circle),
                        child: Icon(Icons.camera_alt_rounded, size: 14.sp, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Center(
              child: Text(
                _selectedPhotoFilename ?? 'اضغط لإضافة الصورة الشخصية (إجباري) *',
                style: TextStyle(fontSize: 11.5.sp, color: _primary, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 20.h),

            // Full Name Input
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration('الاسم الثلاثي الكامل *', Icons.person_outline_rounded, inputBg),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال الاسم الكامل' : null,
            ),
            SizedBox(height: 14.h),

            // Phone Input
            IraqiPhoneInputField(
              controller: _phoneController,
              hintText: 'رقم هاتف المندوب (للتحقق برمز OTP)',
              onChanged: (_) {
                if (_isPhoneVerified) {
                  setState(() {
                    _isPhoneVerified = false;
                    _verifiedPhone = null;
                  });
                }
              },
            ),

            SizedBox(height: 8.h),
            Builder(builder: (context) {
              final formatted = AhyxiOtpService.formatIraqiPhoneNumber(_phoneController.text.trim());
              final isCurrentPhoneVerified = _isPhoneVerified && _verifiedPhone == formatted;

              if (isCurrentPhoneVerified) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, color: const Color(0xFF10B981), size: 16.sp),
                      SizedBox(width: 6.w),
                      Text(
                        'تم التحقق من رقم الهاتف بنجاح',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return InkWell(
                onTap: _isVerifyingPhone ? null : _verifyPhoneOtp,
                borderRadius: BorderRadius.circular(10.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 8.w),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isVerifyingPhone
                          ? SizedBox(
                              width: 14.r,
                              height: 14.r,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                            )
                          : Icon(Icons.mark_email_read_outlined, size: 15.sp, color: _primary),
                      SizedBox(width: 6.w),
                      Text(
                        'التحقق من رقم الهاتف الآن عبر رمز OTP',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: _primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ━━━━ 2. Step 2: Vehicle Info ━━━━
  Widget _buildStep2VehicleInfo(Color cardBg, Color inputBg, bool isDark) {
    final vehicleOptions = [
      'دراجة نارية (موتور)',
      'سيارة توصيل صغيرة',
      'ستوتة / تكتك',
      'سيارة حمل (بكب)',
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(20.r),
      child: Form(
        key: _step2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اختر نوع وسيلة التوصيل الخاصة بك: *',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10.h),

            DropdownButtonFormField<String>(
              initialValue: _selectedVehicleType,
              decoration: _inputDecoration('نوع المركبة / التوصيل', Icons.two_wheeler_rounded, inputBg),
              items: vehicleOptions
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(v, style: const TextStyle()),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedVehicleType = val),
            ),
            SizedBox(height: 14.h),

            // Vehicle Model / Year
            TextFormField(
              controller: _vehicleModelController,
              decoration: _inputDecoration('موديل ونوع المركبة (مثل: هوندا 2023) *', Icons.badge_rounded, inputBg),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال موديل المركبة' : null,
            ),
            SizedBox(height: 14.h),

            // Plate Number
            TextFormField(
              controller: _plateNumberController,
              decoration: _inputDecoration('رقم اللوحة / الترخيص (اختياري)', Icons.pin_rounded, inputBg),
            ),
          ],
        ),
      ),
    );
  }

  // ━━━━ 3. Step 3: Location Selection ━━━━
  Widget _buildStep3LocationInfo(Color cardBg, Color inputBg, bool isDark) {
    if (_isLoadingLocations) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(20.r),
      child: Form(
        key: _step3Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'حدد نطاق المحافظة والمنطقة لعمليات التوصيل: *',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),

            // Governorate Dropdown
            DropdownButtonFormField<String>(
              value: _governorates.any((g) => g['id'].toString() == _selectedGovId)
                  ? _selectedGovId
                  : (_governorates.isNotEmpty ? _governorates.first['id'].toString() : null),
              decoration: _inputDecoration('المحافظة *', Icons.map_rounded, inputBg),
              items: _governorates
                  .map((g) => DropdownMenuItem(
                        value: g['id'].toString(),
                        child: Text(g['name'].toString(), style: const TextStyle()),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  final found = _governorates.firstWhere(
                    (g) => g['id'].toString() == val,
                    orElse: () => {'id': val, 'name': val},
                  );
                  setState(() {
                    _selectedGovId = val;
                    _selectedGovName = found['name'].toString();
                  });
                  _loadRegions(val);
                }
              },
            ),
            SizedBox(height: 14.h),

            // Region Dropdown
            DropdownButtonFormField<String>(
              value: _regions.any((r) => r['id'].toString() == _selectedRegId)
                  ? _selectedRegId
                  : (_regions.isNotEmpty ? _regions.first['id'].toString() : null),
              decoration: _inputDecoration('المنطقة الرئيسية للتوصيل *', Icons.location_city_rounded, inputBg),
              items: _regions
                  .map((r) => DropdownMenuItem(
                        value: r['id'].toString(),
                        child: Text(r['name'].toString(), style: const TextStyle()),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  final found = _regions.firstWhere(
                    (r) => r['id'].toString() == val,
                    orElse: () => {'id': val, 'name': val},
                  );
                  setState(() {
                    _selectedRegId = val;
                    _selectedRegName = found['name'].toString();
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ━━━━ 4. Step 4: Security & Terms ━━━━
  Widget _buildStep4SecurityInfo(Color cardBg, Color inputBg, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.r),
      child: Form(
        key: _step4Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تعيين كلمة المرور لحساب مندوب التوصيل: *',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),

            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: _inputDecoration('كلمة المرور *', Icons.lock_outline_rounded, inputBg).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.length < 6) return 'يجب أن لا تقل كلمة المرور عن 6 خانات';
                return null;
              },
            ),
            SizedBox(height: 14.h),

            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: _inputDecoration('تأكيد كلمة المرور *', Icons.lock_clock_outlined, inputBg).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v != _passwordController.text) return 'كلمتا المرور غير متطابقتين';
                return null;
              },
            ),
            SizedBox(height: 16.h),

            CheckboxListTile(
              value: _agreeToTerms,
              onChanged: (val) => setState(() => _agreeToTerms = val ?? false),
              activeColor: _primary,
              title: Text(
                'أوافق على شروط وأحكام العمل كمندوب توصيل معتمد في منصة مدار.',
                style: TextStyle(fontSize: 11.5.sp),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, Color fill) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 12.5.sp),
      prefixIcon: Icon(icon, color: _primary, size: 20.sp),
      filled: true,
      fillColor: fill,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: _primary, width: 1.8)),
    );
  }
}
