import 'package:flutter/foundation.dart';
import '../enums/observability_enums.dart';

/// المقطع الزمني للتتبع الموزع (Distributed Trace Span)
@immutable
class TraceSpan {
  final String traceId;
  final String spanId;
  final String? parentSpanId;
  final String correlationId;
  final String name;
  final ServiceType service;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationMs;
  final SpanStatus status;
  final Map<String, dynamic> attributes;
  final List<Map<String, dynamic>> events;

  const TraceSpan({
    required this.traceId,
    required this.spanId,
    this.parentSpanId,
    required this.correlationId,
    required this.name,
    required this.service,
    required this.startTime,
    this.endTime,
    this.durationMs = 0,
    this.status = SpanStatus.unset,
    this.attributes = const {},
    this.events = const [],
  });

  TraceSpan copyWith({
    String? traceId,
    String? spanId,
    String? parentSpanId,
    String? correlationId,
    String? name,
    ServiceType? service,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMs,
    SpanStatus? status,
    Map<String, dynamic>? attributes,
    List<Map<String, dynamic>>? events,
  }) {
    return TraceSpan(
      traceId: traceId ?? this.traceId,
      spanId: spanId ?? this.spanId,
      parentSpanId: parentSpanId ?? this.parentSpanId,
      correlationId: correlationId ?? this.correlationId,
      name: name ?? this.name,
      service: service ?? this.service,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMs: durationMs ?? this.durationMs,
      status: status ?? this.status,
      attributes: attributes ?? this.attributes,
      events: events ?? this.events,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'traceId': traceId,
      'spanId': spanId,
      'parentSpanId': parentSpanId,
      'correlationId': correlationId,
      'name': name,
      'service': service.key,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'durationMs': durationMs,
      'status': status.key,
      'attributes': attributes,
      'events': events,
    };
  }

  factory TraceSpan.fromMap(Map<String, dynamic> map, String docId) {
    return TraceSpan(
      traceId: map['traceId']?.toString() ?? '',
      spanId: docId,
      parentSpanId: map['parentSpanId']?.toString(),
      correlationId: map['correlationId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      service: ServiceType.fromString(map['service']?.toString()),
      startTime: map['startTime'] != null
          ? DateTime.tryParse(map['startTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endTime: map['endTime'] != null
          ? DateTime.tryParse(map['endTime'].toString())
          : null,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      status: SpanStatus.fromString(map['status']?.toString()),
      attributes: map['attributes'] is Map ? Map<String, dynamic>.from(map['attributes'] as Map) : {},
      events: (map['events'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
    );
  }
}
