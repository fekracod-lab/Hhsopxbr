import 'package:flutter/foundation.dart';
import '../enums/notification_enums.dart';
import 'notification_message.dart';
import 'notification_target.dart';

/// حدث الإشعار المركزي (Central Notification Event)
@immutable
class NotificationEvent {
  final String eventId;
  final NotificationEventType eventType;
  final String entityId;
  final String actorId;
  final NotificationTarget target;
  final NotificationPriority priority;
  final NotificationMessage message;
  final Map<String, dynamic> payload;
  final String idempotencyKey;
  final DateTime createdAt;
  final DateTime expiresAt;

  const NotificationEvent({
    required this.eventId,
    required this.eventType,
    required this.entityId,
    required this.actorId,
    required this.target,
    required this.priority,
    required this.message,
    this.payload = const {},
    required this.idempotencyKey,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'eventType': eventType.key,
      'entityId': entityId,
      'actorId': actorId,
      'target': target.toMap(),
      'priority': priority.name,
      'message': message.toMap(),
      'payload': payload,
      'idempotencyKey': idempotencyKey,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  factory NotificationEvent.fromMap(Map<String, dynamic> map, String docId) {
    final targetData = map['target'] is Map ? Map<String, dynamic>.from(map['target'] as Map) : <String, dynamic>{};
    final messageData = map['message'] is Map ? Map<String, dynamic>.from(map['message'] as Map) : <String, dynamic>{};

    return NotificationEvent(
      eventId: docId,
      eventType: NotificationEventType.fromString(map['eventType']?.toString()),
      entityId: map['entityId']?.toString() ?? '',
      actorId: map['actorId']?.toString() ?? '',
      target: NotificationTarget.fromMap(targetData),
      priority: NotificationPriority.values.firstWhere(
        (p) => p.name == map['priority']?.toString(),
        orElse: () => NotificationPriority.normal,
      ),
      message: NotificationMessage.fromMap(messageData),
      payload: map['payload'] is Map ? Map<String, dynamic>.from(map['payload'] as Map) : {},
      idempotencyKey: map['idempotencyKey']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt'].toString()) ?? DateTime.now().add(const Duration(hours: 24))
          : DateTime.now().add(const Duration(hours: 24)),
    );
  }
}
