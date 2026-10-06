import '../entities/security_audit_result.dart';
import '../enums/security_enums.dart';

/// محرك التدقيق الأمني التلقائي (Automated Security Audit Engine)
class SecurityAuditEngine {
  const SecurityAuditEngine();

  /// فحص الإعدادات وتصاريح البيئة والقواعد الأمنية
  SecurityAuditResult auditEnvironmentSecurity({
    required bool isDebugMode,
    required bool allowMockServices,
    required bool isLocalhostEndpoint,
    required List<String> plaintextSecretFindings,
    required bool hasDenyByDefaultRules,
    required bool hasStorageOwnershipRules,
    DateTime? now,
  }) {
    final findings = <SecurityAuditFinding>[];
    final timestamp = now ?? DateTime.now();

    // 1. فحص وضع التطوير (Debug Mode)
    if (isDebugMode) {
      findings.add(
        const SecurityAuditFinding(
          findingId: 'AUDIT_001_DEBUG_FLAG',
          category: SecurityGateCategory.configurationSecurity,
          severity: ThreatSeverity.critical,
          location: 'Application Configuration',
          description: 'Production release candidate has debugMode enabled',
          recommendation: 'Disable debugMode before production release',
          isBlocker: true,
        ),
      );
    }

    // 2. فحص الخدمات الوهمية (Mock Services)
    if (allowMockServices) {
      findings.add(
        const SecurityAuditFinding(
          findingId: 'AUDIT_002_MOCK_SERVICES',
          category: SecurityGateCategory.configurationSecurity,
          severity: ThreatSeverity.critical,
          location: 'Application Configuration',
          description: 'Mock services and fake bypasses are enabled',
          recommendation: 'Ensure mock services are strictly blocked in production',
          isBlocker: true,
        ),
      );
    }

    // 3. فحص نقاط النهاية المحلية (Localhost API Endpoints)
    if (isLocalhostEndpoint) {
      findings.add(
        const SecurityAuditFinding(
          findingId: 'AUDIT_003_LOCALHOST_ENDPOINT',
          category: SecurityGateCategory.configurationSecurity,
          severity: ThreatSeverity.critical,
          location: 'Network Endpoints',
          description: 'Localhost or unencrypted HTTP endpoint configured',
          recommendation: 'Configure production HTTPS domain endpoints',
          isBlocker: true,
        ),
      );
    }

    // 4. فحص الأسرار والمفاتيح المكشوفة
    if (plaintextSecretFindings.isNotEmpty) {
      for (var i = 0; i < plaintextSecretFindings.length; i++) {
        findings.add(
          SecurityAuditFinding(
            findingId: 'AUDIT_004_SECRET_LEAK_$i',
            category: SecurityGateCategory.secretProtection,
            severity: ThreatSeverity.critical,
            location: 'Codebase / Config',
            description: plaintextSecretFindings[i],
            recommendation: 'Remove hardcoded secrets and use secure environment variables',
            isBlocker: true,
          ),
        );
      }
    }

    // 5. فحص قواعد Firestore (Deny-by-default)
    if (!hasDenyByDefaultRules) {
      findings.add(
        const SecurityAuditFinding(
          findingId: 'AUDIT_005_FIRESTORE_PERMISSIVE',
          category: SecurityGateCategory.firestoreSecurity,
          severity: ThreatSeverity.critical,
          location: 'firestore.rules',
          description: 'Firestore rules do not enforce strict deny-by-default authorization',
          recommendation: 'Apply match /{document=**} { allow read, write: if false; } catch-all',
          isBlocker: true,
        ),
      );
    }

    // 6. فحص قواعد Storage
    if (!hasStorageOwnershipRules) {
      findings.add(
        const SecurityAuditFinding(
          findingId: 'AUDIT_006_STORAGE_UNRESTRICTED',
          category: SecurityGateCategory.storageSecurity,
          severity: ThreatSeverity.high,
          location: 'storage.rules',
          description: 'Storage rules lack strict user ownership or content-type validation',
          recommendation: 'Enforce request.auth.uid ownership on user media uploads',
          isBlocker: false,
        ),
      );
    }

    // احتساب الدرجة الأمنية الإجمالية
    final criticalCount = findings.where((f) => f.severity == ThreatSeverity.critical).length;
    final highCount = findings.where((f) => f.severity == ThreatSeverity.high).length;
    final mediumCount = findings.where((f) => f.severity == ThreatSeverity.medium).length;

    double score = 100.0 - (criticalCount * 25.0) - (highCount * 10.0) - (mediumCount * 5.0);
    if (score < 0.0) score = 0.0;

    final gateStatus = criticalCount > 0
        ? SecurityGateStatus.securityBlocked
        : (highCount > 0 ? SecurityGateStatus.securityWarning : SecurityGateStatus.securityReady);

    return SecurityAuditResult(
      auditId: 'audit_${timestamp.millisecondsSinceEpoch}',
      auditedAt: timestamp,
      findings: findings,
      overallSecurityScore: score,
      status: gateStatus,
    );
  }
}
