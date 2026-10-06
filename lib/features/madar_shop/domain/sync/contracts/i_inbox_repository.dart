// عقد مستودع صندوق الوارد والأحداث القادمة من الخادم (MADAR SHOP IInboxRepository)
// Pure Dart — Zero UI Dependencies

import '../entities/inbox_event.dart';
import '../value_objects/sync_checkpoint.dart';
import 'i_local_database.dart';

abstract class IInboxRepository {
  Future<void> saveInboundEvents(List<InboxEvent> events, {ILocalTransaction? tx});
  Future<List<InboxEvent>> fetchUnapplied({int limit = 50});
  Future<void> markApplied(String eventId, {ILocalTransaction? tx});
  Future<bool> hasEvent(String eventId);
  Future<SyncCheckpoint?> getLastCheckpoint(String businessId, String branchId);
  Future<void> saveCheckpoint(SyncCheckpoint checkpoint, {ILocalTransaction? tx});
  Future<int> countUnapplied();
}
