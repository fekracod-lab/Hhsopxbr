/// محرك إغلاق وحماية السجلات من تسريب البيانات الحساسة (Security Lockdown & Log Redaction Engine)
class SecurityLockdownEngine {
  static const Set<String> sensitiveKeys = {
    'password',
    'pass',
    'token',
    'accesstoken',
    'refreshtoken',
    'authorization',
    'otp',
    'otpcode',
    'secret',
    'apikey',
    'privatekey',
    'cvv',
    'cvn',
    'creditcard',
    'cardnumber',
    'ssn',
  };

  const SecurityLockdownEngine();

  /// تنظيف وتحجيم الخرائط والبيانات قبل تسجيلها (Redact & Sanitize)
  Map<String, dynamic> sanitizePayload(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};

    data.forEach((key, value) {
      final normalizedKey = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (sensitiveKeys.contains(normalizedKey)) {
        sanitized[key] = '[REDACTED_BY_SECURITY_LOCKDOWN]';
      } else if (value is Map) {
        sanitized[key] = sanitizePayload(Map<String, dynamic>.from(value));
      } else if (value is List) {
        sanitized[key] = value.map((item) {
          if (item is Map) {
            return sanitizePayload(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        sanitized[key] = value;
      }
    });

    return sanitized;
  }

  /// تنظيف النصوص الصريحة من كلمات المرور والرموز السرية
  String sanitizeLogMessage(String message) {
    var result = message;
    // استبدال أنماط الـ Bearer tokens أو OTPs
    result = result.replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9\-\._~\+\/]+=*', caseSensitive: false), 'Bearer [REDACTED_TOKEN]');
    result = result.replaceAll(RegExp(r'otp[=:\s]+[0-9]{4,6}', caseSensitive: false), 'otp: [REDACTED_OTP]');
    result = result.replaceAll(RegExp(r'password[=:\s]+[^\s,]+', caseSensitive: false), 'password: [REDACTED_PASSWORD]');
    return result;
  }
}
