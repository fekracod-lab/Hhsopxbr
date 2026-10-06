/// حالات تواجد واتصال السائق في الزمن الحقيقي (Driver Presence State)
enum DriverPresenceState {
  offline('offline'),
  connecting('connecting'),
  online('online'),
  available('available'),
  busy('busy'),
  onTrip('on_trip'),
  stale('stale'),
  reconnecting('reconnecting'),
  suspended('suspended');

  final String key;
  const DriverPresenceState(this.key);

  static DriverPresenceState fromString(String? val) {
    if (val == null || val.isEmpty) return DriverPresenceState.offline;
    final normalized = val.trim().toLowerCase();
    for (final state in DriverPresenceState.values) {
      if (state.key == normalized) return state;
    }
    return DriverPresenceState.offline;
  }

  /// هل السائق متاح للتوزيع وقبول عروض جديدة؟
  bool get isAvailableForDispatch => this == DriverPresenceState.available;

  /// هل السائق متصل بالنظام؟
  bool get isOnline =>
      this == DriverPresenceState.online ||
      this == DriverPresenceState.available ||
      this == DriverPresenceState.busy ||
      this == DriverPresenceState.onTrip;
}

/// حالة نبض الاتصال (Heartbeat Status)
enum HeartbeatStatus {
  healthy('healthy'),
  delayed('delayed'),
  stale('stale'),
  offline('offline'),
  rejected('rejected');

  final String key;
  const HeartbeatStatus(this.key);
}

/// درجة موثوقية إحداثيات الموقع (Location Confidence)
enum LocationConfidence {
  valid('valid'),
  degraded('degraded'),
  suspicious('suspicious'),
  rejected('rejected');

  final String key;
  const LocationConfidence(this.key);
}

/// حالة جلسة التتبع المباشر (Tracking Session Status)
enum TrackingSessionStatus {
  active('active'),
  paused('paused'),
  completed('completed'),
  cancelled('cancelled'),
  stale('stale');

  final String key;
  const TrackingSessionStatus(this.key);

  static TrackingSessionStatus fromString(String? val) {
    if (val == null || val.isEmpty) return TrackingSessionStatus.active;
    final normalized = val.trim().toLowerCase();
    for (final st in TrackingSessionStatus.values) {
      if (st.key == normalized) return st;
    }
    return TrackingSessionStatus.active;
  }
}

/// حالة اتصال الجهاز بالشبكة والخادم (Connection Status)
enum ConnectionStatus {
  connected('connected'),
  disconnected('disconnected'),
  reconnecting('reconnecting');

  final String key;
  const ConnectionStatus(this.key);
}

/// حالة ترتيب الأحداث الزمنية (Event Sequence Status)
enum EventSequenceStatus {
  inOrder('in_order'),
  duplicate('duplicate'),
  stale('stale'),
  outOfOrder('out_of_order'),
  gapDetected('gap_detected');

  final String key;
  const EventSequenceStatus(this.key);
}

/// إجراءات التعافي اللحظي للعمليات المباشرة (Realtime Recovery Action)
enum RealtimeRecoveryAction {
  refreshState('refresh_state'),
  resyncStream('resync_stream'),
  reconcile('reconcile'),
  terminateSession('terminate_session'),
  manualIntervention('manual_intervention');

  final String key;
  const RealtimeRecoveryAction(this.key);
}
