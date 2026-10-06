// منفذ العمليات التبادلية المحلية الذرية (MADAR SHOP Local Transaction Runner)
// Pure Dart — Zero UI Dependencies — Enforces Atomic Outbox Pattern

import '../../../domain/sync/contracts/i_local_database.dart';
import '../../../domain/sync/contracts/i_outbox_repository.dart';
import '../../../domain/sync/entities/sync_command_envelope.dart';

class LocalTransactionRunner {
  final ILocalDatabase _db;
  final IOutboxRepository _outboxRepo;

  LocalTransactionRunner({
    required ILocalDatabase db,
    required IOutboxRepository outboxRepo,
  })  : _db = db,
        _outboxRepo = outboxRepo;

  /// تنفيذ تعديل الكيان المحلي وإدراج أمر المزامنة في صندوق الصادر داخل معاملة ذرية واحدة
  /// Domain Command -> Local Transaction -> Entity Change + Outbox Entry -> Commit
  Future<T> executeAtomic<T>({
    required SyncCommandEnvelope envelope,
    required Future<T> Function(ILocalTransaction tx) localEntityMutation,
  }) async {
    final tx = await _db.beginTransaction();
    try {
      // 1. تنفيذ التعديل المحلي على الكيان داخل المعاملة
      final result = await localEntityMutation(tx);

      // 2. إدراج غلاف المزامنة في جدول outbox داخل نفس المعاملة
      await _outboxRepo.enqueue(envelope, tx: tx);

      // 3. تثبيت المعاملة الذرية Atomic Commit
      await tx.commit();
      return result;
    } catch (e) {
      // التراجع الفوري عند أي خطأ Rollback لمنع انفصال الكيان عن الصادر
      await tx.rollback();
      rethrow;
    }
  }
}
