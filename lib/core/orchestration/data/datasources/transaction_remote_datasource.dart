import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/transaction_context.dart';
import '../../domain/entities/saga_execution.dart';
import '../../domain/entities/domain_event.dart';
import '../../domain/entities/consistency_violation.dart';
import '../../domain/entities/recovery_job.dart';
import '../../domain/enums/orchestration_enums.dart';

/// مصدر البيانات البعيد لتنسيق المعاملات الموزعة (Transaction Remote Datasource)
class TransactionRemoteDatasource {
  final FirebaseFirestore? _customFirestore;

  TransactionRemoteDatasource({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  /// حفظ سياق المعاملة وحالتها
  Future<void> saveTransactionContext(TransactionContext context, TransactionState state) async {
    final docRef = _firestore.collection('transactions').doc(context.transactionId);
    await docRef.set({
      ...context.toMap(),
      'state': state.key,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// جلب سياق المعاملة
  Future<TransactionContext?> getTransactionContext(String transactionId) async {
    final doc = await _firestore.collection('transactions').doc(transactionId).get();
    if (!doc.exists || doc.data() == null) return null;
    return TransactionContext.fromMap(doc.data()!, doc.id);
  }

  /// تحديث حالة المعاملة
  Future<void> updateTransactionState(String transactionId, TransactionState state) async {
    final docRef = _firestore.collection('transactions').doc(transactionId);
    await docRef.update({
      'state': state.key,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// حفظ سجل الملحمة
  Future<void> saveSagaExecution(SagaExecution saga) async {
    final docRef = _firestore.collection('saga_executions').doc(saga.sagaId);
    await docRef.set(saga.toMap());
  }

  /// جلب سجل الملحمة
  Future<SagaExecution?> getSagaExecution(String sagaId) async {
    final doc = await _firestore.collection('saga_executions').doc(sagaId).get();
    if (!doc.exists || doc.data() == null) return null;
    return SagaExecution.fromMap(doc.data()!, doc.id);
  }

  /// حفظ حدث النطاق
  Future<void> saveDomainEvent(DomainEvent event) async {
    final docRef = _firestore.collection('domain_events').doc(event.eventId);
    await docRef.set(event.toMap());
  }

  /// تسجيل انتهاك اتساق بيانات
  Future<void> saveConsistencyViolation(ConsistencyViolation violation) async {
    final docRef = _firestore.collection('consistency_violations').doc(violation.violationId);
    await docRef.set(violation.toMap());
  }

  /// حفظ مهمة تعافي
  Future<void> saveRecoveryJob(RecoveryJob job) async {
    final docRef = _firestore.collection('recovery_jobs').doc(job.jobId);
    await docRef.set(job.toMap());
  }
}
