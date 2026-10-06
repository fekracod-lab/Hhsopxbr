import 'package:flutter/foundation.dart';
import '../enums/observability_enums.dart';

/// سجل التدقيق العملياتي والإداري الدائم غير القابل للتعديل (Tamper-Proof Operational Audit Record)
@immutable
class OperationalAuditRecord {
  final String auditId;
  final String actorId;
  final String actorRole;
  final AuditActionType action;
  final String targetEntityId;
  final String targetEntityType;
  final String reason;
  final int riskScore;
  final String traceId;
  final Map<String, dynamic> beforeState;
  final Map<String, dynamic> afterState;
  final DateTime timestamp;
  final String immutableHash; // SHA-256

  const OperationalAuditRecord({
    required this.auditId,
    required this.actorId,
    required this.actorRole,
    required this.action,
    required this.targetEntityId,
    required this.targetEntityType,
    required this.reason,
    this.riskScore = 0,
    required this.traceId,
    this.beforeState = const {},
    this.afterState = const {},
    required this.timestamp,
    required this.immutableHash,
  });

  Map<String, dynamic> toMap() {
    return {
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
      'timestamp': timestamp.toIso8601String(),
      'immutableHash': immutableHash,
    };
  }

  factory OperationalAuditRecord.fromMap(Map<String, dynamic> map, String docId) {
    return OperationalAuditRecord(
      auditId: docId,
      actorId: map['actorId']?.toString() ?? '',
      actorRole: map['actorRole']?.toString() ?? '',
      action: AuditActionType.fromString(map['action']?.toString()),
      targetEntityId: map['targetEntityId']?.toString() ?? '',
      targetEntityType: map['targetEntityType']?.toString() ?? '',
      reason: map['reason']?.toString() ?? '',
      riskScore: (map['riskScore'] as num?)?.toInt() ?? 0,
      traceId: map['traceId']?.toString() ?? '',
      beforeState: map['beforeState'] is Map ? Map<String, dynamic>.from(map['beforeState'] as Map) : {},
      afterState: map['afterState'] is Map ? Map<String, dynamic>.from(map['afterState'] as Map) : {},
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      immutableHash: map['immutableHash']?.toString() ?? '',
    );
  }
}
