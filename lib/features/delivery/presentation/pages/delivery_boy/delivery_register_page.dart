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

// --- Palette (Delivery Cyan / Mint) ---
const Color _primary = Color(0xFF00BFA5);
const Color _accent = Color(0xFF00897B);
const Color _darkBg = Color(0xFF07191A);
const Color _darkCard = Color(0xFF113033);
const Color _darkText = Color(0xFFE0F2F1);
const Color _darkSub = Color(0xFF80CBC4);
const Color _darkHint = Color(0xFF4DB6AC);

class DeliveryRegisterPage extends StatefulWidget {
  const DeliveryRegisterPage({super.key});

  @override
  State<DeliveryRegisterPage> createState() => _DeliveryRegisterPageState();
}

class _DeliveryRegisterPageState extends State<DeliveryRegisterPage> {
  // --- Step Control ---
  int _currentStep = 0;
  final _pageController = PageController();

  // --- Form Keys ---
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();
  final _step4Key = GlobalKey<FormState>();

  // --- Step 1: Personal Info ---
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  Uint8List? _selectedPersonalImageBytes;
  String? _selectedPersonalImageFilename;
  bool _isPickingPersonalImage = false;

  // --- Step 2: Vehicle Info ---
  String _selectedVehicleType = 'دراجة نارية (ماطور)';
  bool _hasPlate = true;
  String? _selectedPlateGov = 'الأنبار';
  String? _plateLetter = 'أ';
  String _plateType = 'دراجة نارية';
  final _carNumber = TextEditingController();
  final _carType = TextEditingController(text: 'دراجة نارية');
  final _carColor = TextEditingController();
  Uint8List? _selectedVehicleImageBytes;
  String? _selectedVehicleImageFilename;
  bool _isPickingVehicleImage = false;

  // --- Step 3: Location Info ---
  String? _selectedGovId, _selectedGovName;
  String? _selectedRegId, _selectedRegName;
  String? _selectedSubRegionName;
  final _customSubRegionController = TextEditingController();
  List<Map<String, dynamic>> _regions = [];
  List<String> _subRegionsList = [];
  bool _isLoadingRegions = false;
  bool _isLoadingSubRegions = false;

  // --- Step 4: Documents & Security ---
  Uint8List? _selectedIdCardBytes;
  String? _selectedIdCardFilename;
  bool _isPickingIdCard = false;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _agreedToTerms = true;
  bool _loading = false;

  // --- Static Options ---
  static const _stepTitles = ['المعلومات الشخصية', 'وسيلة التوصيل', 'نطاق التوصيل', 'المستمسكات والتأمين'];
  static const _stepIcons = [
    Icons.person_rounded,
    Icons.two_wheeler_rounded,
    Icons.share_location_rounded,
    Icons.verified_user_rounded,
  ];

  static const List<String> _vehicleTypes = [
    'دراجة نارية (ماطور)',
    'تكتك / ستوتة',
    'سيارة صالون (توصيل)',
    'بيك آب / حمل خفيف',
    'دراجة هوائية / سكوتر',
  ];

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

  static const List<String> _plateLetters = [
    'أ', 'ب', 'ج', 'د', 'ر', 'س', 'ط', 'ع', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'هـ', 'و', 'ي', 'بدون حرف',
  ];

  static const List<String> _plateTypes = [
    'دراجة نارية',
    'أجرة (عمومي)',
    'خصوصي',
    'فحص مؤقت',
  ];

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

