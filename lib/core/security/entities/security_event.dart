import 'package:flutter/foundation.dart';
import '../enums/security_enums.dart';

/// حدث أمني مرصود (Security Event Record)
@immutable
class SecurityEventRecord {
  final String eventId;
  final SecurityEventType eventType;
  final ThreatSeverity severity;
  final String actorUserId;
  final String description;
  final String? resource;
  final String? traceId;
  final String? correlationId;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const SecurityEventRecord({
    required this.eventId,
    required this.eventType,
    required this.severity,
    required this.actorUserId,
    required this.description,
    this.resource,
    this.traceId,
    this.correlationId,
    required this.timestamp,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() => {
    'eventId': eventId,
    'eventType': eventType.key,
    'severity': severity.key,
    'actorUserId': actorUserId,
    'description': description,
    'resource': resource,
    'traceId': traceId,
    'correlationId': correlationId,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };

  factory SecurityEventRecord.fromMap(Map<String, dynamic> map, String docId) => SecurityEventRecord(
    eventId: map['eventId']?.toString() ?? docId,
    eventType: SecurityEventType.values.firstWhere(
      (e) => e.key == map['eventType'],
      orElse: () => SecurityEventType.unauthorizedAccess,
    ),
    severity: ThreatSeverity.values.firstWhere(
      (e) => e.key == map['severity'],
      orElse: () => ThreatSeverity.low,
    ),
    actorUserId: map['actorUserId']?.toString() ?? '',
    description: map['description']?.toString() ?? '',
    resource: map['resource']?.toString(),
    traceId: map['traceId']?.toString(),
    correlationId: map['correlationId']?.toString(),
    timestamp: map['timestamp'] != null ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now() : DateTime.now(),
    metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
  );
}
