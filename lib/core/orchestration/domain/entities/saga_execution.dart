import 'package:flutter/foundation.dart';
import '../enums/orchestration_enums.dart';
import 'compensation_action.dart';

/// سجل تنفيذ الملحمة الموزعة وتتبع التعويضات (Saga Execution Log)
@immutable
class SagaExecution {
  final String sagaId;
  final String transactionId;
  final List<SagaStepType> completedSteps;
  final SagaStepType? failedStep;
  final SagaStatus status;
  final List<CompensationAction> compensations;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SagaExecution({
    required this.sagaId,
    required this.transactionId,
    this.completedSteps = const [],
    this.failedStep,
    this.status = SagaStatus.pending,
    this.compensations = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  SagaExecution copyWith({
    String? sagaId,
    String? transactionId,
    List<SagaStepType>? completedSteps,
    SagaStepType? failedStep,
    SagaStatus? status,
    List<CompensationAction>? compensations,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SagaExecution(
      sagaId: sagaId ?? this.sagaId,
      transactionId: transactionId ?? this.transactionId,
      completedSteps: completedSteps ?? this.completedSteps,
      failedStep: failedStep ?? this.failedStep,
      status: status ?? this.status,
      compensations: compensations ?? this.compensations,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sagaId': sagaId,
      'transactionId': transactionId,
      'completedSteps': completedSteps.map((s) => s.key).toList(),
      'failedStep': failedStep?.key,
      'status': status.key,
      'compensations': compensations.map((c) => c.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SagaExecution.fromMap(Map<String, dynamic> map, String docId) {
    final rawCompleted = map['completedSteps'] as List? ?? [];
    final completedSteps = rawCompleted
        .map((k) => SagaStepType.values.firstWhere((s) => s.key == k.toString(), orElse: () => SagaStepType.orderCreation))
        .toList();

    final rawCompensations = map['compensations'] as List? ?? [];
    final compensations = rawCompensations
        .map((c) => CompensationAction.fromMap(Map<String, dynamic>.from(c as Map)))
        .toList();

    return SagaExecution(
      sagaId: docId,
      transactionId: map['transactionId']?.toString() ?? '',
      completedSteps: completedSteps,
      failedStep: map['failedStep'] != null
          ? SagaStepType.values.firstWhere((s) => s.key == map['failedStep']?.toString(), orElse: () => SagaStepType.orderCreation)
          : null,
      status: SagaStatus.values.firstWhere(
        (st) => st.key == map['status']?.toString(),
        orElse: () => SagaStatus.pending,
      ),
      compensations: compensations,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
