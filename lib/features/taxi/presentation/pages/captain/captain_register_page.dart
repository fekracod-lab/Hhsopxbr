import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dalal_alqaim/services/cloudinary_service.dart';
import 'package:dalal_alqaim/widgets/premium_widgets.dart';
import 'package:dalal_alqaim/features/auth/widgets/iraqi_phone_input_field.dart';
import 'package:dalal_alqaim/services/ahyxi_otp_service.dart';
import 'package:dalal_alqaim/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dalal_alqaim/constants/iraq_geography.dart';

// --- Palette ---
const Color _primary = Color(0xFF26A69A);
const Color _accent = Color(0xFF00796B);
const Color _lightText = Color(0xFF2C3E50);
const Color _lightSub = Color(0xFF7F8C8D);

class CaptainRegisterPage extends StatefulWidget {
  const CaptainRegisterPage({super.key});

  @override
  State<CaptainRegisterPage> createState() => _CaptainRegisterPageState();
}

class _CaptainRegisterPageState extends State<CaptainRegisterPage> with TickerProviderStateMixin {
  // --- Step Control ---
  int _currentStep = 0;
  final _pageController = PageController();

  // --- Form Keys ---
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();
  final _step4Key = GlobalKey<FormState>();

  // --- Step 1: Personal Controllers ---
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  // --- Step 2: Car & Plate Controllers ---
  final _carNumber = TextEditingController();
  final _carColor = TextEditingController();
  String? _selectedPlateGov = 'الأنبار';
  String? _plateLetter = 'أ';
  String _plateType = 'أجرة (عمومي)';
  String? _selectedCarMake;
  String? _selectedCarModel;
  String? _selectedCarYear = '2020';
  String _selectedServiceType = 'تكسي اقتصادي (4 ركاب)';

  Uint8List? _selectedCarImageBytes;
  String? _selectedCarImageFilename;
  bool _isPickingCarImage = false;

  // --- Step 3: Location Controllers ---
  String? _selectedGovId, _selectedGovName;
  String? _selectedRegId, _selectedRegName;
  String? _selectedSubRegionName;
  final _customSubRegionController = TextEditingController();
  List<Map<String, dynamic>> _regions = [];
  List<String> _subRegionsList = [];
  bool _isLoadingSubRegions = false;

  // --- Step 4: Auth Controllers ---
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _agreedToTerms = true;

  // --- General State ---
  Uint8List? _selectedImageBytes;
  String? _selectedImageFilename;
  bool _loading = false;
  bool _isPickingImage = false;

  // --- Iraqi Car Plate Governorates ---
  static const List<String> _plateGovernorates = [
    'الأنبار',
    'بغداد',
    'أربيل',
    'البصرة',
    'نينوى',
    'كركوك',
    'صلاح الدين',
    'ديالى',
    'بابل',
    'كربلاء المقدسة',
    'النجف الأشرف',
    'واسط',
    'ميسان',
    'ذي قار',
    'المثنى',
    'القادسية (الديوانية)',
    'دهوك',
    'السليمانية',
  ];

  // --- Iraqi Car Plate Letters ---
  static const List<String> _plateLetters = [
    'أ', 'ب', 'ج', 'د', 'ر', 'س', 'ط', 'ع', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'هـ', 'و', 'ي', 'بدون حرف',
  ];

  // --- Iraqi Car Plate Types ---
  static const List<String> _plateTypes = [
    'أجرة (عمومي)',
    'خصوصي',
    'فحص مؤقت',
  ];

  // --- Taxi Service Types ---
  static const List<String> _serviceTypes = [
    'تكسي اقتصادي (4 ركاب)',
    'تكسي عائلي (7 ركاب)',
    'تكسي VIP / مريح',
    'تكسي نسائي',
  ];

  // --- Car Manufacture Years ---
  static final List<String> _carYears = List.generate(22, (i) => (2026 - i).toString());

