import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dalal_alqaim/services/google_maps_service.dart';

/// نتيجة فك وتحديد الموقع الإداري داخل العراق
class IraqLocationResult {
  final double latitude;
  final double longitude;
  final String country;
  final String? governorate;
  final String? governorateId;
  final String? district;
  final String? area;
  final String formattedAddress;
  final double? accuracy;
  final bool isAccurate;
  final bool isWithinIraq;

  const IraqLocationResult({
    required this.latitude,
    required this.longitude,
    this.country = 'العراق',
    this.governorate,
    this.governorateId,
    this.district,
    this.area,
    required this.formattedAddress,
    this.accuracy,
    this.isAccurate = true,
    this.isWithinIraq = true,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  /// اسم العرض الهرمي المرتب (محافظة - قضاء - منطقة)
  String get displayName {
    final parts = <String>[];
    if (governorate != null && governorate!.isNotEmpty) {
      parts.add(governorate!);
    }
    if (district != null && district!.isNotEmpty && district != governorate) {
      parts.add(district!);
    }
    if (area != null && area!.isNotEmpty && area != district) {
      parts.add(area!);
    }
    if (parts.isEmpty) {
      return formattedAddress.isNotEmpty ? formattedAddress : 'موقع غير معروف';
    }
    return parts.join(' - ');
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'country': country,
      'governorate': governorate,
      'governorateId': governorateId,
      'district': district,
      'area': area,
      'formattedAddress': formattedAddress,
      'accuracy': accuracy,
      'isAccurate': isAccurate,
      'isWithinIraq': isWithinIraq,
    };
  }

  @override
  String toString() =>
      'IraqLocationResult(lat: $latitude, lng: $longitude, gov: $governorate, district: $district, area: $area, accurate: $isAccurate)';
}

/// محرك حل الموقع الجغرافي والإداري لجمهورية العراق
/// (Iraq Location Resolver & Administrative Hierarchy Engine)
class IraqLocationResolver {
  static final IraqLocationResolver _instance = IraqLocationResolver._internal();
  factory IraqLocationResolver() => _instance;
  IraqLocationResolver._internal();

  /// حدود العراق الجغرافية التقريبية (Iraq Bounding Box)
  static const double minLat = 29.0;
  static const double maxLat = 37.5;
  static const double minLng = 38.5;
  static const double maxLng = 48.8;

