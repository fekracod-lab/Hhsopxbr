import '../../domain/entities/transaction_context.dart';
import '../../domain/entities/saga_execution.dart';
import '../../domain/entities/domain_event.dart';
import '../../domain/entities/consistency_violation.dart';
import '../../domain/entities/recovery_job.dart';
import '../../domain/enums/orchestration_enums.dart';
import '../../domain/repositories/i_transaction_repository.dart';
import '../datasources/transaction_remote_datasource.dart';

/// تطبيق مستودع المعاملات الموزعة (TransactionRepository)
class TransactionRepository implements ITransactionRepository {
  final TransactionRemoteDatasource _remoteDatasource;

  TransactionRepository({TransactionRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? TransactionRemoteDatasource();

  @override
  Future<void> saveTransactionContext(TransactionContext context, TransactionState state) {
    return _remoteDatasource.saveTransactionContext(context, state);
  }

  @override
  Future<TransactionContext?> getTransactionContext(String transactionId) {
    return _remoteDatasource.getTransactionContext(transactionId);
  }

  @override
  Future<void> updateTransactionState(String transactionId, TransactionState state) {
    return _remoteDatasource.updateTransactionState(transactionId, state);
  }

  @override
  Future<void> saveSagaExecution(SagaExecution saga) {
    return _remoteDatasource.saveSagaExecution(saga);
  }

  @override
  Future<SagaExecution?> getSagaExecution(String sagaId) {
    return _remoteDatasource.getSagaExecution(sagaId);
  }

  @override
  Future<void> saveDomainEvent(DomainEvent event) {
    return _remoteDatasource.saveDomainEvent(event);
  }

  @override
  Future<void> saveConsistencyViolation(ConsistencyViolation violation) {
    return _remoteDatasource.saveConsistencyViolation(violation);
  }

  @override
  Future<void> saveRecoveryJob(RecoveryJob job) {
    return _remoteDatasource.saveRecoveryJob(job);
  }
}
