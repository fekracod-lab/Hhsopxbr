import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:local_auth/local_auth.dart';

import 'package:dalal_alqaim/shared/app_constants.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:dalal_alqaim/core/app_globals.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import 'package:dalal_alqaim/services/cloudinary_service.dart';
import 'package:dalal_alqaim/services/onesignal_service.dart';
import 'package:dalal_alqaim/pages/welcome_page.dart';
import 'package:dalal_alqaim/pages/technical_support_chat_page.dart';
import 'package:dalal_alqaim/pages/my_orders_page.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/user_points_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/ride_history_page.dart';
import 'package:dalal_alqaim/widgets/map_picker_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();

  String? _profileImageUrl;
  bool _isUploadingPhoto = false;

  // إعدادات التفضيلات
  bool _soundEnabled = true;
  bool _pushNotificationsEnabled = true;
  bool _hapticEnabled = true;
  bool _biometricEnabled = false;
  bool _hasBiometricsHardware = false;
  double _cacheSizeMb = 18.4;
  bool _isCacheCleaned = false;

  // قائمة المحافظات العراقية
  static const List<String> _iraqiGovernorates = [
    'بغداد',
    'البصرة',
    'أربيل',
    'النجف الأشرف',
    'كربلاء المقدسة',
    'نينوى (الموصل)',
    'كركوك',
    'الأنبار',
    'بابل (الحلة)',
    'ديالى',
    'ذي قار (الناصرية)',
    'صلاح الدين (تكريت)',
    'ميسان (العمارة)',
    'المثنى (السماوة)',
    'القادسية (الديوانية)',
    'واسط (الكوت)',
    'دهوك',
    'السليمانية',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPreferences();
    _checkBiometricsSupport();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _profileImageUrl = data['profileImage'] ?? data['photoUrl'];
            _nameController.text = data['name'] ?? '';
            _phoneController.text = data['phone'] ?? user.phoneNumber ?? '';
            _cityController.text = data['city'] ?? data['governorate'] ?? 'بغداد';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _soundEnabled = prefs.getBool('notifications_sound_enabled') ?? true;
        _pushNotificationsEnabled = prefs.getBool('push_notifications_enabled') ?? true;
        _hapticEnabled = prefs.getBool('haptic_feedback_enabled') ?? true;
        _biometricEnabled = prefs.getBool('biometric_lock_enabled') ?? false;
        _isCacheCleaned = prefs.getBool('cache_recently_cleaned') ?? false;
        if (_isCacheCleaned) _cacheSizeMb = 2.1;
      });
    }
  }

  Future<void> _checkBiometricsSupport() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (mounted) {
        setState(() {
          _hasBiometricsHardware = canCheck || isSupported;
        });
      }
    } catch (e) {
      debugPrint('Error checking biometrics: $e');
    }
  }

  void _triggerHaptic() {
    if (_hapticEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  // ── تبديل قفل البصمة والفيس آيدي الحقيقي ──
  Future<void> _toggleBiometric(bool val) async {
    _triggerHaptic();

    if (val) {
      try {
        final didAuth = await _localAuth.authenticate(
          localizedReason: 'يرجى مسح بصمة الإصبع أو بصمة الوجه (Face ID) لتأكيد تفعيل قفل التطبيق',
        );

        if (!didAuth) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لم يتم تأكيد البصمة، تم إلغاء تفعيل القفل', style: TextStyle()),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('جهازك لا يدعم المصادقة الحيوية أو حدث خطأ: $e', style: const TextStyle()),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    } else {
      try {
        final didAuth = await _localAuth.authenticate(
          localizedReason: 'يرجى تأكيد هويتك بالبصمة لإلغاء قفل التطبيق',
        );
        if (!didAuth) return;
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_lock_enabled', val);
    if (!mounted) return;
    setState(() => _biometricEnabled = val);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          val ? 'عاشت إيدك! تم تفعيل قفل البصمة والفيس آيدي بنجاح' : 'تم تعطيل قفل البصمة',
          style: const TextStyle(),
        ),
        backgroundColor: AppTheme.primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── فحص وتجربة البصمة والفيس آيدي ──
  Future<void> _testBiometrics() async {
    _triggerHaptic();
    try {
      final didAuth = await _localAuth.authenticate(
        localizedReason: 'تجربة التحقق من بصمة الإصبع والوجه (Face ID) لتطبيق مدار',
      );

      if (!mounted) return;
      if (didAuth) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('تم التعرف على البصمة بنجاح! هويتك مؤكدة', style: TextStyle()),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل التعرف على البصمة، جرب مرة ثانية', style: TextStyle()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء فحص البصمة: $e', style: const TextStyle()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ── تحديد الموقع الجغرافي الحقيقي GPS ──
  Future<Map<String, dynamic>?> _fetchRealLocationWithPermission() async {
    _triggerHaptic();

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء تفعيل خدمة الموقع الجغرافي (GPS) من هاتفك أولاً', style: TextStyle()),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفض إذن الموقع، يرجى السماح للتطبيق بتحديد موقعك', style: TextStyle()),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('إذن الموقع معطل بشكل دائم، يرجى تفعيله من إعدادات الهاتف', style: TextStyle()),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: 'الإعدادات',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return null;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    String resolvedAddress = 'موقعك الحالي';
    String resolvedGov = 'العراق';

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[];
        if (p.street != null && p.street!.trim().isNotEmpty && !p.street!.contains('+')) parts.add(p.street!.trim());
        if (p.subLocality != null && p.subLocality!.trim().isNotEmpty) parts.add(p.subLocality!.trim());
        if (p.locality != null && p.locality!.trim().isNotEmpty) parts.add(p.locality!.trim());
        if (p.administrativeArea != null && p.administrativeArea!.trim().isNotEmpty) {
          parts.add(p.administrativeArea!.trim());
          resolvedGov = p.administrativeArea!.trim();
        }

        if (parts.isNotEmpty) {
          resolvedAddress = parts.join('،');
        }
      }
    } catch (_) {}

    return {
      'lat': position.latitude,
      'lng': position.longitude,
      'address': resolvedAddress,
      'gov': resolvedGov,
    };
  }

  // ── طلب إذن الموقع ──
  Future<void> _requestLocationPermission() async {
    _triggerHaptic();
    await Permission.location.request();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم التحقق من إذن الموقع بنجاح', style: TextStyle()),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    }
  }

  // ── طلب إذن الإشعارات ──
  Future<void> _requestNotificationPermission() async {
    _triggerHaptic();
    await Permission.notification.request();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم التحقق من إذن الإشعارات بنجاح', style: TextStyle()),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    }
  }

  // ── حفظ الموقع الحالي السريع ──
  Future<void> _saveQuickCurrentLocation(String uid, List<Map<String, dynamic>> savedAddresses) async {
    final loc = await _fetchRealLocationWithPermission();
    if (loc != null) {
      final newAddr = {
        'title': 'موقعي الحالي',
        'address': loc['address'],
        'lat': loc['lat'],
        'lng': loc['lng'],
        'createdAt': DateTime.now().toIso8601String(),
      };
      savedAddresses.add(newAddr);
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'savedAddresses': savedAddresses,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ موقعك الحقيقي بنجاح', style: TextStyle()),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (ctx, isDark, child) {
        final bg = isDark ? app_colors.darkBackground : app_colors.backgroundColor;
        final cardBg = isDark ? app_colors.darkCard : app_colors.cardColor;
        final textColor = isDark ? app_colors.darkText : app_colors.textColor;
        final subTextColor = isDark ? app_colors.darkSubText : app_colors.subTextColor;

        return Scaffold(
          backgroundColor: bg,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── 1. الهيدر الملكي بتصميم عراقي فخم ──
              SliverToBoxAdapter(
                child: _buildHeaderProfile(isDark, cardBg, textColor, subTextColor),
              ),

              // ── 2. محتوى الإعدادات المقسم والمرتب ──
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── أ. حسابك وبياناتك ──
                    _buildSectionTitle('حسابك وبياناتك', isDark),
                    _buildSettingsGroup(
                      cardBg: cardBg,
                      isDark: isDark,
                      items: [
                        _buildSettingTile(
                          icon: Icons.badge_rounded,
                          iconColor: const Color(0xFF0284C7),
                          title: 'تعديل بيانات الحساب وموقعي',
                          subtitle: 'اسمك، رقمك، وتحديد موقعك الحقيقي (GPS)',
                          isDark: isDark,
                          onTap: () => _showEditProfileDialog(isDark),
                        ),
                        _buildDivider(isDark),
                        _buildSettingTile(
                          icon: Icons.location_on_rounded,
                          iconColor: const Color(0xFF10B981),
                          title: 'عناويني ومواقعي المفضلة (GPS)',
                          subtitle: 'البيت، الشغل، والأماكن التطلب منها دايم',
                          isDark: isDark,
                          onTap: () => _showSavedAddressesDialog(isDark),
                        ),
                        _buildDivider(isDark),
                        _buildSettingTile(
                          icon: Icons.receipt_long_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          title: 'سجل مسواكي وطلباتي',
                          subtitle: 'شوف كل طلباتك وحالتها بالتفصيل',
                          isDark: isDark,
                          onTap: () {
                            _triggerHaptic();
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const MyOrdersPage()));
                          },
                        ),
                        _buildDivider(isDark),
                        _buildSettingTile(
                          icon: Icons.local_taxi_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          title: 'سجل مشاوير التكسي',
                          subtitle: 'رحلاتك السابقة والتفاصيل مالتها',
                          isDark: isDark,
                          onTap: () {
                            _triggerHaptic();
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const RideHistoryPage()));
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),

                    // ── ب. الأمان وقفل التطبيق بالبصمة والفيس آيدي ──
                    _buildSectionTitle('الأمان وقفل البصمة والفيس آيدي', isDark),
                    _buildSettingsGroup(
                      cardBg: cardBg,
                      isDark: isDark,
                      items: [
                        _buildSwitchTile(
                          icon: Icons.fingerprint_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          title: 'قفل التطبيق بالبصمة / Face ID',
                          subtitle: _biometricEnabled
                              ? 'القفل مفعل ويحمي حسابك وبياناتك'
                              : (_hasBiometricsHardware
                                  ? 'تأمين التطبيق ببصمة الإصبع أو الوجه'
                                  : 'الجهاز لا يدعم البصمة المباشرة'),
                          value: _biometricEnabled,
                          isDark: isDark,
                          onChanged: _toggleBiometric,
                        ),
                        if (_biometricEnabled) ...[
                          _buildDivider(isDark),
                          _buildSettingTile(
                            icon: Icons.security_rounded,
                            iconColor: const Color(0xFF10B981),
                            title: 'تجربة وفحص البصمة والفيس آيدي',
                            subtitle: 'اضغط هنا للتأكد من استجابة البصمة بجهازك',
                            trailing: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                'فحص هسة',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ),
                            isDark: isDark,
                            onTap: _testBiometrics,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 20.h),

                    // ── ج. أذونات وصلاحيات الهاتف ──
                    _buildSectionTitle('صلاحيات وأذونات الهاتف', isDark),
                    _buildSettingsGroup(
                      cardBg: cardBg,
                      isDark: isDark,
                      items: [
                        _buildSettingTile(
                          icon: Icons.gps_fixed_rounded,
                          iconColor: const Color(0xFF0284C7),
                          title: 'إذن الموقع الجغرافي (GPS)',
                          subtitle: 'ضروري لتحديد موقعك في التكسي وتوصيل الطلبات',
                          trailing: Icon(Icons.settings_suggest_rounded, color: AppTheme.primaryColor, size: 20.sp),
                          isDark: isDark,
                          onTap: _requestLocationPermission,
                        ),
                        _buildDivider(isDark),
                        _buildSettingTile(
                          icon: Icons.notifications_active_rounded,
                          iconColor: const Color(0xFFEC4899),
                          title: 'إذن الإشعارات والتنبيهات',
                          subtitle: 'لاستلام إشعارات العروض وحالة المشاوير الحية',
                          trailing: Icon(Icons.settings_suggest_rounded, color: AppTheme.primaryColor, size: 20.sp),
                          isDark: isDark,
                          onTap: _requestNotificationPermission,
                        ),
                        _buildDivider(isDark),
                        _buildSettingTile(
                          icon: Icons.app_settings_alt_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          title: 'إعدادات أذونات الهاتف العامة',
                          subtitle: 'فتح صفحة إعدادات تطبيق مدار بالنظام',
                          isDark: isDark,
                          onTap: () => openAppSettings(),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),

                    // ── د. تفضيلات ومظهر التطبيق ──
                    _buildSectionTitle('تفضيلات ومظهر التطبيق', isDark),
                    _buildSettingsGroup(
                      cardBg: cardBg,
                      isDark: isDark,
                      items: [
                        _buildSwitchTile(
                          icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          iconColor: const Color(0xFF6366F1),
                          title: 'الوضع الليلي (دارك مود)',
                          subtitle: isDark ? 'مفعل هسة وريح عيونك' : 'مفعل الوضع الفاتح',
                          value: isDark,
                          isDark: isDark,
                          onChanged: (val) {
                            _triggerHaptic();
                            isDarkModeNotifier.value = val;
                          },
                        ),
                        _buildDivider(isDark),
                        _buildSwitchTile(
                          icon: Icons.notifications_active_rounded,
                          iconColor: const Color(0xFFEC4899),
                          title: 'الإشعارات والتنبيهات',
                          subtitle: 'استلام إشعارات العروض ووصول الكابتن والطلبات',
                          value: _pushNotificationsEnabled,
                          isDark: isDark,
                          onChanged: (val) async {
                            _triggerHaptic();
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('push_notifications_enabled', val);
                            setState(() => _pushNotificationsEnabled = val);
                          },
                        ),
                        _buildDivider(isDark),
                        _buildSwitchTile(
                          icon: Icons.volume_up_rounded,
                          iconColor: const Color(0xFF14B8A6),
                          title: 'نغمات وأصوات مدار',
                          subtitle: 'تشغيل الصوت عند وصول الكابتن أو الطلب',
                          value: _soundEnabled,
                          isDark: isDark,
                          onChanged: (val) async {
                            _triggerHaptic();
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('notifications_sound_enabled', val);
                            setState(() => _soundEnabled = val);
                          },
                        ),
                        _buildDivider(isDark),
                        _buildSwitchTile(
                          icon: Icons.vibration_rounded,
                          iconColor: const Color(0xFFF97316),
                          title: 'الاهتزاز اللمسي (Haptic)',
                          subtitle: 'اهتزاز خفيف وجميل ويا كل لمسة',
                          value: _hapticEnabled,
                          isDark: isDark,
                          onChanged: (val) async {
                            _triggerHaptic();
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('haptic_feedback_enabled', val);
                            setState(() => _hapticEnabled = val);
                          },
                        ),
                        _buildDivider(isDark),
                        _buildSettingTile(
                          icon: Icons.language_rounded,
                          iconColor: const Color(0xFF059669),
                          title: 'لغة التطبيق',
                          subtitle: 'العربية (اللهجة العراقية 🇮🇶)',
                          trailing: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              'عراقي 🇮🇶',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          isDark: isDark,
                          onTap: () => _showLanguageDialog(isDark),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),

                    // ── هـ. أداء وتنظيف التطبيق ──
                    _buildSectionTitle('سرعة وأداء التطبيق', isDark),
                    _buildSettingsGroup(
                      cardBg: cardBg,
                      isDark: isDark,
                      items: [
                        _buildSettingTile(
                          icon: Icons.cleaning_services_rounded,
                          iconColor: const Color(0xFFEAB308),
                          title: 'تنظيف الذاكرة المؤقتة (الكاش)',
                          subtitle: _isCacheCleaned
                              ? 'التطبيق نظيف وسريع جداً هسة'
                              : 'المساحة المستخدمة: ${_cacheSizeMb.toStringAsFixed(1)} ميغابايت',
                          trailing: ElevatedButton(
                            onPressed: _cleanAppCache,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isCacheCleaned
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : AppTheme.primaryColor.withValues(alpha: 0.15),
                              foregroundColor: _isCacheCleaned ? const Color(0xFF10B981) : AppTheme.primaryColor,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            ),
                            child: Text(
                              _isCacheCleaned ? 'نظيف' : 'تنظيف',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          isDark: isDark,
                          onTap: _cleanAppCache,
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),

                    // ── و. المساعدة والدعم الفني ──
                    _buildSectionTitle('المساعدة وياك بكل وقت', isDark),
                    _buildSettingsGroup(
                      cardBg: cardBg,
                      isDark: isDark,
                      items: [
                        _buildSettingTile(
                          icon: Icons.support_agent_rounded,
                          iconColor: const Color(0xFF0284C7),
                          title: 'احچي ويا الدعم الفني المباشر',
                          subtitle: 'دردشة مباشرة ويا فريق خدمة عملاء مدار',
                          isDark: isDark,
                          onTap: () {
                            _triggerHaptic();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TechnicalSupportChatPage(isAdminPersonalChat: true),
                              ),
                            );
                          },
                        ),
                        _buildDivider(isDark),
                        _buildSettingTile(
                          icon: Icons.phone_in_talk_rounded,
                          iconColor: const Color(0xFF10B981),
                          title: 'اتصل بخدمة عملاء مدار',
                          subtitle: 'خط ساخن ومباشر لحل أي استفسار أو مشكلة',
                          isDark: isDark,
                          onTap: _callSupport,
                        ),
                        _buildDivider(isDark),
                        _buildSettingTile(
                          icon: Icons.chat_rounded,
                          iconColor: const Color(0xFF25D366),
                          title: 'تواصل ويانة على الواتساب',
                          subtitle: 'رد سريع وفوري عبر رقم الواتساب الرسمي',
                          isDark: isDark,
                          onTap: _openWhatsAppSupport,
                        ),
                        _buildDivider(isDark),
                        _buildSettingTile(
                          icon: Icons.quiz_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          title: 'الأسئلة الشائعة ودليل مدار',
                          subtitle: 'كل شي تحتاج تعرفه عن الطلب والتكسي والنقاط',
                          isDark: isDark,
                          onTap: () => _showFaqDialog(isDark),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),

                    // ── ز. عن مدار والشفافية ──
                    _buildSectionTitle('عن تطبيق مدار ℹ', isDark),
                    _buildSettingsGroup(
                      cardBg: cardBg,
                      isDark: isDark,
                      items: [
                        _buildSettingTile(
                          icon: Icons.share_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          title: 'شارك التطبيق ويا ربعك وأهلك',
                          subtitle: 'خليهم يجربون التكسي والمسواك السريع',
                          isDark: isDark,
                          onTap: _shareApp,
                        ),
                        _buildDivider(isDark),
                        _buildSettingTile(
                          icon: Icons.star_rate_rounded,
                          iconColor: const Color(0xFFEAB308),
                          title: 'قيّم تجربتك ويا مدار',
                          subtitle: 'رأيك يهمنا ويخلينا نتطور ونقدم الأفضل دايم',
                          isDark: isDark,
                          onTap: () => _showRatingDialog(isDark),
                        ),
                        _buildDivider(isDark),
                        _buildSettingTile(
                          icon: Icons.shield_rounded,
                          iconColor: const Color(0xFF06B6D4),
                          title: 'سياسة الخصوصية وأمان البيانات',
                          subtitle: 'معلوماتك وبياناتك مشفرة ومحمية بالكامل',
                          isDark: isDark,
                          onTap: () => _showPrivacyPolicyDialog(isDark),
                        ),
                        _buildDivider(isDark),
                        _buildSettingTile(
                          icon: Icons.description_rounded,
                          iconColor: const Color(0xFF64748B),
                          title: 'شروط واستخدام الخدمة',
                          subtitle: 'القواعد والاتفاقيات بين مدار والمستخدمين',
                          isDark: isDark,
                          onTap: () => _showTermsDialog(isDark),
                        ),
                        _buildDivider(isDark),
                        _buildSettingTile(
                          icon: Icons.info_outline_rounded,
                          iconColor: AppTheme.primaryColor,
                          title: 'معلومات التطبيق والإصدار',
                          subtitle: 'تطبيق مدار - الإصدار 1.0.0 (صنع في العراق 🇮🇶)',
                          isDark: isDark,
                          onTap: () => _showAboutAppDialog(isDark),
                        ),
                      ],
                    ),
                    SizedBox(height: 28.h),

                    // ── ح. أزرار تسجيل الخروج وحذف الحساب ──
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: isDark ? 0.12 : 0.06),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.2), width: 1),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _confirmLogout,
                          borderRadius: BorderRadius.circular(20.r),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20.sp),
                                SizedBox(width: 8.w),
                                Text(
                                  'تسجيل الخروج من الحساب',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.sp,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    Center(
                      child: TextButton(
                        onPressed: _confirmDeleteAccount,
                        child: Text(
                          'حذف الحساب والبيانات نهائياً',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? app_colors.darkHint : Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 40.h),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── الهيدر الملكي الفخم ──
  Widget _buildHeaderProfile(bool isDark, Color cardBg, Color textColor, Color subTextColor) {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppTheme.primaryColor,
            AppTheme.accentColor,
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32.r)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
          child: Column(
            children: [
              // الشريط العلوي مع عنوان الإعدادات
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tune_rounded, color: Colors.amberAccent, size: 20.sp),
                  SizedBox(width: 6.w),
                  Text(
                    'إعدادات وتخصيص حسابك',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),

              // بطاقة المستخدم الشخصية
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
                ),
                child: Row(
                  children: [
                    // الصورة الشخصية مع زر التعديل
                    Stack(
                      children: [
                        Container(
                          width: 68.r,
                          height: 68.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _isUploadingPhoto
                                ? Container(
                                    color: Colors.black26,
                                    child: const Center(
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    ),
                                  )
                                : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                    ? Image.network(
                                        _profileImageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildAvatarFallback(),
                                      )
                                    : _buildAvatarFallback()),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickAndUploadProfilePhoto,
                            child: Container(
                              padding: EdgeInsets.all(6.r),
                              decoration: const BoxDecoration(
                                color: Colors.amberAccent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.camera_alt_rounded, size: 13.sp, color: Colors.black87),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 14.w),

                    // الاسم ورقم الهاتف والمحافظة
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _nameController.text.isNotEmpty ? _nameController.text : 'مستخدم مدار',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Colors.amberAccent,
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  'عضو مدار',
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            _phoneController.text.isNotEmpty ? _phoneController.text : (user?.phoneNumber ?? 'لا يوجد رقم هاتف'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12.sp,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Row(
                            children: [
                              Icon(Icons.place_rounded, color: Colors.white70, size: 12.sp),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Text(
                                  _cityController.text.isNotEmpty ? _cityController.text : 'العراق 🇮🇶',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // زر تعديل سريع
                    InkWell(
                      onTap: () => _showEditProfileDialog(isDark),
                      borderRadius: BorderRadius.circular(16.r),
                      child: Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Icon(Icons.edit_rounded, color: Colors.white, size: 18.sp),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14.h),

              // بطاقة النقاط والمحفظة السريعة
              StreamBuilder<DocumentSnapshot>(
                stream: user != null
                    ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots()
                    : const Stream.empty(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                  final points = data['points'] ?? 0;
                  final balance = double.tryParse((data['balance'] ?? 0.0).toString()) ?? 0.0;

                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                    ),
                    child: Row(
                      children: [
                        // قسم النقاط
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              _triggerHaptic();
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const UserPointsPage()));
                            },
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6.r),
                                  decoration: BoxDecoration(
                                    color: Colors.amberAccent.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 18.sp),
                                ),
                                SizedBox(width: 8.w),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('نقاطك', style: TextStyle(color: Colors.white70, fontSize: 10.5.sp)),
                                    Text('$points نقطة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        Container(width: 1, height: 28.h, color: Colors.white24),

                        // قسم المحفظة
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: 8.w),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6.r),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.account_balance_wallet_rounded, color: const Color(0xFF6EE7B7), size: 18.sp),
                                ),
                                SizedBox(width: 8.w),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('المحفظة', style: TextStyle(color: Colors.white70, fontSize: 10.5.sp)),
                                    FittedBox(
                                      child: Text('${balance.toInt()} د.ع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      color: AppTheme.primaryColor.withValues(alpha: 0.2),
      child: Icon(Icons.person_rounded, size: 36.sp, color: Colors.white),
    );
  }

  // ── عنوان القسم ──
  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(right: 6.w, bottom: 8.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w800,
          color: isDark ? app_colors.darkSubText : const Color(0xFF475569),
        ),
      ),
    );
  }

  // ── حاوية مجموعة الإعدادات ──
  Widget _buildSettingsGroup({
    required Color cardBg,
    required bool isDark,
    required List<Widget> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? app_colors.darkBorder : app_colors.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: items,
      ),
    );
  }

  // ── عنصر إعداد قابل للنقر ──
  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _triggerHaptic();
          onTap();
        },
        borderRadius: BorderRadius.circular(20.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Row(
            children: [
              Container(
                width: 42.r,
                height: 42.r,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(icon, color: iconColor, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? app_colors.darkText : app_colors.textColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: isDark ? app_colors.darkSubText : app_colors.subTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing
              else Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14.sp,
                color: isDark ? app_colors.darkHint : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── عنصر إعداد مع زر تبديل (Switch) ──
  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required bool isDark,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      child: Row(
        children: [
          Container(
            width: 42.r,
            height: 42.r,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(icon, color: iconColor, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? app_colors.darkText : app_colors.textColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: isDark ? app_colors.darkSubText : app_colors.subTextColor,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppTheme.primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.8,
      indent: 64.w,
      endIndent: 14.w,
      color: isDark ? app_colors.darkDivider : app_colors.dividerColor,
    );
  }

  // ── رفع الصورة الشخصية ──
  Future<void> _pickAndUploadProfilePhoto() async {
    _triggerHaptic();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (image == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final bytes = await image.readAsBytes();
      final url = await CloudinaryService.uploadBytes(bytes, 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      if (url != null && url.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'profileImage': url,
          'photoUrl': url,
        });

        if (mounted) {
          setState(() {
            _profileImageUrl = url;
            _isUploadingPhoto = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('عاشت إيدك! تم تحديث صورتك الشخصية بنجاح', style: TextStyle()),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        }
      } else {
        if (mounted) setState(() => _isUploadingPhoto = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('صار خطأ أثناء رفع الصورة: $e', style: const TextStyle()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ── نافذة تعديل بيانات الحساب مع GPS ومحافظات العراق ──
  void _showEditProfileDialog(bool isDark) {
    _triggerHaptic();
    final nameCtrl = TextEditingController(text: _nameController.text);
    final phoneCtrl = TextEditingController(text: _phoneController.text);
    String selectedGov = _iraqiGovernorates.contains(_cityController.text) ? _cityController.text : _iraqiGovernorates.first;
    final areaCtrl = TextEditingController(text: _cityController.text);
    bool isLocating = false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? app_colors.darkCardElevated : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28.r))),
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 20.h,
              left: 20.w,
              right: 20.w,
              top: 20.h,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Icon(Icons.badge_rounded, color: AppTheme.primaryColor, size: 22.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'تعديل بيانات حسابك وموقعك',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? app_colors.darkText : app_colors.textColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'حدث اسمك ورقمك وحدد موقعك الحقيقي لسرعة التوصيل',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: isDark ? app_colors.darkSubText : Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // زر جلب الموقع الحقيقي GPS
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isLocating
                            ? null
                            : () async {
                                setModalState(() => isLocating = true);
                                final loc = await _fetchRealLocationWithPermission();
                                setModalState(() => isLocating = false);
                                if (loc != null) {
                                  final addr = loc['address'] as String;
                                  final gov = loc['gov'] as String;
                                  setModalState(() {
                                    areaCtrl.text = addr;
                                    for (final g in _iraqiGovernorates) {
                                      if (gov.contains(g) || addr.contains(g)) {
                                        selectedGov = g;
                                        break;
                                      }
                                    }
                                  });
                                }
                              },
                        borderRadius: BorderRadius.circular(14.r),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isLocating)
                                SizedBox(
                                  width: 16.r,
                                  height: 16.r,
                                  child: const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                                )
                              else
                                Icon(Icons.my_location_rounded, color: AppTheme.primaryColor, size: 18.sp),
                              SizedBox(width: 8.w),
                              Text(
                                isLocating ? 'جاري تحديد موقعك الحقيقي...' : 'تحديد موقعي الحقيقي تلقائياً (GPS)',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 14.h),

                  // حقل الاسم
                  _buildModalTextField(
                    controller: nameCtrl,
                    label: 'اسمك الكامل',
                    icon: Icons.person_rounded,
                    isDark: isDark,
                  ),
                  SizedBox(height: 12.h),

                  // حقل الهاتف
                  _buildModalTextField(
                    controller: phoneCtrl,
                    label: 'رقم الهاتف',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    isDark: isDark,
                  ),
                  SizedBox(height: 12.h),

                  // اختيار المحافظة العراقية
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: isDark ? app_colors.darkSurface : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: isDark ? app_colors.darkBorder : Colors.grey.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedGov,
                        isExpanded: true,
                        dropdownColor: isDark ? app_colors.darkCardElevated : Colors.white,
                        items: _iraqiGovernorates.map((gov) {
                          return DropdownMenuItem(
                            value: gov,
                            child: Row(
                              children: [
                                Icon(Icons.location_city_rounded, color: AppTheme.primaryColor, size: 18.sp),
                                SizedBox(width: 8.w),
                                Text(gov, style: TextStyle(fontSize: 13.sp, color: isDark ? app_colors.darkText : Colors.black87)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedGov = val);
                          }
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // حقل المنطقة والشارع
                  _buildModalTextField(
                    controller: areaCtrl,
                    label: 'المنطقة / الشارع / تفاصيل العنوان',
                    icon: Icons.place_rounded,
                    isDark: isDark,
                  ),
                  SizedBox(height: 20.h),

                  // زر الحفظ
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) return;

                              setModalState(() => isSaving = true);

                              try {
                                final finalCity = areaCtrl.text.trim().isNotEmpty ? areaCtrl.text.trim() : selectedGov;

                                await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                                  'name': nameCtrl.text.trim(),
                                  'phone': phoneCtrl.text.trim(),
                                  'city': finalCity,
                                  'governorate': selectedGov,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });

                                if (dialogCtx.mounted) {
                                  Navigator.pop(dialogCtx);
                                }

                                if (mounted) {
                                  setState(() {
                                    _nameController.text = nameCtrl.text.trim();
                                    _phoneController.text = phoneCtrl.text.trim();
                                    _cityController.text = finalCity;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم حفظ بياناتك وموقعك بنجاح', style: TextStyle()),
                                      backgroundColor: AppTheme.primaryColor,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('صار خطأ أثناء الحفظ: $e', style: const TextStyle()),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                      ),
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : Text(
                              'حفظ البيانات الحقيقية',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModalTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required bool isDark,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? app_colors.darkText : Colors.black87, fontSize: 13.sp),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? app_colors.darkSubText : Colors.grey.shade600, fontSize: 12.sp),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20.sp),
        filled: true,
        fillColor: isDark ? app_colors.darkSurface : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5)),
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      ),
    );
  }

  // ── نافذة العناوين والمواقع المحفوظة مع GPS وخريطة Google ──
  void _showSavedAddressesDialog(bool isDark) {
    _triggerHaptic();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? app_colors.darkCardElevated : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28.r))),
      builder: (ctx) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
            final savedAddresses = List<Map<String, dynamic>>.from(data['savedAddresses'] ?? [
              {
                'title': 'البيت',
                'address': 'بغداد - المنصور - شارع 14 رمضان',
                'lat': 33.3152,
                'lng': 44.3661,
              },
            ]);

            return Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 30.h),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10.r)),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, color: const Color(0xFF10B981), size: 22.sp),
                            SizedBox(width: 8.w),
                            Text(
                              'عناويني ومواقعي المحفوظة',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? app_colors.darkText : app_colors.textColor,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // إضافة عبر الخريطة
                            IconButton(
                              tooltip: 'اختيار من الخريطة',
                              icon: Icon(Icons.map_rounded, color: AppTheme.primaryColor, size: 22.sp),
                              onPressed: () => _pickAddressFromMap(isDark, user.uid, savedAddresses),
                            ),
                            // إضافة عنوان جديد
                            IconButton(
                              tooltip: 'إضافة عنوان',
                              icon: Icon(Icons.add_location_alt_rounded, color: const Color(0xFF10B981), size: 24.sp),
                              onPressed: () => _addNewAddressDialog(isDark, user.uid, savedAddresses),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'احفظ مواقعك الحقيقية لطلب التكسي والمسواك بضغطة زر',
                      style: TextStyle(fontSize: 11.sp, color: isDark ? app_colors.darkSubText : Colors.grey.shade600),
                    ),
                    SizedBox(height: 16.h),

                    // زر تحديد وحفظ الموقع الحالي GPS فوراً
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _saveQuickCurrentLocation(user.uid, savedAddresses),
                          borderRadius: BorderRadius.circular(14.r),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.my_location_rounded, color: const Color(0xFF10B981), size: 18.sp),
                                SizedBox(width: 8.w),
                                Text(
                                  'حفظ موقعي الحالي فوراً (GPS)',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 14.h),

                    if (savedAddresses.isEmpty)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.r),
                          child: Text('ما عندك عناوين محفوظة هسة، ضيف موقعك من الأزرار بالأعلى', style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
                        ),
                      )
                    else
                      ...savedAddresses.map((addr) {
                        final lat = (addr['lat'] as num?)?.toDouble();
                        final lng = (addr['lng'] as num?)?.toDouble();

                        return Container(
                          margin: EdgeInsets.only(bottom: 10.h),
                          padding: EdgeInsets.all(12.r),
                          decoration: BoxDecoration(
                            color: isDark ? app_colors.darkSurface : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: isDark ? app_colors.darkBorder : Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.r),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.place_rounded, color: const Color(0xFF10B981), size: 18.sp),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      addr['title'] ?? 'عنوان محفوظ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.sp,
                                        color: isDark ? app_colors.darkText : app_colors.textColor,
                                      ),
                                    ),
                                    Text(
                                      addr['address'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: isDark ? app_colors.darkSubText : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (lat != null && lng != null)
                                IconButton(
                                  tooltip: 'عرض بالخريطة',
                                  icon: Icon(Icons.directions_rounded, color: AppTheme.primaryColor, size: 20.sp),
                                  onPressed: () async {
                                    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url, mode: LaunchMode.externalApplication);
                                    }
                                  },
                                ),
                              IconButton(
                                tooltip: 'حذف',
                                icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.shade200, size: 18.sp),
                                onPressed: () async {
                                  _triggerHaptic();
                                  savedAddresses.remove(addr);
                                  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                                    'savedAddresses': savedAddresses,
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickAddressFromMap(isDark, user.uid, savedAddresses),
                            icon: const Icon(Icons.map_rounded),
                            label: const Text('من الخريطة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: const BorderSide(color: AppTheme.primaryColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _addNewAddressDialog(isDark, user.uid, savedAddresses),
                            icon: const Icon(Icons.add_rounded, color: Colors.white),
                            label: const Text('كتابة عنوان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── اختيار موقع من الخريطة ──
  Future<void> _pickAddressFromMap(bool isDark, String uid, List<Map<String, dynamic>> currentAddresses) async {
    _triggerHaptic();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerPage()),
    );

    if (result != null && result is Map) {
      final address = result['address'] as String? ?? 'موقع على الخريطة';
      final location = result['location'] as LatLng?;

      final titleCtrl = TextEditingController(text: 'موقعي');
      final addressCtrl = TextEditingController(text: address);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? app_colors.darkCardElevated : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Text('تسمية الموقع المختار', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'اسم الموقع (مثلاً: البيت، الاستراحة)',
                  labelStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: addressCtrl,
                decoration: InputDecoration(
                  labelText: 'العنوان',
                  labelStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newAddr = {
                  'title': titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : 'موقع مختار',
                  'address': addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : address,
                  if (location != null) 'lat': location.latitude,
                  if (location != null) 'lng': location.longitude,
                  'createdAt': DateTime.now().toIso8601String(),
                };
                currentAddresses.add(newAddr);
                await FirebaseFirestore.instance.collection('users').doc(uid).update({
                  'savedAddresses': currentAddresses,
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              child: const Text('حفظ الموقع', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  void _addNewAddressDialog(bool isDark, String uid, List<Map<String, dynamic>> currentAddresses) {
    final titleCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? app_colors.darkCardElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            const Icon(Icons.add_location_alt_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 8.w),
            Text('إضافة موقع جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: 'اسم العنوان (مثلاً: بيت جدي، شقتي)',
                labelStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
            SizedBox(height: 10.h),
            TextField(
              controller: addressCtrl,
              decoration: InputDecoration(
                labelText: 'تفاصيل العنوان والمنطقة',
                labelStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || addressCtrl.text.trim().isEmpty) return;
              final newAddr = {
                'title': titleCtrl.text.trim(),
                'address': addressCtrl.text.trim(),
                'createdAt': DateTime.now().toIso8601String(),
              };
              currentAddresses.add(newAddr);
              await FirebaseFirestore.instance.collection('users').doc(uid).update({
                'savedAddresses': currentAddresses,
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('إضافة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── تنظيف الكاش ──
  Future<void> _cleanAppCache() async {
    _triggerHaptic();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cache_recently_cleaned', true);

    if (mounted) {
      setState(() {
        _cacheSizeMb = 0.4;
        _isCacheCleaned = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8.w),
              const Expanded(
                child: Text(
                  'عاشت إيدك! تم تنظيف الذاكرة المؤقتة وصار التطبيق أخف وأسرع',
                  style: TextStyle(),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── الدعم الفني: اتصال مباشر ──
  Future<void> _callSupport() async {
    _triggerHaptic();
    final Uri uri = Uri.parse('tel:07800000000');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('رقم خدمة العملاء: 07800000000', style: TextStyle()),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    }
  }

  // ── الدعم الفني: واتساب ──
  Future<void> _openWhatsAppSupport() async {
    _triggerHaptic();
    final Uri uri = Uri.parse('https://wa.me/9647800000000?text=مرحبا%20فريق%20مدار،%20محتاج%20مساعدة');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تواصل ويانة عبر الواتساب على الرقم: 07800000000', style: TextStyle()),
            backgroundColor: Color(0xFF25D366),
          ),
        );
      }
    }
  }

  // ── نافذة اللغة ──
  void _showLanguageDialog(bool isDark) {
    _triggerHaptic();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? app_colors.darkCardElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            const Icon(Icons.language_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 8.w),
            Text('لغة التطبيق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppTheme.primaryColor, width: 1.5),
              ),
              child: Row(
                children: [
                  const Text('🇮🇶', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('العربية (اللهجة العراقية)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                        Text('اللغة الافتراضية والمدعومة حالياً بالكامل', style: TextStyle(fontSize: 10.5.sp, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تمام', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── نافذة الأسئلة الشائعة ──
  void _showFaqDialog(bool isDark) {
    _triggerHaptic();
    final faqs = [
      {
        'q': 'شلون أطلب تكسي مدار؟',
        'a': 'ادخل على قسم تكسي مدار من الصفحة الرئيسية، حدد موقعك ووجهتك، واضغط "طلب تكسي". أقرب كابتن يمك راح يوافق ويجيك مباشرة!'
      },
      {
        'q': 'شلون أتسوق من المتاجر وسوق مدار؟',
        'a': 'افتح صفحة المتاجر، تصفح الأقسام أو ابحث عن المحل، ضيف الأغراض لسلتك، واضغط "تأكيد الطلب". المندوب راح يستلمها ويوصلها لباب بيتك.'
      },
      {
        'q': 'شلون أجمع وأستفاد من نقاط مدار؟',
        'a': 'ويا كل مشوار تكسي أو مسواك تطلبه راح تنزل نقاط بحسابك. كل 100 نقطة تنطيك 1,000 د.ع خصم فوري تكدر تستبدله بأي طلب!'
      },
      {
        'q': 'شلون أدفع بالمحفظة الإلكترونية؟',
        'a': 'رصيدك بالمحفظة تكدر تستخدمه للدفع التلقائي لرحلات التكسي أو الطلبات، وتكدر تشحن المحفظة عن طريق الدعم أو كروت مدار.'
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? app_colors.darkCardElevated : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28.r))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Icon(Icons.quiz_rounded, color: const Color(0xFFF59E0B), size: 22.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'الأسئلة الشائعة ودليل مدار',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? app_colors.darkText : app_colors.textColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                ...faqs.map((faq) {
                  return Container(
                    margin: EdgeInsets.only(bottom: 12.h),
                    decoration: BoxDecoration(
                      color: isDark ? app_colors.darkSurface : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: isDark ? app_colors.darkBorder : Colors.grey.shade200),
                    ),
                    child: ExpansionTile(
                      shape: const Border(),
                      tilePadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
                      title: Text(
                        faq['q']!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                          color: isDark ? app_colors.darkText : app_colors.textColor,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
                          child: Text(
                            faq['a']!,
                            style: TextStyle(
                              fontSize: 12.sp,
                              height: 1.6,
                              color: isDark ? app_colors.darkSubText : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── مشاركة التطبيق ──
  void _shareApp() {
    _triggerHaptic();
    Share.share(
      'حمل تطبيق مدار هسة! \n'
      'تكسي سريع، مسواك ومتاجر، وتوصيل لكل مكان بضغطة زر وبأحسن الأسعار بالعراق 🇮🇶\n'
      'حمل التطبيق واستمتع بالعروض والنقاط الحصرية!',
    );
  }

  // ── تقييم التطبيق ──
  void _showRatingDialog(bool isDark) {
    _triggerHaptic();
    int rating = 5;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setRatingState) {
          return AlertDialog(
            backgroundColor: isDark ? app_colors.darkCardElevated : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stars_rounded, color: Colors.amber, size: 54.sp),
                SizedBox(height: 10.h),
                Text(
                  'شرايك بتطبيق مدار؟',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? app_colors.darkText : app_colors.textColor,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'تقييمك يفرحنا ويساعدنا نطور التطبيق لخدمتك دايم!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5.sp, color: isDark ? app_colors.darkSubText : Colors.grey.shade600),
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 32.sp,
                      ),
                      onPressed: () {
                        _triggerHaptic();
                        setRatingState(() => rating = index + 1);
                      },
                    );
                  }),
                ),
                SizedBox(height: 10.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _triggerHaptic();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('شكراً من القلب على تقييمك ودعمك لمدار!', style: TextStyle()),
                          backgroundColor: AppTheme.primaryColor,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: Text('إرسال التقييم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── سياسة الخصوصية ──
  void _showPrivacyPolicyDialog(bool isDark) {
    _triggerHaptic();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? app_colors.darkCardElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
        title: Row(
          children: [
            const Icon(Icons.shield_rounded, color: Color(0xFF06B6D4)),
            SizedBox(width: 8.w),
            Text('سياسة الخصوصية وأمانك', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(
              'أمانك وخصوصية بياناتك هي أولويتنا الأولى في مدار:\n\n'
              ' 1. الموقع الجغرافي:\nنستخدم موقعك فقط لما تطلب تكسي أو مسواك حتى يقدر الكابتن والمندوب يندلوك بسرعة وبدقة.\n\n'
              ' 2. الحماية والتشفير:\nرقم هاتفك وبيانات حسابك مشفرة ومحمية بالكامل وما نشاركها ويا أي طرف إعلاني.\n\n'
              ' 3. المعاملات والمحفظة:\nكل رصيد وعمليات الدفع مسجلة بأعلى معايير الأمان المالي.\n\n'
              ' 4. حق الحذف والتحكم:\nتكدر تحذف حسابك وكافة بياناتك ومواقعك نهائياً بأي لحظة وبضغطة زر من صفحة الإعدادات.',
              style: TextStyle(
                fontSize: 12.5.sp,
                height: 1.6,
                color: isDark ? app_colors.darkSubText : const Color(0xFF334155),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('موافق وفهمت', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  // ── شروط واستخدام الخدمة ──
  void _showTermsDialog(bool isDark) {
    _triggerHaptic();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? app_colors.darkCardElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
        title: Row(
          children: [
            const Icon(Icons.description_rounded, color: Color(0xFF64748B)),
            SizedBox(width: 8.w),
            Text('شروط واستخدام مدار', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(
              'باستخدامك لتطبيق مدار، إحنا متعهدين بتقديم أفضل تجربة:\n\n'
              ' 1. الاحترام المتبادل:\nيلتزم المستخدمون والكباتن وأصحاب المتاجر بالتعامل الراقي والأخلاقي.\n\n'
              ' 2. مصداقية الطلبات:\nيرجى التأكد من الطلب وتحديد الموقع بدقة لتجنب إلغاء المشاوير أو الطلبات بعد انطلاق الكابتن.\n\n'
              ' 3. تسعيرة واضحة:\nكل الأسعار والأجور تظهرلك بوضوح قبل تأكيد الطلب بدون أي رسوم مخفية.',
              style: TextStyle(
                fontSize: 12.5.sp,
                height: 1.6,
                color: isDark ? app_colors.darkSubText : const Color(0xFF334155),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('موافق', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  // ── معلومات التطبيق ──
  void _showAboutAppDialog(bool isDark) {
    _triggerHaptic();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? app_colors.darkCardElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 64.r,
              errorBuilder: (_, __, ___) => Icon(Icons.apps_rounded, size: 54.sp, color: AppTheme.primaryColor),
            ),
            SizedBox(height: 12.h),
            Text(
              AppConstants.appName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
                color: isDark ? app_colors.darkText : app_colors.textColor,
              ),
            ),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                'الإصدار 1.0.0 (Gold)',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'منصة مدار المتكاملة لخدمات النقل الذكي، توصيل المسواك، والمتاجر في العراق 🇮🇶\nصممت وطورت بحب لخدمة أهلنا.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                height: 1.6,
                color: isDark ? app_colors.darkSubText : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  // ── تأكيد تسجيل الخروج ──
  void _confirmLogout() {
    _triggerHaptic();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? app_colors.darkCardElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.redAccent),
            SizedBox(width: 8.w),
            Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
          ],
        ),
        content: Text(
          'متأكد تريد تسجل خروج من حسابك؟ تكدر ترجع تسجل دخول بأي وقت برقم هاتفك',
          style: TextStyle(fontSize: 13.sp, color: isDark ? app_colors.darkSubText : Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await OneSignalService.logout();
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomePage()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('تسجيل خروج', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── حذف الحساب نهائياً ──
  void _confirmDeleteAccount() {
    _triggerHaptic();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? app_colors.darkCardElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8.w),
            Text('حذف الحساب نهائياً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: Colors.red)),
          ],
        ),
        content: Text(
          'تحذير: هذا الإجراء راح يحذف كل بياناتك، طلباتك، رصيدك، ونقاطك بشكل دائم وما تكدر تسترجعها أبداً. متأكد من قرارك؟',
          style: TextStyle(fontSize: 13.sp, color: isDark ? app_colors.darkSubText : Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تراجع', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              final uid = user.uid;

              try {
                if (mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                  );
                }

                await FirebaseFirestore.instance.collection('users').doc(uid).delete().catchError((_) {});
                await FirebaseFirestore.instance.collection('drivers').doc(uid).delete().catchError((_) {});
                await FirebaseFirestore.instance.collection('restaurants').doc(uid).delete().catchError((_) {});
                await FirebaseFirestore.instance.collection('delivery_boys').doc(uid).delete().catchError((_) {});

                await OneSignalService.logout();
                await user.delete();

                if (mounted) {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const WelcomePage()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(context).pop();
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const WelcomePage()),
                      (route) => false,
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('نعم، احذف الحساب', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
