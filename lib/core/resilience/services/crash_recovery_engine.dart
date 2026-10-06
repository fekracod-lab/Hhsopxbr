import 'recovery_checkpoint_engine.dart';

/// محرك مصالحة واستعادة الحالة بعد انهيار التطبيق (Crash Recovery & Server Reconciliation Engine)
class CrashRecoveryEngine {
  final RecoveryCheckpointEngine checkpointEngine;

  const CrashRecoveryEngine({
    required this.checkpointEngine,
  });

  /// استرجاع ومصالحة الحالة مع الخادم مع اعتماد سلطة الخادم (Server Authority)
  Future<(String restoredState, Map<String, dynamic> payload, String recoveryMode)> reconcileAfterCrash({
    required String operationId,
    required String serverState,
    required int serverVersion,
    required Map<String, dynamic> serverPayload,
  }) async {
    final localCheckpoint = checkpointEngine.getLatestCheckpoint(operationId);

    // 1. إذا لم توجد نقطة تفتيش محلية -> الاعتماد الكامل على الخادم
    if (localCheckpoint == null) {
      return (serverState, serverPayload, 'server_authoritative_fresh');
    }

    // 2. التحقق من سلامة نقطة التفتيش المحلية ضد التلاعب (Integrity Verification)
    final isValid = checkpointEngine.verifyCheckpointIntegrity(localCheckpoint);
    if (!isValid) {
      // تلف في نقطة التفتيش -> رفض الحالة المحلية والاعتماد التام على الخادم
      return (serverState, serverPayload, 'corrupted_local_fallback_to_server');
    }

    // 3. مصالحة الإصدارات: الخادم دائماً يملك السلطة العليا (Server Authority)
    if (serverVersion >= localCheckpoint.version) {
      return (serverState, serverPayload, 'server_authoritative_sync');
    }

    // 4. إذا كانت النسخة المحلية متطابقة
    return (localCheckpoint.state, localCheckpoint.payload, 'restored_from_checkpoint');
  }
}
