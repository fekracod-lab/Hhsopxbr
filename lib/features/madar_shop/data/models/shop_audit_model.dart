// نموذج تسلسل سجلات التدقيق (MADAR SHOP Audit DTO)
// Data Layer — Serialization / Deserialization

import '../../domain/audit/entities/shop_audit_entry.dart';

class ShopAuditModel extends ShopAuditEntry {
  const ShopAuditModel({
    required super.auditId,
    required super.businessId,
    required super.branchId,
    required super.userId,
    required super.userName,
    required super.terminalId,
    required super.action,
    super.referenceId,
    super.beforeState,
    super.afterState,
    super.reason,
    required super.timestamp,
    super.metadata,
  });

  factory ShopAuditModel.fromJson(Map<String, dynamic> json, {String? id}) {
    ShopAuditAction parseAction(String? val) {
      if (val == null) return ShopAuditAction.priceOverride;
      for (final a in ShopAuditAction.values) {
        if (a.name == val || a.toString() == val) return a;
      }
      return ShopAuditAction.priceOverride;
    }

    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    return ShopAuditModel(
      auditId: id ?? (json['auditId'] ?? json['id'] ?? '').toString(),
      businessId: (json['businessId'] ?? '').toString(),
      branchId: (json['branchId'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      userName: (json['userName'] ?? '').toString(),
      terminalId: (json['terminalId'] ?? '').toString(),
      action: parseAction(json['action']?.toString()),
      referenceId: json['referenceId']?.toString(),
      beforeState: json['beforeState'] is Map<String, dynamic> ? json['beforeState'] : const {},
      afterState: json['afterState'] is Map<String, dynamic> ? json['afterState'] : const {},
      reason: json['reason']?.toString(),
      timestamp: parseDate(json['timestamp']),
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'auditId': auditId,
      'businessId': businessId,
      'branchId': branchId,
      'userId': userId,
      'userName': userName,
      'terminalId': terminalId,
      'action': action.name,
      'referenceId': referenceId,
      'beforeState': beforeState,
      'afterState': afterState,
      'reason': reason,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
}
