import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:dalal_alqaim/features/auth/widgets/auth_text_field.dart';
import 'package:dalal_alqaim/features/auth/widgets/role_selector_tab.dart';
import 'package:dalal_alqaim/features/auth/widgets/social_auth_buttons.dart';
import 'package:dalal_alqaim/services/google_auth_service.dart';
import 'package:dalal_alqaim/services/apple_auth_service.dart';
import 'package:dalal_alqaim/features/auth/pages/forgot_password_page.dart';
import 'package:dalal_alqaim/services/onesignal_service.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dalal_alqaim/shared/widgets/madar_button.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/pages/restaurant_register_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/captain_register_page.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/store_register_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_register_page.dart';

class UnifiedLoginPage extends StatefulWidget {
  final UserRole initialRole;
  final bool initialIsRegisterMode;
  final void Function(bool)? onThemeChanged;

  const UnifiedLoginPage({
    super.key,
    this.initialRole = UserRole.customer,
    this.initialIsRegisterMode = false,
    this.onThemeChanged,
  });

  @override
  State<UnifiedLoginPage> createState() => _UnifiedLoginPageState();
}

class _UnifiedLoginPageState extends State<UnifiedLoginPage> with SingleTickerProviderStateMixin {
  late UserRole _selectedRole;
  late bool _isRegisterMode;


