// التعدادات والأنواع التشغيلية لنواة الصمود والتعافي (Resilience & Disaster Recovery Enums)

/// حالات قاطع الدائرة (Circuit Breaker State)
enum CircuitState {
  closed('closed'),
  open('open'),
  halfOpen('half_open');

  final String key;
  const CircuitState(this.key);

  static CircuitState fromString(String? val) {
    return CircuitState.values.firstWhere(
      (e) => e.key == val || e.name == val,
      orElse: () => CircuitState.closed,
    );
  }
}

/// حالة عنصر طابور العمليات غير المتصلة الدائم (Durable Queue Item Status)
enum QueueItemStatus {
  pending('pending'),
  inFlight('in_flight'),
  completed('completed'),
  failed('failed'),
  deadLetter('dead_letter');

  final String key;
  const QueueItemStatus(this.key);

  static QueueItemStatus fromString(String? val) {
    return QueueItemStatus.values.firstWhere(
      (e) => e.key == val || e.name == val,
      orElse: () => QueueItemStatus.pending,
    );
  }
}

/// أنواع حقن الأعطال واختبارات الفوضى (Failure Injection Types - Dev/Test Only)
enum FailureInjectionType {
  networkOffline('network_offline'),
  networkFlapping('network_flapping'),
  timeout('timeout'),
  firestoreUnavailable('firestore_unavailable'),
  slowResponse('slow_response'),
  duplicateResponse('duplicate_response'),
  outOfOrderEvents('out_of_order_events'),
  appCrash('app_crash'),
  backgroundServiceKill('background_service_kill'),
  processRestart('process_restart'),
  partialWrite('partial_write'),
  clockSkew('clock_skew'),
  financialRace('financial_race');

  final String key;
  const FailureInjectionType(this.key);

  static FailureInjectionType fromString(String? val) {
    return FailureInjectionType.values.firstWhere(
      (e) => e.key == val || e.name == val,
      orElse: () => FailureInjectionType.networkOffline,
    );
  }
}

/// حالة بوابة الجاهزية الإنتاجية (Production Readiness Gate Status)
enum ReadinessGateStatus {
  productionReady('production_ready'),
  productionBlocked('production_blocked'),
  warning('warning');

  final String key;
  const ReadinessGateStatus(this.key);

  static ReadinessGateStatus fromString(String? val) {
    return ReadinessGateStatus.values.firstWhere(
      (e) => e.key == val || e.name == val,
      orElse: () => ReadinessGateStatus.productionBlocked,
    );
  }
}

/// فئات التقييم الـ 12 للجاهزية الإنتاجية (Readiness Categories)
enum ReadinessCategory {
  functionalReliability('functional_reliability'),
  security('security'),
  financialIntegrity('financial_integrity'),
  concurrency('concurrency'),
  offlineRecovery('offline_recovery'),
  crashRecovery('crash_recovery'),
  observability('observability'),
  disasterRecovery('disaster_recovery'),
  configuration('configuration'),
  loadResilience('load_resilience'),
  chaosRecovery('chaos_recovery'),
  dataIntegrity('data_integrity');

  final String key;
  const ReadinessCategory(this.key);

  static ReadinessCategory fromString(String? val) {
    return ReadinessCategory.values.firstWhere(
      (e) => e.key == val || e.name == val,
      orElse: () => ReadinessCategory.functionalReliability,
    );
  }
}

/// الحالات التشغيلية الدقيقة لرحلة التاكسي (Hardened Ride Operational State)
enum RideOperationalState {
  requested('requested'),
  matching('matching'),
  driverAssigned('driver_assigned'),
  driverArriving('driver_arriving'),
  arrived('arrived'),
  tripStarted('trip_started'),
  tripCompleted('trip_completed'),
  settled('settled'),
  cancelled('cancelled'),
  expired('expired'),
  failed('failed'),
  recoveryRequired('recovery_required');

  final String key;
  const RideOperationalState(this.key);

  static RideOperationalState fromString(String? val) {
    return RideOperationalState.values.firstWhere(
      (e) => e.key == val || e.name == val,
      orElse: () => RideOperationalState.requested,
    );
  }
}

/// أنواع خروقات واختلالات سلامة البيانات (Integrity Violation Types)
enum IntegrityViolationType {
  negativeBalance('negative_balance'),
  orphanRecord('orphan_record'),
  duplicateTransaction('duplicate_transaction'),
  sequenceGap('sequence_gap'),
  brokenEvidenceHash('broken_evidence_hash'),
  brokenAuditHash('broken_audit_hash'),
  mismatchedTotal('mismatched_total'),
  illegalStateTransition('illegal_state_transition');

  final String key;
  const IntegrityViolationType(this.key);

  static IntegrityViolationType fromString(String? val) {
    return IntegrityViolationType.values.firstWhere(
      (e) => e.key == val || e.name == val,
      orElse: () => IntegrityViolationType.orphanRecord,
    );
  }
}
