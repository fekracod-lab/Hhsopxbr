import '../enums/orchestration_enums.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

/// آلة حالات المعاملات الموزعة الصارمة (Transaction State Machine)
class TransactionStateMachine {
  const TransactionStateMachine();

  static const Map<TransactionState, List<TransactionState>> _legalTransitions = {
    TransactionState.created: [
      TransactionState.validating,
      TransactionState.cancelled,
      TransactionState.failed,
    ],
    TransactionState.validating: [
      TransactionState.pricing,
      TransactionState.compensating,
      TransactionState.failed,
      TransactionState.cancelled,
    ],
    TransactionState.pricing: [
      TransactionState.reserving,
      TransactionState.paymentAuthorizing,
      TransactionState.compensating,
      TransactionState.failed,
      TransactionState.cancelled,
    ],
    TransactionState.reserving: [
      TransactionState.paymentAuthorizing,
      TransactionState.compensating,
      TransactionState.failed,
    ],
    TransactionState.paymentAuthorizing: [
      TransactionState.orderCreating,
      TransactionState.compensating,
      TransactionState.failed,
    ],
    TransactionState.orderCreating: [
      TransactionState.dispatching,
      TransactionState.notifying,
      TransactionState.compensating,
      TransactionState.failed,
    ],
    TransactionState.dispatching: [
      TransactionState.notifying,
      TransactionState.settling,
      TransactionState.compensating,
      TransactionState.failed,
    ],
    TransactionState.notifying: [
      TransactionState.settling,
      TransactionState.completed,
      TransactionState.compensating,
      TransactionState.failed,
    ],
    TransactionState.settling: [
      TransactionState.completed,
      TransactionState.compensating,
      TransactionState.failed,
    ],
    TransactionState.compensating: [
      TransactionState.recovered,
      TransactionState.failed,
    ],
    TransactionState.completed: [], // Terminal State
    TransactionState.recovered: [], // Terminal State
    TransactionState.failed: [], // Terminal State
    TransactionState.cancelled: [], // Terminal State
  };

  /// هل الانتقال بين الحالتين قانوني؟
  static bool canTransition(TransactionState current, TransactionState next) {
    if (current == next) return true;
    final allowed = _legalTransitions[current] ?? [];
    return allowed.contains(next);
  }

  /// التحقق الصارم من صحة الانتقال مع منع التراجع عن الحالات النهائية
  static void assertValidTransition(TransactionState current, TransactionState next) {
    if (!canTransition(current, next)) {
      throw SecurityViolationException(
        'انتقال غير قانوني في حالة المعاملة من ${current.key} إلى ${next.key}',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: 'transactionState',
      );
    }
  }
}
