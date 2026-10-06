import 'package:flutter/foundation.dart';

/// سجل محاولة إعادة التنفيذ (Retry Attempt Record)
@immutable
class RetryAttempt {
  final int attemptNumber;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int durationMs;
  final String? errorClassification;
  final bool isSuccess;

  const RetryAttempt({
    required this.attemptNumber,
    required this.startedAt,
    this.completedAt,
    this.durationMs = 0,
    this.errorClassification,
    this.isSuccess = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'attemptNumber': attemptNumber,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'durationMs': durationMs,
      'errorClassification': errorClassification,
      'isSuccess': isSuccess,
    };
  }

  factory RetryAttempt.fromMap(Map<String, dynamic> map) {
    return RetryAttempt(
      attemptNumber: (map['attemptNumber'] as num?)?.toInt() ?? 1,
      startedAt: map['startedAt'] != null
          ? DateTime.tryParse(map['startedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'].toString())
          : null,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      errorClassification: map['errorClassification']?.toString(),
      isSuccess: map['isSuccess'] == true,
    );
  }
}
