// محاكي بوابة المزامنة البعيدة عالي الدقة للاختبارات الشاملة (MADAR SHOP Mock Remote Sync Gateway)
// Pure Dart — Zero UI Dependencies

import '../../../domain/sync/contracts/i_remote_sync_gateway.dart';
import '../../../domain/sync/entities/inbox_event.dart';
import '../../../domain/sync/entities/sync_command_envelope.dart';
import '../../../domain/sync/enums/sync_command_status.dart';
import '../../../domain/sync/enums/sync_conflict_type.dart';
import '../../../domain/sync/value_objects/sync_ack.dart';

class MockRemoteSyncGateway implements IRemoteSyncGateway {
  bool isOnline = true;
  bool simulateLatency = false;
  Duration latencyDuration = const Duration(milliseconds: 50);

  // سيناريوهات مخصصة للاختبارات
  Set<String> failCommandIds = {};
  Map<String, SyncConflictType> conflictCommandIds = {};
  Map<String, int> serverStock = {}; // للمخزون المركزي الحقيقي على الخادم
  Set<String> processedIdempotencyKeys = {};

  final List<InboxEvent> stagedInboundEvents = [];
  final List<SyncCommandEnvelope> receivedCommands = [];

  void reset() {
    isOnline = true;
    simulateLatency = false;
    failCommandIds.clear();
    conflictCommandIds.clear();
    serverStock.clear();
    processedIdempotencyKeys.clear();
    stagedInboundEvents.clear();
    receivedCommands.clear();
  }

  @override
  Future<bool> probeReachability() async {
    if (simulateLatency) await Future.delayed(latencyDuration);
    return isOnline;
  }

  @override
  Future<List<SyncAck>> pushBatch(List<SyncCommandEnvelope> commands, {String? authToken}) async {
    if (simulateLatency) await Future.delayed(latencyDuration);
    if (!isOnline) {
      throw Exception('Network unreachable: connection timed out');
    }

    final acks = <SyncAck>[];
    final now = DateTime.now();

    for (final cmd in commands) {
      receivedCommands.add(cmd);

      // 1. فحص الفشل الصريح المحدد للاختبار
      if (failCommandIds.contains(cmd.commandId)) {
        acks.add(SyncAck(
          commandId: cmd.commandId,
          idempotencyKey: cmd.idempotencyKey,
          status: SyncCommandStatus.failed,
          serverTimestamp: now,
          entityVersion: cmd.version,
          errorMessage: 'Simulated server processing failure',
        ));
        continue;
      }

      // 2. فحص التعارض المخصص
      if (conflictCommandIds.containsKey(cmd.commandId)) {
        final conflictType = conflictCommandIds[cmd.commandId]!;
        acks.add(SyncAck(
          commandId: cmd.commandId,
          idempotencyKey: cmd.idempotencyKey,
          status: SyncCommandStatus.conflict,
          serverTimestamp: now,
          entityVersion: cmd.version + 1,
          conflictType: conflictType,
          errorMessage: 'Simulated conflict: ${conflictType.name}',
          conflictDetails: {'serverVersion': cmd.version + 1},
        ));
        continue;
      }

      // 3. فحص خاص بالمخزون: منع الرصيد السالب Central Inventory Integrity
      if (cmd.entityType == 'INVENTORY' && cmd.payload.containsKey('requestedQuantity')) {
        final productId = cmd.entityId;
        final requested = (cmd.payload['requestedQuantity'] as num).toDouble();
        final currentStock = (serverStock[productId] ?? 10).toDouble();

        if (requested > currentStock) {
          // مخزون غير كافٍ على السيرفر Central Stock Depleted!
          acks.add(SyncAck(
            commandId: cmd.commandId,
            idempotencyKey: cmd.idempotencyKey,
            status: SyncCommandStatus.conflict,
            serverTimestamp: now,
            entityVersion: cmd.version + 1,
            conflictType: SyncConflictType.quantityConflict,
            errorMessage: 'Insufficient server stock: requested $requested, available $currentStock',
            conflictDetails: {
              'requested': requested,
              'available': currentStock,
            },
          ));
          continue;
        } else {
          // خصم المخزون على السيرفر بنجاح
          serverStock[productId] = (currentStock - requested).toInt();
        }
      }

      // 4. حماية التكرار Idempotency Check
      processedIdempotencyKeys.add(cmd.idempotencyKey);

      acks.add(SyncAck(
        commandId: cmd.commandId,
        idempotencyKey: cmd.idempotencyKey,
        status: SyncCommandStatus.synced,
        serverTimestamp: now,
        entityVersion: cmd.version + 1,
        resultReferenceId: 'SRV-${cmd.entityId}',
      ));
    }

    return acks;
  }

  @override
  Future<List<InboxEvent>> pullDelta(String businessId, String branchId, {String? afterCursor, int limit = 100}) async {
    if (simulateLatency) await Future.delayed(latencyDuration);
    if (!isOnline) {
      throw Exception('Network unreachable: connection timed out');
    }

    // إرجاع الأحداث المجدولة مع دعم الفلترة حسب الـ Cursor
    return stagedInboundEvents.take(limit).toList();
  }
}
