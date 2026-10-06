import 'package:flutter/foundation.dart';
import 'domain_event.dart';

/// مظروف الحدث لتسليم الأحداث المتين بنمط Outbox Pattern (Event Envelope)
@immutable
class EventEnvelope {
  final String envelopeId;
  final DomainEvent event;
  final bool isPublished;
  final DateTime? publishedAt;
  final int retryCount;
  final String? failureReason;

  const EventEnvelope({
    required this.envelopeId,
    required this.event,
    this.isPublished = false,
    this.publishedAt,
    this.retryCount = 0,
    this.failureReason,
  });

  EventEnvelope copyWith({
    String? envelopeId,
    DomainEvent? event,
    bool? isPublished,
    DateTime? publishedAt,
    int? retryCount,
    String? failureReason,
  }) {
    return EventEnvelope(
      envelopeId: envelopeId ?? this.envelopeId,
      event: event ?? this.event,
      isPublished: isPublished ?? this.isPublished,
      publishedAt: publishedAt ?? this.publishedAt,
      retryCount: retryCount ?? this.retryCount,
      failureReason: failureReason ?? this.failureReason,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'envelopeId': envelopeId,
      'event': event.toMap(),
      'isPublished': isPublished,
      'publishedAt': publishedAt?.toIso8601String(),
      'retryCount': retryCount,
      'failureReason': failureReason,
    };
  }

  factory EventEnvelope.fromMap(Map<String, dynamic> map, String docId) {
    final eventData = map['event'] is Map ? Map<String, dynamic>.from(map['event'] as Map) : <String, dynamic>{};
    return EventEnvelope(
      envelopeId: docId,
      event: DomainEvent.fromMap(eventData, eventData['eventId']?.toString() ?? docId),
      isPublished: map['isPublished'] == true,
      publishedAt: map['publishedAt'] != null ? DateTime.tryParse(map['publishedAt'].toString()) : null,
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
      failureReason: map['failureReason']?.toString(),
    );
  }
}