  String get _formattedPlate {
    if (!_hasPlate) return 'بدون لوحة تسجيل';
    final num = _carNumber.text.trim();
    final gov = _selectedPlateGov ?? 'العراق';
    final letter = (_plateLetter != null && _plateLetter != 'بدون حرف') ? ' $_plateLetter' : '';
    final type = _plateType;
    if (num.isEmpty) return '$gov$letter ($type)';
    return '$gov$letter $num ($type)';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _carNumber.dispose();
    _carType.dispose();
    _carColor.dispose();
    _customSubRegionController.dispose();
    _password.dispose();
    _confirm.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // --- Navigation & Validation ---

  Future<void> _nextStep() async {
    if (!_validateCurrentStep()) return;
    if (_currentStep < 3) {
      HapticFeedback.lightImpact();
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _registerDelivery();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      HapticFeedback.lightImpact();
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      Navigator.pop(context);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_selectedPersonalImageBytes == null) {
          _showError('يرجى تحميل الصورة الشخصية لمندوب التوصيل');
          return false;
        }
        final rawPhone = _phone.text.trim();
        if (rawPhone.isEmpty || rawPhone.length < 10) {
          _showError('يرجى إدخال رقم هاتف عراقي صالح');
          return false;
        }
        return _step1Key.currentState?.validate() ?? false;

      case 1:
        if (_hasPlate) {
          if (_selectedPlateGov == null) {
            _showError('يرجى تحديد محافظة تسجيل اللوحة');
            return false;
          }
          if (_carNumber.text.trim().isEmpty) {
            _showError('يرجى إدخال رقم اللوحة أو اختيار بدون لوحة');
            return false;
          }
        }
        return _step2Key.currentState?.validate() ?? false;

      case 2:
        if (_selectedGovId == null) {
          _showError('يرجى اختيار المحافظة');
          return false;
        }
        if (_selectedRegId == null) {
          _showError('يرجى اختيار القضاء أو المنطقة');
          return false;
        }
        if (_selectedSubRegionName == null || _selectedSubRegionName!.trim().isEmpty) {
          _showError('يرجى اختيار الناحية والحي السكني لتحديد نطاق عملك');
          return false;
        }
        if (_selectedSubRegionName == 'أخرى (كتابة يدوية)' && _customSubRegionController.text.trim().isEmpty) {
          _showError('يرجى كتابة اسم الناحية والحي السكني');
          return false;
        }
        return _step3Key.currentState?.validate() ?? false;

      case 3:
        if (!_agreedToTerms) {
          _showError('يرجى الموافقة على شروط وضوابط التوصيل للإكمال');
          return false;
        }
        return _step4Key.currentState?.validate() ?? false;

      default:
        return true;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // --- Image Pickers ---

  Future<void> _pickPersonalImage() async {
    if (_isPickingPersonalImage) return;
    setState(() => _isPickingPersonalImage = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedPersonalImageBytes = bytes;
          _selectedPersonalImageFilename = picked.name;
        });
      }
    } finally {
      if (mounted) setState(() => _isPickingPersonalImage = false);
    }
  }

  Future<void> _pickVehicleImage() async {
    if (_isPickingVehicleImage) return;
    setState(() => _isPickingVehicleImage = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedVehicleImageBytes = bytes;
          _selectedVehicleImageFilename = picked.name;
        });
      }
    } finally {
      if (mounted) setState(() => _isPickingVehicleImage = false);
    }
  }

  Future<void> _pickIdCardImage() async {
    if (_isPickingIdCard) return;
    setState(() => _isPickingIdCard = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedIdCardBytes = bytes;
          _selectedIdCardFilename = picked.name;
        });
      }
    } finally {
      if (mounted) setState(() => _isPickingIdCard = false);
    }
  }

  // --- Location Queries ---

  Future<void> _fetchRegions(String govId) async {
    setState(() {
      _isLoadingRegions = true;
      _regions = [];
      _selectedRegId = null;
      _selectedRegName = null;
      _subRegionsList = [];
      _selectedSubRegionName = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('governorates')
          .doc(govId)
          .collection('regions')
          .where('isActive', isEqualTo: true)
          .get();
      final docs = snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      docs.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
      if (mounted) {
        setState(() {
          _regions = docs;
          _isLoadingRegions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRegions = false);
    }
  }

  Future<void> _loadSubRegions(String govId, String regId, String regName) async {
    setState(() {
      _isLoadingSubRegions = true;
      _selectedSubRegionName = null;
      _subRegionsList = [];
    });

    final cleanName = regName.trim().replaceAll('قضاء', '').replaceAll('ناحية', '').trim();
    List<String> foundList = [];

    if (_knownSubRegions.containsKey(regName)) {
      foundList = List<String>.from(_knownSubRegions[regName]!);
    } else if (_knownSubRegions.containsKey(cleanName)) {
      foundList = List<String>.from(_knownSubRegions[cleanName]!);
    } else {
      for (final entry in _knownSubRegions.entries) {
        if (cleanName.contains(entry.key) || entry.key.contains(cleanName)) {
          foundList = List<String>.from(entry.value);
          break;
        }
      }
    }

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

  // --- Submission ---

  Future<void> _registerDelivery() async {
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

      // 2. رفع الصور إلى Cloudinary
      final photoUrl = await CloudinaryService.uploadBytes(
        _selectedPersonalImageBytes!,
        _selectedPersonalImageFilename ?? 'delivery_avatar.jpg',
      );

      String? vehiclePhotoUrl;
      if (_selectedVehicleImageBytes != null) {
        try {
          vehiclePhotoUrl = await CloudinaryService.uploadBytes(
            _selectedVehicleImageBytes!,
            _selectedVehicleImageFilename ?? 'delivery_vehicle.jpg',
          );
        } catch (_) {}
      }

      String? idCardPhotoUrl;
      if (_selectedIdCardBytes != null) {
        try {
          idCardPhotoUrl = await CloudinaryService.uploadBytes(
            _selectedIdCardBytes!,
            _selectedIdCardFilename ?? 'delivery_id_card.jpg',
          );
        } catch (_) {}
      }

      // 3. البريد الإلكتروني (توليد تلقائي إن لم يتم إدخاله)
      final email = _email.text.trim().isNotEmpty
          ? _email.text.trim()
          : 'delivery_${formattedPhone.replaceAll("+", "")}@dalal-alqaim.com';

      // 4. إنشاء المستخدم في Firebase Auth
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
      final carPlateNumber = _hasPlate ? _carNumber.text.trim() : 'بدون رقم';

      final data = {
        'uid': uid,
        'id': uid,
        'fullName': _name.text.trim(),
        'name': _name.text.trim(),
        'driverName': _name.text.trim(),
        'email': email,
        'phone': formattedPhone,
        'phoneNumber': formattedPhone,
        'isPhoneVerified': true,
        // وسيلة التوصيل والمركبة
        'vehicleType': _selectedVehicleType,
        'hasPlate': _hasPlate,
        'carNumber': carPlateNumber,
        'plateNumber': carPlateNumber,
        'plateGovernorate': _hasPlate ? (_selectedPlateGov ?? '') : '',
        'plateLetter': _hasPlate ? (_plateLetter ?? '') : '',
        'plateType': _hasPlate ? _plateType : 'بدون لوحة',
        'fullCarPlate': fullPlate,
        'carType': _carType.text.trim().isNotEmpty ? _carType.text.trim() : _selectedVehicleType,
        'vehicleModel': _carType.text.trim().isNotEmpty ? _carType.text.trim() : _selectedVehicleType,
        'carColor': _carColor.text.trim().isNotEmpty ? _carColor.text.trim() : 'غير محدد',
        'vehicleInfo': '$_selectedVehicleType ${_carType.text.trim()} $fullPlate'.trim(),
        // النطاق الجغرافي
        'governorateId': _selectedGovId,
        'governorateName': _selectedGovName,
        'governorate': _selectedGovName,
        'regionId': _selectedRegId,
        'regionName': _selectedRegName,
        'subRegionName': subRegion,
        // الصور والوثائق
        'photoUrl': photoUrl,
        'profilePicture': photoUrl,
        'vehiclePhotoUrl': vehiclePhotoUrl ?? '',
        'carPhotoUrl': vehiclePhotoUrl ?? '',
        'carImage': vehiclePhotoUrl ?? '',
        'idCardPhotoUrl': idCardPhotoUrl ?? '',
        // الصلاحيات والحالة
        'role': 'delivery',
        'subRole': 'delivery',
        'isDelivery': true,
        'isDriver': true,
        'isDeliveryApproved': false,
        'isApproved': false,
        'status': 'pending',
        'rating': 5.0,
        'available': false,
        'availability': 'offline',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 5. حفظ متزامن في users و driver_requests و drivers
      await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(uid).set(data, SetOptions(merge: true)),
        FirebaseFirestore.instance.collection('driver_requests').doc(uid).set(data, SetOptions(merge: true)),
        FirebaseFirestore.instance.collection('drivers').doc(uid).set(data, SetOptions(merge: true)),
      ]);

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
        backgroundColor: _darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: _primary, size: 28),
            const SizedBox(width: 10),
            Text(
              'تم استلام طلبك بنجاح',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16, color: _darkText),
            ),
          ],
        ),
        content: Text(
          'أهلاً بك في فريق دليفري مدار! تم إرسال طلب انضمامك لمراجعة الإدارة وتدقيق البيانات، وسوف يتم تفعيل حسابك فور استكمال الاعتماد.',
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, height: 1.5, color: _darkSub),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'حسناً، العودة لتسجيل الدخول',
              style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── BUILD ───────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _darkBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white),
            onPressed: _currentStep > 0 ? _prevStep : () => Navigator.pop(context),
          ),
          title: Text(
            'انضمام مندوب دليفري جديد',
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 17,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            _buildStepper(),
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
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  // ── STEPPER ──

  Widget _buildStepper() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 16),
      child: Column(
        children: [
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  margin: EdgeInsets.only(left: i < 3 ? 6 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: i <= _currentStep ? _primary : _darkCard,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_stepIcons[_currentStep], color: _primary, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الخطوة ${_currentStep + 1} من 4',
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: _darkSub),
                  ),
                  Text(
                    _stepTitles[_currentStep],
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _darkText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── STEP 1: Personal Info ──

  Widget _buildStep1() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Form(
        key: _step1Key,
        child: Column(
          children: [
            const SizedBox(height: 6),
            _buildPersonalPhotoPicker(),
            const SizedBox(height: 20),
            _field(
              controller: _name,
              label: 'الاسم الرباعي واللقب',
              icon: Icons.person_outline,
              validator: (v) => (v == null || v.trim().length < 6) ? 'يرجى كتابة الاسم الرباعي كاملاً' : null,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _email,
              label: 'البريد الإلكتروني (اختياري - يتم توليده تلقائياً)',
              icon: Icons.email_outlined,
              keyboard: TextInputType.emailAddress,
              validator: (v) => null,
            ),
            const SizedBox(height: 14),
            IraqiPhoneInputField(
              controller: _phone,
              hintText: 'رقم هاتف المندوب (07XXXXXXXX)',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _darkCard.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: _primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'يُستخدم رقم الهاتف لتسجيل الدخول مباشرة واستقبال إشعارات الطلبات القريبة من موقعك.',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: _darkSub, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── STEP 2: Vehicle Info & Iraqi Plate ──

  Widget _buildStep2() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Form(
        key: _step2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقة اللوحة إن وجدت
            if (_hasPlate) ...[
              _buildIraqiPlatePreview(),
              const SizedBox(height: 16),
            ],

            // نوع وسيلة التوصيل
            _buildSelect(
              label: 'نوع وسيلة التوصيل',
              value: _selectedVehicleType,
              icon: Icons.delivery_dining_rounded,
              items: _vehicleTypes,
              onSelected: (v) {
                setState(() {
                  _selectedVehicleType = v;
                  if (v.contains('دراجة هوائية')) {
                    _hasPlate = false;
                  }
                  _carType.text = v;
                });
              },
            ),
            const SizedBox(height: 14),

            // خيار: هل تحمل لوحة تسجيل؟
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: _darkCard.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _darkSub.withValues(alpha: 0.15)),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: _primary,
                title: Text(
                  'المركبة تحمل لوحة تسجيل رسمية',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: _darkText, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _hasPlate ? 'قم بتسجيل تفاصيل اللوحة' : 'بدون لوحة (دراجة غير مرقمة أو هوائية)',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: _darkSub),
                ),
                value: _hasPlate,
                onChanged: (val) => setState(() => _hasPlate = val),
              ),
            ),
            const SizedBox(height: 14),

            // حقول اللوحة في حال توفرها
            if (_hasPlate) ...[
              _buildSelect(
                label: 'محافظة تسجيل اللوحة',
                value: _selectedPlateGov,
                icon: Icons.location_city_rounded,
                items: _plateGovernorates,
                onSelected: (v) => setState(() => _selectedPlateGov = v),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildSelect(
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
                    child: _buildSelect(
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
              _field(
                controller: _carNumber,
                label: 'رقم اللوحة (أرقام فقط مثلاً: 12345)',
                icon: Icons.confirmation_number_outlined,
                keyboard: TextInputType.number,
                validator: (v) {
                  if (!_hasPlate) return null;
                  return (v == null || v.trim().isEmpty) ? 'يرجى إدخال رقم اللوحة' : null;
                },
              ),
              const SizedBox(height: 14),
            ],

            // مواصفات وسيلة النقل
            _field(
              controller: _carType,
              label: 'طراز / ماركة الدراجة أو المركبة (مثلاً: دايو 125cc / هوندا)',
              icon: Icons.motorcycle_rounded,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 14),

            _field(
              controller: _carColor,
              label: 'لون الدراجة أو المركبة',
              icon: Icons.palette_outlined,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال اللون' : null,
            ),
            const SizedBox(height: 16),

            // صورة وسيلة النقل
            _buildVehiclePhotoCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // بطاقة معاينة اللوحة العراقية
  Widget _buildIraqiPlatePreview() {
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
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _plateType.contains('أجرة') ? const Color(0xFFC62828) : _accent,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('لوحة توصيل معتمدة', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                Text(_plateType, style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text('العراق', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      const Text('IRAQ', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    govText,
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    if (letterText.isNotEmpty) ...[
                      Text(
                        letterText,
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 20, fontWeight: FontWeight.w900, color: _accent),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      numText,
                      style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: 2),
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

  // ── STEP 3: Location ──

  Widget _buildStep3() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Form(
        key: _step3Key,
        child: Column(
          children: [
            const Icon(Icons.share_location_rounded, color: _primary, size: 52),
            const SizedBox(height: 10),
            Text(
              'حدد نطاق عملك وتغطية طلبات التوصيل',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16, color: _darkText),
            ),
            const SizedBox(height: 4),
            Text(
              'سيتم توجيه طلبات المطاعم والمتاجر الأقرب إلى حيك ومنطقتك أولاً.',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: _darkSub),
            ),
            const SizedBox(height: 20),

            _buildGovernorateDropdown(),
            const SizedBox(height: 14),

            _buildRegionDropdown(),
            const SizedBox(height: 14),

            if (_isLoadingSubRegions)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(color: _primary)),
              )
            else if (_subRegionsList.isNotEmpty) ...[
              _buildSelect(
                label: 'الناحية والحي السكني',
                value: _selectedSubRegionName,
                icon: Icons.holiday_village_rounded,
                items: _subRegionsList,
                onSelected: (v) => setState(() => _selectedSubRegionName = v),
              ),
              if (_selectedSubRegionName == 'أخرى (كتابة يدوية)') ...[
                const SizedBox(height: 12),
                _field(
                  controller: _customSubRegionController,
                  label: 'اكتب اسم الناحية والحي السكني يدوياً',
                  icon: Icons.edit_location_alt_rounded,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة اسم الحي' : null,
                ),
              ],
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── STEP 4: Documents & Security ──

  Widget _buildStep4() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Form(
        key: _step4Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.security_rounded, color: _primary, size: 52),
            const SizedBox(height: 10),
            Text(
              'المستمسكات وتأمين الحساب',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16, color: _darkText),
            ),
            const SizedBox(height: 4),
            Text(
              'عيّن كلمة المرور وارفع صورة البطاقة الوطنية للتحقق وتفعيل حسابك.',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: _darkSub),
            ),
            const SizedBox(height: 18),

            // صورة البطاقة الوطنية
            _buildIdCardPhotoCard(),
            const SizedBox(height: 16),

            _field(
              controller: _password,
              label: 'كلمة المرور',
              icon: Icons.lock_outline,
              obscure: _obscure1,
              validator: (v) => (v == null || v.length < 6) ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : null,
              suffix: IconButton(
                onPressed: () => setState(() => _obscure1 = !_obscure1),
                icon: Icon(_obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _darkSub),
              ),
            ),
            const SizedBox(height: 14),

            _field(
              controller: _confirm,
              label: 'تأكيد كلمة المرور',
              icon: Icons.lock_reset_rounded,
              obscure: _obscure2,
              validator: (v) => (v != _password.text) ? 'كلمة المرور غير متطابقة' : null,
              suffix: IconButton(
                onPressed: () => setState(() => _obscure2 = !_obscure2),
                icon: Icon(_obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _darkSub),
              ),
            ),
            const SizedBox(height: 16),

            // بطاقة ملخص البيانات
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _darkCard.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _darkSub.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ملخص طلب انضمام المندوب:',
                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13, color: _darkText),
                  ),
                  const SizedBox(height: 6),
                  _buildSummaryRow('المندوب:', _name.text.trim().isNotEmpty ? _name.text.trim() : '---'),
                  _buildSummaryRow('الوسيلة:', '$_selectedVehicleType (${_carType.text.trim()})'),
                  _buildSummaryRow('اللوحة:', _formattedPlate),
                  _buildSummaryRow('المنطقة:', '${_selectedGovName ?? ''} - ${_selectedRegName ?? ''}'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // الموافقة على الشروط
            CheckboxListTile(
              value: _agreedToTerms,
              activeColor: _primary,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
              title: Text(
                'أقر بصحة البيانات وأوافق على شروط وضوابط التوصيل وسياسة الخصوصية لمنصة مدار.',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: _darkSub, height: 1.4),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(title, style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: _darkSub)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              val.isNotEmpty ? val : '---',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold, color: _darkText),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── PHOTO CARDS ──

  Widget _buildPersonalPhotoPicker() {
    return Center(
      child: GestureDetector(
        onTap: _pickPersonalImage,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _darkCard,
            border: Border.all(
              color: _selectedPersonalImageBytes != null ? _primary : _darkSub.withValues(alpha: 0.3),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.2),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: _selectedPersonalImageBytes != null
                ? Image.memory(_selectedPersonalImageBytes!, fit: BoxFit.cover)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo_rounded, color: _primary, size: 34),
                      const SizedBox(height: 4),
                      Text(
                        'صورة المندوب',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: _darkSub, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehiclePhotoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _darkCard.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _darkSub.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickVehicleImage,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: _selectedVehicleImageBytes != null ? Colors.transparent : _primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _primary.withValues(alpha: 0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _selectedVehicleImageBytes != null
                    ? Image.memory(_selectedVehicleImageBytes!, fit: BoxFit.cover)
                    : Icon(Icons.add_photo_alternate_rounded, color: _primary, size: 28.sp),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedVehicleImageBytes != null ? 'تم اختيار صورة المركبة' : 'صورة وسيلة التوصيل (مستحسن)',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12.5, color: _darkText),
                ),
                const SizedBox(height: 2),
                Text(
                  'التقط صورة واضحة للدراجة أو المركبة المستخدمة في التوصيل.',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: _darkSub),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _pickVehicleImage,
            child: Text(
              _selectedVehicleImageBytes != null ? 'تغيير' : 'اختيار',
              style: GoogleFonts.ibmPlexSansArabic(color: _primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdCardPhotoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _darkCard.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _darkSub.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickIdCardImage,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: _selectedIdCardBytes != null ? Colors.transparent : _primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _primary.withValues(alpha: 0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _selectedIdCardBytes != null
                    ? Image.memory(_selectedIdCardBytes!, fit: BoxFit.cover)
                    : Icon(Icons.badge_rounded, color: _primary, size: 28.sp),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedIdCardBytes != null ? 'تم رفع صورة الهوية' : 'صورة البطاقة الوطنية / الهوية',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12.5, color: _darkText),
                ),
                const SizedBox(height: 2),
                Text(
                  'التقط صورة للوجه الأمامي للبطاقة الوطنية لتوثيق الحساب.',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: _darkSub),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _pickIdCardImage,
            child: Text(
              _selectedIdCardBytes != null ? 'تغيير' : 'رفع الهوية',
              style: GoogleFonts.ibmPlexSansArabic(color: _primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── BOTTOM BUTTONS ──

  Widget _buildBottomButtons() {
    final isLast = _currentStep == 3;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: _darkBg,
        border: Border(top: BorderSide(color: _darkCard.withValues(alpha: 0.8))),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: _darkSub.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'السابق',
                  style: GoogleFonts.ibmPlexSansArabic(color: _darkSub, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: isLast ? [const Color(0xFF00C853), const Color(0xFF009624)] : [_primary, _accent],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isLast ? const Color(0xFF00C853) : _primary).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _loading ? null : _nextStep,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLast ? 'إرسال طلب الانضمام' : 'متابعة الخطوة التالية',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
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
          ),
        ],
      ),
    );
  }

  // ── CUSTOM SHARED INPUT WIDGETS ──

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      validator: validator,
      style: GoogleFonts.ibmPlexSansArabic(color: _darkText, fontSize: 14, fontWeight: FontWeight.w500),
      cursorColor: _primary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.ibmPlexSansArabic(color: _darkSub, fontSize: 13),
        prefixIcon: Icon(icon, color: _darkHint, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: _darkCard.withValues(alpha: 0.7),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _darkSub.withValues(alpha: 0.15)),
        ),
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
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildSelect({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String) onSelected,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _darkCard.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _darkSub.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        leading: icon != null ? Icon(icon, color: _primary, size: 22) : null,
        title: Text(
          value ?? label,
          style: GoogleFonts.ibmPlexSansArabic(
            color: value == null ? _darkSub : _darkText,
            fontSize: 13.5,
            fontWeight: value == null ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        trailing: const Icon(Icons.keyboard_arrow_down_rounded, color: _darkSub),
        onTap: () => _showPicker(label, items, onSelected),
      ),
    );
  }

  void _showPicker(String title, List<String> items, Function(String) onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _darkCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.55,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: _darkSub.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 14),
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16, color: _darkText),
              ),
              const SizedBox(height: 8),
              Divider(color: _darkSub.withValues(alpha: 0.2)),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد عناصر متاحة',
                          style: GoogleFonts.ibmPlexSansArabic(color: _darkSub),
                        ),
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: _darkSub.withValues(alpha: 0.08)),
                        itemBuilder: (_, i) => ListTile(
                          title: Text(
                            items[i],
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, color: _darkText, fontWeight: FontWeight.w500),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _darkSub),
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

  Widget _buildGovernorateDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('governorates').where('isActive', isEqualTo: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator(color: _primary);
        final items = snapshot.data!.docs.map((d) => {'id': d.id, 'name': d['name'] as String}).toList();
        return _buildSelect(
          label: 'المحافظة',
          value: _selectedGovName,
          icon: Icons.location_city_rounded,
          items: items.map((e) => e['name'] as String).toList(),
          onSelected: (v) {
            final item = items.firstWhere((e) => e['name'] == v);
            setState(() {
              _selectedGovName = v;
              _selectedGovId = item['id'] as String;
            });
            _fetchRegions(_selectedGovId!);
          },
        );
      },
    );
  }

  Widget _buildRegionDropdown() {
    return _buildSelect(
      label: 'القضاء أو المنطقة',
      value: _selectedRegName,
      icon: Icons.map_rounded,
      items: _regions.map((e) => e['name'] as String).toList(),
      onSelected: (v) {
        final item = _regions.firstWhere((e) => e['name'] == v);
        setState(() {
          _selectedRegName = v;
          _selectedRegId = item['id'] as String;
        });
        _loadSubRegions(_selectedGovId ?? '', _selectedRegId!, v);
      },
    );
  }
}
