/// حارس تدقيق إعدادات بيئة الإنتاج ومنع تسريب إعدادات التطوير (Production Config Guard)
class ProductionConfigGuard {
  const ProductionConfigGuard();

  /// فحص شامل لتهيئة بيئة الإنتاج وكشف أي ثغرات أو إعدادات تطوير معطلة للحماية
  (bool isSafe, List<String> blockingIssues, List<String> warnings) auditProductionConfig({
    required Map<String, dynamic> config,
  }) {
    final blockers = <String>[];
    final warnings = <String>[];

    // 1. فحص وضع التصحيح (Debug Mode)
    if (config['debugMode'] == true || config['isDebug'] == true) {
      blockers.add('Debug mode is enabled in production configuration');
    }

    // 2. فحص نقاط النهاية التجريبية (Test Endpoints / Localhost)
    final apiEndpoint = config['apiEndpoint']?.toString().toLowerCase() ?? '';
    if (apiEndpoint.contains('localhost') || apiEndpoint.contains('127.0.0.1') || apiEndpoint.contains('staging-test')) {
      blockers.add('Test or localhost API endpoint detected: $apiEndpoint');
    }

    // 3. فحص الخدمات الوهمية (Mock Repositories / Services)
    if (config['useMockServices'] == true || config['mockEnabled'] == true) {
      blockers.add('Mock services or repositories are enabled in production');
    }

    // 4. فحص حقن الفوضى (Chaos Injection)
    if (config['chaosInjectionEnabled'] == true) {
      blockers.add('Chaos/Failure injection is active in production configuration');
    }

    // 5. فحص المفاتيح النصية الصريحة (Plaintext Secrets)
    if (config.containsKey('firebaseApiKeyPlaintext') || config.containsKey('secretKeyPlaintext')) {
      blockers.add('Hardcoded plaintext secret detected in configuration map');
    }

    // 6. التحقق من وجود المتغيرات الإلزامية
    final requiredKeys = ['environment', 'apiEndpoint', 'firebaseProjectId', 'appVersion'];
    for (final key in requiredKeys) {
      if (!config.containsKey(key) || config[key] == null || config[key].toString().isEmpty) {
        blockers.add('Missing required production configuration key: $key');
      }
    }

    // 7. تحذيرات غير حرجة
    if (config['enableVerboseLogging'] == true) {
      warnings.add('Verbose logging is enabled; recommend disabling in production for optimal performance');
    }

    return (blockers.isEmpty, blockers, warnings);
  }
}
