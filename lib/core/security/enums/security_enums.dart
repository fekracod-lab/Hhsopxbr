/// تصنيف حساسية البيانات (Data Classification)
enum DataClassification {
  public('public', 1),
  internal('internal', 2),
  confidential('confidential', 3),
  sensitive('sensitive', 4),
  highlySensitive('highly_sensitive', 5);

  final String key;
  final int sensitivityLevel;
  const DataClassification(this.key, this.sensitivityLevel);

  bool get requiresMasking => sensitivityLevel >= 4;
  bool get requiresEncryption => sensitivityLevel >= 4;
  bool get isStrictlyConfidential => sensitivityLevel >= 3;
}

/// مستوى خطورة التهديد أو الخرق الأمني (Threat Severity)
enum ThreatSeverity {
  low('low', 1),
  medium('medium', 2),
  high('high', 3),
  critical('critical', 4);

  final String key;
  final int level;
  const ThreatSeverity(this.key, this.level);

  bool get isBlocking => level >= 3;
  bool get requiresImmediateAlert => level >= 3;
}

/// حالة بوابة الجاهزية الأمنية (Security Readiness Gate Status)
enum SecurityGateStatus {
  securityReady('security_ready'),
  securityWarning('security_warning'),
  securityBlocked('security_blocked');

  final String key;
  const SecurityGateStatus(this.key);

  bool get isPassed => this == SecurityGateStatus.securityReady;
  bool get isBlocked => this == SecurityGateStatus.securityBlocked;
}

/// فئات فحص وتدقيق الجاهزية الأمنية الـ 14 (Security Gate Categories)
enum SecurityGateCategory {
  authentication('authentication', 'المصادقة والتحقق من الهوية'),
  authorization('authorization', 'التفويض وسياسة Zero-Trust'),
  rbac('rbac', 'الأدوار والصلاحيات الدقيقة RBAC'),
  firestoreSecurity('firestore_security', 'قواعد أمان وتصاريح Firestore'),
  storageSecurity('storage_security', 'أمان وتصاريح Firebase Storage'),
  secretProtection('secret_protection', 'حماية الأسرار والمفاتيح'),
  piiProtection('pii_protection', 'حماية وخصوصية البيانات الشخصية PII'),
  sessionSecurity('session_security', 'أمان الجلسات وإعادة المصادقة'),
  abuseProtection('abuse_protection', 'حماية إساءة الاستخدام وتحديد المعدل Rate Limiting'),
  financialSecurity('financial_security', 'الأمان المالي والتحصين ضد التلاعب'),
  auditability('auditability', 'سجلات التدقيق غير القابلة للتغيير'),
  securityTesting('security_testing', 'تغطية الاختبارات الأمنية والهجومية'),
  configurationSecurity('configuration_security', 'إعدادات وبيئة الإنتاج المحصنة'),
  dependencySecurity('dependency_security', 'أمان التبعيات والمكتبات');

  final String key;
  final String label;
  const SecurityGateCategory(this.key, this.label);
}

/// حالة الجلسة الأمنية (Session State)
enum SecuritySessionState {
  active('active'),
  expired('expired'),
  revoked('revoked'),
  challengeRequired('challenge_required');

  final String key;
  const SecuritySessionState(this.key);

  bool get isValid => this == SecuritySessionState.active;
}

/// نوع التهديد أو الخرق الأمني (Security Event Type)
enum SecurityEventType {
  unauthorizedAccess('unauthorized_access'),
  permissionDenied('permission_denied'),
  privilegeEscalationAttempt('privilege_escalation_attempt'),
  suspiciousLogin('suspicious_login'),
  repeatedOtpFailures('repeated_otp_failures'),
  abnormalWalletOperation('abnormal_wallet_operation'),
  suspiciousRefund('suspicious_refund'),
  invalidRoleMutation('invalid_role_mutation'),
  firestoreRuleDenial('firestore_rule_denial'),
  tokenAnomaly('token_anomaly'),
  integrityViolation('integrity_violation'),
  rateLimitExceeded('rate_limit_exceeded'),
  secretLeakageAttempt('secret_leakage_attempt'),
  piiExposureDetected('pii_exposure_detected');

  final String key;
  const SecurityEventType(this.key);
}