  /// قائمة المحافظات الـ 18 الرسمية مع معرّفاتها وأسمائها العربية والإنجليزية
  static const Map<String, ({String id, String arName, List<String> aliases})> governorates = {
    'anbar': (
      id: 'anbar',
      arName: 'الأنبار',
      aliases: ['anbar', 'al anbar', 'al-anbar', 'ramadi', 'الانبار', 'الأنبار'],
    ),
    'baghdad': (
      id: 'baghdad',
      arName: 'بغداد',
      aliases: ['baghdad', 'bagdad', 'بغداد', 'مدينة بغداد'],
    ),
    'basra': (
      id: 'basra',
      arName: 'البصرة',
      aliases: ['basra', 'basrah', 'al basrah', 'البصرة', 'البصره'],
    ),
    'ninawa': (
      id: 'ninawa',
      arName: 'نينوى',
      aliases: ['ninawa', 'nineveh', 'mosul', 'نينوى', 'الموصل'],
    ),
    'erbil': (
      id: 'erbil',
      arName: 'أربيل',
      aliases: ['erbil', 'arbil', 'hawler', 'اربيل', 'أربيل', 'هولير'],
    ),
    'sulaymaniyah': (
      id: 'sulaymaniyah',
      arName: 'السليمانية',
      aliases: ['sulaymaniyah', 'sulaimaniyah', 'slemani', 'السليمانية', 'السليمانيه'],
    ),
    'duhok': (
      id: 'duhok',
      arName: 'دهوك',
      aliases: ['duhok', 'dohuk', 'dahuk', 'دهوك'],
    ),
    'kirkuk': (
      id: 'kirkuk',
      arName: 'كركوك',
      aliases: ['kirkuk', 'كركوك'],
    ),
    'salah_al_din': (
      id: 'salah_al_din',
      arName: 'صلاح الدين',
      aliases: ['salah al-din', 'salah ad-din', 'salahuddin', 'saladin', 'صلاح الدين', 'تكريت'],
    ),
    'diyala': (
      id: 'diyala',
      arName: 'ديالى',
      aliases: ['diyala', 'ديالى', 'ديالي', 'بعقوبة'],
    ),
    'babil': (
      id: 'babil',
      arName: 'بابل',
      aliases: ['babil', 'babylon', 'بابل', 'الحلة', 'الحله'],
    ),
    'karbala': (
      id: 'karbala',
      arName: 'كربلاء',
      aliases: ['karbala', 'kerbala', 'كربلاء', 'كربلاء المقدسة'],
    ),
    'najaf': (
      id: 'najaf',
      arName: 'النجف',
      aliases: ['najaf', 'an najaf', 'النجف', 'النجف الأشرف'],
    ),
    'qadisiyah': (
      id: 'qadisiyah',
      arName: 'القادسية',
      aliases: ['qadisiyah', 'al qadisiyah', 'diwaniyah', 'القادسية', 'الديوانية'],
    ),
    'muthanna': (
      id: 'muthanna',
      arName: 'المثنى',
      aliases: ['muthanna', 'al muthanna', 'samawah', 'المثنى', 'السماوة'],
    ),
    'dhi_qar': (
      id: 'dhi_qar',
      arName: 'ذي قار',
      aliases: ['dhi qar', 'thi qar', 'nasiriyah', 'ذي قار', 'الناصرية'],
    ),
    'maysan': (
      id: 'maysan',
      arName: 'ميسان',
      aliases: ['maysan', 'maisan', 'amarah', 'ميسان', 'العمارة'],
    ),
    'wasit': (
      id: 'wasit',
      arName: 'واسط',
      aliases: ['wasit', 'kut', 'واسط', 'الكوت'],
    ),
    'halabja': (
      id: 'halabja',
      arName: 'حلبجة',
      aliases: ['halabja', 'حلبجة', 'حلبجه'],
    ),
  };

  /// الأقضية والمناطق الإدارية المعروفة داخل العراق
  static const Map<String, String> knownDistrictsToGov = {
    // الأنبار
    'القائم': 'anbar',
    'الرمادي': 'anbar',
    'الفلوجة': 'anbar',
    'هيت': 'anbar',
    'حديثة': 'anbar',
    'عنه': 'anbar',
    'عنة': 'anbar',
    'راوه': 'anbar',
    'راوة': 'anbar',
    'الرطبة': 'anbar',
    'الكرمة': 'anbar',
    'الخالدية': 'anbar',
    'البغدادي': 'anbar',
    'الحبانية': 'anbar',
    'al-qaim': 'anbar',
    'alqaim': 'anbar',
    'al qaim': 'anbar',
    'ramadi': 'anbar',
    'fallujah': 'anbar',
    'hit': 'anbar',
    'haditha': 'anbar',
    // بغداد
    'الكرخ': 'baghdad',
    'الرصافة': 'baghdad',
    'الكاظمية': 'baghdad',
    'الأعظمية': 'baghdad',
    'المنصور': 'baghdad',
    'الكرادة': 'baghdad',
    'الدورة': 'baghdad',
    'مدينة الصدر': 'baghdad',
    'المحمودية': 'baghdad',
    'التاجي': 'baghdad',
    'أبو غريب': 'baghdad',
    'المدائن': 'baghdad',
    'karkh': 'baghdad',
    'rusafa': 'baghdad',
    'mansour': 'baghdad',
    'karrada': 'baghdad',
    // البصرة
    'الزبير': 'basra',
    'شط العرب': 'basra',
    'القرنة': 'basra',
    'الفاو': 'basra',
    'أبو الخصيب': 'basra',
    'المدينة': 'basra',
    'الهوير': 'basra',
    'zubair': 'basra',
    'qurna': 'basra',
    'faw': 'basra',
    // نينوى
    'الموصل': 'ninawa',
    'تلعفر': 'ninawa',
    'سنجار': 'ninawa',
    'الحمدانية': 'ninawa',
    'الشيخان': 'ninawa',
    'تلكيف': 'ninawa',
    'الحضر': 'ninawa',
    'مخمور': 'ninawa',
    'mosul': 'ninawa',
    'sinjar': 'ninawa',
    // أربيل
    'أربيل': 'erbil',
    'شقلاوة': 'erbil',
    'سوران': 'erbil',
    'كويه': 'erbil',
    'رواندوز': 'erbil',
    'خبات': 'erbil',
    // كركوك
    'كركوك': 'kirkuk',
    'الحويجة': 'kirkuk',
    'داقوق': 'kirkuk',
    'الدبس': 'kirkuk',
    // النجف
    'النجف': 'najaf',
    'الكوفة': 'najaf',
    'المناذرة': 'najaf',
    'المشخاب': 'najaf',
    'kufa': 'najaf',
    // كربلاء
    'كربلاء': 'karbala',
    'عين التمر': 'karbala',
    'الهندية': 'karbala',
    'طويريج': 'karbala',
    // بابل
    'الحلة': 'babil',
    'المسيب': 'babil',
    'المحاويل': 'babil',
    'الهاشمية': 'babil',
    'hillah': 'babil',
  };

