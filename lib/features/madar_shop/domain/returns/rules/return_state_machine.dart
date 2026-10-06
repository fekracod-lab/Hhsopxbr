// آلة حالات دورة حياة المرتجع للزبون (MADAR SHOP Customer Return State Machine)
// Pure Dart — Zero UI Dependencies

import '../enums/return_order_status.dart';

class ReturnStateTransitionValidation {
  final bool isAllowed;
  final String? rejectionReason;

  const ReturnStateTransitionValidation._(this.isAllowed, this.rejectionReason);

  factory ReturnStateTransitionValidation.allowed() =>
      const ReturnStateTransitionValidation._(true, null);

  factory ReturnStateTransitionValidation.rejected(String reason) =>
      ReturnStateTransitionValidation._(false, reason);
}

class ReturnStateMachine {
  const ReturnStateMachine._();

  static const Map<ReturnOrderStatus, Set<ReturnOrderStatus>> _allowedTransitions = {
    ReturnOrderStatus.requested: {
      ReturnOrderStatus.approved,
      ReturnOrderStatus.rejected,
      ReturnOrderStatus.cancelled,
    },
    ReturnOrderStatus.approved: {
      ReturnOrderStatus.received,
      ReturnOrderStatus.cancelled,
    },
    ReturnOrderStatus.received: {
      ReturnOrderStatus.refunded,
    },
    ReturnOrderStatus.refunded: {
      ReturnOrderStatus.completed,
    },
    ReturnOrderStatus.completed: {},
    ReturnOrderStatus.rejected: {},
    ReturnOrderStatus.cancelled: {},
  };

  /// التحقق الصارم من صحة الانتقال بين الحالات
  static ReturnStateTransitionValidation validateTransition({
    required ReturnOrderStatus currentStatus,
    required ReturnOrderStatus nextStatus,
  }) {
    if (currentStatus == nextStatus) {
      return ReturnStateTransitionValidation.allowed();
    }

    final allowed = _allowedTransitions[currentStatus] ?? const {};
    if (allowed.contains(nextStatus)) {
      return ReturnStateTransitionValidation.allowed();
    }

    return ReturnStateTransitionValidation.rejected(
      'غير مسموح بالانتقال من حالة ($currentStatus) إلى حالة ($nextStatus). مسار المرتجع إلزامي: '
      'REQUESTED -> APPROVED -> RECEIVED -> REFUNDED -> COMPLETED.',
    );
  }
}
