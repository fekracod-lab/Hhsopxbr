import '../entities/security_event.dart';
import '../entities/security_audit_result.dart';
import '../entities/security_readiness_result.dart';

/// مصدر البيانات المحلي لسجلات ونتائج الأمان (Security Local Datasource)
class SecurityLocalDatasource {
  final List<SecurityEventRecord> _events = [];
  final Map<String, SecurityAuditResult> _audits = {};
  final Map<String, SecurityReadinessResult> _readinessAudits = {};

  Future<void> cacheSecurityEvent(SecurityEventRecord event) async {
    _events.insert(0, event);
    if (_events.length > 500) _events.removeLast();
  }

  Future<List<SecurityEventRecord>> getRecentSecurityEvents({int limit = 50}) async {
    return _events.take(limit).toList();
  }

  Future<void> cacheAuditResult(SecurityAuditResult result) async {
    _audits[result.auditId] = result;
  }

  Future<SecurityAuditResult?> getLatestAuditResult() async {
    if (_audits.isEmpty) return null;
    final sorted = _audits.values.toList()..sort((a, b) => b.auditedAt.compareTo(a.auditedAt));
    return sorted.first;
  }

  Future<void> cacheReadinessAudit(SecurityReadinessResult result) async {
    _readinessAudits[result.auditId] = result;
  }

  Future<SecurityReadinessResult?> getLatestReadinessAudit() async {
    if (_readinessAudits.isEmpty) return null;
    final sorted = _readinessAudits.values.toList()..sort((a, b) => b.auditedAt.compareTo(a.auditedAt));
    return sorted.first;
  }
}
