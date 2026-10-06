import '../entities/security_event.dart';
import '../entities/security_audit_result.dart';
import '../entities/security_readiness_result.dart';

/// واجهة مستودع الأمان والخصوصية (Security Repository Contract)
abstract class ISecurityRepository {
  Future<void> saveSecurityEvent(SecurityEventRecord event);
  Future<List<SecurityEventRecord>> getRecentSecurityEvents({int limit = 50});
  Future<void> saveAuditResult(SecurityAuditResult result);
  Future<SecurityAuditResult?> getLatestAuditResult();
  Future<void> saveReadinessAudit(SecurityReadinessResult result);
  Future<SecurityReadinessResult?> getLatestReadinessAudit();
}
