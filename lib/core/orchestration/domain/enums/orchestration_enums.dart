/// حالات آلة المعاملات الموزعة في مدار (Transaction States)
enum TransactionState {
  created('created'),
  validating('validating'),
  pricing('pricing'),
  reserving('reserving'),
  paymentAuthorizing('payment_authorizing'),
  orderCreating('order_creating'),
  dispatching('dispatching'),
  notifying('notifying'),
  settling('settling'),
  completed('completed'),
  compensating('compensating'),
  recovered('recovered'),
  failed('failed'),
  cancelled('cancelled');

  final String key;
  const TransactionState(this.key);

  static TransactionState fromString(String? val) {
    if (val == null || val.isEmpty) return TransactionState.created;
    final normalized = val.trim().toLowerCase();
    for (final state in TransactionState.values) {
      if (state.key == normalized) return state;
    }
    return TransactionState.created;
  }
}

/// أنواع خطوات ملحمة المعاملات الموزعة (Saga Steps)
enum SagaStepType {
  securityValidation('security_validation'),
  fareCalculation('fare_calculation'),
  inventoryReservation('inventory_reservation'),
  paymentAuthorization('payment_authorization'),
  orderCreation('order_creation'),
  driverDispatch('driver_dispatch'),
  notificationDispatch('notification_dispatch'),
  financialSettlement('financial_settlement');

  final String key;
  const SagaStepType(this.key);
}

/// حالة تنفيذ الملحمة (Saga Execution Status)
enum SagaStatus {
  pending('pending'),
  inProgress('in_progress'),
  completed('completed'),
  compensating('compensating'),
  compensated('compensated'),
  failed('failed');

  final String key;
  const SagaStatus(this.key);
}

/// تصنيف أنواع الفشل والأخطاء الموزعة (Failure Types)
enum FailureType {
  validationFailure('validation_failure'),
  securityFailure('security_failure'),
  pricingFailure('pricing_failure'),
  inventoryFailure('inventory_failure'),
  paymentFailure('payment_failure'),
  dispatchFailure('dispatch_failure'),
  notificationFailure('notification_failure'),
  concurrencyFailure('concurrency_failure'),
  idempotencyConflict('idempotency_conflict'),
  transientNetworkFailure('transient_network_failure'),
  consistencyFailure('consistency_failure'),
  unknown('unknown');

  final String key;
  const FailureType(this.key);
}

/// الإجراء المطلوب عند حدوث فشل (Failure Action Strategy)
enum FailureAction {
  retry('retry'),
  compensate('compensate'),
  abort('abort'),
  escalate('escalate');

  final String key;
  const FailureAction(this.key);
}

/// تصنيفات انتهاك اتساق البيانات وتناقض الحالات (Consistency Violation Types)
enum ConsistencyViolationType {
  completedOrderPendingPayment('completed_order_pending_payment'),
  cancelledOrderActiveReservation('cancelled_order_active_reservation'),
  assignedOrderNoDriver('assigned_order_no_driver'),
  capturedPaymentMissingOrder('captured_payment_missing_order'),
  duplicateDriverAssignment('duplicate_driver_assignment'),
  refundWithoutPayment('refund_without_payment');

  final String key;
  const ConsistencyViolationType(this.key);
}

/// درجة خطورة انتهاك الاتساق (Violation Severity)
enum ViolationSeverity {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  final String key;
  const ViolationSeverity(this.key);
}

/// إجراءات التعافي واستعادة الاتساق (Recovery Actions)
enum RecoveryAction {
  retryStep('retry_step'),
  executeCompensation('execute_compensation'),
  markFailed('mark_failed'),
  manualIntervention('manual_intervention');

  final String key;
  const RecoveryAction(this.key);
}
