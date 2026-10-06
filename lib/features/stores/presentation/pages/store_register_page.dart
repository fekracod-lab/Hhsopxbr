import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dalal_alqaim/services/cloudinary_service.dart';
import 'package:dalal_alqaim/features/auth/widgets/iraqi_phone_input_field.dart';
import 'package:dalal_alqaim/services/ahyxi_otp_service.dart';
import 'package:dalal_alqaim/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dalal_alqaim/constants/iraq_geography.dart';

// --- Palette ---
const Color _primary = Color(0xFFE65100); // Warm Deep Amber/Orange
const Color _lightBg = Color(0xFFFBF9F6);
const Color _lightText = Color(0xFF2C3E50);
const Color _lightSub = Color(0xFF7F8C8D);

class StoreRegisterPage extends StatefulWidget {
  const StoreRegisterPage({super.key});

  @override
  State<StoreRegisterPage> createState() => _StoreRegisterPageState();
}

class _StoreRegisterPageState extends State<StoreRegisterPage> with TickerProviderStateMixin {
  // --- Step Control ---
  int _currentStep = 0;
  final _pageController = PageController();

  // --- Form Keys ---
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();
  final _step4Key = GlobalKey<FormState>();

  // --- Controllers ---
  final _ownerName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _storeName = TextEditingController();
  final _storeAddress = TextEditingController();
  final _workingHours = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  // --- State ---
  String? _selectedCategory;
  String? _selectedGovId, _selectedGovName;
  String? _selectedRegId, _selectedRegName;
  List<Map<String, dynamic>> _regions = [];
  bool _isLoadingRegions = false;
  Uint8List? _selectedLogoBytes;
  String? _selectedLogoFilename;
  bool _loading = false;
  bool _isPickingLogo = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  final List<String> _categories = [
    'سوبرماركت ومواد غذائية',
    'ملابس وأزياء وموضة',
    'إلكترونيات وأجهزة منزلية',
    'مستحضرات تجميل وعطور',
    'عطارة ومستلزمات منزلية',
    'هواتف واكسسوارات',
    'ألعاب وأطفال',
    'متجر شامل / نشاط آخر',
  ];

  static const _stepTitles = ['بيانات المالك', 'تفاصيل المتجر', 'الموقع والمنطقة', 'تأمين الحساب'];
  static const _stepIcons = [Icons.person_outline_rounded, Icons.storefront_rounded, Icons.location_on_outlined, Icons.lock_outline_rounded];

  @override
  void initState() {
    super.initState();
    _selectedGovName = 'الأنبار';
    _selectedGovId = 'anbar';
    final initialRegions = getRegionsForGovernorate('الأنبار');
    _regions = initialRegions.map((r) => {'id': r, 'name': r}).toList();
    if (_regions.isNotEmpty) {
      _selectedRegName = _regions.first['name'];
      _selectedRegId = _regions.first['id'];
    }
  }

