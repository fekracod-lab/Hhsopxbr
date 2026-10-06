import '../entities/transaction_context.dart';
import '../entities/saga_execution.dart';
import '../entities/domain_event.dart';
import '../entities/consistency_violation.dart';
import '../entities/recovery_job.dart';
import '../enums/orchestration_enums.dart';

/// العقد التجريدي لمستودع تنسيق المعاملات والملاحم الموزعة (ITransactionRepository)
abstract class ITransactionRepository {
  /// حفظ سياق المعاملة وحالتها
  Future<void> saveTransactionContext(TransactionContext context, TransactionState state);

  /// جلب سياق المعاملة
  Future<TransactionContext?> getTransactionContext(String transactionId);

  /// تحديث حالة المعاملة
  Future<void> updateTransactionState(String transactionId, TransactionState state);

  /// حفظ وتحديث سجل الملحمة الموزعة
  Future<void> saveSagaExecution(SagaExecution saga);

  /// جلب سجل الملحمة الموزعة
  Future<SagaExecution?> getSagaExecution(String sagaId);

  /// حفظ حدث النطاق في سجل دائم
  Future<void> saveDomainEvent(DomainEvent event);

  /// تسجيل انتهاك اتساق بيانات
  Future<void> saveConsistencyViolation(ConsistencyViolation violation);

  /// حفظ مهمة تعافي
  Future<void> saveRecoveryJob(RecoveryJob job);
}
