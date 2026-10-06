/// مستوى الخطورة الحتمي (Risk Level)
enum RiskLevel {
  trusted('trusted', minScore: 0, maxScore: 19),
  low('low', minScore: 20, maxScore: 39),
  medium('medium', minScore: 40, maxScore: 59),
  high('high', minScore: 60, maxScore: 79),
  critical('critical', minScore: 80, maxScore: 100);

  final String key;
  final int minScore;
  final int maxScore;
  const RiskLevel(this.key, {required this.minScore, required this.maxScore});

  static RiskLevel fromScore(int score) {
    final clamped = score.clamp(0, 100);
    for (final level in RiskLevel.values) {
      if (clamped >= level.minScore && clamped <= level.maxScore) {
        return level;
      }
    }
    return RiskLevel.trusted;
  }

  static RiskLevel fromString(String? val) {
    if (val == null || val.isEmpty) return RiskLevel.low;
    final normalized = val.trim().toLowerCase();
    for (final level in RiskLevel.values) {
      if (level.key == normalized) return level;
    }
    return RiskLevel.low;
  }
}

/// القرار النهائي للتقييم الأمني (Risk Decision)
enum RiskDecisionType {
  allow('allow'),
  challenge('challenge'),
  limit('limit'),
  review('review'),
  block('block');

  final String key;
  const RiskDecisionType(this.key);

  static RiskDecisionType fromString(String? val) {
    if (val == null || val.isEmpty) return RiskDecisionType.allow;
    final normalized = val.trim().toLowerCase();
    for (final dec in RiskDecisionType.values) {
      if (dec.key == normalized) return dec;
    }
    return RiskDecisionType.allow;
  }
}

/// الإجراء التشغيلي المطبق بناءً على المخاطر (Risk Action Type)
enum RiskActionType {
  allow('allow'),
  requireOtp('require_otp'),
  requireReauth('require_reauth'),
  applyRateLimit('apply_rate_limit'),
  temporaryLimit('temporary_limit'),
  flagForReview('flag_for_review'),
  blockOperation('block_operation'),
  freezeWalletOperation('freeze_wallet_operation'),
  escalateToAdmin('escalate_to_admin');

  final String key;
  const RiskActionType(this.key);
}

/// نوع إشارة الخطر المكتشفة (Risk Signal Type)
enum RiskSignalType {
  velocityLimitExceeded('velocity_limit_exceeded'),
  deviceAccountFarming('device_account_farming'),
  impossibleTravel('impossible_travel'),
  gpsTeleportation('gps_teleportation'),
  fakeLocationDetected('fake_location_detected'),
  couponAbuse('coupon_abuse'),
  walletRapidMutation('wallet_rapid_mutation'),
  repeatedFailedPayments('repeated_failed_payments'),
  cancellationSpam('cancellation_spam'),
  behavioralAnomaly('behavioral_anomaly'),
  collusionPattern('collusion_pattern'),
  untrustedAccount('untrusted_account'),
  tamperedPayload('tampered_payload');

  final String key;
  const RiskSignalType(this.key);
}

/// نوع الكيان الخاضع لتقييم المخاطر (Risk Subject Type)
enum RiskSubjectType {
  customer('customer'),
  driver('driver'),
  merchant('merchant'),
  device('device'),
  paymentInstrument('payment_instrument');

  final String key;
  const RiskSubjectType(this.key);

  static RiskSubjectType fromString(String? val) {
    if (val == null || val.isEmpty) return RiskSubjectType.customer;
    final normalized = val.trim().toLowerCase();
    for (final st in RiskSubjectType.values) {
      if (st.key == normalized) return st;
    }
    return RiskSubjectType.customer;
  }
}

/// مصدر إشارة الخطر (Risk Source)
enum RiskSource {
  client('client'),
  realtimeEngine('realtime_engine'),
  financialEngine('financial_engine'),
  orderEngine('order_engine'),
  dispatchEngine('dispatch_engine'),
  securityEngine('security_engine'),
  orchestrator('orchestrator');

  final String key;
  const RiskSource(this.key);
}

/// حالة عملية تقييم المخاطر (Risk Evaluation Status)
enum RiskEvaluationStatus {
  pending('pending'),
  completed('completed'),
  failed('failed');

  final String key;
  const RiskEvaluationStatus(this.key);
}

/// حالة قضية الاحتيال (Fraud Case Status)
enum FraudCaseStatus {
  open('open'),
  triaged('triaged'),
  underReview('under_review'),
  confirmed('confirmed'),
  dismissed('dismissed'),
  resolved('resolved');

  final String key;
  const FraudCaseStatus(this.key);

  static FraudCaseStatus fromString(String? val) {
    if (val == null || val.isEmpty) return FraudCaseStatus.open;
    final normalized = val.trim().toLowerCase();
    for (final st in FraudCaseStatus.values) {
      if (st.key == normalized) return st;
    }
    return FraudCaseStatus.open;
  }
}

/// درجة خطورة قضية الاحتيال (Fraud Case Severity)
enum FraudCaseSeverity {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  final String key;
  const FraudCaseSeverity(this.key);
}

/// النافذة الزمنية لاحتساب سرعة وتكرار العمليات (Velocity Window)
enum VelocityWindow {
  oneMinute('1m', duration: Duration(minutes: 1)),
  fiveMinutes('5m', duration: Duration(minutes: 5)),
  fifteenMinutes('15m', duration: Duration(minutes: 15)),
  oneHour('1h', duration: Duration(hours: 1)),
  twentyFourHours('24h', duration: Duration(hours: 24)),
  sevenDays('7d', duration: Duration(days: 7));

  final String key;
  final Duration duration;
  const VelocityWindow(this.key, {required this.duration});
}

/// مستوى موثوقية الجهاز (Device Trust Level)
enum DeviceTrustLevel {
  trusted('trusted'),
  neutral('neutral'),
  suspicious('suspicious'),
  blocked('blocked');

  final String key;
  const DeviceTrustLevel(this.key);
}

/// نوع التحدي الأمني المطلوب (Challenge Type)
enum ChallengeType {
  otp('otp'),
  reauth('reauth'),
  captcha('captcha'),
  biometric('biometric'),
  adminVerification('admin_verification');

  final String key;
  const ChallengeType(this.key);
}

/// نوع الدليل الأمني المحفوظ (Evidence Type)
enum EvidenceType {
  gpsTrace('gps_trace'),
  velocityAudit('velocity_audit'),
  deviceFingerprint('device_fingerprint'),
  financialLog('financial_log'),
  couponExploit('coupon_exploit'),
  behaviorSnapshot('behavior_snapshot');

  final String key;
  const EvidenceType(this.key);
}
