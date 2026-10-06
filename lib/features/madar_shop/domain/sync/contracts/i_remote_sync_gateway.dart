// عقد بوابة المزامنة البعيدة مع الخادم المركزي (MADAR SHOP IRemoteSyncGateway)
// Pure Dart — Zero UI Dependencies

import '../entities/inbox_event.dart';
import '../entities/sync_command_envelope.dart';
import '../value_objects/sync_ack.dart';

abstract class IRemoteSyncGateway {
  Future<List<SyncAck>> pushBatch(List<SyncCommandEnvelope> commands, {String? authToken});
  Future<List<InboxEvent>> pullDelta(String businessId, String branchId, {String? afterCursor, int limit = 100});
  Future<bool> probeReachability();
}
