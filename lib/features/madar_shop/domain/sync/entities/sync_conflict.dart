// كيان تعارض المزامنة مع تتبع النسخ وتفاصيل الحل (MADAR SHOP Sync Conflict)
// Pure Dart — Zero UI Dependencies

import '../enums/conflict_resolution_status.dart';
import '../enums/sync_conflict_type.dart';

class SyncConflict {
  final String id;
  final String commandId;
  final String entityId;
  final String entityType;

  final int localVersion;
  final int serverVersion;

  final Map<String, dynamic> localPayload;
  final Map<String, dynamic> serverPayload;

  final SyncConflictType conflictType;
  final DateTime detectedAt;

  final ConflictResolutionStatus resolutionStatus;
  final String? resolvedBy;
  final String? resolutionMethod;
  final DateTime? resolvedAt;

  const SyncConflict({
    required this.id,
    required this.commandId,
    required this.entityId,
    required this.entityType,
    required this.localVersion,
    required this.serverVersion,
    required this.localPayload,
    required this.serverPayload,
    required this.conflictType,
    required this.detectedAt,
    this.resolutionStatus = ConflictResolutionStatus.unresolved,
    this.resolvedBy,
    this.resolutionMethod,
    this.resolvedAt,
  });

  bool get isResolved => resolutionStatus.isResolved;

  SyncConflict resolve({
    required ConflictResolutionStatus status,
    required String actorId,
    required String method,
    DateTime? timestamp,
  }) {
    return SyncConflict(
      id: id,
      commandId: commandId,
      entityId: entityId,
      entityType: entityType,
      localVersion: localVersion,
      serverVersion: serverVersion,
      localPayload: localPayload,
      serverPayload: serverPayload,
      conflictType: conflictType,
      detectedAt: detectedAt,
      resolutionStatus: status,
      resolvedBy: actorId,
      resolutionMethod: method,
      resolvedAt: timestamp ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'commandId': commandId,
        'entityId': entityId,
        'entityType': entityType,
        'localVersion': localVersion,
        'serverVersion': serverVersion,
        'localPayload': localPayload,
        'serverPayload': serverPayload,
        'conflictType': conflictType.name,
        'detectedAt': detectedAt.toIso8601String(),
        'resolutionStatus': resolutionStatus.name,
        'resolvedBy': resolvedBy,
        'resolutionMethod': resolutionMethod,
        'resolvedAt': resolvedAt?.toIso8601String(),
      };

  factory SyncConflict.fromJson(Map<String, dynamic> json) {
    return SyncConflict(
      id: json['id'] as String,
      commandId: json['commandId'] as String,
      entityId: json['entityId'] as String,
      entityType: json['entityType'] as String,
      localVersion: (json['localVersion'] as num).toInt(),
      serverVersion: (json['serverVersion'] as num).toInt(),
      localPayload: Map<String, dynamic>.from(json['localPayload'] as Map),
      serverPayload: Map<String, dynamic>.from(json['serverPayload'] as Map),
      conflictType: SyncConflictType.values.byName(json['conflictType'] as String),
      detectedAt: DateTime.parse(json['detectedAt'] as String),
      resolutionStatus: ConflictResolutionStatus.values.byName(json['resolutionStatus'] as String),
      resolvedBy: json['resolvedBy'] as String?,
      resolutionMethod: json['resolutionMethod'] as String?,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : null,
    );
  }
}
