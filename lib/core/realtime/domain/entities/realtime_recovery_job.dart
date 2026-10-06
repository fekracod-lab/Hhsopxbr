import 'package:flutter/foundation.dart';
import '../enums/realtime_enums.dart';

/// مهمة التعافي اللحظي للعمليات العالقة (Realtime Recovery Job)
@immutable
class RealtimeRecoveryJob {
  final String jobId;
  final String targetType; // 'driver', 'session', 'stream'
  final String targetId;
  final RealtimeRecoveryAction action;
  final String reason;
  final DateTime createdAt;

  const RealtimeRecoveryJob({
    required this.jobId,
    required this.targetType,
    required this.targetId,
    required this.action,
    required this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'targetType': targetType,
      'targetId': targetId,
      'action': action.key,
      'reason': reason,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory RealtimeRecoveryJob.fromMap(Map<String, dynamic> map, String docId) {
    return RealtimeRecoveryJob(
      jobId: docId,
      targetType: map['targetType']?.toString() ?? 'driver',
      targetId: map['targetId']?.toString() ?? '',
      action: RealtimeRecoveryAction.values.firstWhere(
        (a) => a.key == map['action']?.toString(),
        orElse: () => RealtimeRecoveryAction.refreshState,
      ),
      reason: map['reason']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
