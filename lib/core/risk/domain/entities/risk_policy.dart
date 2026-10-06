import 'package:flutter/foundation.dart';

/// وثيقة سياسة تقييم المخاطر المعتمدة (Risk Policy Entity)
@immutable
class RiskPolicy {
  final String policyId;
  final String version;
  final bool enabled;
  final Map<String, int> riskThresholds; // e.g. {'critical': 80, 'high': 60, 'medium': 40, 'low': 20}
  final Map<String, int> velocityLimits; // e.g. {'order_1h': 10, 'wallet_1h': 5, 'coupon_24h': 3}
  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;

  const RiskPolicy({
    required this.policyId,
    required this.version,
    this.enabled = true,
    this.riskThresholds = const {
      'critical': 80,
      'high': 60,
      'medium': 40,
      'low': 20,
    },
    this.velocityLimits = const {
      'order_create_1h': 10,
      'wallet_debit_1h': 5,
      'coupon_redeem_24h': 3,
      'ride_request_1h': 10,
    },
    required this.effectiveFrom,
    this.effectiveUntil,
  });

  Map<String, dynamic> toMap() {
    return {
      'policyId': policyId,
      'version': version,
      'enabled': enabled,
      'riskThresholds': riskThresholds,
      'velocityLimits': velocityLimits,
      'effectiveFrom': effectiveFrom.toIso8601String(),
      'effectiveUntil': effectiveUntil?.toIso8601String(),
    };
  }

  factory RiskPolicy.fromMap(Map<String, dynamic> map, String docId) {
    return RiskPolicy(
      policyId: docId,
      version: map['version']?.toString() ?? 'v1.0.0',
      enabled: map['enabled'] == true,
      riskThresholds: (map['riskThresholds'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {
        'critical': 80,
        'high': 60,
        'medium': 40,
        'low': 20,
      },
      velocityLimits: (map['velocityLimits'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {
        'order_create_1h': 10,
        'wallet_debit_1h': 5,
        'coupon_redeem_24h': 3,
        'ride_request_1h': 10,
      },
      effectiveFrom: map['effectiveFrom'] != null
          ? DateTime.tryParse(map['effectiveFrom'].toString()) ?? DateTime.now()
          : DateTime.now(),
      effectiveUntil: map['effectiveUntil'] != null
          ? DateTime.tryParse(map['effectiveUntil'].toString())
          : null,
    );
  }
}
