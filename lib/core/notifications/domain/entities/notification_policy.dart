import 'package:flutter/foundation.dart';

/// سياسة حوكمة وإرسال الإشعارات (Notification Policy)
@immutable
class NotificationPolicy {
  final String policyId;
  final int throttleWindowSeconds;
  final int maxPerWindow;
  final int groupingThreshold;
  final int maxRetries;
  final int retryBackoffSeconds;

  const NotificationPolicy({
    this.policyId = 'default_notification_policy',
    this.throttleWindowSeconds = 60, // نافذة 60 ثانية
    this.maxPerWindow = 5, // 5 إشعارات كحد أقصى للنافذة
    this.groupingThreshold = 3, // تجميع عند وصول 3 إشعارات متشابهة
    this.maxRetries = 3,
    this.retryBackoffSeconds = 10,
  });

  Map<String, dynamic> toMap() {
    return {
      'policyId': policyId,
      'throttleWindowSeconds': throttleWindowSeconds,
      'maxPerWindow': maxPerWindow,
      'groupingThreshold': groupingThreshold,
      'maxRetries': maxRetries,
      'retryBackoffSeconds': retryBackoffSeconds,
    };
  }

  factory NotificationPolicy.fromMap(Map<String, dynamic> map) {
    return NotificationPolicy(
      policyId: map['policyId']?.toString() ?? 'default_notification_policy',
      throttleWindowSeconds: (map['throttleWindowSeconds'] as num?)?.toInt() ?? 60,
      maxPerWindow: (map['maxPerWindow'] as num?)?.toInt() ?? 5,
      groupingThreshold: (map['groupingThreshold'] as num?)?.toInt() ?? 3,
      maxRetries: (map['maxRetries'] as num?)?.toInt() ?? 3,
      retryBackoffSeconds: (map['retryBackoffSeconds'] as num?)?.toInt() ?? 10,
    );
  }
}
