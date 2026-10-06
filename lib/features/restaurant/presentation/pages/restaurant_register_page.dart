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
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dalal_alqaim/widgets/map_picker_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dalal_alqaim/constants/iraq_geography.dart';

// --- Palette ---
const Color _primary = Color(0xFFE65100); // Warm Deep Amber/Orange
const Color _lightBg = Color(0xFFFFFBF7);
const Color _lightText = Color(0xFF2C3E50);
const Color _lightSub = Color(0xFF7F8C8D);

class RestaurantRegisterPage extends StatefulWidget {
  const RestaurantRegisterPage({super.key});

  @override
  State<RestaurantRegisterPage> createState() => _RestaurantRegisterPageState();
}

class _RestaurantRegisterPageState extends State<RestaurantRegisterPage> with TickerProviderStateMixin {
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
  final _restaurantName = TextEditingController();
  final _restaurantAddress = TextEditingController();
  final _workingHours = TextEditingController();
  final _deliveryTime = TextEditingController(text: '25 - 35 دقيقة');
  final _minOrderAmount = TextEditingController(text: '5000');
  final _whatsappPhone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  // --- State ---
  String? _selectedCuisine;
  String? _selectedGovId, _selectedGovName;
  String? _selectedRegId, _selectedRegName;
  String? _selectedSubRegionName;
  final _customSubRegionController = TextEditingController();
  List<Map<String, dynamic>> _regions = [];
  List<String> _subRegionsList = [];
  bool _isLoadingRegions = false;
  bool _isLoadingSubRegions = false;
  Uint8List? _selectedCoverBytes;
  String? _selectedCoverFilename;
  bool _loading = false;
  bool _isPickingImage = false;
  bool _isLocating = false;
  double? _latitude;
  double? _longitude;
  bool _agreedToTerms = true;
  bool _obscure1 = true;
  bool _obscure2 = true;

  final List<String> _cuisines = [
    'مأكولات عراقية وشرقية',
    'مشويات وكباب عراقي',
    'وجبات سريعة وبرغر',
    'بيتزا ومعجنات إيطالية',
    'مأكولات بحرية وسمك',
    'شاورما وقص',
    'حلويات وكنافة وعصائر',
    'مطعم وكافيه شامل',
  ];

