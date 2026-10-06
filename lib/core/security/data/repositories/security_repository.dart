import '../../domain/entities/security_models.dart';
import '../../domain/repositories/i_security_repository.dart';
import '../datasources/security_remote_datasource.dart';

/// تطبيق مستودع الأمان والرقابة في مدار
class SecurityRepository implements ISecurityRepository {
  final SecurityRemoteDatasource _remoteDatasource;

  SecurityRepository({SecurityRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? SecurityRemoteDatasource();

  @override
  Future<RefundRequestEntity> submitRefundRequest(RefundRequestEntity request) {
    return _remoteDatasource.submitRefundRequest(request);
  }

  @override
  Future<List<RefundRequestEntity>> getUserRefundRequests(String userId) {
    return _remoteDatasource.getUserRefundRequests(userId);
  }

  @override
  Future<void> logSecurityViolation(SecurityViolation violation) {
    return _remoteDatasource.logSecurityViolation(violation);
  }

  @override
  Future<bool> verifyIdempotencyKey(String idempotencyKey) {
    return _remoteDatasource.verifyIdempotencyKey(idempotencyKey);
  }
}
