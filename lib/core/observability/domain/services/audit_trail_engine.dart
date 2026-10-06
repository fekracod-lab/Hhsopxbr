import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../entities/operational_audit_record.dart';
import '../enums/observability_enums.dart';

/// محرك تسجيل التدقيق العملياتي والإداري غير القابل للتعديل (Tamper-Proof Audit Trail Engine)
class AuditTrailEngine {
  const AuditTrailEngine();

  /// إنشاء وتوثيق سجل تدقيق مشفر بالـ SHA-256
  static OperationalAuditRecord createAuditRecord({
    required String actorId,
    required String actorRole,
    required AuditActionType action,
    required String targetEntityId,
    required String targetEntityType,
    required String reason,
    int riskScore = 0,
    required String traceId,
    Map<String, dynamic> beforeState = const {},
    Map<String, dynamic> afterState = const {},
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final auditId = 'audit-$targetEntityType-$targetEntityId-${currentTime.millisecondsSinceEpoch}';

    // 1. حساب الـ Hash الشامل لمنع أي تلاعب بالسجل (Tamper-Evident Hash)
    final payloadToHash = {
      'auditId': auditId,
      'actorId': actorId,
      'actorRole': actorRole,
      'action': action.key,
      'targetEntityId': targetEntityId,
      'targetEntityType': targetEntityType,
      'reason': reason,
      'riskScore': riskScore,
      'traceId': traceId,
      'beforeState': beforeState,
      'afterState': afterState,
      'timestamp': currentTime.toIso8601String(),
    };

    final jsonStr = jsonEncode(payloadToHash);
    final immutableHash = sha256.convert(utf8.encode(jsonStr)).toString();

    return OperationalAuditRecord(
      auditId: auditId,
      actorId: actorId,
      actorRole: actorRole,
      action: action,
      targetEntityId: targetEntityId,
      targetEntityType: targetEntityType,
      reason: reason,
      riskScore: riskScore,
      traceId: traceId,
      beforeState: beforeState,
      afterState: afterState,
      timestamp: currentTime,
      immutableHash: immutableHash,
    );
  }
}
