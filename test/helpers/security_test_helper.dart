import 'package:dalal_alqaim/core/security/security.dart';

/// 🧪 مستودع اختبارات الأمان في الذاكرة (In-Memory Security Test Repository)
class InMemorySecurityRepository implements ISecurityRepository {
  final List<SecurityEventRecord> events = [];
  SecurityAuditResult? latestAudit;
  SecurityReadinessResult? latestReadiness;

  @override
  Future<void> saveSecurityEvent(SecurityEventRecord event) async {
    events.insert(0, event);
  }

  @override
  Future<List<SecurityEventRecord>> getRecentSecurityEvents({int limit = 50}) async {
    return events.take(limit).toList();
  }

  @override
  Future<void> saveAuditResult(SecurityAuditResult result) async {
    latestAudit = result;
  }

  @override
  Future<SecurityAuditResult?> getLatestAuditResult() async {
    return latestAudit;
  }

  @override
  Future<void> saveReadinessAudit(SecurityReadinessResult result) async {
    latestReadiness = result;
  }

  @override
  Future<SecurityReadinessResult?> getLatestReadinessAudit() async {
    return latestReadiness;
  }
}
