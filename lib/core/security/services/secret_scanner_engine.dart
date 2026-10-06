/// محرك كشف الأسرار والمفاتيح والرموز الحساسة (Secret & Token Scanner Engine)
class SecretScannerEngine {
  const SecretScannerEngine();

  // Known patterns for secrets, private keys, JWTs, and API tokens
  static final RegExp _jwtPattern = RegExp(r'eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}');
  static final RegExp _apiKeyPattern = RegExp(r'(?:AIza|AKIA|sk_live|rk_live)[0-9A-Za-z-_]{16,}', caseSensitive: false);
  static final RegExp _privateKeyPattern = RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----');
  static final RegExp _otpPattern = RegExp(r'(?:otp|code)[\s:=]+(\d{4,6})', caseSensitive: false);

  /// فحص نص أو رسالة واكتشاف الأسرار المكشوفة
  List<String> scanStringForSecrets(String text) {
    final findings = <String>[];

    if (_privateKeyPattern.hasMatch(text)) {
      findings.add('Detected RSA/EC Private Key in plaintext string');
    }
    if (_apiKeyPattern.hasMatch(text)) {
      findings.add('Detected high-entropy API key signature in plaintext string');
    }
    if (_jwtPattern.hasMatch(text)) {
      findings.add('Detected JWT bearer token string in raw context');
    }
    if (_otpPattern.hasMatch(text)) {
      findings.add('Detected plaintext OTP code in raw text string');
    }

    return findings;
  }

  /// فحص هيكل Map بحثاً عن مفاتيح وأسرار حساسة مكشوفة
  List<String> scanMapForSensitiveData(Map<String, dynamic> data) {
    final findings = <String>[];
    final sensitiveKeys = {'password', 'secret', 'privatekey', 'token', 'cvv', 'cardnumber', 'jwt'};

    for (final entry in data.entries) {
      final keyLower = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (sensitiveKeys.contains(keyLower)) {
        final val = entry.value?.toString() ?? '';
        if (val.isNotEmpty && !val.contains('[REDACTED')) {
          findings.add('Plaintext sensitive field detected: [${entry.key}]');
        }
      }
      if (entry.value is Map) {
        findings.addAll(scanMapForSensitiveData(Map<String, dynamic>.from(entry.value as Map)));
      }
    }

    return findings;
  }

  /// حجب الأسرار والرموز الحساسة من النصوص التلقائية
  String redactSecretsFromText(String text) {
    var sanitized = text;
    sanitized = sanitized.replaceAll(_jwtPattern, '[REDACTED_JWT_TOKEN]');
    sanitized = sanitized.replaceAll(_apiKeyPattern, '[REDACTED_API_KEY]');
    sanitized = sanitized.replaceAll(_privateKeyPattern, '[REDACTED_PRIVATE_KEY]');
    return sanitized;
  }
}
