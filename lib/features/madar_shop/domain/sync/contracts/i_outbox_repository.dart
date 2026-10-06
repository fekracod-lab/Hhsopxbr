// عقد مستودع صندوق الصادر المحلي (MADAR SHOP IOutboxRepository)
// Pure Dart — Zero UI Dependencies

import '../entities/sync_command_envelope.dart';
import '../entities/sync_conflict.dart';
import '../value_objects/sync_ack.dart';
import '../value_objects/sync_lease.dart';
import 'i_local_database.dart';

abstract class IOutboxRepository {
  Future<void> enqueue(SyncCommandEnvelope command, {ILocalTransaction? tx});
  Future<List<SyncCommandEnvelope>> fetchPending({int limit = 50});
  Future<void> markInFlight(List<String> commandIds, SyncLease lease, {ILocalTransaction? tx});
  Future<void> markAcknowledged(String commandId, SyncAck ack, {ILocalTransaction? tx});
  Future<void> markFailed(String commandId, String error, {bool canRetry = true, ILocalTransaction? tx});
  Future<void> markConflict(String commandId, SyncConflict conflict, {ILocalTransaction? tx});
  Future<int> recoverExpiredLeases(DateTime threshold, {ILocalTransaction? tx});
  
  Future<int> countPending();
  Future<int> countInFlight();
  Future<int> countFailed();
  Future<int> countConflicts();

  Future<int> purgeAcknowledged(DateTime olderThan);
  Future<SyncCommandEnvelope?> findById(String commandId);
  Future<SyncCommandEnvelope?> findByIdempotencyKey(String idempotencyKey);
  Future<List<SyncCommandEnvelope>> getAll();
}