  @override
  void dispose() {
    _ownerName.dispose(); _email.dispose(); _phone.dispose();
    _storeName.dispose(); _storeAddress.dispose(); _workingHours.dispose();
    _password.dispose(); _confirm.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;

    if (_currentStep < 3) {
      HapticFeedback.mediumImpact();
      setState(() => _currentStep++);
      _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutQuart);
    } else {
      _registerStore();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      HapticFeedback.lightImpact();
      setState(() => _currentStep--);
      _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutQuart);
    } else {
      Navigator.pop(context);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_selectedLogoBytes == null) {
          _showError('يرجى تحميل شعار / صورة المتجر للإكمال (إجباري)');
          return false;
        }
        return _step1Key.currentState?.validate() ?? false;
      case 1:
        if (_selectedCategory == null) { _showError('يرجى اختيار تصنيف المتجر / المطعم'); return false; }
        return _step2Key.currentState?.validate() ?? false;
      case 2:
        if (_selectedGovId == null) { _showError('يرجى اختيار المحافظة'); return false; }
        if (_selectedRegId == null) { _showError('يرجى اختيار المنطقة'); return false; }
        return _step3Key.currentState?.validate() ?? false;
      case 3:
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

  Future<void> _pickLogoImage() async {
    if (_isPickingLogo) return;
    _isPickingLogo = true;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 800);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedLogoBytes = bytes;
          _selectedLogoFilename = picked.name;
        });
      }
    } catch (e) {
      _showError('تعذر اختيار صورة الشعار: $e');
    } finally {
      _isPickingLogo = false;
    }
  }

  Future<void> _registerStore() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      // 1. Create Auth User
      final cleanEmail = _email.text.trim();
      final cleanPass = _password.text.trim();

      UserCredential credential;
      try {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: cleanPass,
        );
      } catch (authError) {
        // Fallback for existing or custom auth
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: cleanEmail,
          password: cleanPass,
        );
      }

      final uid = credential.user!.uid;

      // 2. Upload Logo Image if selected
      String? logoUrl;
      if (_selectedLogoBytes != null) {
        logoUrl = await CloudinaryService.uploadBytes(
          _selectedLogoBytes!,
          _selectedLogoFilename ?? 'store_logo.jpg',
        );
      }

      final rawPhone = _phone.text.trim();
      final formattedPhone = AhyxiOtpService.formatIraqiPhoneNumber(rawPhone);

      // 3. Save User & Store Profile to Firestore
      final storeData = {
        'uid': uid,
        'name': _ownerName.text.trim(),
        'fullName': _ownerName.text.trim(),
        'email': cleanEmail,
        'phone': formattedPhone,
        'isPhoneVerified': true,
        'role': 'store',
        'subRole': 'store',
        'storeName': _storeName.text.trim(),
        'category': _selectedCategory,
        'storeCategory': _selectedCategory,
        'address': _storeAddress.text.trim(),
        'workingHours': _workingHours.text.trim().isNotEmpty ? _workingHours.text.trim() : 'من 9:00 ص إلى 11:00 م',
        'governorateId': _selectedGovId,
        'governorateName': _selectedGovName,
        'regionId': _selectedRegId,
        'regionName': _selectedRegName,
        'logoUrl': logoUrl ?? '',
        'imageUrl': logoUrl ?? '',
        'status': 'pending',
        'isApproved': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('users').doc(uid).set(storeData, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('stores').doc(uid).set(storeData, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('store_requests').doc(uid).set(storeData, SetOptions(merge: true));

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentUserRole_$uid', 'store');
        await prefs.setString('currentUserRole', 'store');
        await prefs.setString('currentUserId', uid);
      } catch (_) {}

      if (!mounted) return;
      setState(() => _loading = false);

      // Success Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
              SizedBox(width: 8.w),
              const Text('تم تقديم الطلب بنجاح!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'شكراً لإنضمامك لمنصة مدار! تم إرسال بيانات متجرك إلى فريق الإدارة، وسوف يتم تفعيل حسابك فور مراجعة البيانات.',
            style: TextStyle(fontSize: 13.sp, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx); // Close dialog
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
              child: const Text('متابعة حالة الحساب والدخول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('حدث خطأ أثناء التسجيل: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF12181B) : _lightBg;
    final cardBg = isDark ? const Color(0xFF1E272C) : Colors.white;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : _lightText, size: 20.r),
            onPressed: _prevStep,
          ),
          title: Text(
            'تسجيل متجر / مطعم جديد',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: isDark ? Colors.white : _lightText),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Stepper Header Bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                child: Row(
                  children: List.generate(4, (index) {
                    final isActive = index == _currentStep;
                    final isDone = index < _currentStep;

                    return Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 38.r,
                                  height: 38.r,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDone ? Colors.green : (isActive ? _primary : (isDark ? const Color(0xFF2C3840) : const Color(0xFFE2EBE8))),
                                    boxShadow: isActive ? [BoxShadow(color: _primary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))] : null,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isDone ? Icons.check_rounded : _stepIcons[index],
                                      color: (isDone || isActive) ? Colors.white : (isDark ? Colors.white38 : Colors.grey),
                                      size: 18.sp,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  _stepTitles[index],
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                    color: isActive ? _primary : (isDark ? Colors.white54 : _lightSub),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (index < 3)
                            Container(
                              width: 20.w,
                              height: 2.h,
                              margin: EdgeInsets.only(bottom: 16.h),
                              color: index < _currentStep ? Colors.green : (isDark ? Colors.white12 : Colors.grey.shade300),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
              ),

              SizedBox(height: 10.h),

              // PageView content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1Personal(cardBg, isDark),
                    _buildStep2StoreDetails(cardBg, isDark),
                    _buildStep3Location(cardBg, isDark),
                    _buildStep4Security(cardBg, isDark),
                  ],
                ),
              ),

              // Action Navigation Bar
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: cardBg,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -3))],
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            side: const BorderSide(color: _primary),
                          ),
                          child: const Text('السابق', style: TextStyle(fontWeight: FontWeight.bold, color: _primary)),
                        ),
                      ),
                    if (_currentStep > 0) SizedBox(width: 12.w),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          elevation: 3,
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : Text(
                                _currentStep == 3 ? 'إرسال طلب الانضمام' : 'التالي',
                                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
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

  // ═══════════════════════════════════════════════════
  // STEP 1: PERSONAL OWNER DATA
  // ═══════════════════════════════════════════════════
  Widget _buildStep1Personal(Color cardBg, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.r),
      child: Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الخطوة 1: معلومات مالك النشاط', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: _primary)),
            SizedBox(height: 4.h),
            Text('أدخل البيانات الشخصية المعتمدة لمالك المطعم أو المتجر.', style: TextStyle(fontSize: 12.sp, color: _lightSub)),
            SizedBox(height: 16.h),

            // Logo Upload Widget
            Center(
              child: GestureDetector(
                onTap: _pickLogoImage,
                child: Stack(
                  children: [
                    Container(
                      width: 90.r,
                      height: 90.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF2C3840) : const Color(0xFFFFF3E0),
                        border: Border.all(color: _primary, width: 2),
                      ),
                      child: ClipOval(
                        child: _selectedLogoBytes != null
                            ? Image.memory(_selectedLogoBytes!, fit: BoxFit.cover)
                            : Icon(Icons.storefront_rounded, size: 40.r, color: _primary),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle),
                        child: Icon(Icons.camera_alt_rounded, size: 14.sp, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 6.h),
            Center(
              child: Text(
                _selectedLogoFilename ?? 'اضغط لإضافة شعار / صورة المتجر (إجباري) *',
                style: TextStyle(fontSize: 11.sp, color: _primary, fontWeight: FontWeight.bold),
              ),
            ),

            SizedBox(height: 20.h),

            // Owner Name
            TextFormField(
              controller: _ownerName,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة اسم المالك' : null,
              decoration: _inputDeco('اسم مالك المتجر الثلاثي', Icons.person_outline_rounded, isDark),
            ),

            SizedBox(height: 12.h),

            // Phone
            IraqiPhoneInputField(
              controller: _phone,
              hintText: 'رقم هاتف المالك',
            ),

            SizedBox(height: 14.h),

            // Email
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'يرجى كتابة البريد الإلكتروني';
                if (!v.contains('@') || !v.contains('.')) return 'بريد إلكتروني غير صالح';
                return null;
              },
              decoration: _inputDeco('البريد الإلكتروني', Icons.email_outlined, isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // STEP 2: STORE DETAILS
  // ═══════════════════════════════════════════════════
  Widget _buildStep2StoreDetails(Color cardBg, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.r),
      child: Form(
        key: _step2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الخطوة 2: تفاصيل المطعم أو المتجر', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: _primary)),
            SizedBox(height: 4.h),
            Text('حدد التخصص والتصنيف التجاري للتطوير والعرض على العملاء.', style: TextStyle(fontSize: 12.sp, color: _lightSub)),
            SizedBox(height: 16.h),

            // Store Name
            TextFormField(
              controller: _storeName,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة اسم المطعم أو المتجر' : null,
              decoration: _inputDeco('اسم المطعم / المتجر التجاري', Icons.storefront_rounded, isDark),
            ),

            SizedBox(height: 14.h),

            // Category Dropdown
            Text('تصنيف النشاط التجاري:', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 6.h),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              isExpanded: true,
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle()))).toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
              decoration: _inputDeco('اختر التصنيف الرئيسي', Icons.category_outlined, isDark),
            ),

            SizedBox(height: 14.h),

            // Working Hours
            TextFormField(
              controller: _workingHours,
              decoration: _inputDeco('أوقات العمل (مثال: يومياً من 9:00 ص إلى 12:00 م)', Icons.access_time_rounded, isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // STEP 3: LOCATION & REGION
  // ═══════════════════════════════════════════════════
  Widget _buildStep3Location(Color cardBg, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.r),
      child: Form(
        key: _step3Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الخطوة 3: موقع ومكان المتجر', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: _primary)),
            SizedBox(height: 4.h),
            Text('حدد المحافظة والمنطقة لربط طلبات التوصيل بالمنطقة المحيطة.', style: TextStyle(fontSize: 12.sp, color: _lightSub)),
            SizedBox(height: 16.h),

            // Governorate Picker Stream
            // Governorate Picker Stream
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('governorates').snapshots(),
              builder: (context, snapshot) {
                List<Map<String, String>> govItems = [];
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  for (final doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>?;
                    final name = (data?['name'] ?? data?['title'] ?? doc.id).toString().trim();
                    if (name.isNotEmpty && !govItems.any((i) => i['name'] == name)) {
                      govItems.add({'id': doc.id, 'name': name});
                    }
                  }
                }
                if (govItems.isEmpty) {
                  govItems = kIraqiGovernorates.map((g) => {'id': g, 'name': g}).toList();
                }

                final hasValue = govItems.any((g) => g['id'] == _selectedGovId);
                final currentGovValue = hasValue ? _selectedGovId : (govItems.isNotEmpty ? govItems.first['id'] : null);

                return DropdownButtonFormField<String>(
                  value: currentGovValue,
                  isExpanded: true,
                  hint: const Text('اختر المحافظة', style: TextStyle()),
                  items: govItems.map((g) {
                    return DropdownMenuItem<String>(
                      value: g['id'],
                      child: Text(g['name']!, style: const TextStyle()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    final selectedDoc = govItems.firstWhere((d) => d['id'] == val, orElse: () => {'id': val, 'name': val});
                    final name = selectedDoc['name'] ?? val;
                    setState(() {
                      _selectedGovId = val;
                      _selectedGovName = name;
                      _selectedRegId = null;
                      _selectedRegName = null;
                    });
                    _loadRegions(val);
                  },
                  decoration: _inputDeco('المحافظة', Icons.map_outlined, isDark),
                );
              },
            ),

            SizedBox(height: 14.h),

            // Region Picker
            if (_isLoadingRegions)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<String>(
                value: _regions.any((r) => r['id'] == _selectedRegId)
                    ? _selectedRegId
                    : (_regions.isNotEmpty ? _regions.first['id'] : null),
                isExpanded: true,
                hint: const Text('اختر المنطقة / القضاء', style: TextStyle()),
                items: _regions.map((reg) {
                  final id = (reg['id'] ?? '').toString();
                  final name = (reg['name'] ?? '').toString();
                  return DropdownMenuItem<String>(
                    value: id,
                    child: Text(name, style: const TextStyle()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val == null) return;
                  final selectedReg = _regions.firstWhere((r) => r['id'] == val, orElse: () => {'id': val, 'name': val});
                  setState(() {
                    _selectedRegId = val;
                    _selectedRegName = (selectedReg['name'] ?? val).toString();
                  });
                },
                decoration: _inputDeco('المنطقة', Icons.location_city_outlined, isDark),
              ),

            SizedBox(height: 14.h),

            // Detailed Store Address
            TextFormField(
              controller: _storeAddress,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة العنوان التفصيلي' : null,
              decoration: _inputDeco('العنوان التفصيلي (اسم الشارع / أقرب نقطة دالة)', Icons.place_outlined, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadRegions(String govId) async {
    setState(() => _isLoadingRegions = true);
    List<Map<String, dynamic>> fetched = [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('governorates')
          .doc(govId)
          .collection('regions')
          .get();

      for (final d in snap.docs) {
        final data = d.data();
        final name = (data['name'] ?? data['title'] ?? d.id).toString().trim();
        if (name.isNotEmpty) {
          fetched.add({'id': d.id, 'name': name, ...data});
        }
      }
    } catch (_) {}

    if (fetched.isEmpty) {
      final defaults = getRegionsForGovernorate(_selectedGovName ?? govId);
      fetched = defaults.map((r) => {'id': r, 'name': r}).toList();
    }

    if (mounted) {
      setState(() {
        _regions = fetched;
        _isLoadingRegions = false;
        if (fetched.isNotEmpty) {
          _selectedRegId = (fetched.first['id'] ?? '').toString();
          _selectedRegName = (fetched.first['name'] ?? '').toString();
        }
      });
    }
  }

  // ═══════════════════════════════════════════════════
  // STEP 4: SECURITY & PASSWORD
  // ═══════════════════════════════════════════════════
  Widget _buildStep4Security(Color cardBg, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.r),
      child: Form(
        key: _step4Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الخطوة 4: كلمة المرور وتأكيد الحساب', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: _primary)),
            SizedBox(height: 4.h),
            Text('عين كلمة مرور قوية لدخول لوحة تحكم المتجر ومتابعة الطلبات.', style: TextStyle(fontSize: 12.sp, color: _lightSub)),
            SizedBox(height: 16.h),

            // Password
            TextFormField(
              controller: _password,
              obscureText: _obscure1,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'يرجى كتابة كلمة المرور';
                if (v.trim().length < 6) return 'كلمة المرور يجب أن لا تقل عن 6 أحرف';
                return null;
              },
              decoration: _inputDeco('كلمة المرور', Icons.lock_outline_rounded, isDark).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility, color: _primary),
                  onPressed: () => setState(() => _obscure1 = !_obscure1),
                ),
              ),
            ),

            SizedBox(height: 12.h),

            // Confirm Password
            TextFormField(
              controller: _confirm,
              obscureText: _obscure2,
              validator: (v) {
                if (v != _password.text) return 'كلمتا المرور غير متطابقتين';
                return null;
              },
              decoration: _inputDeco('تأكيد كلمة المرور', Icons.lock_reset_rounded, isDark).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility, color: _primary),
                  onPressed: () => setState(() => _obscure2 = !_obscure2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12.sp, color: isDark ? Colors.white38 : Colors.grey),
      prefixIcon: Icon(icon, color: _primary, size: 20.sp),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E272C) : Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: _primary, width: 1.8)),
    );
  }
}
