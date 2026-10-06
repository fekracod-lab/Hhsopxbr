import 'package:flutter/foundation.dart';
import '../enums/observability_enums.dart';

/// سجل وإدارة الحادث التشغيلي (Incident Management Record)
@immutable
class IncidentRecord {
  final String incidentId;
  final String title;
  final IncidentSeverity severity;
  final IncidentStatus status;
  final ServiceType affectedService;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final List<String> traceIds;
  final List<String> evidence;
  final List<String> affectedUserIds;
  final List<String> affectedDriverIds;
  final List<String> recoveryAttempts;
  final String? resolution;
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IncidentRecord({
    required this.incidentId,
    required this.title,
    required this.severity,
    this.status = IncidentStatus.open,
    required this.affectedService,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.traceIds = const [],
    this.evidence = const [],
    this.affectedUserIds = const [],
    this.affectedDriverIds = const [],
    this.recoveryAttempts = const [],
    this.resolution,
    this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
  });

  IncidentRecord copyWith({
    String? incidentId,
    String? title,
    IncidentSeverity? severity,
    IncidentStatus? status,
    ServiceType? affectedService,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
    List<String>? traceIds,
    List<String>? evidence,
    List<String>? affectedUserIds,
    List<String>? affectedDriverIds,
    List<String>? recoveryAttempts,
    String? resolution,
    String? assignedTo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IncidentRecord(
      incidentId: incidentId ?? this.incidentId,
      title: title ?? this.title,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      affectedService: affectedService ?? this.affectedService,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      traceIds: traceIds ?? this.traceIds,
      evidence: evidence ?? this.evidence,
      affectedUserIds: affectedUserIds ?? this.affectedUserIds,
      affectedDriverIds: affectedDriverIds ?? this.affectedDriverIds,
      recoveryAttempts: recoveryAttempts ?? this.recoveryAttempts,
      resolution: resolution ?? this.resolution,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'incidentId': incidentId,
      'title': title,
      'severity': severity.key,
      'status': status.key,
      'affectedService': affectedService.key,
      'firstSeenAt': firstSeenAt.toIso8601String(),
      'lastSeenAt': lastSeenAt.toIso8601String(),
      'traceIds': traceIds,
      'evidence': evidence,
      'affectedUserIds': affectedUserIds,
      'affectedDriverIds': affectedDriverIds,
      'recoveryAttempts': recoveryAttempts,
      'resolution': resolution,
      'assignedTo': assignedTo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory IncidentRecord.fromMap(Map<String, dynamic> map, String docId) {
    return IncidentRecord(
      incidentId: docId,
      title: map['title']?.toString() ?? '',
      severity: IncidentSeverity.fromString(map['severity']?.toString()),
      status: IncidentStatus.fromString(map['status']?.toString()),
      affectedService: ServiceType.fromString(map['affectedService']?.toString()),
      firstSeenAt: map['firstSeenAt'] != null
          ? DateTime.tryParse(map['firstSeenAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastSeenAt: map['lastSeenAt'] != null
          ? DateTime.tryParse(map['lastSeenAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      traceIds: (map['traceIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      evidence: (map['evidence'] as List?)?.map((e) => e.toString()).toList() ?? [],
      affectedUserIds: (map['affectedUserIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      affectedDriverIds: (map['affectedDriverIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      recoveryAttempts: (map['recoveryAttempts'] as List?)?.map((e) => e.toString()).toList() ?? [],
      resolution: map['resolution']?.toString(),
      assignedTo: map['assignedTo']?.toString(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
