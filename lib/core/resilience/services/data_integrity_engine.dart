import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../entities/integrity_violation.dart';
import '../enums/resilience_enums.dart';

/// محرك الفحص والتدقيق العميق لسلامة وتطابق البيانات (Data Integrity Engine)
class DataIntegrityEngine {
  const DataIntegrityEngine();

  /// فحص الأرصدة والتأكد من عدم وجود أرصدة سالبة (Zero Negative Balance Audit)
  List<IntegrityViolation> auditWalletBalances(Map<String, int> balances, {DateTime? now}) {
    final violations = <IntegrityViolation>[];
    final timestamp = now ?? DateTime.now();

    balances.forEach((walletId, balance) {
      if (balance < 0) {
        violations.add(
          IntegrityViolation(
            violationId: 'viol_neg_${walletId}_${timestamp.millisecondsSinceEpoch}',
            type: IntegrityViolationType.negativeBalance,
            entityId: walletId,
            entityType: 'Wallet',
            details: 'Negative wallet balance detected: $balance minor units',
            severity: 'critical',
            detectedAt: timestamp,
          ),
        );
      }
    });

    return violations;
  }

  /// فحص السجلات اليتيمة (Orphan Records Detection)
  List<IntegrityViolation> auditOrphanRecords({
    required List<String> childEntityIds,
    required List<String> parentEntityIds,
    required String childType,
    required String parentType,
    DateTime? now,
  }) {
    final violations = <IntegrityViolation>[];
    final parentSet = parentEntityIds.toSet();
    final timestamp = now ?? DateTime.now();

    for (final childId in childEntityIds) {
      if (!parentSet.contains(childId)) {
        violations.add(
          IntegrityViolation(
            violationId: 'viol_orphan_${childId}_${timestamp.millisecondsSinceEpoch}',
            type: IntegrityViolationType.orphanRecord,
            entityId: childId,
            entityType: childType,
            details: 'Orphan $childType with ID [$childId] has no matching $parentType in parent set',
            severity: 'critical',
            detectedAt: timestamp,
          ),
        );
      }
    }

    return violations;
  }

  /// فحص وتدقيق صحة تواقيع الـ SHA-256 للأدلة وسجلات التدقيق
  List<IntegrityViolation> auditTamperProofHashes({
    required List<(String id, String payloadString, String expectedHash)> records,
    required String recordType,
    DateTime? now,
  }) {
    final violations = <IntegrityViolation>[];
    final timestamp = now ?? DateTime.now();

    for (final (id, payload, expectedHash) in records) {
      final computedHash = sha256.convert(utf8.encode(payload)).toString();
      if (computedHash != expectedHash) {
        violations.add(
          IntegrityViolation(
            violationId: 'viol_hash_${id}_${timestamp.millisecondsSinceEpoch}',
            type: IntegrityViolationType.brokenAuditHash,
            entityId: id,
            entityType: recordType,
            details: 'Tampered or corrupted hash for $recordType [$id]. Expected $expectedHash, computed $computedHash',
            severity: 'critical',
            detectedAt: timestamp,
          ),
        );
      }
    }

    return violations;
  }

  /// فحص تطابق الإجماليات (Mismatched Totals)
  List<IntegrityViolation> auditOrderTotals({
    required String orderId,
    required int subtotalMinor,
    required int deliveryFeeMinor,
    required int discountMinor,
    required int finalTotalMinor,
    DateTime? now,
  }) {
    final violations = <IntegrityViolation>[];
    final calculated = subtotalMinor + deliveryFeeMinor - discountMinor;
    final timestamp = now ?? DateTime.now();

    if (calculated != finalTotalMinor) {
      violations.add(
        IntegrityViolation(
          violationId: 'viol_tot_${orderId}_${timestamp.millisecondsSinceEpoch}',
          type: IntegrityViolationType.mismatchedTotal,
          entityId: orderId,
          entityType: 'Order',
          details: 'Order total mismatch: calculated $calculated minor units != stored finalTotal $finalTotalMinor',
          severity: 'critical',
          detectedAt: timestamp,
        ),
      );
    }

    return violations;
  }
}
