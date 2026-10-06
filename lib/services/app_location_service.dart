import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, ChangeNotifier, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';
import 'package:dalal_alqaim/widgets/location_selector_widget.dart';
import 'package:dalal_alqaim/core/location_permission_helper.dart'; // Added helper import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dalal_alqaim/core/location/iraq_location_resolver.dart';

/// أسباب فشل الكشف التلقائي عن الموقع
enum LocationFailureReason {
  none,
  /// خدمة الموقع (GPS) غير مفعلة على الجهاز
  serviceDisabled,
  /// المستخدم رفض إذن الموقع
  permissionDenied,
  /// المستخدم رفض إذن الموقع نهائياً
  permissionDeniedForever,
  /// انتهت مهلة الحصول على الموقع
  timeout,
  /// لم يُطابق الموقع أي محافظة مسجلة في النظام
  noMatchFound,
  /// لم يتم التعرف على العنوان من الإحداثيات
  geocodingFailed,
  /// خطأ غير متوقع
  unknownError,
}

class AppLocation {
  final String? governorateId;
  final String? governorateName;
  final String? regionId;
  final String? regionName;

  AppLocation({this.governorateId, this.governorateName, this.regionId, this.regionName});

  bool get isAllIraq => governorateId == null;

  String get displayName {
    if (isAllIraq) return 'كل العراق';
    if (regionName != null && governorateName != null) {
      return '$governorateName - $regionName';
    }
    return governorateName ?? 'موقع غير معروف';
  }
}

class AppLocationService extends ChangeNotifier {
  static final AppLocationService _instance = AppLocationService._internal();
  factory AppLocationService() => _instance;
  AppLocationService._internal();

  AppLocation _currentLocation = AppLocation();
  AppLocation get currentLocation => _currentLocation;

  bool _isDetecting = false;
  bool get isDetecting => _isDetecting;

  /// سبب فشل آخر محاولة كشف تلقائي
  LocationFailureReason _lastFailureReason = LocationFailureReason.none;
  LocationFailureReason get lastFailureReason => _lastFailureReason;

  /// رسالة الخطأ التفصيلية (مثل exception message)
  String _lastErrorDetail = '';
  String get lastErrorDetail => _lastErrorDetail;

  /// هل تمت المحاولة من قبل؟
  bool _hasAttemptedDetection = false;
  bool get hasAttemptedDetection => _hasAttemptedDetection;

  /// مسح حالة الفشل
  void clearFailure() {
    _lastFailureReason = LocationFailureReason.none;
    _lastErrorDetail = '';
    notifyListeners();
  }

  static const String _keyGovId = 'user_gov_id';
  static const String _keyGovName = 'user_gov_name';
  static const String _keyRegId = 'user_reg_id';
  static const String _keyRegName = 'user_reg_name';
  static const String _keyGovCache = 'gov_regions_cache';
  static const String _keyCacheTime = 'gov_cache_time';
  static const String _keyGovUsage = 'gov_usage_counts';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final govId = prefs.getString(_keyGovId);
    final govName = prefs.getString(_keyGovName);
    final regId = prefs.getString(_keyRegId);
    final regName = prefs.getString(_keyRegName);

