// آلة حالات مهمة الطباعة (MADAR SHOP Print State Machine)
// Pure Dart — Zero UI Dependencies

import '../enums/print_job_status.dart';

class PrintTransitionResult {
  final bool isAllowed;
  final String? rejectionReason;

  const PrintTransitionResult._(this.isAllowed, this.rejectionReason);

  factory PrintTransitionResult.allow() => const PrintTransitionResult._(true, null);
  factory PrintTransitionResult.deny(String reason) => PrintTransitionResult._(false, reason);
}

class PrintStateMachine {
  static const Map<PrintJobStatus, Set<PrintJobStatus>> _allowedTransitions = {
    PrintJobStatus.queued: {
      PrintJobStatus.printing,
      PrintJobStatus.cancelled,
    },
    PrintJobStatus.printing: {
      PrintJobStatus.completed,
      PrintJobStatus.failed,
      PrintJobStatus.queued, // Retry backoff
      PrintJobStatus.unknownRequiresConfirmation, // ACK timeout
      PrintJobStatus.cancelled,
    },
    PrintJobStatus.unknownRequiresConfirmation: {
      PrintJobStatus.completed,
      PrintJobStatus.failed,
      PrintJobStatus.cancelled,
    },
    PrintJobStatus.completed: {},
    PrintJobStatus.failed: {},
    PrintJobStatus.cancelled: {},
  };

  static PrintTransitionResult validateTransition({
    required PrintJobStatus currentStatus,
    required PrintJobStatus nextStatus,
  }) {
    if (currentStatus == nextStatus) {
      return PrintTransitionResult.allow();
    }

    final targets = _allowedTransitions[currentStatus] ?? {};
    if (targets.contains(nextStatus)) {
      return PrintTransitionResult.allow();
    }

    if (currentStatus.isTerminal) {
      return PrintTransitionResult.deny(
        'لا يمكن تغيير حالة مهمة الطباعة المنتهية ($currentStatus) إلى ($nextStatus).',
      );
    }

    return PrintTransitionResult.deny(
      'الانتقال من حالة ($currentStatus) إلى ($nextStatus) غير مسموح برمجياً.',
    );
  }
}
