import 'package:flutter/foundation.dart';

/// حدث النطاق الموحد (Unified Domain Event)
@immutable
class DomainEvent {
  final String eventId;
  final String eventType;
  final String aggregateId;
  final String aggregateType;
  final String transactionId;
  final String correlationId;
  final DateTime occurredAt;
  final Map<String, dynamic> payload;
  final int schemaVersion;

  const DomainEvent({
    required this.eventId,
    required this.eventType,
    required this.aggregateId,
    required this.aggregateType,
    required this.transactionId,
    required this.correlationId,
    required this.occurredAt,
    this.payload = const {},
    this.schemaVersion = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'eventType': eventType,
      'aggregateId': aggregateId,
      'aggregateType': aggregateType,
      'transactionId': transactionId,
      'correlationId': correlationId,
      'occurredAt': occurredAt.toIso8601String(),
      'payload': payload,
      'schemaVersion': schemaVersion,
    };
  }

  factory DomainEvent.fromMap(Map<String, dynamic> map, String docId) {
    return DomainEvent(
      eventId: docId,
      eventType: map['eventType']?.toString() ?? 'unknown',
      aggregateId: map['aggregateId']?.toString() ?? '',
      aggregateType: map['aggregateType']?.toString() ?? '',
      transactionId: map['transactionId']?.toString() ?? '',
      correlationId: map['correlationId']?.toString() ?? '',
      occurredAt: map['occurredAt'] != null
          ? DateTime.tryParse(map['occurredAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      payload: map['payload'] is Map ? Map<String, dynamic>.from(map['payload'] as Map) : {},
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}
