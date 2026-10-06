import '../datasources/security_local_datasource.dart';
import '../datasources/security_remote_datasource.dart';
import '../entities/security_event.dart';
import '../entities/security_audit_result.dart';
import '../entities/security_readiness_result.dart';
import 'i_security_repository.dart';

/// مستودع الأمان والخصوصية (Security Repository Implementation)
class SecurityRepository implements ISecurityRepository {
  final SecurityLocalDatasource localDatasource;
  final SecurityRemoteDatasource remoteDatasource;

  SecurityRepository({
    SecurityLocalDatasource? localDatasource,
    SecurityRemoteDatasource? remoteDatasource,
  }) : localDatasource = localDatasource ?? SecurityLocalDatasource(),
        remoteDatasource = remoteDatasource ?? const SecurityRemoteDatasource();

  @override
  Future<void> saveSecurityEvent(SecurityEventRecord event) async {
    await localDatasource.cacheSecurityEvent(event);
    try {
      await remoteDatasource.persistSecurityEvent(event);
    } catch (_) {
      // Graceful local cache fallback
    }
  }

  @override
  Future<List<SecurityEventRecord>> getRecentSecurityEvents({int limit = 50}) async {
    return localDatasource.getRecentSecurityEvents(limit: limit);
  }

  @override
  Future<void> saveAuditResult(SecurityAuditResult result) async {
    await localDatasource.cacheAuditResult(result);
  }

  @override
  Future<SecurityAuditResult?> getLatestAuditResult() async {
    return localDatasource.getLatestAuditResult();
  }

  @override
  Future<void> saveReadinessAudit(SecurityReadinessResult result) async {
    await localDatasource.cacheReadinessAudit(result);
    try {
      await remoteDatasource.persistReadinessAudit(result);
    } catch (_) {
      // Graceful fallback
    }
  }

  @override
  Future<SecurityReadinessResult?> getLatestReadinessAudit() async {
    return localDatasource.getLatestReadinessAudit();
  }
}
