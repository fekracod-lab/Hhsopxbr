import '../entities/reconciliation_result.dart';
import '../entities/tracking_session.dart';

/// محرك مطابقة الاتساق وحل التضارب مع الخادم (Authoritative Reconciliation Engine)
class ReconciliationEngine {
  const ReconciliationEngine();

  /// مطابقة جلسة تتبع محلية مع الحالة المعتمدة على الخادم
  static (TrackingSession, ReconciliationResult) reconcileTrackingSession({
    required TrackingSession localSession,
    required TrackingSession? serverSession,
  }) {
    if (serverSession == null) {
      // الجلسة غير موجودة على الخادم
      return (
        localSession,
        ReconciliationResult(
          isConsistent: false,
          unreconciledCount: 1,
          resolvedConflicts: ['الجلسة غير موجودة على الخادم'],
          reconciledAt: DateTime.now(),
        ),
      );
    }

    final resolvedConflicts = <String>[];

    // قاعدة حتمية: الخادم هو المصدر الموثوق النهائي (Server Authority)
    TrackingSession effectiveSession = serverSession;

    if (serverSession.version >= localSession.version) {
      if (serverSession.status != localSession.status) {
        resolvedConflicts.add('تم تحديث حالة الجلسة من (${localSession.status.key}) إلى (${serverSession.status.key})');
      }
    } else {
      // الحالة المحلية أحدث ولكن غير مثبتة بعد على الخادم
      resolvedConflicts.add('الحالة المحلية تحتوي إصداراً أحدث (${localSession.version}) - اعتماد حالة الخادم الموثقة');
      effectiveSession = serverSession;
    }

    return (
      effectiveSession,
      ReconciliationResult(
        isConsistent: resolvedConflicts.isEmpty,
        unreconciledCount: resolvedConflicts.length,
        resolvedConflicts: resolvedConflicts,
        reconciledAt: DateTime.now(),
      ),
    );
  }
}
