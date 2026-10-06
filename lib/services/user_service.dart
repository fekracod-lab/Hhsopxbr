import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dalal_alqaim/features/auth/widgets/role_selector_tab.dart';
import 'package:dalal_alqaim/features/home/pages/home_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/driver_dashboard_page.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/pages/restaurant_dashboard_page.dart';
import 'package:dalal_alqaim/features/stores/presentation/pages/store_dashboard_page.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/driver_registration_status_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/delivery_registration_status_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/delivery_dashboard_page.dart';
import 'package:dalal_alqaim/services/onesignal_service.dart';
import 'package:dalal_alqaim/core/app_initializer.dart';

/// Smart Global User & Session Management Service
class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  // Cached User State
  String? _uid;
  String? _name;
  String? _phone;
  String? _email;
  String _roleStr = 'customer';
  UserRole _role = UserRole.customer;
  String _status = 'active';
  bool _isApproved = true;
  bool _isInitialized = false;

  // Getters
  String? get uid => _uid ?? FirebaseAuth.instance.currentUser?.uid;
  String get name => (_name != null && _name!.isNotEmpty) ? _name! : 'مستخدم';
  String get phone => _phone ?? '';
  String get email => _email ?? '';
  String get roleStr => _roleStr;
  UserRole get role => _role;
  String get status => _status;
  bool get isApproved => _isApproved;
  bool get isInitialized => _isInitialized;

  /// Initialize User Data synchronously/asynchronously on boot
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _name = prefs.getString('user_name');
      _phone = prefs.getString('user_phone');
      _roleStr = prefs.getString('currentUserRole') ?? 'customer';
      _uid = prefs.getString('currentUserId') ?? FirebaseAuth.instance.currentUser?.uid;

      _role = _parseRoleStr(_roleStr);
      _isInitialized = true;
    } catch (e) {
      debugPrint(' UserService init error: $e');
    }
  }

  /// Auto-Check phone registration status in Firestore
  static Future<Map<String, dynamic>?> checkPhoneRegistration(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleanPhone.length < 10) return null;

    String format1 = cleanPhone;
    if (!format1.startsWith('+')) {
      format1 = format1.startsWith('0') ? '+964${format1.substring(1)}' : '+964$format1';
    }
    String format2 = cleanPhone.startsWith('0') ? cleanPhone : '0${cleanPhone.replaceAll('+964', '')}';

    try {
      // Query users collection by phone
      final query1 = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', whereIn: [cleanPhone, format1, format2])
          .limit(1)
          .get();

      if (query1.docs.isNotEmpty) {
        final doc = query1.docs.first;
        return {
          'exists': true,
          'uid': doc.id,
          'data': doc.data(),
          'name': doc.data()['name']?.toString() ?? '',
          'role': doc.data()['role']?.toString() ?? 'customer',
          'status': doc.data()['status']?.toString() ?? 'active',
          'isApproved': doc.data()['isApproved'] as bool? ?? true,
        };
      }
    } catch (e) {
      debugPrint(' Phone check error: $e');
    }
    return {'exists': false};
  }

  /// Sync latest profile data from Firestore
  Future<void> syncFromFirestore(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          _uid = userId;
          _name = data['name']?.toString() ?? _name;
          _phone = data['phone']?.toString() ?? _phone;
          _email = data['email']?.toString() ?? _email;
          _roleStr = data['role']?.toString() ?? _roleStr;
          _status = data['status']?.toString() ?? 'active';
          _isApproved = data['isApproved'] as bool? ?? true;
          _role = _parseRoleStr(_roleStr);

          // Save locally
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', _name ?? 'مستخدم');
          await prefs.setString('user_phone', _phone ?? '');
          await prefs.setString('currentUserRole', _roleStr);
          await prefs.setString('currentUserId', userId);
          await prefs.setBool('user_data_registered', true);
        }
      }
    } catch (e) {
      debugPrint(' Sync Firestore error: $e');
    }
  }

  /// Save user profile on Login/Register
  Future<void> saveSession({
    required String userId,
    required String name,
    required String phone,
    required UserRole userRole,
    String? email,
    String status = 'active',
    bool isApproved = true,
  }) async {
    _uid = userId;
    _name = name.isNotEmpty ? name : 'مستخدم';
    _phone = phone;
    _email = email ?? '';
    _role = userRole;
    _roleStr = userRole.name;
    _status = status;
    _isApproved = isApproved;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentUserId', userId);
    await prefs.setString('user_name', _name!);
    await prefs.setString('user_phone', phone);
    await prefs.setString('currentUserRole', _roleStr);
    await prefs.setBool('user_data_registered', true);

    // Sync OneSignal Notification tags
    await OneSignalService.syncUserRole(userId);
  }

  static UserRole _parseRoleStr(String? role) {
    final r = role?.toLowerCase();
    if (r == 'delivery' || r == 'delivery_captain' || r == 'delivery_boy') return UserRole.delivery;
    if (r == 'captain' || r == 'driver' || r == 'taxi_captain' || r == 'transport_captain') return UserRole.captain;
    if (r == 'restaurant' || r == 'restaurant_owner' || r == 'merchant') return UserRole.restaurant;
    if (r == 'store' || r == 'market') return UserRole.store;
    return UserRole.customer;
  }

  /// Get target role page destination widget
  static Widget getDestinationPage({
    required UserRole role,
    required String status,
    required bool isApproved,
    String? userId,
  }) {
    final statusClean = status.toLowerCase();
    final isPendingOrUnderReview = !isApproved || statusClean == 'pending' || statusClean == 'under_review' || statusClean == 'waiting';

    if (role == UserRole.delivery && isPendingOrUnderReview) {
      return const PopScope(canPop: true, child: DeliveryRegistrationStatusPage());
    }

    if ((role == UserRole.captain || role == UserRole.restaurant || role == UserRole.store) && isPendingOrUnderReview) {
      return const PopScope(canPop: true, child: DriverRegistrationStatusPage());
    }

    switch (role) {
      case UserRole.customer:
        return const HomePage();
      case UserRole.captain:
        return const PopScope(canPop: false, child: DriverDashboardPage());
      case UserRole.restaurant:
        return const PopScope(canPop: false, child: RestaurantDashboardPage());
      case UserRole.store:
        return PopScope(
          canPop: false,
          child: StoreDashboardPage(storeId: userId ?? FirebaseAuth.instance.currentUser?.uid ?? ''),
        );
      case UserRole.delivery:
        return const PopScope(canPop: false, child: DeliveryDashboardPage());
    }
  }

  /// Safe Sign Out & Notification Token Purge
  static Future<void> signOut() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. تعطيل توكن الجهاز الحالي في سجل الأجهزة المتعددة
        try {
          final deviceId = await AppInitializer.getOrGenerateDeviceId();
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('notification_devices')
              .doc(deviceId)
              .update({
                'enabled': false,
                'disabledAt': FieldValue.serverTimestamp(),
                'disabledReason': 'user_logout',
              }).catchError((_) {});
        } catch (_) {}

        // 2. إزالة التوكنات القديمة من Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
          'oneSignalId': FieldValue.delete(),
          'isLoggedIn': false,
        }).catchError((_) {});

        await FirebaseFirestore.instance.collection('drivers').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
          'oneSignalId': FieldValue.delete(),
          'availability': 'offline',
        }).catchError((_) {});
      }

      // 3. مسح بيانات الجلسة المحلية من SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('currentUserId');
      await prefs.remove('currentUserRole');
      if (user != null) {
        await prefs.remove('currentUserRole_${user.uid}');
      }
      await prefs.remove('user_name');
      await prefs.remove('user_phone');
      await prefs.remove('user_data_registered');

      // 4. تسجيل الخروج من OneSignal
      await OneSignalService.logout();

      // 5. تسجيل الخروج من Firebase Auth
      await FirebaseAuth.instance.signOut();
      debugPrint(' User signed out and notification tokens purged.');
    } catch (e) {
      debugPrint(' Error during safe signOut: $e');
      await FirebaseAuth.instance.signOut();
    }
  }
}
