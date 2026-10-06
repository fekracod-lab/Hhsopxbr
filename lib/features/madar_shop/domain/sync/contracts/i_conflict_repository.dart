// عقد مستودع تعارضات المزامنة (MADAR SHOP IConflictRepository)
// Pure Dart — Zero UI Dependencies

import '../entities/sync_conflict.dart';
import '../enums/conflict_resolution_status.dart';
import 'i_local_database.dart';

abstract class IConflictRepository {
  Future<void> saveConflict(SyncConflict conflict, {ILocalTransaction? tx});
  Future<List<SyncConflict>> getUnresolved();
  Future<SyncConflict?> getById(String id);
  Future<void> resolve(
    String id,
    ConflictResolutionStatus status,
    String actorId,
    String method, {
    ILocalTransaction? tx,
  });
  Future<int> countUnresolved();
}