  /// هل تقع الإحداثيات داخل العراق؟
  static bool isCoordinatesInIraq(double lat, double lng) {
    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }

  /// تطبيع النص للمقارنة
  static String normalize(String text) {
    return text
        .trim()
        .replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670]'), '')
        .replaceAll('ال', '')
        .replaceAll('ة', 'ه')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ى', 'ي')
        .replaceAll(' ', '')
        .toLowerCase();
  }

  /// مطابقة اسم المحافظة من أي نص أو تصنيف جغرافي
  static ({String id, String arName})? matchGovernorate(String text) {
    final cleaned = text.trim().toLowerCase();
    final norm = normalize(cleaned);

    for (final gov in governorates.values) {
      for (final alias in gov.aliases) {
        if (cleaned.contains(alias.toLowerCase()) || norm.contains(normalize(alias))) {
          return (id: gov.id, arName: gov.arName);
        }
      }
    }
    return null;
  }

  /// مطابقة اسم القضاء
  static String? matchDistrict(String text) {
    final cleaned = text.trim();
    final norm = normalize(cleaned);

    for (final entry in knownDistrictsToGov.entries) {
      if (cleaned.contains(entry.key) || norm == normalize(entry.key)) {
        return entry.key;
      }
    }
    return null;
  }

  /// فك التشفير الهرمي الكامل للإحداثيات الحقيقية
  /// لا يعتمد على أي قيمة افتراضية؛ إذا لم يعرف القضاء يتركه null
  Future<IraqLocationResult> resolveFromCoordinates({
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    final inIraq = isCoordinatesInIraq(latitude, longitude);
    final location = LatLng(latitude, longitude);

    String? detectedGov;
    String? detectedGovId;
    String? detectedDistrict;
    String? detectedArea;
    String? fullAddress;

    // ── 1. محاولة Reverse Geocode عبر GoogleMapsService المركزية ──
    try {
      final regional = await GoogleMapsService.instance.getRegionalDetails(location);
      if (regional.governorate != null) {
        final matched = matchGovernorate(regional.governorate!);
        if (matched != null) {
          detectedGov = matched.arName;
          detectedGovId = matched.id;
        } else {
          detectedGov = regional.governorate;
        }
      }

      if (regional.city != null && regional.city!.isNotEmpty) {
        detectedDistrict = matchDistrict(regional.city!) ?? regional.city;
      }

      if (regional.district != null && regional.district!.isNotEmpty) {
        detectedArea = regional.district;
      }
    } catch (e) {
      debugPrint(' IraqLocationResolver: Google regional geocoding failed: $e');
    }

    // ── 2. محاولة مكملة عبر native Placemark ──
    try {
      final placemarks = await geo.placemarkFromCoordinates(
        latitude,
        longitude,
      ).timeout(const Duration(seconds: 4), onTimeout: () => []);

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        // فحص المحافظة إذا لم تكن مكتشفة
        if (detectedGov == null && p.administrativeArea != null) {
          final matched = matchGovernorate(p.administrativeArea!);
          if (matched != null) {
            detectedGov = matched.arName;
            detectedGovId = matched.id;
          }
        }

        // فحص القضاء / المدينة
        if (detectedDistrict == null) {
          final candidate = p.subAdministrativeArea ?? p.locality ?? p.subLocality;
          if (candidate != null && candidate.isNotEmpty) {
            detectedDistrict = matchDistrict(candidate) ?? candidate;
          }
        }

        // فحص المنطقة أو الحي
        if (detectedArea == null) {
          final candidate = p.subLocality ?? p.thoroughfare ?? p.street;
          if (candidate != null && candidate.isNotEmpty && candidate != detectedDistrict) {
            detectedArea = candidate;
          }
        }

        // تجميع العنوان الكامل المقروء
        final addressParts = <String>[];
        if (p.street != null && p.street!.trim().isNotEmpty && !p.street!.contains('+')) {
          addressParts.add(p.street!.trim());
        }
        if (p.subLocality != null && p.subLocality!.trim().isNotEmpty) {
          addressParts.add(p.subLocality!.trim());
        }
        if (p.locality != null && p.locality!.trim().isNotEmpty) {
          addressParts.add(p.locality!.trim());
        }
        if (p.administrativeArea != null && p.administrativeArea!.trim().isNotEmpty) {
          addressParts.add(p.administrativeArea!.trim());
        }
        if (addressParts.isNotEmpty) {
          fullAddress = addressParts.join('، ');
        }
      }
    } catch (e) {
      debugPrint(' IraqLocationResolver: Native placemark geocoding failed: $e');
    }

    // مطابقة عكسية للقضاء لمعرفة المحافظة إن كانت غير محددة بعد
    if (detectedGov == null && detectedDistrict != null) {
      final govIdFromDistrict = knownDistrictsToGov[detectedDistrict] ??
          knownDistrictsToGov[normalize(detectedDistrict)];
      if (govIdFromDistrict != null) {
        final gov = governorates[govIdFromDistrict];
        if (gov != null) {
          detectedGov = gov.arName;
          detectedGovId = gov.id;
        }
      }
    }

    final isAccurate = (accuracy == null) || (accuracy <= 65.0);

    return IraqLocationResult(
      latitude: latitude,
      longitude: longitude,
      country: inIraq ? 'العراق' : 'خارج العراق',
      governorate: detectedGov,
      governorateId: detectedGovId,
      district: detectedDistrict,
      area: detectedArea,
      formattedAddress: fullAddress ??
          (detectedDistrict != null
              ? '$detectedGov - $detectedDistrict'
              : (detectedGov ?? '$latitude, $longitude')),
      accuracy: accuracy,
      isAccurate: isAccurate,
      isWithinIraq: inIraq,
    );
  }

  /// التقاط موقع GPS الحقيقي للجهاز مع فحص الخدمة والصلاحيات والدقة
  Future<IraqLocationResult?> getCurrentDeviceLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 8),
  }) async {
    try {
      // 1. فحص خدمة GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint(' IraqLocationResolver: GPS service disabled on device');
        return null;
      }

      // 2. فحص الصلاحيات
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint(' IraqLocationResolver: Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(' IraqLocationResolver: Location permission permanently denied');
        return null;
      }

      // 3. طلب الموقع الحالي الحقيقي والحديث
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeLimit,
      );

      debugPrint(
        ' IraqLocationResolver: Real GPS fix obtained: ${pos.latitude}, ${pos.longitude} (accuracy: ${pos.accuracy}m)',
      );

      return await resolveFromCoordinates(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
      );
    } catch (e) {
      debugPrint(' IraqLocationResolver: Failed to acquire real GPS: $e');
      return null;
    }
  }
}
