import '../entities/recovery_checkpoint.dart';
import '../entities/circuit_breaker_record.dart';
import '../entities/integrity_violation.dart';
import '../entities/disaster_recovery_snapshot.dart';
import '../entities/production_readiness_result.dart';
import '../datasources/resilience_local_datasource.dart';
import '../datasources/resilience_remote_datasource.dart';
import 'i_resilience_repository.dart';

/// تطبيق مستودع الصمود والتعافي الشامل (ResilienceRepository Implementation)
class ResilienceRepository implements IResilienceRepository {
  final ResilienceLocalDatasource localDatasource;
  final ResilienceRemoteDatasource remoteDatasource;

  const ResilienceRepository({
    required this.localDatasource,
    required this.remoteDatasource,
  });

  @override
  Future<void> saveCheckpoint(RecoveryCheckpoint checkpoint) async {
    await localDatasource.saveCheckpoint(checkpoint);
    await remoteDatasource.saveCheckpoint(checkpoint);
  }

  @override
  Future<RecoveryCheckpoint?> getCheckpoint(String operationId) async {
    final local = await localDatasource.getCheckpoint(operationId);
    if (local != null) return local;
    return await remoteDatasource.getCheckpoint(operationId);
  }

  @override
  Future<void> saveCircuitBreaker(CircuitBreakerRecord breaker) async {
    await localDatasource.saveCircuitBreaker(breaker);
    await remoteDatasource.saveCircuitBreaker(breaker);
  }

  @override
  Future<CircuitBreakerRecord?> getCircuitBreaker(String serviceKey) async {
    final local = await localDatasource.getCircuitBreaker(serviceKey);
    if (local != null) return local;
    return await remoteDatasource.getCircuitBreaker(serviceKey);
  }

  @override
  Future<void> saveIntegrityViolation(IntegrityViolation violation) async {
    await remoteDatasource.saveIntegrityViolation(violation);
  }

  @override
  Future<List<IntegrityViolation>> getIntegrityViolations() async {
    return await remoteDatasource.getIntegrityViolations();
  }

  @override
  Future<void> saveDisasterRecoverySnapshot(DisasterRecoverySnapshot snapshot) async {
    await remoteDatasource.saveDisasterRecoverySnapshot(snapshot);
  }

  @override
  Future<DisasterRecoverySnapshot?> getLatestDisasterRecoverySnapshot(String domain) async {
    return await remoteDatasource.getLatestDisasterRecoverySnapshot(domain);
  }

  @override
  Future<void> saveProductionReadinessResult(ProductionReadinessResult result) async {
    await remoteDatasource.saveProductionReadinessResult(result);
  }

  @override
  Future<ProductionReadinessResult?> getLatestProductionReadinessResult() async {
    return await remoteDatasource.getLatestProductionReadinessResult();
  }
}
