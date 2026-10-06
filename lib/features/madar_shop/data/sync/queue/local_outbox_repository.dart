// التنفيذ الفعلي لمستودع صندوق الصادر المحلي المعتمد على قاعدة البيانات (MADAR SHOP Local Outbox Repository)
// Pure Dart — Zero UI Dependencies

import '../../../domain/sync/contracts/i_local_database.dart';
import '../../../domain/sync/contracts/i_outbox_repository.dart';
import '../../../domain/sync/entities/sync_command_envelope.dart';
import '../../../domain/sync/entities/sync_conflict.dart';
import '../../../domain/sync/enums/sync_command_status.dart';
import '../../../domain/sync/rules/sync_state_machine.dart';
import '../../../domain/sync/value_objects/sync_ack.dart';
import '../../../domain/sync/value_objects/sync_lease.dart';

class LocalOutboxRepository implements IOutboxRepository {
  static const String tableName = 'sync_outbox';
  final ILocalDatabase _db;

  LocalOutboxRepository(this._db);

  @override
  Future<void> enqueue(SyncCommandEnvelope command, {ILocalTransaction? tx}) async {
    final row = {
      'commandId': command.commandId,
      'commandType': command.commandType,
      'entityType': command.entityType,
      'entityId': command.entityId,
      'businessId': command.businessId,
      'branchId': command.branchId,
      'terminalId': command.terminalId,
      'sessionId': command.sessionId,
      'createdAt': command.createdAt.toIso8601String(),
      'clientTimestamp': command.clientTimestamp.toIso8601String(),
      'sequence': command.sequence,
      'idempotencyKey': command.idempotencyKey,
      'payloadJson': command.payload,
      'version': command.version,
      'status': command.status.name,
      'retryCount': command.retryCount,
      'lastAttemptAt': command.lastAttemptAt?.toIso8601String(),
      'lastError': command.lastError,
      'leaseId': null,
      'leaseExpiresAt': null,
    };

    if (tx != null) {
      await tx.insert(tableName, row);
    } else {
      await _db.insert(tableName, row);
    }
  }

  @override
  Future<List<SyncCommandEnvelope>> fetchPending({int limit = 50}) async {
    final rows = await _db.query(
      tableName,
      where: 'status = ?',
      whereArgs: [SyncCommandStatus.queued.name],
      orderBy: 'sequence ASC',
      limit: limit,
    );
    return rows.map(_mapToEnvelope).toList();
  }

  @override
  Future<void> markInFlight(List<String> commandIds, SyncLease lease, {ILocalTransaction? tx}) async {
    for (final id in commandIds) {
      final current = await findById(id);
      if (current != null) {
        SyncStateMachine.validateCommandTransition(current.status, SyncCommandStatus.syncing, id);
      }

      final updateData = {
        'status': SyncCommandStatus.syncing.name,
        'leaseId': lease.leaseId,
        'leaseExpiresAt': lease.expiresAt.toIso8601String(),
        'lastAttemptAt': DateTime.now().toIso8601String(),
      };

      if (tx != null) {
        await tx.update(tableName, updateData, where: 'commandId = ?', whereArgs: [id]);
      } else {
        await _db.update(tableName, updateData, where: 'commandId = ?', whereArgs: [id]);
      }
    }
  }

  @override
  Future<void> markAcknowledged(String commandId, SyncAck ack, {ILocalTransaction? tx}) async {
    final current = await findById(commandId);
    if (current != null) {
      SyncStateMachine.validateCommandTransition(current.status, SyncCommandStatus.synced, commandId);
    }

    final updateData = {
      'status': SyncCommandStatus.synced.name,
      'leaseId': null,
      'leaseExpiresAt': null,
      'version': ack.entityVersion,
      'lastError': null,
    };

    if (tx != null) {
      await tx.update(tableName, updateData, where: 'commandId = ?', whereArgs: [commandId]);
    } else {
      await _db.update(tableName, updateData, where: 'commandId = ?', whereArgs: [commandId]);
    }
  }

  @override
  Future<void> markFailed(String commandId, String error, {bool canRetry = true, ILocalTransaction? tx}) async {
    final current = await findById(commandId);
    final nextStatus = canRetry ? SyncCommandStatus.queued : SyncCommandStatus.failed;
    final nextRetry = (current?.retryCount ?? 0) + 1;

    final updateData = {
      'status': nextStatus.name,
      'retryCount': nextRetry,
      'lastError': error,
      'leaseId': null,
      'leaseExpiresAt': null,
    };

    if (tx != null) {
      await tx.update(tableName, updateData, where: 'commandId = ?', whereArgs: [commandId]);
    } else {
      await _db.update(tableName, updateData, where: 'commandId = ?', whereArgs: [commandId]);
    }
  }