  static const _stepTitles = ['البيانات الشخصية', 'تفاصيل المطعم', 'الموقع والمنطقة', 'تأمين الحساب'];
  static const _stepIcons = [Icons.person_outline_rounded, Icons.restaurant_menu_rounded, Icons.location_on_outlined, Icons.lock_outline_rounded];

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
      _loadSubRegions(_selectedGovId ?? '', _selectedRegId!, _selectedRegName!);
    }
  }

  @override
  void dispose() {
    _ownerName.dispose(); _email.dispose(); _phone.dispose();
    _restaurantName.dispose(); _restaurantAddress.dispose(); _workingHours.dispose();
    _deliveryTime.dispose(); _minOrderAmount.dispose(); _whatsappPhone.dispose();
    _password.dispose(); _confirm.dispose();
    _customSubRegionController.dispose();
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
      _registerRestaurant();
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
        if (_selectedCoverBytes == null) {
          _showError('يرجى تحميل شعار / صورة غلاف المطعم للإكمال (إجباري)');
          return false;
        }
        return _step1Key.currentState?.validate() ?? false;
      case 1:
        if (_selectedCuisine == null) { _showError('يرجى اختيار تخصص المأكولات والمطعم'); return false; }
        return _step2Key.currentState?.validate() ?? false;
      case 2:
        if (_selectedGovId == null) { _showError('يرجى اختيار المحافظة'); return false; }
        if (_selectedRegId == null) { _showError('يرجى اختيار المنطقة / القضاء'); return false; }
        if (_selectedSubRegionName == null || _selectedSubRegionName!.trim().isEmpty) {
          _showError('يرجى اختيار الناحية والمنطقة / الحي');
          return false;
        }
        if (_selectedSubRegionName == 'أخرى (كتابة يدوية)' && _customSubRegionController.text.trim().isEmpty) {
          _showError('يرجى كتابة اسم الناحية والمنطقة / الحي');
          return false;
        }
        return _step3Key.currentState?.validate() ?? false;
      case 3:
        if (!_agreedToTerms) {
          _showError('يرجى الموافقة على شروط وضوابط منصة مدار للإكمال');
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

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerPage()),
    );

    if (result != null && result['location'] is LatLng) {
      final LatLng loc = result['location'] as LatLng;
      setState(() {
        _latitude = loc.latitude;
        _longitude = loc.longitude;
        final selectedAddr = result['address'] as String?;
        if (selectedAddr != null && selectedAddr.isNotEmpty && selectedAddr != 'جاري تحديد العنوان...') {
          if (_restaurantAddress.text.trim().isEmpty) {
            _restaurantAddress.text = selectedAddr;
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تم تثبيت موقع المطعم من خرائط Google بنجاح! (${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('خدمة الـ GPS مطفأة في هاتفك. يمكنك النقر على زر "تحديد من الخريطة" لتعيين الموقع مباشرة.');
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('تم رفض إذن الوصول للموقع. يرجى اختيار الموقع من الخريطة.');
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('إذن الموقع مرفوض في إعدادات الهاتف. يمكنك تحديد الموقع من الخريطة مباشرة.');
        setState(() => _isLocating = false);
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 8),
          );
        } catch (_) {
          try {
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 6),
            );
          } catch (_) {}
        }
      }

      final p = position;
      if (p != null) {
        setState(() {
          _latitude = p.latitude;
          _longitude = p.longitude;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم التقاط إحداثيات موقع المطعم بنجاح! (${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)})',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
            ),
          );
        }
      } else {
        _showError('تعذر التقاط إشارة GPS حالياً. يرجى الضغط على "فتح الخريطة وتحديد موقع المطعم" لاختياره بدقة.');
      }
    } catch (e) {
      _showError('تعذر تحديد الموقع تلقائياً. يرجى النقر على زر الخريطة لاختيار الموقع.');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _pickCoverImage() async {
    if (_isPickingImage) return;
    _isPickingImage = true;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 800);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedCoverBytes = bytes;
          _selectedCoverFilename = picked.name;
        });
      }
    } catch (e) {
      _showError('تعذر اختيار صورة غلاف المطعم: $e');
    } finally {
      _isPickingImage = false;
    }
  }

  Future<void> _registerRestaurant() async {
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
      } catch (_) {
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: cleanEmail,
          password: cleanPass,
        );
      }

      final uid = credential.user!.uid;

      // 2. Upload Cover Image if selected
      String? coverUrl;
      if (_selectedCoverBytes != null) {
        coverUrl = await CloudinaryService.uploadBytes(
          _selectedCoverBytes!,
          _selectedCoverFilename ?? 'restaurant_cover.jpg',
        );
      }

      final rawPhone = _phone.text.trim();
      final formattedPhone = AhyxiOtpService.formatIraqiPhoneNumber(rawPhone);
      final rawWhatsapp = _whatsappPhone.text.trim();
      final formattedWhatsapp = rawWhatsapp.isNotEmpty
          ? AhyxiOtpService.formatIraqiPhoneNumber(rawWhatsapp)
          : formattedPhone;
      final subRegion = (_selectedSubRegionName == 'أخرى (كتابة يدوية)')
          ? _customSubRegionController.text.trim()
          : (_selectedSubRegionName ?? '');

      final double minOrder = double.tryParse(_minOrderAmount.text.trim()) ?? 5000.0;
      final String deliveryTimeStr = _deliveryTime.text.trim().isNotEmpty
          ? _deliveryTime.text.trim()
          : '25 - 35 دقيقة';

      // 3. Save User Profile to Firestore
      final userData = {
        'uid': uid,
        'name': _ownerName.text.trim(),
        'fullName': _ownerName.text.trim(),
        'email': cleanEmail,
        'phone': formattedPhone,
        'whatsappPhone': formattedWhatsapp,
        'isPhoneVerified': true,
        'role': 'restaurant',
        'subRole': 'restaurant',
        'restaurantName': _restaurantName.text.trim(),
        'cuisine': _selectedCuisine,
        'storeCategory': _selectedCuisine,
        'address': _restaurantAddress.text.trim(),
        'workingHours': _workingHours.text.trim().isNotEmpty ? _workingHours.text.trim() : 'من 10:00 ص إلى 12:00 م',
        'governorateId': _selectedGovId,
        'governorateName': _selectedGovName,
        'regionId': _selectedRegId,
        'regionName': _selectedRegName,
        'subRegion': subRegion,
        'subRegionName': subRegion,
        'neighborhood': subRegion,
        'district': _selectedRegName,
        'latitude': _latitude,
        'longitude': _longitude,
        'deliveryTime': deliveryTimeStr,
        'minOrderAmount': minOrder,
        'logoUrl': coverUrl ?? '',
        'imageUrl': coverUrl ?? '',
        'status': 'pending',
        'isApproved': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 4. Save Restaurant Profile to Firestore
      final restData = Map<String, dynamic>.from(userData);
      restData['isOpen'] = false;
      restData['rating'] = 5.0;
      restData['deliveryFee'] = 1500.0;

      // 5. Save to restaurant_requests (FOR ADMIN PANEL TO DETECT AND APPROVE)
      final requestData = {
        'uid': uid,
        'restaurantName': _restaurantName.text.trim(),
        'ownerName': _ownerName.text.trim(),
        'name': _restaurantName.text.trim(),
        'phone': formattedPhone,
        'whatsappPhone': formattedWhatsapp,
        'email': cleanEmail,
        'address': _restaurantAddress.text.trim(),
        'type': _selectedCuisine ?? 'مطعم',
        'cuisine': _selectedCuisine,
        'governorateId': _selectedGovId,
        'governorateName': _selectedGovName,
        'regionId': _selectedRegId,
        'regionName': _selectedRegName,
        'subRegion': subRegion,
        'district': _selectedRegName,
        'neighborhood': subRegion,
        'imageUrl': coverUrl ?? '',
        'logoUrl': coverUrl ?? '',
        'latitude': _latitude,
        'longitude': _longitude,
        'deliveryTime': deliveryTimeStr,
        'minOrderAmount': minOrder,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('users').doc(uid).set(userData, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('restaurants').doc(uid).set(restData, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('restaurant_requests').doc(uid).set(requestData, SetOptions(merge: true));

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentUserRole_$uid', 'restaurant');
        await prefs.setString('currentUserRole', 'restaurant');
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
              const Text('تم تقديم طلب المطعم بنجاح!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'أهلاً بك شريكنا العزيز! تم إرسال طلب انضمام مطعمك لمراجعة الإدارة، وسوف يتم تفعيل حسابك مباشرة فور الاعتماد.',
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
            'تسجيل مطعم جديد',
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
                    _buildStep2RestaurantDetails(cardBg, isDark),
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
            Text('الخطوة 1: معلومات مالك المطعم', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: _primary)),
            SizedBox(height: 4.h),
            Text('أدخل البيانات الشخصية المعتمدة لمالك أو مدير المطعم.', style: TextStyle(fontSize: 12.sp, color: _lightSub)),
            SizedBox(height: 16.h),

            // Logo / Cover Upload Widget
            Center(
              child: GestureDetector(
                onTap: _pickCoverImage,
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
                        child: _selectedCoverBytes != null
                            ? Image.memory(_selectedCoverBytes!, fit: BoxFit.cover)
                            : Icon(Icons.restaurant_rounded, size: 40.r, color: _primary),
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
                _selectedCoverFilename ?? 'اضغط لإضافة شعار / صورة غلاف المطعم (إجباري) *',
                style: TextStyle(fontSize: 11.sp, color: _primary, fontWeight: FontWeight.bold),
              ),
            ),

            SizedBox(height: 20.h),

            // Owner Name
            TextFormField(
              controller: _ownerName,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة اسم المالك' : null,
              decoration: _inputDeco('اسم مالك أو مدير المطعم', Icons.person_outline_rounded, isDark),
            ),

            SizedBox(height: 12.h),

            // Phone
            IraqiPhoneInputField(
              controller: _phone,
              hintText: 'رقم هاتف المالك (مثال: 07701234567)',
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
              decoration: _inputDeco('البريد الإلكتروني الرسمي للمطعم', Icons.email_outlined, isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // STEP 2: RESTAURANT DETAILS
  // ═══════════════════════════════════════════════════
  Widget _buildStep2RestaurantDetails(Color cardBg, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.r),
      child: Form(
        key: _step2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الخطوة 2: تفاصيل وقائمة المطعم', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: _primary)),
            SizedBox(height: 4.h),
            Text('حدد تخصص المطعم التجاري لإتاحة طلب الوجبات بسهولة للزبائن.', style: TextStyle(fontSize: 12.sp, color: _lightSub)),
            SizedBox(height: 16.h),

            // Restaurant Name
            TextFormField(
              controller: _restaurantName,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة اسم المطعم الرسمي' : null,
              decoration: _inputDeco('اسم المطعم التجاري', Icons.restaurant_rounded, isDark),
            ),

            SizedBox(height: 14.h),

            // Cuisine Dropdown
            Text('تخصص المأكولات والمطعم:', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 6.h),
            DropdownButtonFormField<String>(
              initialValue: _selectedCuisine,
              isExpanded: true,
              items: _cuisines.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle()))).toList(),
              onChanged: (v) => setState(() => _selectedCuisine = v),
              decoration: _inputDeco('اختر التخصص الرئيسي', Icons.restaurant_menu_rounded, isDark),
            ),

            SizedBox(height: 14.h),

            // Working Hours
            TextFormField(
              controller: _workingHours,
              decoration: _inputDeco('ساعات الدوام (مثال: يومياً من 10:00 ص إلى 12:00 م)', Icons.access_time_rounded, isDark),
            ),

            SizedBox(height: 14.h),

            // Delivery Time
            TextFormField(
              controller: _deliveryTime,
              decoration: _inputDeco('وقت التوصيل التقديري للزبائن (مثال: 25 - 35 دقيقة)', Icons.timer_outlined, isDark),
            ),

            SizedBox(height: 14.h),

            // Minimum Order Amount
            TextFormField(
              controller: _minOrderAmount,
              keyboardType: TextInputType.number,
              decoration: _inputDeco('الحد الأدنى للطلب بالدينار (مثال: 5000)', Icons.monetization_on_outlined, isDark),
            ),

            SizedBox(height: 14.h),

            // WhatsApp Orders Phone
            TextFormField(
              controller: _whatsappPhone,
              keyboardType: TextInputType.phone,
              decoration: _inputDeco('رقم واتساب المطبخ / الطلبات (اختياري، إن كان مختلفاً)', Icons.chat_outlined, isDark),
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
            Text('الخطوة 3: عنوان ومكان المطعم', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: _primary)),
            SizedBox(height: 4.h),
            Text('حدد المحافظة والمنطقة لتسهيل استلام ووصول كباتن التوصيل.', style: TextStyle(fontSize: 12.sp, color: _lightSub)),
            SizedBox(height: 16.h),

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
                      _selectedSubRegionName = null;
                      _customSubRegionController.clear();
                      _subRegionsList = [];
                    });
                    _loadRegions(val);
                  },
                  decoration: _inputDeco('المحافظة', Icons.map_outlined, isDark),
                );
              },
            ),

            SizedBox(height: 14.h),

            // Region Picker (القضاء / المنطقة)
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
                    _selectedSubRegionName = null;
                    _customSubRegionController.clear();
                  });
                  _loadSubRegions(_selectedGovId ?? '', val, _selectedRegName!);
                },
                decoration: _inputDeco('المنطقة أو القضاء', Icons.location_city_outlined, isDark),
              ),

            // Sub-Region / Neighborhood Picker (الناحية والمنطقة / الحي)
            if (_selectedRegName != null) ...[
              SizedBox(height: 14.h),
              if (_isLoadingSubRegions)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedSubRegionName,
                  isExpanded: true,
                  hint: Text('اختر الناحية / الحي في $_selectedRegName', style: const TextStyle()),
                  items: _subRegionsList.map((sub) {
                    return DropdownMenuItem<String>(
                      value: sub,
                      child: Text(sub, style: const TextStyle()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSubRegionName = val;
                      if (val != 'أخرى (كتابة يدوية)') {
                        _customSubRegionController.clear();
                      }
                    });
                  },
                  validator: (v) => (v == null || v.isEmpty) ? 'يرجى اختيار الناحية / الحي' : null,
                  decoration: _inputDeco('الناحية والمنطقة / الحي (مثال: حصيبة، الكرابلة، العبيدي...)', Icons.holiday_village_outlined, isDark),
                ),

              if (_selectedSubRegionName == 'أخرى (كتابة يدوية)') ...[
                SizedBox(height: 10.h),
                TextFormField(
                  controller: _customSubRegionController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة اسم الناحية أو المنطقة' : null,
                  decoration: _inputDeco('اكتب اسم الناحية أو المنطقة / الحي هنا بالتحديد', Icons.edit_location_alt_outlined, isDark),
                ),
              ],
            ],

            SizedBox(height: 14.h),

            // Detailed Address
            TextFormField(
              controller: _restaurantAddress,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة العنوان التفصيلي' : null,
              decoration: _inputDeco('العنوان التفصيلي للمطعم (الشارع / أقرب نقطة دالة)', Icons.place_outlined, isDark),
            ),

            SizedBox(height: 14.h),

            // Google Maps Location Pin Card
            Container(
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: _latitude != null
                    ? Colors.green.withValues(alpha: 0.08)
                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.orange.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: _latitude != null
                      ? Colors.green.withValues(alpha: 0.5)
                      : _primary.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: (_latitude != null ? Colors.green : _primary).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _latitude != null ? Icons.check_circle_rounded : Icons.map_rounded,
                          color: _latitude != null ? Colors.green : _primary,
                          size: 24.sp,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _latitude != null
                                  ? 'تم تثبيت موقع المطعم على الخريطة'
                                  : 'تحديد موقع المطعم على خرائط Google',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: _latitude != null ? Colors.green.shade800 : (isDark ? Colors.white : _lightText),
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              _latitude != null
                                  ? 'الإحداثيات: ${_latitude!.toStringAsFixed(4)} , ${_longitude!.toStringAsFixed(4)}'
                                  : 'افتح خرائط Google وحدد مكان مطعمك بدقة لنرشد الزبائن وكباتن التوصيل.',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: isDark ? Colors.white60 : _lightSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openMapPicker,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _latitude != null ? Colors.green.shade700 : _primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            elevation: 0,
                          ),
                          icon: Icon(
                            _latitude != null ? Icons.edit_location_alt_rounded : Icons.map_rounded,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                          label: Text(
                            _latitude != null ? 'تغيير الموقع من الخريطة' : 'فتح خرائط Google لتحديد الموقع',
                            style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      OutlinedButton(
                        onPressed: _isLocating ? null : _getCurrentLocation,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primary,
                          side: BorderSide(color: _primary.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
                        ),
                        child: _isLocating
                            ? SizedBox(width: 18.w, height: 18.h, child: const CircularProgressIndicator(strokeWidth: 2, color: _primary))
                            : Icon(Icons.my_location_rounded, size: 20.sp, color: _primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const Map<String, List<String>> _knownSubRegions = {
    // قضاء القائم ونواحيه وأحياؤه بالتفصيل
    'القائم': [
      'مركز القائم (حصيبة الغربية)',
      'ناحية الكرابلة',
      'ناحية العبيدي',
      'ناحية الرمانة',
      'منطقة السنجك',
      'منطقة السعدة',
      'حي الشهداء',
      'حي التأميم',
      'حي الفرات',
      'حي الرسالة',
      'حي السكك',
      'حي الجماهير',
      'حي الضباط',
      'حي اليرموك',
      'منطقة الباغوز',
      'منطقة المشاريع',
      'منطقة تلول السوسة',
      'منطقة الخسفة',
      'قرية كريطية',
    ],
    'الرمادي': [
      'مركز الرمادي',
      'التأميم',
      '7 نيسان',
      'حي المعلمين',
      'حي الضباط',
      'الحوز',
      'الصوفية',
      'جويبة',
      'الخمسة كيلو (5 كغم)',
      'السبعة كيلو (7 كغم)',
      'الورار',
      'الملعب',
      'زنكورة',
      'الجزيرة',
    ],
    'الفلوجة': [
      'مركز الفلوجة',
      'حي الجمهورية',
      'حي نزال',
      'حي الجولان',
      'حي الضباط',
      'حي الرسالة',
      'حي العسكري',
      'حي جبيل',
      'حي الشرطة',
      'حي المعلمين',
      'الصقلاوية',
      'الكرمة',
      'عامرية الصمود',
    ],
    'هيت': [
      'مركز هيت',
      'ناحية البغدادي',
      'ناحية كبيسة',
      'ناحية الفرات',
      'منطقة المحمدي',
      'حي البكر',
      'حي المعلمين',
      'منطقة الزوية',
    ],
    'حديثة': [
      'مركز حديثة',
      'ناحية بروانة',
      'ناحية الحقلانية',
      'حي اليرموك',
      'حي المعلمين',
      'حي النفط',
    ],
    'عانة': [
      'مركز عانة',
      'عانة القديمة',
      'عانة الجديدة',
      'ناحية الريحانة',
      'حي الجزيرة',
    ],
    'راوة': [
      'مركز راوة',
      'حي الفرات',
      'حي القلعة',
      'حي الشهداء',
    ],
    'الرطبة': [
      'مركز الرطبة',
      'ناحية الوليد',
      'منطقة طريبيل',
      'حي الانتصار',
    ],
    'الكرخ': [
      'المنصور',
      'اليرموك',
      'الحارثية',
      'الداودي',
      'الإسكان',
      'العامرية',
      'الغزالية',
      'الدورة',
      'السيدية',
      'حي الجامعة',
      'حي الخضراء',
      'حي الجهاد',
      'الشعلة',
      'الكاظمية',
    ],
    'الرصافة': [
      'الكرادة داخل',
      'الكرادة خارج',
      'الجادرية',
      'شارع فلسطين',
      'زيونة',
      'الغدير',
      'بغداد الجديدة',
      'الأعظمية',
      'الصليخ',
      'الشعب',
      'حي القاهرة',
      'مدينة الصدر',
    ],
  };

  Future<void> _loadSubRegions(String govId, String regId, String regName) async {
    setState(() => _isLoadingSubRegions = true);

    List<String> foundList = getSubRegionsForRegion(regName);

    try {
      if (govId.isNotEmpty && regId.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('governorates')
            .doc(govId)
            .collection('regions')
            .doc(regId)
            .collection('sub_regions')
            .get();

        for (final doc in snap.docs) {
          final sName = (doc.data()['name'] ?? '').toString().trim();
          if (sName.isNotEmpty && !foundList.contains(sName)) {
            foundList.add(sName);
          }
        }
      }
    } catch (_) {}

    if (foundList.isEmpty) {
      foundList = [
        'مركز $regName',
        'حي المعلمين',
        'حي الشهداء',
        'حي الفرات',
        'حي الرسالة',
        'حي التأميم',
      ];
    }

    if (!foundList.contains('أخرى (كتابة يدوية)')) {
      foundList.add('أخرى (كتابة يدوية)');
    }

    if (mounted) {
      setState(() {
        _subRegionsList = foundList;
        _isLoadingSubRegions = false;
      });
    }
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
          _loadSubRegions(govId, _selectedRegId!, _selectedRegName!);
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
            Text('عين كلمة مرور قوية لدخول لوحة تحكم المطعم واستقبال الطلبات.', style: TextStyle(fontSize: 12.sp, color: _lightSub)),
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

            SizedBox(height: 16.h),

            // Terms and Conditions Agreement
            InkWell(
              onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
              borderRadius: BorderRadius.circular(10.r),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 6.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24.w,
                      height: 24.h,
                      child: Checkbox(
                        value: _agreedToTerms,
                        activeColor: _primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.r)),
                        onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'أوافق وأتعهد بالالتزام بشروط وضوابط منصة مدار للمطاعم الشريكة، ومعايير جودة ونظافة الأطعمة، ونسبة العمولة المتفق عليها.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          height: 1.4,
                          color: isDark ? Colors.white70 : _lightText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
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
