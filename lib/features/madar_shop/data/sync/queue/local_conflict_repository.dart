// التنفيذ الفعلي لمستودع تعارضات المزامنة المحلي (MADAR SHOP Local Conflict Repository)
// Pure Dart — Zero UI Dependencies

import '../../../domain/sync/contracts/i_conflict_repository.dart';
import '../../../domain/sync/contracts/i_local_database.dart';
import '../../../domain/sync/entities/sync_conflict.dart';
import '../../../domain/sync/enums/conflict_resolution_status.dart';

class LocalConflictRepository implements IConflictRepository {
  static const String tableName = 'sync_conflicts';
  final ILocalDatabase _db;

  LocalConflictRepository(this._db);

  @override
  Future<void> saveConflict(SyncConflict conflict, {ILocalTransaction? tx}) async {
    final row = conflict.toJson();
    if (tx != null) {
      await tx.insert(tableName, row);
    } else {
      await _db.insert(tableName, row);
    }
  }

  @override
  Future<List<SyncConflict>> getUnresolved() async {
    final rows = await _db.query(
      tableName,
      where: 'resolutionStatus = ?',
      whereArgs: [ConflictResolutionStatus.unresolved.name],
      orderBy: 'detectedAt DESC',
    );
    return rows.map((r) => SyncConflict.fromJson(r)).toList();
  }

  @override
  Future<SyncConflict?> getById(String id) async {
    final row = await _db.findById(tableName, 'id', id);
    if (row == null) return null;
    return SyncConflict.fromJson(row);
  }

  @override
  Future<void> resolve(
    String id,
    ConflictResolutionStatus status,
    String actorId,
    String method, {
    ILocalTransaction? tx,
  }) async {
    final updateData = {
      'resolutionStatus': status.name,
      'resolvedBy': actorId,
      'resolutionMethod': method,
      'resolvedAt': DateTime.now().toIso8601String(),
    };

    if (tx != null) {
      await tx.update(tableName, updateData, where: 'id = ?', whereArgs: [id]);
    } else {
      await _db.update(tableName, updateData, where: 'id = ?', whereArgs: [id]);
    }
  }

  @override
  Future<int> countUnresolved() async {
    return _db.count(
      tableName,
      where: 'resolutionStatus = ?',
      whereArgs: [ConflictResolutionStatus.unresolved.name],
    );
  }
}
