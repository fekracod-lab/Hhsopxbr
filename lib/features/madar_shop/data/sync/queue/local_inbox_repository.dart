// التنفيذ الفعلي لمستودع صندوق الوارد والأحداث القادمة (MADAR SHOP Local Inbox Repository)
// Pure Dart — Zero UI Dependencies

import '../../../domain/sync/contracts/i_inbox_repository.dart';
import '../../../domain/sync/contracts/i_local_database.dart';
import '../../../domain/sync/entities/inbox_event.dart';
import '../../../domain/sync/value_objects/sync_checkpoint.dart';

class LocalInboxRepository implements IInboxRepository {
  static const String tableInbox = 'sync_inbox';
  static const String tableCheckpoints = 'sync_checkpoints';
  final ILocalDatabase _db;

  LocalInboxRepository(this._db);

  @override
  Future<void> saveInboundEvents(List<InboxEvent> events, {ILocalTransaction? tx}) async {
    for (final event in events) {
      final exists = await hasEvent(event.eventId);
      if (exists) continue; // حماية صارمة من التكرار Replay Protection

      final row = {
        'eventId': event.eventId,
        'businessId': event.businessId,
        'branchId': event.branchId,
        'entityType': event.entityType,
        'entityId': event.entityId,
        'serverCursor': event.serverCursor,
        'serverTimestamp': event.serverTimestamp.toIso8601String(),
        'payloadJson': event.payload,
        'isApplied': event.isApplied ? 1 : 0,
        'appliedAt': event.appliedAt?.toIso8601String(),
      };

      if (tx != null) {
        await tx.insert(tableInbox, row);
      } else {
        await _db.insert(tableInbox, row);
      }
    }
  }

  @override
  Future<List<InboxEvent>> fetchUnapplied({int limit = 50}) async {
    final rows = await _db.query(
      tableInbox,
      where: 'isApplied = ?',
      whereArgs: [0],
      orderBy: 'serverTimestamp ASC',
      limit: limit,
    );
    return rows.map(_mapToEvent).toList();
  }

  @override
  Future<void> markApplied(String eventId, {ILocalTransaction? tx}) async {
    final updateData = {
      'isApplied': 1,
      'appliedAt': DateTime.now().toIso8601String(),
    };

    if (tx != null) {
      await tx.update(tableInbox, updateData, where: 'eventId = ?', whereArgs: [eventId]);
    } else {
      await _db.update(tableInbox, updateData, where: 'eventId = ?', whereArgs: [eventId]);
    }
  }

  @override
  Future<bool> hasEvent(String eventId) async {
    final row = await _db.findById(tableInbox, 'eventId', eventId);
    return row != null;
  }

  @override
  Future<SyncCheckpoint?> getLastCheckpoint(String businessId, String branchId) async {
    final rows = await _db.query(
      tableCheckpoints,
      where: 'businessId = ? AND branchId = ?',
      whereArgs: [businessId, branchId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SyncCheckpoint.fromJson(rows.first);
  }

  @override
  Future<void> saveCheckpoint(SyncCheckpoint checkpoint, {ILocalTransaction? tx}) async {
    final existing = await getLastCheckpoint(checkpoint.businessId, checkpoint.branchId);
    final row = checkpoint.toJson();

    if (existing != null) {
      if (tx != null) {
        await tx.update(
          tableCheckpoints,
          row,
          where: 'businessId = ? AND branchId = ?',
          whereArgs: [checkpoint.businessId, checkpoint.branchId],
        );
      } else {
        await _db.update(
          tableCheckpoints,
          row,
          where: 'businessId = ? AND branchId = ?',
          whereArgs: [checkpoint.businessId, checkpoint.branchId],
        );
      }
    } else {
      if (tx != null) {
        await tx.insert(tableCheckpoints, row);
      } else {
        await _db.insert(tableCheckpoints, row);
      }
    }
  }

  @override
  Future<int> countUnapplied() async {
    return _db.count(tableInbox, where: 'isApplied = ?', whereArgs: [0]);
  }

  InboxEvent _mapToEvent(Map<String, dynamic> row) {
    return InboxEvent(
      eventId: row['eventId'] as String,
      businessId: row['businessId'] as String,
      branchId: row['branchId'] as String,
      entityType: row['entityType'] as String,
      entityId: row['entityId'] as String,
      serverCursor: row['serverCursor'] as String,
      serverTimestamp: DateTime.parse(row['serverTimestamp'] as String),
      payload: Map<String, dynamic>.from(row['payloadJson'] as Map),
      isApplied: (row['isApplied'] as num?)?.toInt() == 1,
      appliedAt: row['appliedAt'] != null
          ? DateTime.parse(row['appliedAt'] as String)
          : null,
    );
  }
}