  // Common Controllers
  final _nameController = TextEditingController();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Role-Specific Registration Controllers
  final _carModelController = TextEditingController();
  final _carPlateController = TextEditingController();
  final _cityController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _storeCategoryController = TextEditingController();
  final _deliveryVehicleController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _acceptedTerms = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
    _isRegisterMode = widget.initialIsRegisterMode;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    if (_isRegisterMode && _selectedRole != UserRole.customer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigateToSpecializedRegistration(_selectedRole);
        }
      });
    }
  }

  bool _isNavigatingSpecialized = false;

  Future<void> _navigateToSpecializedRegistration(UserRole role) async {
    if (_isNavigatingSpecialized || !mounted) return;
    _isNavigatingSpecialized = true;
    HapticFeedback.mediumImpact();

    try {
      Widget destination;
      switch (role) {
        case UserRole.restaurant:
          destination = const RestaurantRegisterPage();
          break;
        case UserRole.captain:
          destination = const CaptainRegisterPage();
          break;
        case UserRole.store:
          destination = const StoreRegisterPage();
          break;
        case UserRole.delivery:
          destination = const DeliveryRegisterPage();
          break;
        case UserRole.customer:
          return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
    } catch (e) {
      debugPrint('Error navigating to specialized registration: $e');
    } finally {
      if (mounted) {
        setState(() {
          _selectedRole = UserRole.customer;
          _isNavigatingSpecialized = false;
        });
      } else {
        _isNavigatingSpecialized = false;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _carModelController.dispose();
    _carPlateController.dispose();
    _cityController.dispose();
    _storeNameController.dispose();
    _storeCategoryController.dispose();
    _deliveryVehicleController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? Colors.redAccent : app_colors.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
    );
  }

  Future<void> _saveUserData(String uid, {String? userEmail, String? userPhone}) async {
    final phone = userPhone ?? '';
    final name = _nameController.text.trim();

    final sanitizedRole = (_selectedRole == UserRole.captain)
        ? 'captain'
        : (_selectedRole == UserRole.restaurant)
            ? 'restaurant'
            : (_selectedRole == UserRole.store)
                ? 'store'
                : (_selectedRole == UserRole.delivery)
                    ? 'delivery'
                    : 'customer';

    try {
      // 1. Save core user document
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': name.isNotEmpty ? name : 'مستخدم مدار',
        'phone': phone,
        'email': userEmail ?? _emailController.text.trim(),
        'role': sanitizedRole,
        'status': (sanitizedRole == 'customer') ? 'active' : 'pending',
        'isApproved': (sanitizedRole == 'customer'),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Save role-specific partner documents
      if (_selectedRole == UserRole.captain) {
        final carModel = _carModelController.text.trim();
        final carPlate = _carPlateController.text.trim();
        final city = _cityController.text.trim();

        await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
          'uid': uid,
          'name': name.isNotEmpty ? name : 'كابتن تكسي',
          'phone': phone,
          'carModel': carModel,
          'carPlate': carPlate,
          'city': city,
          'role': 'driver',
          'isApproved': false,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await FirebaseFirestore.instance.collection('driver_requests').doc(uid).set({
          'driverId': uid,
          'name': name.isNotEmpty ? name : 'كابتن تكسي',
          'phone': phone,
          'carModel': carModel,
          'carPlate': carPlate,
          'city': city,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else if (_selectedRole == UserRole.restaurant) {
        final restName = _storeNameController.text.trim().isNotEmpty ? _storeNameController.text.trim() : 'مطعم جديد';
        final category = _storeCategoryController.text.trim();
        final city = _cityController.text.trim();

        await FirebaseFirestore.instance.collection('restaurants').doc(uid).set({
          'uid': uid,
          'ownerName': name,
          'restaurantName': restName,
          'name': restName,
          'category': category,
          'city': city,
          'phone': phone,
          'isApproved': false,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await FirebaseFirestore.instance.collection('restaurant_requests').doc(uid).set({
          'requestId': uid,
          'restaurantId': uid,
          'ownerName': name,
          'restaurantName': restName,
          'category': category,
          'city': city,
          'phone': phone,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else if (_selectedRole == UserRole.store) {
        final storeName = _storeNameController.text.trim().isNotEmpty ? _storeNameController.text.trim() : 'متجر جديد';
        final category = _storeCategoryController.text.trim();
        final city = _cityController.text.trim();

        await FirebaseFirestore.instance.collection('stores').doc(uid).set({
          'ownerId': uid,
          'uid': uid,
          'storeName': storeName,
          'name': storeName,
          'category': category,
          'city': city,
          'phone': phone,
          'isApproved': false,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await FirebaseFirestore.instance.collection('store_requests').doc(uid).set({
          'requestId': uid,
          'storeId': uid,
          'ownerName': name,
          'storeName': storeName,
          'category': category,
          'city': city,
          'phone': phone,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else if (_selectedRole == UserRole.delivery) {
        final vehicle = _deliveryVehicleController.text.trim();
        final city = _cityController.text.trim();

        await FirebaseFirestore.instance.collection('delivery_boys').doc(uid).set({
          'uid': uid,
          'name': name,
          'vehicleType': vehicle,
          'city': city,
          'phone': phone,
          'isApproved': false,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
          'uid': uid,
          'name': name,
          'vehicleType': vehicle,
          'city': city,
          'phone': phone,
          'isDelivery': true,
          'role': 'delivery',
          'isApproved': false,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error saving Firestore profile: $e');
    }
  }

  Future<void> _onLoginSuccess(User? user, {String? fallbackPhone}) async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();

    if (user == null) {
      _showSnackBar('تعذر إتمام المصادقة بنجاح، يرجى المحاولة ثانية', isError: true);
      return;
    }

    final String activeUid = user.uid;

    // ══════════════════════════════════════════════════════════════════════
    // تنظيف الكاش القديم أولاً لمنع تعارض الأدوار
    // ══════════════════════════════════════════════════════════════════════
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('currentUserRole_$activeUid');
      await prefs.remove('currentUserRole');
      await prefs.remove('currentUserId');
    } catch (_) {}

    if (_isRegisterMode) {
      await _saveUserData(activeUid, userEmail: user.email, userPhone: user.phoneNumber ?? fallbackPhone);
      final sanitizedRole = (_selectedRole == UserRole.captain)
          ? 'captain'
          : (_selectedRole == UserRole.restaurant)
              ? 'restaurant'
              : (_selectedRole == UserRole.store)
                  ? 'store'
                  : (_selectedRole == UserRole.delivery)
                      ? 'delivery'
                      : 'customer';
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentUserRole_$activeUid', sanitizedRole);
        await prefs.setString('currentUserRole', sanitizedRole);
        await prefs.setString('currentUserId', activeUid);
      } catch (_) {}
    } else {
      // ══════════════════════════════════════════════════════════════════════
      // الكشف والتحديد التلقائي للدور عند تسجيل الدخول (Automatic Role Detection)
      // ══════════════════════════════════════════════════════════════════════
      String resolvedRole = 'customer';
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(activeUid).get();
        if (userDoc.exists) {
          final data = userDoc.data() ?? {};
          final raw = data['role']?.toString().trim().toLowerCase();
          final sub = data['subRole']?.toString().trim().toLowerCase();

          if (raw == 'restaurant' || raw == 'restaurant_owner' || raw == 'merchant' || sub == 'restaurant') {
            resolvedRole = 'restaurant';
          } else if (raw == 'store' || raw == 'store_owner' || raw == 'market' || sub == 'store') {
            resolvedRole = 'store';
          } else if (raw == 'captain' || raw == 'driver' || raw == 'taxi_captain' || sub == 'captain' || sub == 'driver') {
            resolvedRole = 'captain';
          } else if (raw == 'delivery' || raw == 'delivery_boy' || raw == 'delivery_captain' || sub == 'delivery') {
            resolvedRole = 'delivery';
          } else if (raw == 'admin' || raw == 'limited_admin') {
            resolvedRole = 'admin';
          } else if (raw == 'real_estate' || raw == 'property_owner') {
            resolvedRole = 'real_estate';
          } else {
            // التحقق عبر المجموعات المتخصصة في حال كان دور المستخدم مسجل في مكان آخر
            final storeDoc = await FirebaseFirestore.instance.collection('stores').doc(activeUid).get();
            if (storeDoc.exists) {
              resolvedRole = 'store';
            } else {
              final restDoc = await FirebaseFirestore.instance.collection('restaurants').doc(activeUid).get();
              if (restDoc.exists) {
                resolvedRole = 'restaurant';
              } else {
                final drDoc = await FirebaseFirestore.instance.collection('drivers').doc(activeUid).get();
                if (drDoc.exists) {
                  final drData = drDoc.data() ?? {};
                  resolvedRole = (drData['isDelivery'] == true || drData['role'] == 'delivery') ? 'delivery' : 'captain';
                } else {
                  final delDoc = await FirebaseFirestore.instance.collection('delivery_boys').doc(activeUid).get();
                  if (delDoc.exists) {
                    resolvedRole = 'delivery';
                  }
                }
              }
            }
          }

          await FirebaseFirestore.instance.collection('users').doc(activeUid).update({
            'role': resolvedRole,
            'lastLogin': FieldValue.serverTimestamp(),
          }).catchError((_) {});
        } else {
          // لم يتم العثور على وثيقة users، نقوم بفحص المجموعات المتخصصة لتحديد الهوية تلقائياً
          final storeDoc = await FirebaseFirestore.instance.collection('stores').doc(activeUid).get();
          if (storeDoc.exists) {
            resolvedRole = 'store';
          } else {
            final restDoc = await FirebaseFirestore.instance.collection('restaurants').doc(activeUid).get();
            if (restDoc.exists) {
              resolvedRole = 'restaurant';
            } else {
              final drDoc = await FirebaseFirestore.instance.collection('drivers').doc(activeUid).get();
              if (drDoc.exists) {
                final drData = drDoc.data() ?? {};
                resolvedRole = (drData['isDelivery'] == true || drData['role'] == 'delivery') ? 'delivery' : 'captain';
              } else {
                final delDoc = await FirebaseFirestore.instance.collection('delivery_boys').doc(activeUid).get();
                if (delDoc.exists) {
                  resolvedRole = 'delivery';
                }
              }
            }
          }

          await FirebaseFirestore.instance.collection('users').doc(activeUid).set({
            'uid': activeUid,
            'name': (user.displayName != null && user.displayName!.isNotEmpty) ? user.displayName! : 'مستخدم مدار',
            'email': user.email ?? '',
            'phone': user.phoneNumber ?? (fallbackPhone ?? ''),
            'role': resolvedRole,
            'status': (resolvedRole == 'customer') ? 'active' : 'pending',
            'isApproved': (resolvedRole == 'customer'),
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentUserRole_$activeUid', resolvedRole);
        await prefs.setString('currentUserRole', resolvedRole);
        await prefs.setString('currentUserId', activeUid);
      } catch (e) {
        debugPrint('Error auto-detecting user doc on login: $e');
      }
    }

    OneSignalService.syncUserRole(activeUid);

    if (mounted) {
      _showSnackBar('تم الدخول بنجاح، يا هلا بيك');
      // التوجيه إلى المسار الجذري ليعمل RoleBasedRouter على فتح اللوحة الصحيحة تلقائياً
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Future<void> _handleEmailAuth() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_isRegisterMode && !_acceptedTerms) {
      _showSnackBar('يرجى الموافقة على الشروط وسياسة الاستخدام للمتابعة', isError: true);
      return;
    }

    _safeSetState(() => _isLoading = true);
    try {
      UserCredential userCredential;
      if (_isRegisterMode) {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
      _safeSetState(() => _isLoading = false);
      if (mounted) {
        await _onLoginSuccess(userCredential.user);
      }
    } on FirebaseAuthException catch (e) {
      _safeSetState(() => _isLoading = false);
      String errorMsg = 'تعذر تسجيل الدخول، تأكد من البيانات';
      if (e.code == 'user-not-found') {
        errorMsg = 'الحساب غير مسجل، تكَدر تسوي حساب جديد';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMsg = 'بيانات الدخول غير صحيحة، تأكد من البريد وكلمة المرور';
      } else if (e.code == 'email-already-in-use') {
        errorMsg = 'هذا البريد مسجل مسبقاً، سجل دخولك مباشرة';
      } else if (e.code == 'invalid-email') {
        errorMsg = 'صيغة البريد الإلكتروني غير صحيحة';
      }
      _showSnackBar(errorMsg, isError: true);
    } catch (e) {
      _safeSetState(() => _isLoading = false);
      _showSnackBar('صار خلل غير متوقع: $e', isError: true);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    _safeSetState(() => _isLoading = true);
    try {
      final user = await GoogleAuthService.signIn();
      _safeSetState(() => _isLoading = false);
      if (user != null && mounted) {
        await _onLoginSuccess(user);
      }
    } catch (e) {
      _safeSetState(() => _isLoading = false);
      _showSnackBar('تعذر الدخول بواسطة Google', isError: true);
    }
  }

  Future<void> _handleAppleSignIn() async {
    _safeSetState(() => _isLoading = true);
    try {
      final user = await AppleAuthService.signIn();
      _safeSetState(() => _isLoading = false);
      if (user != null && mounted) {
        await _onLoginSuccess(user);
      }
    } catch (e) {
      _safeSetState(() => _isLoading = false);
      _showSnackBar('تعذر الدخول بواسطة Apple', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = app_colors.primaryColor;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final cardBg = isDark ? app_colors.darkCard : Colors.white;
    final borderColor = isDark ? app_colors.darkBorder : const Color(0xFFE2EBE9);
    final activeThemeColor = _isRegisterMode ? _selectedRole.roleColor : primary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: isDark ? app_colors.darkBackground : const Color(0xFFF8FAFC),
            body: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 10.h),

                        // ═══════════════════════════════════════════════════
                        // 1. HEADER LOGO & CLEAN TITLE
                        // ═══════════════════════════════════════════════════
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 78.r,
                                height: 78.r,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? app_colors.darkCard : const Color(0xFFE8F5F3),
                                  border: Border.all(color: activeThemeColor.withValues(alpha: 0.35), width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: activeThemeColor.withValues(alpha: 0.2),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'imges/dala_alqaim_logo.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      'assets/images/logo.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                        _isRegisterMode ? _selectedRole.icon : Icons.hub_rounded,
                                        size: 36.r,
                                        color: activeThemeColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                _isRegisterMode ? 'إنشاء حساب ${_selectedRole.title}' : 'تسجيل الدخول الموحد',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? app_colors.darkText : const Color(0xFF112525),
                                  height: 1.2,
                                ),
                              ),
                              SizedBox(height: 5.h),
                              Text(
                                _isRegisterMode
                                    ? 'أدخل بياناتك للانضمام إلى مدار كـ ${_selectedRole.title}'
                                    : 'سجل دخولك وسيتم توجيهك لحسابك ولوحتك تلقائياً',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w400,
                                  color: isDark ? app_colors.darkSubText : const Color(0xFF7A8F8D),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 18.h),

                        // ═══════════════════════════════════════════════════
                        // 2. MODE SWITCHER (LOGIN VS REGISTER)
                        // ═══════════════════════════════════════════════════
                        Container(
                          padding: EdgeInsets.all(4.r),
                          decoration: BoxDecoration(
                            color: isDark ? app_colors.darkCard : const Color(0xFFEDF3F2),
                            borderRadius: BorderRadius.circular(18.r),
                            border: Border.all(color: borderColor, width: 1.2),
                          ),
                          child: Row(
                            children: [
                              // Login Tab
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _isRegisterMode = false);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    padding: EdgeInsets.symmetric(vertical: 10.h),
                                    decoration: BoxDecoration(
                                      color: !_isRegisterMode
                                          ? (isDark ? app_colors.darkSurface : Colors.white)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(14.r),
                                      boxShadow: !_isRegisterMode
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.05),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Text(
                                      'تسجيل الدخول',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 13.5.sp,
                                        fontWeight: !_isRegisterMode ? FontWeight.w700 : FontWeight.w500,
                                        color: !_isRegisterMode ? primary : (isDark ? app_colors.darkSubText : app_colors.subTextColor),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Register Tab
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _isRegisterMode = true);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    padding: EdgeInsets.symmetric(vertical: 10.h),
                                    decoration: BoxDecoration(
                                      color: _isRegisterMode
                                          ? (isDark ? app_colors.darkSurface : Colors.white)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(14.r),
                                      boxShadow: _isRegisterMode
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.05),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Text(
                                      'حساب جديد',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 13.5.sp,
                                        fontWeight: _isRegisterMode ? FontWeight.w700 : FontWeight.w500,
                                        color: _isRegisterMode ? primary : (isDark ? app_colors.darkSubText : app_colors.subTextColor),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16.h),

                        // ═══════════════════════════════════════════════════
                        // 3. ROLE SELECTOR SECTION (REGISTER MODE ONLY)
                        // ═══════════════════════════════════════════════════
                        if (_isRegisterMode) ...[
                          RoleSelectorTab(
                            selectedRole: _selectedRole,
                            onRoleSelected: (role) {
                              HapticFeedback.lightImpact();
                              if (role == UserRole.customer) {
                                _safeSetState(() {
                                  _selectedRole = UserRole.customer;
                                });
                              } else {
                                _safeSetState(() {
                                  _selectedRole = role;
                                });
                                _navigateToSpecializedRegistration(role);
                              }
                            },
                          ),
                          SizedBox(height: 14.h),
                        ],

                        // ═══════════════════════════════════════════════════
                        // 4. MAIN FORM INPUTS CARD
                        // ═══════════════════════════════════════════════════
                        Container(
                          padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(color: borderColor, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Registration Form Fields ──
                              if (_isRegisterMode && _selectedRole != UserRole.customer) ...[
                                _buildSpecializedRoleCard(isDark),
                              ] else ...[
                                if (_isRegisterMode) ...[
                                  AuthTextField(
                                    controller: _nameController,
                                    hintText: 'الاسم الكامل (مثال: أحمد محمد)',
                                    prefixIcon: Icons.person_outline_rounded,
                                    validator: (val) => (val == null || val.trim().isEmpty) ? 'يرجى كتابة الاسم' : null,
                                  ),
                                  SizedBox(height: 10.h),
                                ],

                                // ── Email Authentication Form ──
                                AuthTextField(
                                  controller: _emailController,
                                  hintText: 'name@example.com',
                                  prefixIcon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  textDirection: TextDirection.ltr,
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                                    if (!val.contains('@')) return 'البريد الإلكتروني غير صالح';
                                    return null;
                                  },
                                ),
                                SizedBox(height: 10.h),
                                AuthTextField(
                                  controller: _passwordController,
                                  hintText: 'كلمة السر',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                      color: activeThemeColor,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'يرجى إدخال كلمة السر';
                                    if (val.length < 6) return 'كلمة السر لازم تكون 6 خانات على الأقل';
                                    return null;
                                  },
                                ),
                                if (!_isRegisterMode) ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                                        );
                                      },
                                      child: Text(
                                        'نسيت كلمة السر؟',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 12.5.sp,
                                          color: primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  SizedBox(height: 10.h),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20.r,
                                        height: 20.r,
                                        child: Checkbox(
                                          value: _acceptedTerms,
                                          activeColor: activeThemeColor,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.r)),
                                          onChanged: (val) => setState(() => _acceptedTerms = val ?? true),
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                                          child: Text.rich(
                                            TextSpan(
                                              text: 'أوافق على ',
                                              style: GoogleFonts.ibmPlexSansArabic(
                                                fontSize: 12.sp,
                                                color: isDark ? app_colors.darkSubText : const Color(0xFF5A6E6C),
                                              ),
                                              children: [
                                                TextSpan(
                                                  text: 'الشروط وسياسة الاستخدام لمنصة مدار',
                                                  style: GoogleFonts.ibmPlexSansArabic(
                                                    fontWeight: FontWeight.w600,
                                                    color: activeThemeColor,
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12.h),
                                ],
                                MadarButton(
                                  text: _isRegisterMode
                                      ? 'إنشاء الحساب والمتابعة'
                                      : 'تسجيل الدخول',
                                  isLoading: _isLoading,
                                  onPressed: _handleEmailAuth,
                                  height: 50.h,
                                ),
                              ],
                            ],
                          ),
                        ),


                        SizedBox(height: 16.h),

                        // ═══════════════════════════════════════════════════
                        // 5. DIVIDER & SOCIAL AUTH
                        // ═══════════════════════════════════════════════════
                        Row(
                          children: [
                            Expanded(child: Divider(color: borderColor, thickness: 1)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12.w),
                              child: Text(
                                'أو تسجيل الدخول السريع',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? app_colors.darkSubText : app_colors.subTextColor,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: borderColor, thickness: 1)),
                          ],
                        ),

                        SizedBox(height: 14.h),

                        SocialAuthButtons(
                          onGoogleTap: _handleGoogleSignIn,
                          onAppleTap: isIOS ? _handleAppleSignIn : null,
                        ),

                        SizedBox(height: 14.h),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecializedRoleCard(bool isDark) {
    final roleColor = _selectedRole.roleColor;
    final gradient = _selectedRole.gradientColors;

    String description = '';
    String featuresText = '';
    switch (_selectedRole) {
      case UserRole.restaurant:
        description = 'واجهة متكاملة مخصصة للمطاعم والكافيهات، تشمل إعداد وتعديل قائمة الوجبات، تحديد موقع المطعم بدقة على الخريطة، وساعات العمل وتتبع طلبات الزبائن.';
        featuresText = '✓ إدارة المنيو والوجبات  •  ✓ ربط مباشر مع مناديب مدار  •  ✓ لوحة أرباح وإحصائيات';
        break;
      case UserRole.captain:
        description = 'واجهة كباتن التكسي والنقل السريع، مخصصة لإدخال بيانات المركبة، أرقام اللوحات والمحافظة، رفع رخصة القيادة، واستقبال مشاوير الركاب فوراً.';
        featuresText = '✓ عداد رحلات ذكي  •  ✓ تسعيرة رسمية عادلة  •  ✓ نظام تتبع مباشر للراكب';
        break;
      case UserRole.store:
        description = 'واجهة خاصة بأصحاب المتاجر والمحلات التجارية، لرفع شعار المتجر، وتصنيف الأقسام والمنتجات، واستقبال وتجهيز طلبات الزبائن إلكترونياً.';
        featuresText = '✓ متجر إلكتروني متكامل  •  ✓ إدارة المخزون  •  ✓ تقارير مبيعات تفصيلية';
        break;
      case UserRole.delivery:
        description = 'واجهة مخصصة لكباتن ومناديب التوصيل، لتسجيل وسيلة النقل (دراجة نارية / سيارة)، وتحديد مناطق التغطية وبدء استلام وتوصيل الطلبات والطرود.';
        featuresText = '✓ إشعارات فورية بالطلبات  •  ✓ خرائط توجيه ذكية  •  ✓ محفظة أرباح فورية';
        break;
      case UserRole.customer:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradient.first.withValues(alpha: isDark ? 0.22 : 0.08),
            gradient.last.withValues(alpha: isDark ? 0.12 : 0.04),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: roleColor.withValues(alpha: isDark ? 0.45 : 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46.r,
                height: 46.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: gradient),
                  boxShadow: [
                    BoxShadow(
                      color: roleColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _selectedRole.icon,
                    size: 22.r,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تسجيل حساب ${_selectedRole.title}',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF112525),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _selectedRole.tagLine,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                        color: roleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            description,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12.sp,
              color: isDark ? app_colors.darkSubText : const Color(0xFF4A5568),
              height: 1.45,
            ),
          ),
          SizedBox(height: 10.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: roleColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Text(
              featuresText,
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton.icon(
              onPressed: () => _navigateToSpecializedRegistration(_selectedRole),
              icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
              label: Text(
                'فتح واجهة تسجيل ${_selectedRole.title} الآن',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: roleColor,
                elevation: 3,
                shadowColor: roleColor.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Center(
            child: TextButton.icon(
              onPressed: () {
                _safeSetState(() {
                  _selectedRole = UserRole.customer;
                });
              },
              icon: Icon(Icons.arrow_back_rounded, size: 14.sp, color: isDark ? app_colors.darkSubText : app_colors.subTextColor),
              label: Text(
                'العودة إلى إنشاء حساب زبون عادي',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12.sp,
                  color: isDark ? app_colors.darkSubText : app_colors.subTextColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