    _currentLocation = AppLocation(
      governorateId: govId,
      governorateName: govName,
      regionId: regId,
      regionName: regName,
    );
    notifyListeners();
  }

  Future<void> setLocation({
    String? governorateId,
    String? governorateName,
    String? regionId,
    String? regionName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (governorateId == null) {
      await prefs.remove(_keyGovId);
      await prefs.remove(_keyGovName);
      await prefs.remove(_keyRegId);
      await prefs.remove(_keyRegName);
    } else {
      await prefs.setString(_keyGovId, governorateId);
      await prefs.setString(_keyGovName, governorateName ?? 'موقع غير معروف');
      if (regionId != null) {
        await prefs.setString(_keyRegId, regionId);
        await prefs.setString(_keyRegName, regionName ?? '');
      } else {
        await prefs.remove(_keyRegId);
        await prefs.remove(_keyRegName);
      }
    }

    _currentLocation = AppLocation(
      governorateId: governorateId,
      governorateName: governorateName,
      regionId: regionId,
      regionName: regionName,
    );

    // تحديث عداد الاستخدام للترتيب الذكي
    if (governorateId != null) {
      incrementUsageCount(governorateId);
    }

    notifyListeners();
  }

  Future<void> clearLocation() async {
    await setLocation(governorateId: null);
  }

  static const Map<String, String> _englishToArabicGovs = {
    'baghdad': 'بغداد',
    'basra': 'البصرة',
    'basrah': 'البصرة',
    'ninawa': 'نينوى',
    'nineveh': 'نينوى',
    'erbil': 'أربيل',
    'arbil': 'أربيل',
    'sulaymaniyah': 'السليمانية',
    'sulaimaniyah': 'السليمانية',
    'kirkuk': 'كركوك',
    'babylon': 'بابل',
    'babil': 'بابل',
    'najaf': 'النجف',
    'karbala': 'كربلاء',
    'kerbala': 'كربلاء',
    'dhi qar': 'ذي قار',
    'thi qar': 'ذي قار',
    'anbar': 'الأنبار',
    'al anbar': 'الأنبار',
    'diyala': 'ديالى',
    'muthanna': 'المثنى',
    'al muthanna': 'المثنى',
    'qadisiyah': 'القادسية',
    'al qadisiyah': 'القادسية',
    'diwaniyah': 'القادسية',
    'maysan': 'ميسان',
    'maisan': 'ميسان',
    'wasit': 'واسط',
    'salah al-din': 'صلاح الدين',
    'salah ad-din': 'صلاح الدين',
    'salahuddin': 'صلاح الدين',
    'dahuk': 'دهوك',
    'dohuk': 'دهوك',
    'halabja': 'حلبجة',
  };

  String _translateEnglishToArabicGov(String input) {
    final cleaned = input.trim().toLowerCase();
    for (var entry in _englishToArabicGovs.entries) {
      if (cleaned.contains(entry.key)) {
        return entry.value;
      }
    }
    return input;
  }

  /// تطبيع النص العربي للمقارنة — يزيل التشكيل والفروقات الإملائية
  static String normalize(String text) {
    return text
        .replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670]'), '') // حذف التشكيل
        .replaceAll(' ', '')
        .replaceAll('ال', '')
        .replaceAll('ة', 'ه')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ى', 'ي')
        .toLowerCase();
  }

  // Alias for internal use
  String _normalize(String text) => normalize(text);

  /// Levenshtein Distance — مسافة التحرير بين نصين
  static int levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    if (a == b) return 0;

    final la = a.length;
    final lb = b.length;

    // تحسين: استخدام صف واحد بدل مصفوفة كاملة O(min(m,n)) memory
    List<int> prev = List.generate(lb + 1, (i) => i);
    List<int> curr = List.filled(lb + 1, 0);

    for (int i = 1; i <= la; i++) {
      curr[0] = i;
      for (int j = 1; j <= lb; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1, // حذف
          curr[j - 1] + 1, // إضافة
          prev[j - 1] + cost, // استبدال
        ].reduce((a, b) => a < b ? a : b);
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }
    return prev[lb];
  }

  /// Fuzzy Match Score — نسبة التطابق من 0.0 إلى 1.0
  static double fuzzyMatchScore(String query, String target) {
    final nq = normalize(query);
    final nt = normalize(target);
    if (nq.isEmpty || nt.isEmpty) return 0;
    if (nq == nt) return 1.0;
    if (nt.contains(nq) || nq.contains(nt)) return 0.85;

    final maxLen = nq.length > nt.length ? nq.length : nt.length;
    final dist = levenshteinDistance(nq, nt);
    final score = 1.0 - (dist / maxLen);
    return score < 0 ? 0 : score;
  }

  /// زيادة عداد استخدام محافظة
  Future<void> incrementUsageCount(String govId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyGovUsage) ?? '{}';
      final Map<String, dynamic> counts = Map<String, dynamic>.from(jsonDecode(raw));
      counts[govId] = (counts[govId] as int? ?? 0) + 1;
      await prefs.setString(_keyGovUsage, jsonEncode(counts));
    } catch (e) {
      debugPrint(' Usage count error: $e');
    }
  }

  /// جلب عدادات استخدام المحافظات
  Future<Map<String, int>> getUsageCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyGovUsage) ?? '{}';
      final Map<String, dynamic> decoded = Map<String, dynamic>.from(jsonDecode(raw));
      return decoded.map((k, v) => MapEntry(k, v as int? ?? 0));
    } catch (e) {
      debugPrint(' Usage counts read error: $e');
      return {};
    }
  }

  /// يجلب بيانات المحافظات والمناطق من الكاش أو Firestore (استعلام واحد مدمج)
  Future<List<Map<String, dynamic>>> _getGovernorateCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_keyGovCache);
    final cacheTimeMs = prefs.getInt(_keyCacheTime) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // استخدام الكاش إذا كان أحدث من 24 ساعة
    if (cached != null && (now - cacheTimeMs) < 86400000) {
      try {
        final List<dynamic> decoded = jsonDecode(cached);
        return decoded.cast<Map<String, dynamic>>();
      } catch (_) {
        // كاش تالف — إعادة الجلب
      }
    }

    // جلب كل المحافظات مع مناطقها في استعلامين فقط (بدلاً من N+1)
    final govsSnap = await FirebaseFirestore.instance
        .collection('governorates')
        .where('isActive', isEqualTo: true)
        .get()
        .timeout(const Duration(seconds: 5));

    final List<Map<String, dynamic>> result = [];

    // جلب كل المناطق بالتوازي
    final regionFutures = govsSnap.docs.map((govDoc) async {
      final govData = govDoc.data();
      final regionsSnap = await govDoc.reference
          .collection('regions')
          .where('isActive', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 4));

      final regions =
          regionsSnap.docs.map((r) => {'id': r.id, 'name': r.data()['name'] ?? ''}).toList();

      return {'id': govDoc.id, 'name': govData['name'] ?? '', 'regions': regions};
    });

    result.addAll(await Future.wait(regionFutures));

    // تخزين في الكاش
    try {
      await prefs.setString(_keyGovCache, jsonEncode(result));
      await prefs.setInt(_keyCacheTime, now);
    } catch (_) {}

    return result;
  }

  Future<void> autoDetectLocation([BuildContext? context, bool forceRefresh = false]) async {
    // إذا كان الموقع محفوظ مسبقاً ولم يُطلب تحديث — لا حاجة للكشف من جديد
    if (_currentLocation.governorateId != null && !forceRefresh) {
      debugPrint(' AutoDetect: Location already cached, skipping.');
      return;
    }

    if (forceRefresh) {
      debugPrint(' AutoDetect: Force refresh requested, clearing cached location...');
    }

    if (_isDetecting) return;
    _isDetecting = true;
    _lastFailureReason = LocationFailureReason.none;
    _lastErrorDetail = '';
    _hasAttemptedDetection = true;
    notifyListeners();

    try {
      // ── 1. فحص خدمة GPS ──
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint(' AutoDetect: Location services are disabled.');
        _lastFailureReason = LocationFailureReason.serviceDisabled;
        if (context != null && context.mounted) _showFailureDialog(context, _lastFailureReason);
        return;
      }

      // ── 2. فحص وطلب الأذونات ──
      if (context != null && context.mounted) {
        bool hasPermission = await LocationPermissionHelper.requestLocationPermissionWithDisclosure(
          context,
        );
        if (!hasPermission) {
          debugPrint(' AutoDetect: Permission denied via helper.');
          // تحديد نوع الرفض بدقة
          final permStatus = await Permission.locationWhenInUse.status;
          if (permStatus.isPermanentlyDenied) {
            _lastFailureReason = LocationFailureReason.permissionDeniedForever;
          } else {
            _lastFailureReason = LocationFailureReason.permissionDenied;
          }
          if (context.mounted) _showFailureDialog(context, _lastFailureReason);
          return;
        }
      } else {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            debugPrint(' AutoDetect: Permission denied.');
            _lastFailureReason = LocationFailureReason.permissionDenied;
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          debugPrint(' AutoDetect: Permission denied forever.');
          _lastFailureReason = LocationFailureReason.permissionDeniedForever;
          return;
        }
      }

      // ── 3. الحصول على الموقع الحالي (دائماً getCurrentPosition أولاً) ──
      Position? pos;
      try {
        // دائماً نطلب الموقع الحالي الفعلي لتجنب مواقع مخبأة قديمة
        debugPrint(' AutoDetect: Requesting fresh current position...');
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        debugPrint(' AutoDetect: Got position: ${pos.latitude}, ${pos.longitude}');
      } on TimeoutException {
        // في حالة timeout، نحاول getLastKnownPosition كـ fallback
        debugPrint(' AutoDetect: Position request timed out, trying last known...');
        pos = kIsWeb ? null : await Geolocator.getLastKnownPosition();
        if (pos == null) {
          _lastFailureReason = LocationFailureReason.timeout;
          if (context != null && context.mounted) _showFailureDialog(context, _lastFailureReason);
          return;
        }
        debugPrint(' AutoDetect: Using last known position: ${pos.latitude}, ${pos.longitude}');
      } catch (e) {
        debugPrint(' AutoDetect: Position error: $e');
        // محاولة أخيرة مع getLastKnownPosition
        try {
          pos = kIsWeb ? null : await Geolocator.getLastKnownPosition();
        } catch (_) {}
        if (pos == null) {
          if (e.toString().contains('timeout') || e.toString().contains('TimeLimit')) {
            _lastFailureReason = LocationFailureReason.timeout;
          } else {
            _lastFailureReason = LocationFailureReason.unknownError;
            _lastErrorDetail = e.toString();
          }
          if (context != null && context.mounted) _showFailureDialog(context, _lastFailureReason);
          return;
        }
      }

      // ── 4. تحويل الإحداثيات إلى محافظة وقضاء عبر IraqLocationResolver ──
      try {
        final iraqResult = await IraqLocationResolver().resolveFromCoordinates(
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracy: pos.accuracy,
        );

        if (iraqResult.governorate != null) {
          debugPrint(' Detected Location via IraqLocationResolver: ${iraqResult.governorate} - ${iraqResult.district}');
          _lastFailureReason = LocationFailureReason.none;
          await setLocation(
            governorateId: iraqResult.governorateId ?? iraqResult.governorate,
            governorateName: iraqResult.governorate,
            regionId: iraqResult.district,
            regionName: iraqResult.district,
          );
          return;
        }
      } catch (e) {
        debugPrint(' IraqLocationResolver step error: $e');
      }

      // ── 5. محاولة مكملة عبر الكاش وقواعد بيانات المحافظات ──
      final results = await Future.wait([
        placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        ).timeout(const Duration(seconds: 4), onTimeout: () => []),
        _getGovernorateCachedData(),
      ]);

      final placemarks = results[0] as List<Placemark>;
      final govData = results[1] as List<Map<String, dynamic>>;

      if (placemarks.isEmpty) {
        debugPrint(' AutoDetect: Geocoding returned empty placemarks.');
        _lastFailureReason = LocationFailureReason.geocodingFailed;
        if (context != null && context.mounted) _showFailureDialog(context, _lastFailureReason);
        return;
      }

      final place = placemarks.first;
      final rawArea = place.administrativeArea ?? '';
      final rawCity = place.locality ?? '';
      final rawSubLocality = place.subLocality ?? '';
      final rawNameInPlacemark = place.name ?? '';

      final area = _translateEnglishToArabicGov(rawArea);
      final city = _translateEnglishToArabicGov(rawCity);
      final subLocality = _translateEnglishToArabicGov(rawSubLocality);
      final nameInPlacemark = _translateEnglishToArabicGov(rawNameInPlacemark);

      debugPrint('--- Advanced Location Detection Debug ---');
      debugPrint('Area: $area (raw: $rawArea), City: $city (raw: $rawCity), Sub: $subLocality (raw: $rawSubLocality), Name: $nameInPlacemark (raw: $rawNameInPlacemark)');

      final nArea = _normalize(area);
      final nCity = _normalize(city);
      final nSub = _normalize(subLocality);
      final nName = _normalize(nameInPlacemark);

      String? bestGovId;
      String? bestGovName;
      String? bestRegId;
      String? bestRegName;
      int maxConfidence = -1;

      for (var gov in govData) {
        final govName = gov['name'] as String;
        final nGov = _normalize(govName);
        final regions = gov['regions'] as List<dynamic>;

        // Level 1: مقارنة المناطق (أعلى دقة)
        for (var reg in regions) {
          final regName = reg['name'] as String;
          final nReg = _normalize(regName);

          int confidence = -1;
          if (nSub.isNotEmpty && nReg.isNotEmpty) {
            if (nSub == nReg) {
              confidence = 100;
            } else if (nSub.contains(nReg) || nReg.contains(nSub)) {
              confidence = 70;
            }
          }
          if (confidence < 0 && nCity.isNotEmpty && nReg.isNotEmpty) {
            if (nCity == nReg) {
              confidence = 90;
            } else if (nCity.contains(nReg) || nReg.contains(nCity)) {
              confidence = 60;
            }
          }
          if (confidence < 0 && nName.isNotEmpty && nReg.isNotEmpty) {
            if (nName == nReg) {
              confidence = 80;
            } else if (nName.contains(nReg) || nReg.contains(nName)) {
              confidence = 50;
            }
          }

          if (confidence > maxConfidence) {
            maxConfidence = confidence;
            bestGovId = gov['id'] as String;
            bestGovName = govName;
            bestRegId = reg['id'] as String;
            bestRegName = regName;
          }
        }

        // Level 2: مقارنة المحافظة نفسها
        if (maxConfidence < 40) {
          int govConf = -1;
          if (nArea.isNotEmpty && nGov.isNotEmpty) {
            if (nArea == nGov) {
              govConf = 40;
            } else if (nArea.contains(nGov) || nGov.contains(nArea)) {
              govConf = 30;
            }
          }
          if (govConf < 0 && nCity.isNotEmpty && nGov.isNotEmpty) {
            if (nCity.contains(nGov) || nGov.contains(nCity)) {
              govConf = 20;
            }
          }

          if (govConf > maxConfidence) {
            maxConfidence = govConf;
            bestGovId = gov['id'] as String;
            bestGovName = govName;
            bestRegId = null;
            bestRegName = null;
          }
        }
      }

      if (bestGovId != null) {
        debugPrint('Detected Location with confidence $maxConfidence: $bestGovName - $bestRegName');
        _lastFailureReason = LocationFailureReason.none;
        await setLocation(
          governorateId: bestGovId,
          governorateName: bestGovName,
          regionId: bestRegId,
          regionName: bestRegName,
        );
      } else {
        debugPrint('No location match found above threshold.');
        _lastFailureReason = LocationFailureReason.noMatchFound;
        _lastErrorDetail = 'المنطقة: $area, المدينة: $city';
        if (context != null && context.mounted) _showFailureDialog(context, _lastFailureReason);
      }
    } catch (e) {
      debugPrint('Auto detect location error: $e');
      _lastFailureReason = LocationFailureReason.unknownError;
      _lastErrorDetail = e.toString();
    } finally {
      _isDetecting = false;
      notifyListeners();
    }
  }

  void _showFailureDialog(BuildContext context, LocationFailureReason reason) {
    String title;
    String content;
    String actionText;
    VoidCallback onAction;

    switch (reason) {
      case LocationFailureReason.serviceDisabled:
        title = 'تفعيل خدمة الموقع (GPS)';
        content = 'لكي نتمكن من تحديد موقعك وتوفير أقرب الخدمات إليك، يرجى تفعيل خدمة الـ GPS من إعدادات جهازك.';
        actionText = 'الذهاب للإعدادات';
        onAction = () {
          Navigator.pop(context);
          Geolocator.openLocationSettings();
        };
        break;
      case LocationFailureReason.permissionDenied:
      case LocationFailureReason.permissionDeniedForever:
        title = 'صلاحية الوصول للموقع';
        content = 'التطبيق يحتاج إلى إذن الوصول للموقع لتحديد منطقتك. يرجى تفعيل الإذن من إعدادات التطبيق لتجربة أفضل.';
        actionText = 'إعدادات الأذونات';
        onAction = () {
          Navigator.pop(context);
          Geolocator.openAppSettings();
        };
        break;
      case LocationFailureReason.timeout:
      case LocationFailureReason.geocodingFailed:
      case LocationFailureReason.unknownError:
        title = 'فشل تحديد الموقع';
        content = 'حدث خطأ أثناء محاولة تحديد موقعك (قد يكون بسبب ضعف الإشارة). هل تود المحاولة مجدداً أو تحديد موقعك يدوياً؟';
        actionText = 'حاول مرة ثانية';
        onAction = () {
          Navigator.pop(context);
          autoDetectLocation(context);
        };
        break;
      case LocationFailureReason.noMatchFound:
        title = 'موقع خارج التغطية';
        content = 'لم نتمكن من مطابقة موقعك الحالي مع المحافظات المدعومة. يرجى اختيار الموقع يدوياً من القائمة.';
        actionText = 'تحديد يدوياً';
        onAction = () {
          Navigator.pop(context);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const LocationSelectorWidget(),
          );
        };
        break;
      default:
        return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.location_off_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
        content: Text(content, style: const TextStyle(fontSize: 14)),
        actions: [
          if (reason != LocationFailureReason.noMatchFound)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const LocationSelectorWidget(),
                );
              },
              child: const Text('أو حدد يدوياً', style: TextStyle(color: Colors.grey)),
            ),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(actionText, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
