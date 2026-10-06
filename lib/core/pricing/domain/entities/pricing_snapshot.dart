import 'package:flutter/foundation.dart';
import '../enums/pricing_enums.dart';
import 'fare_breakdown.dart';

/// لقطة التسعير غير القابلة للتعديل والمحمية بالـ Hash (Immutable Pricing Snapshot)
@immutable
class PricingSnapshot {
  final String snapshotId;
  final String orderId;
  final int pricingPolicyVersion;
  final PricingServiceType serviceType;
  final FareBreakdown fareBreakdown;
  final String calculationHash;
  final DateTime calculatedAt;
  final String currency;

  const PricingSnapshot({
    required this.snapshotId,
    required this.orderId,
    required this.pricingPolicyVersion,
    required this.serviceType,
    required this.fareBreakdown,
    required this.calculationHash,
    required this.calculatedAt,
    this.currency = 'IQD',
  });

  int get finalFare => fareBreakdown.finalFare;

  Map<String, dynamic> toMap() {
    return {
      'snapshotId': snapshotId,
      'orderId': orderId,
      'pricingPolicyVersion': pricingPolicyVersion,
      'serviceType': serviceType.key,
      'fareBreakdown': fareBreakdown.toMap(),
      'calculationHash': calculationHash,
      'calculatedAt': calculatedAt.toIso8601String(),
      'currency': currency,
    };
  }

  factory PricingSnapshot.fromMap(Map<String, dynamic> map, String docId) {
    final breakdownData = map['fareBreakdown'] is Map
        ? Map<String, dynamic>.from(map['fareBreakdown'] as Map)
        : <String, dynamic>{};

    return PricingSnapshot(
      snapshotId: docId,
      orderId: map['orderId']?.toString() ?? '',
      pricingPolicyVersion: (map['pricingPolicyVersion'] as num?)?.toInt() ?? 1,
      serviceType: PricingServiceType.fromString(map['serviceType']?.toString()),
      fareBreakdown: FareBreakdown.fromMap(breakdownData),
      calculationHash: map['calculationHash']?.toString() ?? '',
      calculatedAt: map['calculatedAt'] != null
          ? DateTime.tryParse(map['calculatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      currency: map['currency']?.toString() ?? 'IQD',
    );
  }
}
