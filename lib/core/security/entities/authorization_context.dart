import 'package:flutter/foundation.dart';
import '../domain/entities/security_models.dart';
import '../enums/security_enums.dart';

/// سياق التفويض والتحقق من الصلاحيات (Zero-Trust Authorization Context)
@immutable
class AuthorizationContext {
  final String subjectUserId;
  final MadarRole role;
  final String action;
  final String resourceType;
  final String? resourceId;
  final String? resourceOwnerId;
  final SecuritySessionState sessionState;
  final bool isMfaVerified;
  final double currentRiskScore;
  final String? clientIp;
  final String? deviceId;
  final Map<String, dynamic> additionalAttributes;

  const AuthorizationContext({
    required this.subjectUserId,
    required this.role,
    required this.action,
    required this.resourceType,
    this.resourceId,
    this.resourceOwnerId,
    this.sessionState = SecuritySessionState.active,
    this.isMfaVerified = false,
    this.currentRiskScore = 0.0,
    this.clientIp,
    this.deviceId,
    this.additionalAttributes = const {},
  });

  /// هل المستخدم هو مالك المورد المستهدف؟
  bool get isResourceOwner => resourceOwnerId != null && resourceOwnerId == subjectUserId;

  /// هل الحساب إداري؟
  bool get isAdmin => role.isAdmin;

  /// هل الجلسة صالحة أمنياً؟
  bool get isSessionValid => sessionState == SecuritySessionState.active;

  /// هل مستوى الخطر في الحدود الآمنة؟ (Risk Score < 80)
  bool get isRiskAcceptable => currentRiskScore < 80.0;

  Map<String, dynamic> toMap() => {
    'subjectUserId': subjectUserId,
    'role': role.key,
    'action': action,
    'resourceType': resourceType,
    'resourceId': resourceId,
    'resourceOwnerId': resourceOwnerId,
    'sessionState': sessionState.key,
    'isMfaVerified': isMfaVerified,
    'currentRiskScore': currentRiskScore,
    'clientIp': clientIp,
    'deviceId': deviceId,
    'additionalAttributes': additionalAttributes,
  };
}
