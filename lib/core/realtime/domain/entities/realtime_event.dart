import 'package:flutter/foundation.dart';

/// حدث تشغيلي في الزمن الحقيقي (Realtime Event)
@immutable
class RealtimeEvent {
  final String eventId;
  final String eventType;
  final String entityId;
  final int sequenceNumber;
  final DateTime occurredAt;
  final Map<String, dynamic> payload;

  const RealtimeEvent({
    required this.eventId,
    required this.eventType,
    required this.entityId,
    required this.sequenceNumber,
    required this.occurredAt,
    this.payload = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'eventType': eventType,
      'entityId': entityId,
      'sequenceNumber': sequenceNumber,
      'occurredAt': occurredAt.toIso8601String(),
      'payload': payload,
    };
  }

  factory RealtimeEvent.fromMap(Map<String, dynamic> map, String docId) {
    return RealtimeEvent(
      eventId: docId,
      eventType: map['eventType']?.toString() ?? 'unknown',
      entityId: map['entityId']?.toString() ?? '',
      sequenceNumber: (map['sequenceNumber'] as num?)?.toInt() ?? 0,
      occurredAt: map['occurredAt'] != null
          ? DateTime.tryParse(map['occurredAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      payload: map['payload'] is Map ? Map<String, dynamic>.from(map['payload'] as Map) : {},
    );
  }
}
