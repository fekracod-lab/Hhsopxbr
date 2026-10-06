// إشعار تأكيد معالجة الأمر من الخادم (MADAR SHOP Sync Ack)
// Pure Dart — Zero UI Dependencies

import '../enums/sync_command_status.dart';
import '../enums/sync_conflict_type.dart';

class SyncAck {
  final String commandId;
  final String idempotencyKey;
  final SyncCommandStatus status;
  final DateTime serverTimestamp;
  final int entityVersion;
  final String? resultReferenceId;
  final String? errorMessage;
  final SyncConflictType? conflictType;
  final Map<String, dynamic>? conflictDetails;

  const SyncAck({
    required this.commandId,
    required this.idempotencyKey,
    required this.status,
    required this.serverTimestamp,
    required this.entityVersion,
    this.resultReferenceId,
    this.errorMessage,
    this.conflictType,
    this.conflictDetails,
  });

  bool get isSuccess => status == SyncCommandStatus.synced;
  bool get isConflict => status == SyncCommandStatus.conflict || status == SyncCommandStatus.requiresReview;
  bool get isFailure => status == SyncCommandStatus.failed;

  Map<String, dynamic> toJson() => {
        'commandId': commandId,
        'idempotencyKey': idempotencyKey,
        'status': status.name,
        'serverTimestamp': serverTimestamp.toIso8601String(),
        'entityVersion': entityVersion,
        'resultReferenceId': resultReferenceId,
        'errorMessage': errorMessage,
        'conflictType': conflictType?.name,
        'conflictDetails': conflictDetails,
      };

  factory SyncAck.fromJson(Map<String, dynamic> json) {
    return SyncAck(
      commandId: json['commandId'] as String,
      idempotencyKey: json['idempotencyKey'] as String,
      status: SyncCommandStatus.values.byName(json['status'] as String),
      serverTimestamp: DateTime.parse(json['serverTimestamp'] as String),
      entityVersion: (json['entityVersion'] as num).toInt(),
      resultReferenceId: json['resultReferenceId'] as String?,
      errorMessage: json['errorMessage'] as String?,
      conflictType: json['conflictType'] != null
          ? SyncConflictType.values.byName(json['conflictType'] as String)
          : null,
      conflictDetails: json['conflictDetails'] as Map<String, dynamic>?,
    );
  }
}