  // --- Car Makes and Models ---
  final Map<String, List<String>> _carMakesAndModels = {
    'تويوتا (Toyota)': ['Corolla', 'Camry', 'Avalon', 'Land Cruiser', 'Hilux', 'RAV4', 'Prado'],
    'هيونداي (Hyundai)': ['Elantra', 'Sonata', 'Accent', 'Tucson', 'Santa Fe', 'Kona'],
    'كيا (Kia)': ['Sportage', 'Sorento', 'Optima', 'Cerato', 'Rio', 'Picanto', 'Cadenza'],
    'نيسان (Nissan)': ['Altima', 'Sentra', 'Sunny', 'Patrol', 'Pathfinder', 'X-Terra'],
    'ام جي (MG)': ['MG5', 'MG6', 'ZS', 'RX5', 'RX8'],
    'شيري (Chery)': ['Tiggo 7', 'Tiggo 8', 'Arrizo 6', 'Tiggo 4'],
    'هوندا (Honda)': ['Civic', 'Accord', 'CR-V'],
    'مازدا (Mazda)': ['Mazda 3', 'Mazda 6', 'CX-5'],
    'فورد (Ford)': ['Taurus', 'Explorer', 'Expedition', 'Edge', 'Focus'],
    'شيفروليه (Chevrolet)': ['Malibu', 'Tahoe', 'Silverado', 'Cruze', 'Captiva'],
    'بي ام دبليو (BMW)': ['Series 3', 'Series 5', 'Series 7', 'X5'],
    'مرسيدس (Mercedes)': ['C-Class', 'E-Class', 'S-Class', 'GLE'],
    'أخرى (Other)': ['موديل آخر'],
  };

