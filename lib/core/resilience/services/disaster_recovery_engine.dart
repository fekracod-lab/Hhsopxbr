import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../entities/disaster_recovery_snapshot.dart';

/// محرك إدارة خطة التعافي من الكوارث وحساب RPO / RTO (Disaster Recovery Engine)
class DisasterRecoveryEngine {
  final Map<String, (int rpoSeconds, int rtoSeconds)> domainPolicies = {
    'payments': (0, 10),
    'wallet': (0, 10),
    'audit_logs': (0, 15),
    'rides': (5, 30),
    'orders': (15, 60),
    'analytics': (300, 600),
  };

  DisasterRecoveryEngine();

  (int rpo, int rto) getPolicyForDomain(String domain) {
    return domainPolicies[domain.toLowerCase()] ?? (30, 120);
  }

  /// إنشاء لقطة تعافي مع التحقق من الـ Checksum وسرعة التعافي
  DisasterRecoverySnapshot createSnapshot({
    required String domain,
    required List<Map<String, dynamic>> records,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final policy = getPolicyForDomain(domain);

    final rawData = '$domain|${records.length}|${timestamp.toIso8601String()}|${jsonEncode(records)}';
    final checksum = sha256.convert(utf8.encode(rawData)).toString();

    return DisasterRecoverySnapshot(
      snapshotId: 'snap_dr_${domain}_${timestamp.millisecondsSinceEpoch}',
      domain: domain,
      rpoSeconds: policy.$1,
      rtoSeconds: policy.$2,
      createdAt: timestamp,
      consistencyStatus: 'consistent',
      recordsCount: records.length,
      integrityChecksum: checksum,
    );
  }

  /// التحقق من سلامة لقطة الاسترجاع
  bool verifySnapshotIntegrity({
    required DisasterRecoverySnapshot snapshot,
    required List<Map<String, dynamic>> records,
  }) {
    final rawData = '${snapshot.domain}|${records.length}|${snapshot.createdAt.toIso8601String()}|${jsonEncode(records)}';
    final computedChecksum = sha256.convert(utf8.encode(rawData)).toString();
    return computedChecksum == snapshot.integrityChecksum;
  }
}
