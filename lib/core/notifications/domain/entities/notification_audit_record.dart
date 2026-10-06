import 'package:flutter/foundation.dart';
import '../enums/notification_enums.dart';

/// سجل التدقيق والمراقبة للإشعارات (Notification Audit Record)
@immutable
class NotificationAuditRecord {
  final String auditId;
  final String eventId;
  final String userId;
  final NotificationEventType eventType;
  final NotificationPriority priority;
  final NotificationChannel channel;
  final DeliveryStatus status;
  final String reason;
  final DateTime timestamp;

  const NotificationAuditRecord({
    required this.auditId,
    required this.eventId,
    required this.userId,
    required this.eventType,
    required this.priority,
    required this.channel,
    required this.status,
    required this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'auditId': auditId,
      'eventId': eventId,
      'userId': userId,
      'eventType': eventType.key,
      'priority': priority.name,
      'channel': channel.key,
      'status': status.key,
      'reason': reason,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory NotificationAuditRecord.fromMap(Map<String, dynamic> map, String docId) {
    return NotificationAuditRecord(
      auditId: docId,
      eventId: map['eventId']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      eventType: NotificationEventType.fromString(map['eventType']?.toString()),
      priority: NotificationPriority.values.firstWhere(
        (p) => p.name == map['priority']?.toString(),
        orElse: () => NotificationPriority.normal,
      ),
      channel: NotificationChannel.values.firstWhere(
        (c) => c.key == map['channel']?.toString(),
        orElse: () => NotificationChannel.push,
      ),
      status: DeliveryStatus.fromString(map['status']?.toString()),
      reason: map['reason']?.toString() ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
