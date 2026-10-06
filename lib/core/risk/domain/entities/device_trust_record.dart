import 'package:flutter/foundation.dart';
import '../enums/risk_enums.dart';

/// سجل موثوقية الجهاز وبصمته المشفرة (Device Trust Record)
@immutable
class DeviceTrustRecord {
  final String deviceId;
  final String deviceFingerprintHash;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final DeviceTrustLevel deviceTrustLevel;
  final int associatedAccountsCount;
  final List<String> riskSignals;

  const DeviceTrustRecord({
    required this.deviceId,
    required this.deviceFingerprintHash,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.deviceTrustLevel = DeviceTrustLevel.neutral,
    this.associatedAccountsCount = 1,
    this.riskSignals = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'deviceFingerprintHash': deviceFingerprintHash,
      'firstSeenAt': firstSeenAt.toIso8601String(),
      'lastSeenAt': lastSeenAt.toIso8601String(),
      'deviceTrustLevel': deviceTrustLevel.key,
      'associatedAccountsCount': associatedAccountsCount,
      'riskSignals': riskSignals,
    };
  }

  factory DeviceTrustRecord.fromMap(Map<String, dynamic> map, String docId) {
    return DeviceTrustRecord(
      deviceId: docId,
      deviceFingerprintHash: map['deviceFingerprintHash']?.toString() ?? '',
      firstSeenAt: map['firstSeenAt'] != null
          ? DateTime.tryParse(map['firstSeenAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastSeenAt: map['lastSeenAt'] != null
          ? DateTime.tryParse(map['lastSeenAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      deviceTrustLevel: DeviceTrustLevel.values.firstWhere(
        (d) => d.key == map['deviceTrustLevel']?.toString(),
        orElse: () => DeviceTrustLevel.neutral,
      ),
      associatedAccountsCount: (map['associatedAccountsCount'] as num?)?.toInt() ?? 1,
      riskSignals: (map['riskSignals'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