  @override
  Future<void> markConflict(String commandId, SyncConflict conflict, {ILocalTransaction? tx}) async {
    final updateData = {
      'status': SyncCommandStatus.conflict.name,
      'lastError': 'Conflict detected: ${conflict.conflictType.name}',
      'leaseId': null,
      'leaseExpiresAt': null,
    };

    if (tx != null) {
      await tx.update(tableName, updateData, where: 'commandId = ?', whereArgs: [commandId]);
    } else {
      await _db.update(tableName, updateData, where: 'commandId = ?', whereArgs: [commandId]);
    }
  }

  @override
  Future<int> recoverExpiredLeases(DateTime threshold, {ILocalTransaction? tx}) async {
    final inFlightRows = await _db.query(
      tableName,
      where: 'status = ?',
      whereArgs: [SyncCommandStatus.syncing.name],
    );

    int recovered = 0;
    for (final row in inFlightRows) {
      final expiresStr = row['leaseExpiresAt'] as String?;
      if (expiresStr == null) continue;
      final expiresAt = DateTime.parse(expiresStr);

      if (expiresAt.isBefore(threshold)) {
        final commandId = row['commandId'] as String;
        final updateData = {
          'status': SyncCommandStatus.queued.name,
          'leaseId': null,
          'leaseExpiresAt': null,
          'lastError': 'Lease expired; recovered to queue',
        };

        if (tx != null) {
          await tx.update(tableName, updateData, where: 'commandId = ?', whereArgs: [commandId]);
        } else {
          await _db.update(tableName, updateData, where: 'commandId = ?', whereArgs: [commandId]);
        }
        recovered++;
      }
    }
    return recovered;
  }

  @override
  Future<int> countPending() async {
    return _db.count(tableName, where: 'status = ?', whereArgs: [SyncCommandStatus.queued.name]);
  }

  @override
  Future<int> countInFlight() async {
    return _db.count(tableName, where: 'status = ?', whereArgs: [SyncCommandStatus.syncing.name]);
  }

  @override
  Future<int> countFailed() async {
    return _db.count(tableName, where: 'status = ?', whereArgs: [SyncCommandStatus.failed.name]);
  }

  @override
  Future<int> countConflicts() async {
    return _db.count(tableName, where: 'status = ?', whereArgs: [SyncCommandStatus.conflict.name]);
  }

  @override
  Future<int> purgeAcknowledged(DateTime olderThan) async {
    final rows = await _db.query(
      tableName,
      where: 'status = ?',
      whereArgs: [SyncCommandStatus.synced.name],
    );

    int purged = 0;
    for (final r in rows) {
      final created = DateTime.parse(r['createdAt'] as String);
      if (created.isBefore(olderThan)) {
        await _db.delete(tableName, where: 'commandId = ?', whereArgs: [r['commandId']]);
        purged++;
      }
    }
    return purged;
  }

  @override
  Future<SyncCommandEnvelope?> findById(String commandId) async {
    final row = await _db.findById(tableName, 'commandId', commandId);
    if (row == null) return null;
    return _mapToEnvelope(row);
  }

  @override
  Future<SyncCommandEnvelope?> findByIdempotencyKey(String idempotencyKey) async {
    final rows = await _db.query(
      tableName,
      where: 'idempotencyKey = ?',
      whereArgs: [idempotencyKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapToEnvelope(rows.first);
  }

  @override
  Future<List<SyncCommandEnvelope>> getAll() async {
    final rows = await _db.query(tableName, orderBy: 'sequence ASC');
    return rows.map(_mapToEnvelope).toList();
  }

  SyncCommandEnvelope _mapToEnvelope(Map<String, dynamic> row) {
    return SyncCommandEnvelope(
      commandId: row['commandId'] as String,
      commandType: row['commandType'] as String,
      entityType: row['entityType'] as String,
      entityId: row['entityId'] as String,
      businessId: row['businessId'] as String,
      branchId: row['branchId'] as String,
      terminalId: row['terminalId'] as String,
      sessionId: row['sessionId'] as String,
      createdAt: DateTime.parse(row['createdAt'] as String),
      clientTimestamp: DateTime.parse(row['clientTimestamp'] as String),
      sequence: (row['sequence'] as num).toInt(),
      idempotencyKey: row['idempotencyKey'] as String,
      payload: Map<String, dynamic>.from(row['payloadJson'] as Map),
      version: (row['version'] as num?)?.toInt() ?? 1,
      status: SyncCommandStatus.values.byName(row['status'] as String),
      retryCount: (row['retryCount'] as num?)?.toInt() ?? 0,
      lastAttemptAt: row['lastAttemptAt'] != null
          ? DateTime.parse(row['lastAttemptAt'] as String)
          : null,
      lastError: row['lastError'] as String?,
    );
  }
}
