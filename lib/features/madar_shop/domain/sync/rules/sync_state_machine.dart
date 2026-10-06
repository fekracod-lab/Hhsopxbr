// آلة حالات المزامنة الصارمة (MADAR SHOP Sync State Machine)
// Pure Dart — Zero UI Dependencies

import '../enums/outbox_state.dart';
import '../enums/sync_command_status.dart';
import '../failures/sync_failures.dart';

class SyncStateMachine {
  static const Map<SyncCommandStatus, Set<SyncCommandStatus>> _allowedCommandTransitions = {
    SyncCommandStatus.localOnly: {
      SyncCommandStatus.queued,
      SyncCommandStatus.cancelled,
    },
    SyncCommandStatus.queued: {
      SyncCommandStatus.syncing,
      SyncCommandStatus.synced,
      SyncCommandStatus.cancelled,
    },
    SyncCommandStatus.syncing: {
      SyncCommandStatus.synced,
      SyncCommandStatus.failed,
      SyncCommandStatus.conflict,
      SyncCommandStatus.requiresReview,
      SyncCommandStatus.queued, // عند انتهاء عقد الإيجار (Lease Expired / Recovered)
    },
    SyncCommandStatus.failed: {
      SyncCommandStatus.queued, // إعادة محاولة
      SyncCommandStatus.synced,
      SyncCommandStatus.cancelled,
    },
    SyncCommandStatus.conflict: {
      SyncCommandStatus.queued, // بعد حل التعارض
      SyncCommandStatus.synced, // حل التعارض لصالح الخادم
      SyncCommandStatus.cancelled,
      SyncCommandStatus.requiresReview,
    },
    SyncCommandStatus.requiresReview: {
      SyncCommandStatus.queued,
      SyncCommandStatus.cancelled,
    },
    SyncCommandStatus.synced: {},    // حالة نهائية
    SyncCommandStatus.cancelled: {}, // حالة نهائية
  };

  static const Map<OutboxState, Set<OutboxState>> _allowedOutboxTransitions = {
    OutboxState.pending: {
      OutboxState.inFlight,
    },
    OutboxState.inFlight: {
      OutboxState.acknowledged,
      OutboxState.failed,
      OutboxState.conflict,
      OutboxState.pending, // استعادة بعد الانهيار
    },
    OutboxState.failed: {
      OutboxState.pending, // إعادة إدراج في الطابور
    },
    OutboxState.conflict: {
      OutboxState.pending, // بعد الحل
    },
    OutboxState.acknowledged: {}, // حالة نهائية
  };

  static void validateCommandTransition(
    SyncCommandStatus current,
    SyncCommandStatus target,
    String commandId,
  ) {
    if (current == target) return;
    final allowed = _allowedCommandTransitions[current] ?? {};
    if (!allowed.contains(target)) {
      throw InvalidSyncStateTransitionFailure(
        'Invalid command transition from ${current.name} to ${target.name} for command $commandId',
      );
    }
  }

  static void validateOutboxTransition(
    OutboxState current,
    OutboxState target,
    String outboxEntryId,
  ) {
    if (current == target) return;
    final allowed = _allowedOutboxTransitions[current] ?? {};
    if (!allowed.contains(target)) {
      throw InvalidSyncStateTransitionFailure(
        'Invalid outbox transition from ${current.name} to ${target.name} for entry $outboxEntryId',
      );
    }
  }
}
