import '../entities/recovery_job.dart';
import '../entities/saga_execution.dart';
import '../entities/transaction_context.dart';
import '../enums/orchestration_enums.dart';

/// محرك التعافي من الأعطال والعمليات العالقة (Crash Recovery & Watchdog Engine)
class RecoveryEngine {
  const RecoveryEngine();

  /// أقصى مدة مسموحة للعملية قبل اعتبارها عالقة (10 دقائق)
  static const Duration maxOperationStuckThreshold = Duration(minutes: 10);

  /// فحص هل المعاملة عالقة وتحتاج إلى تعافي
  static bool isTransactionStuck({
    required TransactionContext context,
    required TransactionState currentState,
    DateTime? now,
  }) {
    if (currentState == TransactionState.completed ||
        currentState == TransactionState.recovered ||
        currentState == TransactionState.failed ||
        currentState == TransactionState.cancelled) {
      return false; // حالة منتهية
    }

    final currentTime = now ?? DateTime.now();
    return currentTime.difference(context.createdAt) > maxOperationStuckThreshold;
  }

  /// إنشاء مهمة تعافي من حالة الملحمة الحالية
  static RecoveryJob createRecoveryJob({
    required String transactionId,
    required SagaExecution saga,
    required TransactionState currentState,
  }) {
    return RecoveryJob(
      jobId: 'rec-$transactionId-${DateTime.now().millisecondsSinceEpoch}',
      transactionId: transactionId,
      sagaId: saga.sagaId,
      state: currentState,
      attemptCount: 0,
      nextRetryAt: DateTime.now().add(const Duration(seconds: 15)),
      failureReason: 'استعادة بعد تعطل أو انقطاع في المعاملة الموزعة',
      createdAt: DateTime.now(),
    );
  }
}
