import 'package:flutter/foundation.dart';

/// لقطة خطة التعافي من الكوارث والتحقق من RPO / RTO (Disaster Recovery Snapshot)
@immutable
class DisasterRecoverySnapshot {
  final String snapshotId;
  final String domain;
  final int rpoSeconds; // Recovery Point Objective target in seconds
  final int rtoSeconds; // Recovery Time Objective target in seconds
  final DateTime createdAt;
  final String consistencyStatus; // 'consistent', 'reconciled', 'divergent'
  final int recordsCount;
  final String integrityChecksum; // SHA-256

  const DisasterRecoverySnapshot({
    required this.snapshotId,
    required this.domain,
    required this.rpoSeconds,
    required this.rtoSeconds,
    required this.createdAt,
    this.consistencyStatus = 'consistent',
    this.recordsCount = 0,
    required this.integrityChecksum,
  });

  Map<String, dynamic> toMap() {
    return {
      'snapshotId': snapshotId,
      'domain': domain,
      'rpoSeconds': rpoSeconds,
      'rtoSeconds': rtoSeconds,
      'createdAt': createdAt.toIso8601String(),
      'consistencyStatus': consistencyStatus,
      'recordsCount': recordsCount,
      'integrityChecksum': integrityChecksum,
    };
  }

  factory DisasterRecoverySnapshot.fromMap(Map<String, dynamic> map, String docId) {
    return DisasterRecoverySnapshot(
      snapshotId: docId,
      domain: map['domain']?.toString() ?? 'global',
      rpoSeconds: (map['rpoSeconds'] as num?)?.toInt() ?? 0,
      rtoSeconds: (map['rtoSeconds'] as num?)?.toInt() ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      consistencyStatus: map['consistencyStatus']?.toString() ?? 'consistent',
      recordsCount: (map['recordsCount'] as num?)?.toInt() ?? 0,
      integrityChecksum: map['integrityChecksum']?.toString() ?? '',
    );
  }
}
