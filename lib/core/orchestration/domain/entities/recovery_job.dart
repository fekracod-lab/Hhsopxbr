import 'package:flutter/foundation.dart';
import '../enums/orchestration_enums.dart';

/// مهمة التعافي واستعادة العمليات العالقة (Recovery Job Entity)
@immutable
class RecoveryJob {
  final String jobId;
  final String transactionId;
  final String sagaId;
  final TransactionState state;
  final int attemptCount;
  final DateTime nextRetryAt;
  final String? failureReason;
  final DateTime createdAt;

  const RecoveryJob({
    required this.jobId,
    required this.transactionId,
    required this.sagaId,
    required this.state,
    this.attemptCount = 0,
    required this.nextRetryAt,
    this.failureReason,
    required this.createdAt,
  });

  RecoveryJob copyWith({
    String? jobId,
    String? transactionId,
    String? sagaId,
    TransactionState? state,
    int? attemptCount,
    DateTime? nextRetryAt,
    String? failureReason,
    DateTime? createdAt,
  }) {
    return RecoveryJob(
      jobId: jobId ?? this.jobId,
      transactionId: transactionId ?? this.transactionId,
      sagaId: sagaId ?? this.sagaId,
      state: state ?? this.state,
      attemptCount: attemptCount ?? this.attemptCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      failureReason: failureReason ?? this.failureReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'transactionId': transactionId,
      'sagaId': sagaId,
      'state': state.key,
      'attemptCount': attemptCount,
      'nextRetryAt': nextRetryAt.toIso8601String(),
      'failureReason': failureReason,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory RecoveryJob.fromMap(Map<String, dynamic> map, String docId) {
    return RecoveryJob(
      jobId: docId,
      transactionId: map['transactionId']?.toString() ?? '',
      sagaId: map['sagaId']?.toString() ?? '',
      state: TransactionState.fromString(map['state']?.toString()),
      attemptCount: (map['attemptCount'] as num?)?.toInt() ?? 0,
      nextRetryAt: map['nextRetryAt'] != null
          ? DateTime.tryParse(map['nextRetryAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      failureReason: map['failureReason']?.toString(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
