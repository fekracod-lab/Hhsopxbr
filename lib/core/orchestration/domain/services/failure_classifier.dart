import '../enums/orchestration_enums.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

/// مصنف الأخطاء الموزعة وتحديد استراتيجية التعافي (Failure Classifier)
class FailureClassifier {
  const FailureClassifier();

  /// تصنيف أي استثناء إلى نوع خطأ موحد مع تحديد الإجراء المناسب
  static (FailureType, FailureAction) classify(Object error) {
    if (error is SecurityViolationException) {
      if (error.type == SecurityViolationType.unauthorizedRoleEscalation ||
          error.type == SecurityViolationType.bannedUserAction) {
        return (FailureType.securityFailure, FailureAction.abort);
      }
      if (error.type == SecurityViolationType.unauthorizedFinancialMutation) {
        return (FailureType.paymentFailure, FailureAction.compensate);
      }
      if (error.type == SecurityViolationType.tamperedPayload ||
          error.type == SecurityViolationType.invalidIdempotency) {
        return (FailureType.idempotencyConflict, FailureAction.abort);
      }
      return (FailureType.securityFailure, FailureAction.abort);
    }

    final errStr = error.toString().toLowerCase();

    if (errStr.contains('stock') || errStr.contains('inventory') || errStr.contains('مخزون')) {
      return (FailureType.inventoryFailure, FailureAction.compensate);
    }

    if (errStr.contains('payment') || errStr.contains('balance') || errStr.contains('رصيد')) {
      return (FailureType.paymentFailure, FailureAction.compensate);
    }

    if (errStr.contains('dispatch') || errStr.contains('driver') || errStr.contains('كابتن')) {
      return (FailureType.dispatchFailure, FailureAction.compensate);
    }

    if (errStr.contains('timeout') || errStr.contains('network') || errStr.contains('connection')) {
      return (FailureType.transientNetworkFailure, FailureAction.retry);
    }

    if (errStr.contains('concurrency') || errStr.contains('race')) {
      return (FailureType.concurrencyFailure, FailureAction.retry);
    }

    return (FailureType.unknown, FailureAction.compensate);
  }
}