  // --- Preloaded SubRegions / Districts Dictionary ---
  static const Map<String, List<String>> _knownSubRegions = {
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

  static const _stepTitles = ['البيانات الشخصية', 'المركبة واللوحة', 'منطقة النشاط', 'تأمين الحساب'];
  static const _stepIcons = [
    Icons.person_rounded,
    Icons.directions_car_filled_rounded,
    Icons.location_on_rounded,
    Icons.verified_user_rounded,
  ];

  String get _formattedPlate {
    final num = _carNumber.text.trim();
    final gov = _selectedPlateGov ?? 'العراق';
    final letter = (_plateLetter != null && _plateLetter != 'بدون حرف') ? ' $_plateLetter' : '';
    final type = _plateType;
    if (num.isEmpty) return '$gov$letter ($type)';
    return '$gov$letter $num ($type)';
  }

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
      _subRegionsList = getSubRegionsForRegion(_selectedRegName!);
      if (!_subRegionsList.contains('أخرى (كتابة يدوية)')) {
        _subRegionsList.add('أخرى (كتابة يدوية)');
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _carNumber.dispose();
    _carColor.dispose();
    _customSubRegionController.dispose();
    _password.dispose();
    _confirm.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (!_validateCurrentStep()) return;

    if (_currentStep < 3) {
      HapticFeedback.mediumImpact();
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _registerCaptain();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      HapticFeedback.lightImpact();
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      Navigator.pop(context);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_selectedImageBytes == null) {
          _showError('يرجى تحميل الصورة الشخصية للكابتن');
          return false;
        }
        final rawPhone = _phone.text.trim();
        if (rawPhone.isEmpty || rawPhone.length < 10) {
          _showError('يرجى إدخال رقم هاتف عراقي صالح');
          return false;
        }
        return _step1Key.currentState?.validate() ?? false;

      case 1:
        if (_selectedPlateGov == null) {
          _showError('يرجى تحديد محافظة رقم السيارة');
          return false;
        }
        if (_carNumber.text.trim().isEmpty) {
          _showError('يرجى إدخال رقم اللوحة');
          return false;
        }
        if (_selectedCarMake == null) {
          _showError('يرجى اختيار ماركة السيارة');
          return false;
        }
        if (_selectedCarModel == null) {
          _showError('يرجى اختيار موديل السيارة');
          return false;
        }
        if (_selectedCarYear == null) {
          _showError('يرجى اختيار سنة صنع السيارة');
          return false;
        }
        return _step2Key.currentState?.validate() ?? false;

      case 2:
        if (_selectedGovId == null) {
          _showError('يرجى اختيار المحافظة');
          return false;
        }
        if (_selectedRegId == null) {
          _showError('يرجى اختيار المنطقة أو القضاء');
          return false;
        }
        if (_selectedSubRegionName == null || _selectedSubRegionName!.trim().isEmpty) {
          _showError('يرجى اختيار الناحية والمنطقة / الحي');
          return false;
        }
        if (_selectedSubRegionName == 'أخرى (كتابة يدوية)' && _customSubRegionController.text.trim().isEmpty) {
          _showError('يرجى كتابة اسم الناحية والمنطقة / الحي يدوياً');
          return false;
        }
        return _step3Key.currentState?.validate() ?? false;

      case 3:
        if (!_agreedToTerms) {
          _showError('يرجى الموافقة على الشروط والأحكام للإكمال');
          return false;
        }
        return _step4Key.currentState?.validate() ?? false;

      default:
        return true;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
      backgroundColor: Colors.redAccent.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageFilename = picked.name;
        });
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _pickCarImage() async {
    if (_isPickingCarImage) return;
    setState(() => _isPickingCarImage = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedCarImageBytes = bytes;
          _selectedCarImageFilename = picked.name;
        });
      }
    } finally {
      if (mounted) setState(() => _isPickingCarImage = false);
    }
  }

  Future<void> _fetchRegions(String govId) async {
    setState(() {
      _regions = [];
      _selectedRegId = null;
      _selectedRegName = null;
      _subRegionsList = [];
      _selectedSubRegionName = null;
    });

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
        if (fetched.isNotEmpty) {
          _selectedRegId = (fetched.first['id'] ?? '').toString();
          _selectedRegName = (fetched.first['name'] ?? '').toString();
          _loadSubRegions(govId, _selectedRegId!, _selectedRegName!);
        }
      });
    }
  }

  Future<void> _loadSubRegions(String govId, String regId, String regName) async {
    setState(() {
      _isLoadingSubRegions = true;
      _selectedSubRegionName = null;
      _subRegionsList = [];
    });

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

  Future<void> _registerCaptain() async {
    setState(() => _loading = true);
    final rawPhone = _phone.text.trim();
    final formattedPhone = AhyxiOtpService.formatIraqiPhoneNumber(rawPhone);

    try {
      // 1. فحص تكرار رقم الهاتف
      final check = await UserService.checkPhoneRegistration(formattedPhone);
      if (check != null && check['exists'] == true) {
        setState(() => _loading = false);
        _showError('رقم الهاتف مسجل مسبقاً في منصة مدار، يرجى تسجيل الدخول أو استخدام رقم آخر.');
        return;
      }

      // 2. رفع الصورة الشخصية وصورة السيارة
      final photoUrl = await CloudinaryService.uploadBytes(
        _selectedImageBytes!,
        _selectedImageFilename ?? 'captain_avatar.jpg',
      );

      String? carPhotoUrl;
      if (_selectedCarImageBytes != null) {
        try {
          carPhotoUrl = await CloudinaryService.uploadBytes(
            _selectedCarImageBytes!,
            _selectedCarImageFilename ?? 'captain_car.jpg',
          );
        } catch (_) {}
      }

      final email = _email.text.trim().isNotEmpty
          ? _email.text.trim()
          : 'captain_${formattedPhone.replaceAll("+", "")}@dalal-alqaim.com';

      // 3. إنشاء حساب المستخدم في Firebase Auth
      UserCredential cred;
      try {
        cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: _password.text.trim(),
        );
      } catch (_) {
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: _password.text.trim(),
        );
      }

      final uid = cred.user!.uid;
      final subRegion = (_selectedSubRegionName == 'أخرى (كتابة يدوية)')
          ? _customSubRegionController.text.trim()
          : (_selectedSubRegionName ?? '');

      final fullPlate = _formattedPlate;

      final data = {
        'uid': uid,
        'id': uid,
        'fullName': _name.text.trim(),
        'name': _name.text.trim(),
        'email': email,
        'phone': formattedPhone,
        'isPhoneVerified': true,
        // تفاصيل لوحة السيارة العراقية
        'carNumber': _carNumber.text.trim(),
        'plateGovernorate': _selectedPlateGov ?? '',
        'plateLetter': _plateLetter ?? '',
        'plateType': _plateType,
        'fullCarPlate': fullPlate,
        // تفاصيل المركبة
        'carType': _selectedCarMake ?? '',
        'carModel': _selectedCarModel ?? '',
        'carYear': _selectedCarYear ?? '',
        'carColor': _carColor.text.trim(),
        'serviceType': _selectedServiceType,
        // النطاق الجغرافي
        'governorateId': _selectedGovId,
        'governorateName': _selectedGovName,
        'regionId': _selectedRegId,
        'regionName': _selectedRegName,
        'subRegionName': subRegion,
        // الصور
        'photoUrl': photoUrl,
        'profilePicture': photoUrl,
        'carPhotoUrl': carPhotoUrl ?? '',
        'carImage': carPhotoUrl ?? '',
        // الصلاحيات والحالة
        'role': 'driver',
        'isDriver': true,
        'isDelivery': false,
        'status': 'pending',
        'isApproved': false,
        'rating': 5.0,
        'available': false,
        'availability': 'offline',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 4. حفظ متزامن في users, driver_requests, drivers
      await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(uid).set(data, SetOptions(merge: true)),
        FirebaseFirestore.instance.collection('driver_requests').doc(uid).set(data, SetOptions(merge: true)),
        FirebaseFirestore.instance.collection('drivers').doc(uid).set(data, SetOptions(merge: true)),
      ]);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentUserRole_$uid', 'captain');
        await prefs.setString('currentUserRole', 'captain');
        await prefs.setString('currentUserId', uid);
      } catch (_) {}

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        _showError('حدث خطأ أثناء التسجيل: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            Text(
              'تم استلام طلبك بنجاح',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'أهلاً بك كابتن! تم إرسال طلب انضمامك إلى إدارة تكسي مدار للمراجعة والتدقيق. سيتم تفعيل حسابك فور استكمال الاعتماد.',
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'متابعة حالة الحساب والدخول',
              style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: Image.asset(
                  'assets/images/aviation_bg_pattern.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  PremiumStepper(
                    currentStep: _currentStep,
                    icons: _stepIcons,
                    titles: _stepTitles,
                    activeColor: _primary,
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStep1(),
                        _buildStep2(),
                        _buildStep3(),
                        _buildStep4(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomActions()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, color: _lightText),
            onPressed: _prevStep,
          ),
          const Expanded(
            child: Text(
              'انضمام كابتن تكسي جديد',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _primary),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildStepCard({required List<Widget> children, GlobalKey<FormState>? formKey}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 90),
      child: GlassCard(
        opacity: 0.6,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(key: formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
        ),
      ),
    );
  }

  // --- الخطوة 1: البيانات الشخصية (بدون OTP) ---
  Widget _buildStep1() {
    return _buildStepCard(
      formKey: _step1Key,
      children: [
        Center(child: _buildPremiumPhotoPicker()),
        const SizedBox(height: 20),
        PremiumTextField(
          controller: _name,
          label: 'الاسم الرباعي واللقب للكابتن',
          icon: Icons.person_outline,
          primaryColor: _primary,
          validator: (v) => (v == null || v.trim().length < 6) ? 'يرجى إدخال الاسم الرباعي كاملاً' : null,
        ),
        const SizedBox(height: 16),
        PremiumTextField(
          controller: _email,
          label: 'البريد الإلكتروني (اختياري - يتم إنشاؤه تلقائياً)',
          icon: Icons.email_outlined,
          primaryColor: _primary,
          keyboard: TextInputType.emailAddress,
          validator: (v) => null,
        ),
        const SizedBox(height: 16),
        IraqiPhoneInputField(
          controller: _phone,
          hintText: 'رقم هاتف الكابتن (07XXXXXXXX)',
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: _primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'سيتم استخدام رقم الهاتف لتسجيل الدخول والتواصل واستقبال طلبات الركاب مباشرة.',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: _accent, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- الخطوة 2: المركبة ونظام لوحة السيارة العراقية المتقدم ---
  Widget _buildStep2() {
    return _buildStepCard(
      formKey: _step2Key,
      children: [
        // بطاقة اللوحة العراقية التفاعلية
        _buildIraqiPlatePreview(),
        const SizedBox(height: 20),

        // 1. محافظة رقم السيارة
        _buildPremiumSelect(
          label: 'محافظة تسجيل لوحة السيارة',
          value: _selectedPlateGov,
          icon: Icons.location_city_rounded,
          items: _plateGovernorates,
          onSelected: (v) => setState(() => _selectedPlateGov = v),
        ),
        const SizedBox(height: 14),

        // 2. صنف اللوحة + حرف اللوحة في سطر واحد
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildPremiumSelect(
                label: 'صنف اللوحة',
                value: _plateType,
                icon: Icons.category_rounded,
                items: _plateTypes,
                onSelected: (v) => setState(() => _plateType = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _buildPremiumSelect(
                label: 'حرف اللوحة',
                value: _plateLetter,
                icon: Icons.sort_by_alpha_rounded,
                items: _plateLetters,
                onSelected: (v) => setState(() => _plateLetter = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 3. رقم اللوحة
        PremiumTextField(
          controller: _carNumber,
          label: 'رقم لوحة السيارة (أرقام فقط مثلاً: 12345)',
          icon: Icons.pin_rounded,
          primaryColor: _primary,
          keyboard: TextInputType.number,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال رقم اللوحة' : null,
        ),
        const SizedBox(height: 16),

        const Divider(height: 24),
        Text(
          'مواصفات المركبة',
          style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 14, color: _primary),
        ),
        const SizedBox(height: 12),

        // 4. الماركة والموديل
        _buildPremiumSelect(
          label: 'ماركة السيارة (الصانع)',
          value: _selectedCarMake,
          icon: Icons.directions_car_rounded,
          items: _carMakesAndModels.keys.toList(),
          onSelected: (v) => setState(() {
            _selectedCarMake = v;
            _selectedCarModel = null;
          }),
        ),
        const SizedBox(height: 14),

        _buildPremiumSelect(
          label: 'الموديل (الطراز)',
          value: _selectedCarModel,
          icon: Icons.model_training_rounded,
          items: _selectedCarMake != null ? _carMakesAndModels[_selectedCarMake!]! : [],
          onSelected: (v) => setState(() => _selectedCarModel = v),
        ),
        const SizedBox(height: 14),

        // 5. سنة الصنع واللون
        Row(
          children: [
            Expanded(
              child: _buildPremiumSelect(
                label: 'سنة الصنع',
                value: _selectedCarYear,
                icon: Icons.calendar_today_rounded,
                items: _carYears,
                onSelected: (v) => setState(() => _selectedCarYear = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PremiumTextField(
                controller: _carColor,
                label: 'لون السيارة',
                icon: Icons.palette_outlined,
                primaryColor: _primary,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 6. نوع الخدمة
        _buildPremiumSelect(
          label: 'فئة خدمة التكسي',
          value: _selectedServiceType,
          icon: Icons.local_taxi_rounded,
          items: _serviceTypes,
          onSelected: (v) => setState(() => _selectedServiceType = v),
        ),
        const SizedBox(height: 18),

        // 7. صورة المركبة
        _buildCarPhotoCard(),
      ],
    );
  }

  // معاينة لوحة السيارة العراقية التفاعلية
  Widget _buildIraqiPlatePreview() {
    final isTaxi = _plateType.contains('أجرة');
    final isPrivate = _plateType.contains('خصوصي');

    final plateColor = isTaxi
        ? const Color(0xFFC62828) // أحمر للأجرة
        : (isPrivate ? const Color(0xFF37474F) : const Color(0xFF2E7D32));

    final govText = _selectedPlateGov ?? 'العراق';
    final letterText = (_plateLetter != null && _plateLetter != 'بدون حرف') ? _plateLetter! : '';
    final numText = _carNumber.text.trim().isNotEmpty ? _carNumber.text.trim() : '-----';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.15), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // شريط علوي صغير يوضح صنف اللوحة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: plateColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'لوحة مركبة عراقية',
                  style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  _plateType,
                  style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // جسم اللوحة الرئيسي
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // ختم العراق
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text('العراق', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      const Text('IRAQ', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // المحافظة
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    govText,
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.bold, color: _lightText),
                  ),
                ),
                const Spacer(),
                // الحرف والرقم
                Row(
                  children: [
                    if (letterText.isNotEmpty) ...[
                      Text(
                        letterText,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      numText,
                      style: GoogleFonts.montserrat(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: _lightText,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarPhotoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickCarImage,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: _selectedCarImageBytes != null ? Colors.transparent : _primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _primary.withValues(alpha: 0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _selectedCarImageBytes != null
                    ? Image.memory(_selectedCarImageBytes!, fit: BoxFit.cover)
                    : Icon(Icons.add_photo_alternate_rounded, color: _primary, size: 30.sp),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedCarImageBytes != null ? 'تم اختيار صورة المركبة' : 'صورة سيارة الكابتن (مستحسن)',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13, color: _lightText),
                ),
                const SizedBox(height: 2),
                Text(
                  'التقط صورة واضحة لمركبتك من الأمام أو الجانب لتوثيق الحساب ومساعدة الركاب.',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: _lightSub),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _pickCarImage,
            child: Text(
              _selectedCarImageBytes != null ? 'تغيير' : 'اختيار',
              style: GoogleFonts.ibmPlexSansArabic(color: _primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // --- الخطوة 3: تحديد منطقة النشاط والنواحي ---
  Widget _buildStep3() {
    return _buildStepCard(
      formKey: _step3Key,
      children: [
        const Icon(Icons.share_location_rounded, color: _primary, size: 54),
        const SizedBox(height: 12),
        Text(
          'حدد نطاق عملك وتغطية المشاوير',
          textAlign: TextAlign.center,
          style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16, color: _lightText),
        ),
        const SizedBox(height: 4),
        Text(
          'اختر المحافظة والقضاء ثم حدد الناحية أو الحي الذي تتواجد فيه بشكل رئيسي.',
          textAlign: TextAlign.center,
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: _lightSub),
        ),
        const SizedBox(height: 20),

        // 1. المحافظة
        _buildGovDropdown(),
        const SizedBox(height: 14),

        // 2. القضاء / المنطقة
        _buildRegDropdown(),
        const SizedBox(height: 14),

        // 3. الناحية / الحي
        if (_isLoadingSubRegions)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(color: _primary)),
          )
        else if (_subRegionsList.isNotEmpty) ...[
          _buildPremiumSelect(
            label: 'الناحية والمنطقة / الحي',
            value: _selectedSubRegionName,
            icon: Icons.holiday_village_rounded,
            items: _subRegionsList,
            onSelected: (v) => setState(() => _selectedSubRegionName = v),
          ),
          if (_selectedSubRegionName == 'أخرى (كتابة يدوية)') ...[
            const SizedBox(height: 12),
            PremiumTextField(
              controller: _customSubRegionController,
              label: 'اكتب اسم الناحية والمنطقة / الحي يدوياً',
              icon: Icons.edit_location_alt_rounded,
              primaryColor: _primary,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة اسم المنطقة' : null,
            ),
          ],
        ],
      ],
    );
  }

  // --- الخطوة 4: تأمين الحساب والموافقة ---
  Widget _buildStep4() {
    return _buildStepCard(
      formKey: _step4Key,
      children: [
        const Icon(Icons.shield_rounded, color: _primary, size: 54),
        const SizedBox(height: 12),
        Text(
          'تأمين حساب الكابتن',
          textAlign: TextAlign.center,
          style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16, color: _lightText),
        ),
        const SizedBox(height: 4),
        Text(
          'عيّن كلمة مرور قوية لتسجيل الدخول إلى لوحة كابتن مدار في أي وقت.',
          textAlign: TextAlign.center,
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: _lightSub),
        ),
        const SizedBox(height: 20),

        PremiumTextField(
          controller: _password,
          label: 'كلمة المرور',
          icon: Icons.lock_outline,
          primaryColor: _primary,
          obscure: _obscure1,
          validator: (v) => (v == null || v.length < 6) ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : null,
          suffix: IconButton(
            icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility, color: _lightSub),
            onPressed: () => setState(() => _obscure1 = !_obscure1),
          ),
        ),
        const SizedBox(height: 14),

        PremiumTextField(
          controller: _confirm,
          label: 'تأكيد كلمة المرور',
          icon: Icons.lock_reset_rounded,
          primaryColor: _primary,
          obscure: _obscure2,
          validator: (v) => (v != _password.text) ? 'كلمة المرور غير متطابقة' : null,
          suffix: IconButton(
            icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility, color: _lightSub),
            onPressed: () => setState(() => _obscure2 = !_obscure2),
          ),
        ),
        const SizedBox(height: 16),

        // ملخص سريع للبيانات
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ملخص طلب الانضمام:',
                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13, color: _lightText),
              ),
              const SizedBox(height: 6),
              _buildSummaryRow('الكابتن:', _name.text.trim().isNotEmpty ? _name.text.trim() : 'غير محدد'),
              _buildSummaryRow('المركبة:', '${_selectedCarMake ?? ''} ${_selectedCarModel ?? ''} ${_selectedCarYear ?? ''}'.trim()),
              _buildSummaryRow('اللوحة:', _formattedPlate),
              _buildSummaryRow('المنطقة:', '${_selectedGovName ?? ''} - ${_selectedRegName ?? ''}'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // خانة الموافقة على الشروط
        CheckboxListTile(
          value: _agreedToTerms,
          activeColor: _primary,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
          title: Text(
            'أقر بصحة البيانات وأوافق على الشروط والأحكام وسياسة الخصوصية الخاصة بكباتن منصة مدار.',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: _lightText, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(title, style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: _lightSub)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              val.isNotEmpty ? val : '---',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold, color: _lightText),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumPhotoPicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
          border: Border.all(color: _selectedImageBytes != null ? _primary : Colors.grey.shade200, width: 3),
        ),
        child: ClipOval(
          child: _selectedImageBytes != null
              ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_rounded, size: 36, color: _primary),
                    const SizedBox(height: 6),
                    Text(
                      'صورة الكابتن',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: _lightSub, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPremiumSelect({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String) onSelected,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: icon != null ? Icon(icon, color: _primary, size: 22) : null,
        title: Text(
          value ?? label,
          style: GoogleFonts.ibmPlexSansArabic(
            color: value == null ? _lightSub : _lightText,
            fontSize: 13.5,
            fontWeight: value == null ? FontWeight.normal : FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.keyboard_arrow_down_rounded, color: _primary),
        onTap: () => _showPicker(label, items, onSelected),
      ),
    );
  }

  void _showPicker(String title, List<String> items, Function(String) onSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.55,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 14),
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16, color: _lightText),
              ),
              const SizedBox(height: 8),
              const Divider(),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد عناصر متاحة',
                          style: GoogleFonts.ibmPlexSansArabic(color: _lightSub),
                        ),
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                        itemBuilder: (_, i) => ListTile(
                          title: Text(
                            items[i],
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _lightSub),
                          onTap: () {
                            onSelected(items[i]);
                            Navigator.pop(context);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGovDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('governorates').snapshots(),
      builder: (context, snap) {
        List<Map<String, String>> items = [];
        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          for (final d in snap.data!.docs) {
            final data = d.data() as Map<String, dynamic>?;
            final name = (data?['name'] ?? data?['title'] ?? d.id).toString().trim();
            if (name.isNotEmpty && !items.any((it) => it['name'] == name)) {
              items.add({'id': d.id, 'name': name});
            }
          }
        }
        if (items.isEmpty) {
          items = kIraqiGovernorates.map((g) => {'id': g, 'name': g}).toList();
        }

        final namesList = items.map((e) => e['name']!).toList();
        if (_selectedGovName == null || !namesList.contains(_selectedGovName)) {
          _selectedGovName = namesList.contains('الأنبار') ? 'الأنبار' : namesList.first;
          final matched = items.firstWhere((e) => e['name'] == _selectedGovName, orElse: () => items.first);
          _selectedGovId = matched['id'];
        }

        return _buildPremiumSelect(
          label: 'المحافظة',
          value: _selectedGovName,
          icon: Icons.location_city_rounded,
          items: namesList,
          onSelected: (v) {
            final item = items.firstWhere((e) => e['name'] == v, orElse: () => {'id': v, 'name': v});
            setState(() {
              _selectedGovName = v;
              _selectedGovId = item['id'];
            });
            _fetchRegions(_selectedGovId!);
          },
        );
      },
    );
  }

  Widget _buildRegDropdown() {
    final names = _regions
        .map((e) => (e['name'] ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return _buildPremiumSelect(
      label: 'المنطقة أو القضاء',
      value: _selectedRegName,
      icon: Icons.map_rounded,
      items: names,
      onSelected: (v) {
        final item = _regions.firstWhere(
          (e) => (e['name'] ?? '').toString() == v,
          orElse: () => {'id': v, 'name': v},
        );
        setState(() {
          _selectedRegName = v;
          _selectedRegId = (item['id'] ?? v).toString();
        });
        _loadSubRegions(_selectedGovId ?? '', _selectedRegId!, v);
      },
    );
  }

  Widget _buildBottomActions() {
    final isLast = _currentStep == 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: _loading
              ? null
              : LinearGradient(
                  colors: isLast ? [const Color(0xFF00897B), _accent] : [_primary, _accent],
                ),
          color: _loading ? Colors.grey.shade300 : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loading ? null : _nextStep,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isLast ? 'إرسال طلب انضمام الكابتن' : 'متابعة الخطوة التالية',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isLast ? Icons.check_circle_rounded : Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
