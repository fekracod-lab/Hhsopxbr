import '../entities/driver_presence.dart';
import '../enums/realtime_enums.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

/// محرك حوكمة تواجد وحالة السائقين في الزمن الحقيقي (Driver Presence Engine)
class DriverPresenceEngine {
  const DriverPresenceEngine();

  /// التحقق من أهلية السائق لاستقبال عروض التوزيع الفوري
  static bool isEligibleForDispatch({
    required DriverPresence presence,
    Duration maxStaleThreshold = const Duration(seconds: 90),
    DateTime? now,
  }) {
    if (!presence.state.isAvailableForDispatch) {
      return false; // ليس في حالة متاح
    }

    if (presence.activeOrdersCount > 0) {
      return false; // لديه طلبات نشطة (مشغول)
    }

    final currentTime = now ?? DateTime.now();
    final timeSinceHeartbeat = currentTime.difference(presence.lastHeartbeatAt).abs();
    if (timeSinceHeartbeat > maxStaleThreshold) {
      return false; // نبض الاتصال قديم وغير موثوق (Stale)
    }

    return true;
  }

  /// تنفيذ انتقال حالة التواجد مع فرض قواعد الأمان
  static DriverPresence transitionState({
    required DriverPresence current,
    required DriverPresenceState nextState,
    int? newActiveOrdersCount,
  }) {
    if (current.state == DriverPresenceState.suspended && nextState != DriverPresenceState.offline) {
      throw const SecurityViolationException(
        'لا يمكن للسائق الموقوف تغيير حالته إلا عبر الإدارة',
        type: SecurityViolationType.bannedUserAction,
        fieldName: 'driverPresenceState',
      );
    }

    final activeCount = newActiveOrdersCount ?? current.activeOrdersCount;

    // إذا أصبح لديه طلبات نشطة وهو متاح، يتحول تلقائياً إلى OnTrip أو Busy
    var effectiveState = nextState;
    if (activeCount > 0 && effectiveState == DriverPresenceState.available) {
      effectiveState = DriverPresenceState.busy;
    }

    return current.copyWith(
      state: effectiveState,
      activeOrdersCount: activeCount,
      updatedAt: DateTime.now(),
    );
  }
}
