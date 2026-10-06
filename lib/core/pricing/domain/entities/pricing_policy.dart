import 'package:flutter/foundation.dart';
import '../enums/pricing_enums.dart';

/// فترة الذروة الزمنية
@immutable
class PeakPeriod {
  final int startHour; // 0 - 23
  final int startMinute;
  final int endHour;
  final int endMinute;
  final double multiplier; // e.g. 1.2
  final List<int> applicableDays; // 1 (Mon) - 7 (Sun)
  final bool isEnabled;

  const PeakPeriod({
    required this.startHour,
    this.startMinute = 0,
    required this.endHour,
    this.endMinute = 0,
    this.multiplier = 1.2,
    this.applicableDays = const [1, 2, 3, 4, 5, 6, 7],
    this.isEnabled = true,
  });

  /// التحقق مما إذا كان الوقت المعطى يقع ضمن فترة الذروة
  bool isWithinPeak(DateTime time) {
    if (!isEnabled) return false;
    if (!applicableDays.contains(time.weekday)) return false;

    final currentMinutes = time.hour * 60 + time.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    // التعامل مع الفترات التي تعبر منتصف الليل (Midnight Crossing)
    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'multiplier': multiplier,
      'applicableDays': applicableDays,
      'isEnabled': isEnabled,
    };
  }

  factory PeakPeriod.fromMap(Map<String, dynamic> map) {
    return PeakPeriod(
      startHour: (map['startHour'] as num?)?.toInt() ?? 0,
      startMinute: (map['startMinute'] as num?)?.toInt() ?? 0,
      endHour: (map['endHour'] as num?)?.toInt() ?? 0,
      endMinute: (map['endMinute'] as num?)?.toInt() ?? 0,
      multiplier: (map['multiplier'] as num?)?.toDouble() ?? 1.0,
      applicableDays: (map['applicableDays'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [1, 2, 3, 4, 5, 6, 7],
      isEnabled: map['isEnabled'] != false,
    );
  }
}

/// سياسة التسعير الموثقة والإصدارية (Versioned Pricing Policy)
@immutable
class PricingPolicy {
  final String policyId;
  final PricingServiceType serviceType;
  final int version;
  final int baseFare; // IQD
  final int pricePerKm; // IQD
  final int pricePerMinute; // IQD
  final int minimumFare; // IQD
  final int maximumFare; // IQD
  final int waitingFeePerMinute; // IQD
  final int serviceFee; // IQD
  final int stopFee; // IQD per additional stop
  final double maxSurgeMultiplier;
  final RoundingUnit roundingUnit;
  final List<PeakPeriod> peakPeriods;
  final bool isEnabled;
  final DateTime effectiveFrom;

  const PricingPolicy({
    required this.policyId,
    required this.serviceType,
    required this.version,
    required this.baseFare,
    required this.pricePerKm,
    this.pricePerMinute = 0,
    required this.minimumFare,
    this.maximumFare = 1000000,
    this.waitingFeePerMinute = 0,
    this.serviceFee = 0,
    this.stopFee = 1000,
    this.maxSurgeMultiplier = 2.0,
    this.roundingUnit = RoundingUnit.twoFifty,
    this.peakPeriods = const [],
    this.isEnabled = true,
    required this.effectiveFrom,
  });

  /// السياسة الافتراضية لرحلات التكسي
  static final PricingPolicy defaultTaxiPolicy = PricingPolicy(
    policyId: 'pol_taxi_v1',
    serviceType: PricingServiceType.taxi,
    version: 1,
    baseFare: 3000, // 3,000 IQD base
    pricePerKm: 500, // 500 IQD per km
    pricePerMinute: 100, // 100 IQD per min
    minimumFare: 3000,
    maximumFare: 100000,
    waitingFeePerMinute: 150,
    serviceFee: 500,
    stopFee: 1500,
    maxSurgeMultiplier: 2.0,
    roundingUnit: RoundingUnit.twoFifty,
    peakPeriods: const [
      PeakPeriod(startHour: 7, endHour: 9, multiplier: 1.2), // Morning rush
      PeakPeriod(startHour: 17, endHour: 20, multiplier: 1.3), // Evening rush
    ],
    effectiveFrom: DateTime(2026, 1, 1),
  );

  /// السياسة الافتراضية لطلبات توصيل الطعام
  static final PricingPolicy defaultFoodPolicy = PricingPolicy(
    policyId: 'pol_food_v1',
    serviceType: PricingServiceType.food,
    version: 1,
    baseFare: 1500, // 1,500 IQD base delivery
    pricePerKm: 250,
    minimumFare: 1500,
    maximumFare: 15000,
    serviceFee: 0,
    maxSurgeMultiplier: 1.5,
    roundingUnit: RoundingUnit.twoFifty,
    effectiveFrom: DateTime(2026, 1, 1),
  );

  /// السياسة الافتراضية لطلبات المتاجر
  static final PricingPolicy defaultStorePolicy = PricingPolicy(
    policyId: 'pol_store_v1',
    serviceType: PricingServiceType.store,
    version: 1,
    baseFare: 2000,
    pricePerKm: 300,
    minimumFare: 2000,
    maximumFare: 20000,
    serviceFee: 0,
    maxSurgeMultiplier: 1.5,
    roundingUnit: RoundingUnit.twoFifty,
    effectiveFrom: DateTime(2026, 1, 1),
  );

  /// السياسة الافتراضية لخدمة مرسال والطرود
  static final PricingPolicy defaultMersalPolicy = PricingPolicy(
    policyId: 'pol_mersal_v1',
    serviceType: PricingServiceType.mersal,
    version: 1,
    baseFare: 2500,
    pricePerKm: 400,
    minimumFare: 2500,
    maximumFare: 50000,
    stopFee: 1000,
    maxSurgeMultiplier: 1.8,
    roundingUnit: RoundingUnit.twoFifty,
    effectiveFrom: DateTime(2026, 1, 1),
  );

  Map<String, dynamic> toMap() {
    return {
      'policyId': policyId,
      'serviceType': serviceType.key,
      'version': version,
      'baseFare': baseFare,
      'pricePerKm': pricePerKm,
      'pricePerMinute': pricePerMinute,
      'minimumFare': minimumFare,
      'maximumFare': maximumFare,
      'waitingFeePerMinute': waitingFeePerMinute,
      'serviceFee': serviceFee,
      'stopFee': stopFee,
      'maxSurgeMultiplier': maxSurgeMultiplier,
      'roundingUnit': roundingUnit.value,
      'peakPeriods': peakPeriods.map((p) => p.toMap()).toList(),
      'isEnabled': isEnabled,
      'effectiveFrom': effectiveFrom.toIso8601String(),
    };
  }

  factory PricingPolicy.fromMap(Map<String, dynamic> map, String docId) {
    final rawPeaks = map['peakPeriods'] as List? ?? [];
    final peakPeriods = rawPeaks
        .map((p) => PeakPeriod.fromMap(Map<String, dynamic>.from(p as Map)))
        .toList();

    return PricingPolicy(
      policyId: docId,
      serviceType: PricingServiceType.fromString(map['serviceType']?.toString()),
      version: (map['version'] as num?)?.toInt() ?? 1,
      baseFare: (map['baseFare'] as num?)?.toInt() ?? 2000,
      pricePerKm: (map['pricePerKm'] as num?)?.toInt() ?? 500,
      pricePerMinute: (map['pricePerMinute'] as num?)?.toInt() ?? 0,
      minimumFare: (map['minimumFare'] as num?)?.toInt() ?? 2000,
      maximumFare: (map['maximumFare'] as num?)?.toInt() ?? 1000000,
      waitingFeePerMinute: (map['waitingFeePerMinute'] as num?)?.toInt() ?? 0,
      serviceFee: (map['serviceFee'] as num?)?.toInt() ?? 0,
      stopFee: (map['stopFee'] as num?)?.toInt() ?? 1000,
      maxSurgeMultiplier: (map['maxSurgeMultiplier'] as num?)?.toDouble() ?? 2.0,
      roundingUnit: RoundingUnit.values.firstWhere(
        (r) => r.value == (map['roundingUnit'] as num?)?.toInt(),
        orElse: () => RoundingUnit.twoFifty,
      ),
      peakPeriods: peakPeriods,
      isEnabled: map['isEnabled'] != false,
      effectiveFrom: map['effectiveFrom'] != null
          ? DateTime.tryParse(map['effectiveFrom'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
