// التعدادات والأنواع التشغيلية لمنظومة المراقبة ومركز العمليات (Observability Enums)

/// حالة المقطع الزمني للتتبع الموزع (Span Status)
enum SpanStatus {
  ok('ok'),
  error('error'),
  unset('unset');

  final String key;
  const SpanStatus(this.key);

  static SpanStatus fromString(String? val) {
    return SpanStatus.values.firstWhere(
      (e) => e.key == val || e.name == val,
      orElse: () => SpanStatus.unset,
    );
  }
}

/// حالة صحة الخدمة والاعتمادية (Health Status)
enum HealthStatus {
  healthy('healthy'),
  degraded('degraded'),
  unhealthy('unhealthy'),
  unknown('unknown');

  final String key;
  const HealthStatus(this.key);

  static HealthStatus fromString(String? val) {
    return HealthStatus.values.firstWhere(
      (e) => e.key == val || e.name == val,
      orElse: () => HealthStatus.unknown,
    );
  }
}

/// مستوى خطورة التنبيه التشغيلي (Alert Severity)
enum AlertSeverity {
  info('info'),
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  final String key;
  const AlertSeverity(this.key);

  static AlertSeverity fromString(String? val) {
    return AlertSeverity.values.firstWhere(
      (e) => e.key == val || e.name == val,
      orElse: () => AlertSeverity.info,
    );
  }
}

/// حالة التنبيه التشغيلي (Alert Status)
enum AlertStatus {
  active('active'),
  acknowledged('acknowledged'),
  resolved('resolved'),
  suppressed('suppressed');

  final String key;
  const AlertStatus(this.key);

  static AlertStatus fromString(String? val) {
    return AlertStatus.values.firstWhere(
      (e) => e.key == val || e.name == val,
      orElse: () => AlertStatus.active,
    );
  }
}

/// مستوى خطورة الحادث التشغيلي (Incident Severity)
enum IncidentSeverity {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  final String key;
  const IncidentSeverity(this.key);

  static IncidentSeverity fromString(String? val) {
    return IncidentSeverity.values.firstWhere(
      (e) => e.key == val || e.name == val,
      orElse: () => IncidentSeverity.medium,
    );
  }
}

/// حالة الحادث التشغيلي (Incident Status Lifecycle)
enum IncidentStatus {
  open('open'),
  acknowledged('acknowledged'),
  investigating('investigating'),
  mitigating('mitigating'),
  resolved('resolved'),
  closed('closed');

  final String key;
  const IncidentStatus(this.key);

  static IncidentStatus fromString(String? val) {
    return IncidentStatus.values.firstWhere(
      (e) => e.key == val || e.name == val,
      orElse: () => IncidentStatus.open,
    );
  }
}

/// نوع الخدمة والتبعية المراقبَة (Monitored Service Type)
enum ServiceType {
  firebaseAuth('firebase_auth'),
  firestore('firestore'),
  storage('storage'),
  notifications('notifications'),
  functions('functions'),
  realtimeTracking('realtime_tracking'),
  gps('gps'),
  network('network'),
  localCache('local_cache'),
  riskEngine('risk_engine'),
  dispatchEngine('dispatch_engine'),
  orderEngine('order_engine'),
  financialEngine('financial_engine');

  final String key;
  const ServiceType(this.key);

  static ServiceType fromString(String? val) {
    return ServiceType.values.firstWhere(
      (e) => e.key == val || e.name == val,
      orElse: () => ServiceType.firestore,
    );
  }
}

/// أنواع الإجراءات الإدارية والتشغيلية في سجل التدقيق (Operational Audit Actions)
enum AuditActionType {
  blockDriver('block_driver'),
  unblockDriver('unblock_driver'),
  refundTransaction('refund_transaction'),
  forceCancelOrder('force_cancel_order'),
  updateRiskPolicy('update_risk_policy'),
  acknowledgeIncident('acknowledge_incident'),
  mitigateIncident('mitigate_incident'),
  resolveIncident('resolve_incident'),
  triggerRecovery('trigger_recovery'),
  systemRecoveryJob('system_recovery_job');

  final String key;
  const AuditActionType(this.key);

  static AuditActionType fromString(String? val) {
    return AuditActionType.values.firstWhere(
      (e) => e.key == val || e.name == val,
      orElse: () => AuditActionType.triggerRecovery,
    );
  }
}
