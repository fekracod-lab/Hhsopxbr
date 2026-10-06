import 'package:flutter/foundation.dart';
import '../enums/orchestration_enums.dart';

/// إجراء التعويض العكسي (Saga Compensating Action)
@immutable
class CompensationAction {
  final SagaStepType stepType;
  final String targetEntityId;
  final String actionDescription;
  final Map<String, dynamic> payload;
  final bool isExecuted;
  final DateTime? executedAt;
  final String? errorMessage;

  const CompensationAction({
    required this.stepType,
    required this.targetEntityId,
    required this.actionDescription,
    this.payload = const {},
    this.isExecuted = false,
    this.executedAt,
    this.errorMessage,
  });

  CompensationAction copyWith({
    SagaStepType? stepType,
    String? targetEntityId,
    String? actionDescription,
    Map<String, dynamic>? payload,
    bool? isExecuted,
    DateTime? executedAt,
    String? errorMessage,
  }) {
    return CompensationAction(
      stepType: stepType ?? this.stepType,
      targetEntityId: targetEntityId ?? this.targetEntityId,
      actionDescription: actionDescription ?? this.actionDescription,
      payload: payload ?? this.payload,
      isExecuted: isExecuted ?? this.isExecuted,
      executedAt: executedAt ?? this.executedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stepType': stepType.key,
      'targetEntityId': targetEntityId,
      'actionDescription': actionDescription,
      'payload': payload,
      'isExecuted': isExecuted,
      'executedAt': executedAt?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  factory CompensationAction.fromMap(Map<String, dynamic> map) {
    return CompensationAction(
      stepType: SagaStepType.values.firstWhere(
        (s) => s.key == map['stepType']?.toString(),
        orElse: () => SagaStepType.orderCreation,
      ),
      targetEntityId: map['targetEntityId']?.toString() ?? '',
      actionDescription: map['actionDescription']?.toString() ?? '',
      payload: map['payload'] is Map ? Map<String, dynamic>.from(map['payload'] as Map) : {},
      isExecuted: map['isExecuted'] == true,
      executedAt: map['executedAt'] != null ? DateTime.tryParse(map['executedAt'].toString()) : null,
      errorMessage: map['errorMessage']?.toString(),
    );
  }
}
