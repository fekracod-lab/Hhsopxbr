import 'package:flutter/foundation.dart';

/// أدوار المستخدمين في منصة مدار
enum MadarRole {
  customer('customer'),
  driver('driver'),
  taxiCaptain('taxi_captain'),
  restaurant('restaurant'),
  store('store'),
  merchant('merchant'),
  delivery('delivery'),
  deliveryCaptain('delivery_captain'),
  admin('admin'),
  superAdmin('super_admin'),
  mainAdmin('main_admin'),
  limitedAdmin('limited_admin'),
  complaintsAdmin('complaints_admin'),
  support('support'),
  auditor('auditor'),
  regionManager('region_manager'),
  dispatchOperator('dispatch_operator');

  final String key;
  const MadarRole(this.key);

  static MadarRole fromString(String? val) {
    if (val == null || val.isEmpty) return MadarRole.customer;
    final normalized = val.trim().toLowerCase();
    for (final role in MadarRole.values) {
      if (role.key == normalized) return role;
    }
    return MadarRole.customer;
  }

  bool get isAdmin =>
      this == MadarRole.admin ||
      this == MadarRole.superAdmin ||
      this == MadarRole.mainAdmin ||
      this == MadarRole.limitedAdmin ||
      this == MadarRole.complaintsAdmin ||
      this == MadarRole.regionManager;

  bool get isCaptain =>
      this == MadarRole.driver ||
      this == MadarRole.taxiCaptain ||
      this == MadarRole.delivery ||
      this == MadarRole.deliveryCaptain;
}

/// صلاحيات النظام في منصة مدار
enum MadarPermission {
  cancelOrder,
  requestRefund,
  processRefund,
  viewAuditLogs,
  manageDrivers,
  modifyConfig,
  processWithdrawal,
  overridePrice,
  broadcastEmergency,
  directFinancialMutation,
}

/// أنواع العمليات المالية
enum FinancialOperationType {
  orderPayment('order_payment'),
  orderRefund('order_refund'),
  driverPayout('driver_payout'),
  walletDeposit('wallet_deposit'),
  walletWithdrawal('wallet_withdrawal'),
  platformCommission('platform_commission'),
  pointsRedemption('points_redemption');

  final String key;
  const FinancialOperationType(this.key);
}

/// حمولة العملية المالية الموثقة
@immutable
class FinancialOperationPayload {
  final FinancialOperationType operationType;
  final double amount;
  final String currency;
  final String sourceUserId;
  final String? targetUserId;
  final String? orderId;
  final String idempotencyKey;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const FinancialOperationPayload({
    required this.operationType,
    required this.amount,
    this.currency = 'IQD',
    required this.sourceUserId,
    this.targetUserId,
    this.orderId,
    required this.idempotencyKey,
    required this.timestamp,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'operationType': operationType.key,
      'amount': amount,
      'currency': currency,
      'sourceUserId': sourceUserId,
      'targetUserId': targetUserId,
      'orderId': orderId,
      'idempotencyKey': idempotencyKey,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
}

/// حالة طلب الاسترداد المالي
enum RefundStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  processed('processed');

  final String key;
  const RefundStatus(this.key);

  static RefundStatus fromString(String? val) {
    if (val == null) return RefundStatus.pending;
    return RefundStatus.values.firstWhere(
      (e) => e.key == val.toLowerCase().trim(),
      orElse: () => RefundStatus.pending,
    );
  }
}

/// كيان طلب الاسترداد المالي الموثق (Server-Authoritative Refund Request)
@immutable
class RefundRequestEntity {
  final String id;
  final String orderId;
  final String orderSource; // 'food', 'store', 'mersal', 'taxi'
  final String userId;
  final double amount;
  final int points;
  final String reason;
  final RefundStatus status;
  final String idempotencyKey;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? adminNote;

  const RefundRequestEntity({
    required this.id,
    required this.orderId,
    required this.orderSource,
    required this.userId,
    required this.amount,
    this.points = 0,
    required this.reason,
    this.status = RefundStatus.pending,
    required this.idempotencyKey,
    required this.createdAt,
    this.processedAt,
    this.adminNote,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'orderSource': orderSource,
      'userId': userId,
      'amount': amount,
      'points': points,
      'reason': reason,
      'status': status.key,
      'idempotencyKey': idempotencyKey,
      'createdAt': createdAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'adminNote': adminNote,
    };
  }

  factory RefundRequestEntity.fromMap(Map<String, dynamic> map, String docId) {
    return RefundRequestEntity(
      id: docId,
      orderId: map['orderId']?.toString() ?? '',
      orderSource: map['orderSource']?.toString() ?? 'store',
      userId: map['userId']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      points: (map['points'] as num?)?.toInt() ?? 0,
      reason: map['reason']?.toString() ?? '',
      status: RefundStatus.fromString(map['status']?.toString()),
      idempotencyKey: map['idempotencyKey']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      processedAt: map['processedAt'] != null
          ? DateTime.tryParse(map['processedAt'].toString())
          : null,
      adminNote: map['adminNote']?.toString(),
    );
  }
}

/// نوع الانتهاك الأمني
enum SecurityViolationType {
  unauthorizedFinancialMutation('unauthorized_financial_mutation'),
  unauthorizedRoleEscalation('unauthorized_role_escalation'),
  tamperedPayload('tampered_payload'),
  invalidIdempotency('invalid_idempotency'),
  rateLimitExceeded('rate_limit_exceeded'),
  bannedUserAction('banned_user_action');

  final String key;
  const SecurityViolationType(this.key);
}

/// كيان الحادثة الأمنية (Security Incident)
@immutable
class SecurityViolation {
  final SecurityViolationType type;
  final String userId;
  final String actionAttempted;
  final String reason;
  final String severity; // 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const SecurityViolation({
    required this.type,
    required this.userId,
    required this.actionAttempted,
    required this.reason,
    this.severity = 'HIGH',
    required this.timestamp,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.key,
      'userId': userId,
      'actionAttempted': actionAttempted,
      'reason': reason,
      'severity': severity,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
}

/// استثناء أمني صارم عند محاولة التلاعب
class SecurityViolationException implements Exception {
  final String message;
  final SecurityViolationType type;
  final String? fieldName;

  const SecurityViolationException(this.message, {this.type = SecurityViolationType.tamperedPayload, this.fieldName});

  @override
  String toString() => ' [SecurityViolationException] $message (type: ${type.key}, field: $fieldName)';
}
