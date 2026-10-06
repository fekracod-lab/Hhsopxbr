import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نموذج بيانات حساب المطعم المحفوظ للعمل بدون إنترنت (Offline Restaurant Profile)
class OfflineRestaurantProfile {
  final String uid;
  final String email;
  final String passwordHash;
  final String restaurantName;
  final String ownerName;
  final String city;
  final String role;
  final String status;
  final String pinHash;
  final bool isLocalOnly;
  final DateTime lastLoginAt;

  OfflineRestaurantProfile({
    required this.uid,
    required this.email,
    required this.passwordHash,
    required this.restaurantName,
    required this.ownerName,
    required this.city,
    required this.role,
    required this.status,
    required this.pinHash,
    required this.isLocalOnly,
    required this.lastLoginAt,
  });

  OfflineRestaurantProfile copyWith({
    String? uid,
    String? email,
    String? passwordHash,
    String? restaurantName,
    String? ownerName,
    String? city,
    String? role,
    String? status,
    String? pinHash,
    bool? isLocalOnly,
    DateTime? lastLoginAt,
  }) {
    return OfflineRestaurantProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      restaurantName: restaurantName ?? this.restaurantName,
      ownerName: ownerName ?? this.ownerName,
      city: city ?? this.city,
      role: role ?? this.role,
      status: status ?? this.status,
      pinHash: pinHash ?? this.pinHash,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'passwordHash': passwordHash,
      'restaurantName': restaurantName,
      'ownerName': ownerName,
      'city': city,
      'role': role,
      'status': status,
      'pinHash': pinHash,
      'isLocalOnly': isLocalOnly,
      'lastLoginAt': lastLoginAt.toIso8601String(),
    };
  }

  factory OfflineRestaurantProfile.fromMap(Map<String, dynamic> map) {
    return OfflineRestaurantProfile(
      uid: map['uid'] as String? ?? 'offline_local_merchant',
      email: map['email'] as String? ?? '',
      passwordHash: map['passwordHash'] as String? ?? '',
      restaurantName: map['restaurantName'] as String? ?? 'مطعم مدار المحلي',
      ownerName: map['ownerName'] as String? ?? 'كاشير المحطة',
      city: map['city'] as String? ?? 'القائم',
      role: map['role'] as String? ?? 'merchant',
      status: map['status'] as String? ?? 'approved',
      pinHash: map['pinHash'] as String? ?? '',
      isLocalOnly: map['isLocalOnly'] as bool? ?? false,
      lastLoginAt: DateTime.tryParse(map['lastLoginAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// نتيجة محاولة تسجيل الدخول بدون إنترنت
class OfflineAuthResult {
  final bool success;
  final String message;
  final OfflineRestaurantProfile? profile;

  OfflineAuthResult({
    required this.success,
    required this.message,
    this.profile,
  });
}

/// خدمة تسجيل الدخول وإدارة الهوية بدون إنترنت (Enterprise Offline-First Authentication)
/// تتيح للمطاعم تسجيل الدخول والعمل بشكل مستقل 100% دون الحاجة لأي اتصال بالإنترنت
class OfflineAuthService extends ChangeNotifier {
  static final OfflineAuthService instance = OfflineAuthService._internal();
  OfflineAuthService._internal();

  static const String _kProfilesKey = 'madar_offline_restaurant_profiles';
  static const String _kActiveSessionKey = 'madar_offline_session_active';
  static const String _kActiveUidKey = 'madar_offline_session_uid';

  final List<OfflineRestaurantProfile> _cachedProfiles = [];
  OfflineRestaurantProfile? _currentProfile;
  bool _isOfflineSession = false;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  bool get isOfflineSession => _isOfflineSession;
  OfflineRestaurantProfile? get currentProfile => _currentProfile;
  List<OfflineRestaurantProfile> get cachedProfiles => List.unmodifiable(_cachedProfiles);
  bool get hasAnyCachedMerchant => _cachedProfiles.isNotEmpty;

  /// معرف المطعم النشط (سواء محلي أو سحابي محفوظ)
  String get currentUid => _currentProfile?.uid ?? '';

  /// اسم المطعم النشط
  String get cachedRestaurantName => _currentProfile?.restaurantName ?? 'مطعم مدار';

  /// اسم صاحب المطعم أو الكاشير النشط
  String get cachedOwnerName => _currentProfile?.ownerName ?? 'كاشير مدار';

  /// تشفير نصوص كلمات المرور ورموز PIN بواسطة SHA-256
  static String hashValue(String value) {
    final bytes = utf8.encode(value.trim());
    return sha256.convert(bytes).toString();
  }

  /// تهيئة الخدمة وقراءة البيانات المحفوظة محلياً
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = prefs.getString(_kProfilesKey);
      _cachedProfiles.clear();

      if (profilesJson != null && profilesJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(profilesJson) as List<dynamic>;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _cachedProfiles.add(OfflineRestaurantProfile.fromMap(item));
          }
        }
      }

      final isSessionActive = prefs.getBool(_kActiveSessionKey) ?? false;
      final activeUid = prefs.getString(_kActiveUidKey);

      if (isSessionActive && activeUid != null && activeUid.isNotEmpty) {
        final matching = _cachedProfiles.where((p) => p.uid == activeUid);
        if (matching.isNotEmpty) {
          _currentProfile = matching.first;
          _isOfflineSession = true;
        } else if (_cachedProfiles.isNotEmpty) {
          _currentProfile = _cachedProfiles.first;
          _isOfflineSession = true;
        }
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[OfflineAuthService] Init error: $e');
      _isInitialized = true;
    }
  }

  /// فحص ما إذا كانت هناك جلسة أوفلاين نشطة حالياً
  Future<bool> hasActiveOfflineSession() async {
    if (!_isInitialized) await init();
    return _isOfflineSession && _currentProfile != null;
  }

  /// فحص ما إذا كان هناك مطعم مخزن بهذا الـ UID وحالته مقبولة
  bool isMerchantCached(String uid) {
    final match = _cachedProfiles.where((p) => p.uid == uid);
    if (match.isEmpty) return false;
    final status = match.first.status.toLowerCase();
    return status == 'approved' || status == 'active';
  }

  /// حفظ وتحديث بيانات الدخول بعد تسجيل الدخول عبر الإنترنت بنجاح
  Future<void> cacheOnlineCredentials({
    required String uid,
    required String email,
    required String password,
    required String restaurantName,
    required String ownerName,
    String city = 'القائم',
    String role = 'merchant',
    String status = 'approved',
    String? pin,
  }) async {
    if (!_isInitialized) await init();

    final pHash = hashValue(password);
    final defaultPinHash = hashValue('0000');
    final actualPinHash = (pin != null && pin.trim().isNotEmpty)
        ? hashValue(pin.trim())
        : defaultPinHash;

    // استخراج الملف الحالي إن وُجد للاحتفاظ برمز PIN المخصص
    final existingIndex = _cachedProfiles.indexWhere((p) => p.uid == uid || p.email.toLowerCase() == email.toLowerCase().trim());
    String preservedPinHash = actualPinHash;
    if (existingIndex >= 0 && pin == null) {
      preservedPinHash = _cachedProfiles[existingIndex].pinHash;
      if (preservedPinHash.isEmpty) preservedPinHash = defaultPinHash;
    }

    final newProfile = OfflineRestaurantProfile(
      uid: uid,
      email: email.trim().toLowerCase(),
      passwordHash: pHash,
      restaurantName: restaurantName.trim().isNotEmpty ? restaurantName.trim() : 'مطعم مدار',
      ownerName: ownerName.trim().isNotEmpty ? ownerName.trim() : 'صاحب المطعم',
      city: city.trim().isNotEmpty ? city.trim() : 'القائم',
      role: role,
      status: status,
      pinHash: preservedPinHash,
      isLocalOnly: false,
      lastLoginAt: DateTime.now(),
    );

    if (existingIndex >= 0) {
      _cachedProfiles[existingIndex] = newProfile;
    } else {
      _cachedProfiles.add(newProfile);
    }

    _currentProfile = newProfile;
    await _persistProfiles();
    notifyListeners();
  }

  /// التحقق من بيانات الدخول (البريد وكلمة المرور) في وضع الأوفلاين
  Future<OfflineAuthResult> authenticateOffline({
    required String email,
    required String password,
  }) async {
    if (!_isInitialized) await init();

    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      return OfflineAuthResult(
        success: false,
        message: 'يرجى كتابة البريد الإلكتروني وكلمة المرور للمطعم.',
      );
    }

    final pHash = hashValue(cleanPassword);

    // البحث عن الحساب المطابق في السجلات المحفوظة
    OfflineRestaurantProfile? match;
    for (final p in _cachedProfiles) {
      if (p.email.toLowerCase() == cleanEmail && p.passwordHash == pHash) {
        match = p;
        break;
      }
    }

    if (match == null) {
      return OfflineAuthResult(
        success: false,
        message: 'بيانات الدخول غير صحيحة أو لم يتم حفظ هذا الحساب على الجهاز مسبقاً في وضع عدم الاتصال.',
      );
    }

    // التحقق من حالة الحساب المحفوظ
    final status = match.status.toLowerCase();
    if (status == 'banned' || status == 'removed') {
      return OfflineAuthResult(
        success: false,
        message: 'حساب هذا المطعم محظور من قبل الإدارة.',
      );
    }

    _currentProfile = match.copyWith(lastLoginAt: DateTime.now());
    _isOfflineSession = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kActiveSessionKey, true);
    await prefs.setString(_kActiveUidKey, match.uid);
    await _persistProfiles();

    notifyListeners();
    return OfflineAuthResult(
      success: true,
      message: 'تم تسجيل الدخول بنجاح في وضع الأوفلاين.',
      profile: _currentProfile,
    );
  }

  /// تسجيل الدخول السريع برمز PIN للكاشير (4 أرقام - الافتراضي 0000)
  Future<OfflineAuthResult> authenticateWithPin(String pin) async {
    if (!_isInitialized) await init();

    final cleanPin = pin.trim();
    if (cleanPin.isEmpty) {
      return OfflineAuthResult(
        success: false,
        message: 'يرجى إدخال رمز PIN للدخول السريع.',
      );
    }

    final inputHash = hashValue(cleanPin);
    final defaultHash = hashValue('0000');

    OfflineRestaurantProfile? target;

    // إذا وُجد حساب نشط حالياً، تحقق من الـ PIN الخاص به أولاً
    if (_currentProfile != null) {
      if (_currentProfile!.pinHash == inputHash || (_currentProfile!.pinHash.isEmpty && inputHash == defaultHash)) {
        target = _currentProfile;
      }
    }

    // إذا لم يتطابق، ابحث في الحسابات المحفوظة
    if (target == null) {
      for (final p in _cachedProfiles) {
        if (p.pinHash == inputHash || (p.pinHash.isEmpty && inputHash == defaultHash)) {
          target = p;
          break;
        }
      }
    }

    // إذا كانت القائمة فارغة تماماً ودخل الكاشير بالرمز الافتراضي 0000، نؤسس له حساباً محلياً افتراضياً تلقائياً
    if (target == null && _cachedProfiles.isEmpty && cleanPin == '0000') {
      return await createLocalOfflineRestaurant(
        restaurantName: 'مطعم محلي (أوفلاين)',
        ownerName: 'كاشير المحطة',
        pin: '0000',
      );
    }

    if (target == null) {
      return OfflineAuthResult(
        success: false,
        message: 'رمز PIN غير صحيح. الرمز الافتراضي للنظام هو 0000.',
      );
    }

    _currentProfile = target.copyWith(lastLoginAt: DateTime.now());
    _isOfflineSession = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kActiveSessionKey, true);
    await prefs.setString(_kActiveUidKey, target.uid);
    await _persistProfiles();

    notifyListeners();
    return OfflineAuthResult(
      success: true,
      message: 'تم التحقق بنجاح برمز PIN والدخول لوضع الأوفلاين.',
      profile: _currentProfile,
    );
  }

  /// تأسيس مطعم محلي أوفلاين بالكامل (للمطاعم التي لا تمتلك إنترنت نهائياً)
  Future<OfflineAuthResult> createLocalOfflineRestaurant({
    required String restaurantName,
    required String ownerName,
    String city = 'القائم',
    String pin = '0000',
  }) async {
    if (!_isInitialized) await init();

    final cleanName = restaurantName.trim().isNotEmpty ? restaurantName.trim() : 'مطعم مدار المحلي';
    final cleanOwner = ownerName.trim().isNotEmpty ? ownerName.trim() : 'كاشير مدار';
    final cleanCity = city.trim().isNotEmpty ? city.trim() : 'القائم';
    final pinHash = hashValue(pin.trim().isNotEmpty ? pin.trim() : '0000');
    final uniqueId = 'local_rest_${DateTime.now().millisecondsSinceEpoch}';

    final localProfile = OfflineRestaurantProfile(
      uid: uniqueId,
      email: 'local@madar.pos',
      passwordHash: hashValue('madar_local_pos'),
      restaurantName: cleanName,
      ownerName: cleanOwner,
      city: cleanCity,
      role: 'merchant',
      status: 'approved',
      pinHash: pinHash,
      isLocalOnly: true,
      lastLoginAt: DateTime.now(),
    );

    _cachedProfiles.add(localProfile);
    _currentProfile = localProfile;
    _isOfflineSession = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kActiveSessionKey, true);
    await prefs.setString(_kActiveUidKey, uniqueId);
    await _persistProfiles();

    notifyListeners();
    return OfflineAuthResult(
      success: true,
      message: 'تم تأسيس المطعم المحلي بنجاح والدخول إلى نقطة البيع!',
      profile: localProfile,
    );
  }

  /// تحديث رمز PIN السريع للمطعم الحالي
  Future<bool> updateCashierPin(String newPin) async {
    if (_currentProfile == null) return false;
    final newHash = hashValue(newPin.trim());
    final updated = _currentProfile!.copyWith(pinHash: newHash);

    final idx = _cachedProfiles.indexWhere((p) => p.uid == updated.uid);
    if (idx >= 0) {
      _cachedProfiles[idx] = updated;
    } else {
      _cachedProfiles.add(updated);
    }
    _currentProfile = updated;
    await _persistProfiles();
    notifyListeners();
    return true;
  }

  /// تسجيل الخروج من جلسة الأوفلاين
  Future<void> signOutOffline() async {
    _isOfflineSession = false;
    _currentProfile = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kActiveSessionKey, false);
      await prefs.remove(_kActiveUidKey);
    } catch (_) {}
    notifyListeners();
  }

  /// حفظ قائمة الحسابات في التخزين المحلي
  Future<void> _persistProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listMaps = _cachedProfiles.map((p) => p.toMap()).toList();
      await prefs.setString(_kProfilesKey, jsonEncode(listMaps));
    } catch (e) {
      debugPrint('[OfflineAuthService] Persist error: $e');
    }
  }
}
