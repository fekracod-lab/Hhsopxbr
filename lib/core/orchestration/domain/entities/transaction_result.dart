import 'package:flutter/foundation.dart';
import '../enums/orchestration_enums.dart';
import 'saga_execution.dart';

/// النتيجة النهائية لتنسيق المعاملة الموزعة (Transaction Result)
@immutable
class TransactionResult {
  final bool isSuccess;
  final String transactionId;
  final String? orderId;
  final String? rideId;
  final TransactionState finalState;
  final SagaExecution? sagaExecution;
  final FailureType? failureType;
  final String? errorMessage;
  final Map<String, dynamic> metadata;

  const TransactionResult._({
    required this.isSuccess,
    required this.transactionId,
    this.orderId,
    this.rideId,
    required this.finalState,
    this.sagaExecution,
    this.failureType,
    this.errorMessage,
    this.metadata = const {},
  });

  factory TransactionResult.success({
    required String transactionId,
    String? orderId,
    String? rideId,
    SagaExecution? sagaExecution,
    Map<String, dynamic> metadata = const {},
  }) {
    return TransactionResult._(
      isSuccess: true,
      transactionId: transactionId,
      orderId: orderId,
      rideId: rideId,
      finalState: TransactionState.completed,
      sagaExecution: sagaExecution,
      metadata: metadata,
    );
  }

  factory TransactionResult.failed({
    required String transactionId,
    String? orderId,
    String? rideId,
    required TransactionState state,
    required FailureType failureType,
    required String errorMessage,
    SagaExecution? sagaExecution,
    Map<String, dynamic> metadata = const {},
  }) {
    return TransactionResult._(
      isSuccess: false,
      transactionId: transactionId,
      orderId: orderId,
      rideId: rideId,
      finalState: state,
      failureType: failureType,
      errorMessage: errorMessage,
      sagaExecution: sagaExecution,
      metadata: metadata,
    );
  }
}
