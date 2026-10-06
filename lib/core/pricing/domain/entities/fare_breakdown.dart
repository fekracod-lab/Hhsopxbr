import 'package:flutter/foundation.dart';

/// تفصيل الأجرة الشامل (Detailed Fare Breakdown)
@immutable
class FareBreakdown {
  final int baseFare;
  final int distanceFare;
  final int timeFare;
  final int waitingFare;
  final int serviceFee;
  final int packageFee;
  final int stopFee;
  final double surgeMultiplier;
  final double peakMultiplier;
  final int demandAdjustment;
  final int peakAdjustment;
  final int discount;
  final int subtotal;
  final int finalFare; // Rounded final amount in IQD
  final String currency;

  const FareBreakdown({
    required this.baseFare,
    required this.distanceFare,
    this.timeFare = 0,
    this.waitingFare = 0,
    this.serviceFee = 0,
    this.packageFee = 0,
    this.stopFee = 0,
    this.surgeMultiplier = 1.0,
    this.peakMultiplier = 1.0,
    this.demandAdjustment = 0,
    this.peakAdjustment = 0,
    this.discount = 0,
    required this.subtotal,
    required this.finalFare,
    this.currency = 'IQD',
  });

  Map<String, dynamic> toMap() {
    return {
      'baseFare': baseFare,
      'distanceFare': distanceFare,
      'timeFare': timeFare,
      'waitingFare': waitingFare,
      'serviceFee': serviceFee,
      'packageFee': packageFee,
      'stopFee': stopFee,
      'surgeMultiplier': surgeMultiplier,
      'peakMultiplier': peakMultiplier,
      'demandAdjustment': demandAdjustment,
      'peakAdjustment': peakAdjustment,
      'discount': discount,
      'subtotal': subtotal,
      'finalFare': finalFare,
      'currency': currency,
    };
  }

  factory FareBreakdown.fromMap(Map<String, dynamic> map) {
    return FareBreakdown(
      baseFare: (map['baseFare'] as num?)?.toInt() ?? 0,
      distanceFare: (map['distanceFare'] as num?)?.toInt() ?? 0,
      timeFare: (map['timeFare'] as num?)?.toInt() ?? 0,
      waitingFare: (map['waitingFare'] as num?)?.toInt() ?? 0,
      serviceFee: (map['serviceFee'] as num?)?.toInt() ?? 0,
      packageFee: (map['packageFee'] as num?)?.toInt() ?? 0,
      stopFee: (map['stopFee'] as num?)?.toInt() ?? 0,
      surgeMultiplier: (map['surgeMultiplier'] as num?)?.toDouble() ?? 1.0,
      peakMultiplier: (map['peakMultiplier'] as num?)?.toDouble() ?? 1.0,
      demandAdjustment: (map['demandAdjustment'] as num?)?.toInt() ?? 0,
      peakAdjustment: (map['peakAdjustment'] as num?)?.toInt() ?? 0,
      discount: (map['discount'] as num?)?.toInt() ?? 0,
      subtotal: (map['subtotal'] as num?)?.toInt() ?? 0,
      finalFare: (map['finalFare'] as num?)?.toInt() ?? 0,
      currency: map['currency']?.toString() ?? 'IQD',
    );
  }
}
