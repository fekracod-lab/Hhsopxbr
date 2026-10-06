import '../entities/recovery_checkpoint.dart';
import '../entities/circuit_breaker_record.dart';
import '../entities/integrity_violation.dart';
import '../entities/disaster_recovery_snapshot.dart';
import '../entities/production_readiness_result.dart';

/// واجهة مستودع نواة الصمود والتعافي (IResilienceRepository)
abstract class IResilienceRepository {
  Future<void> saveCheckpoint(RecoveryCheckpoint checkpoint);
  Future<RecoveryCheckpoint?> getCheckpoint(String operationId);
  Future<void> saveCircuitBreaker(CircuitBreakerRecord breaker);
  Future<CircuitBreakerRecord?> getCircuitBreaker(String serviceKey);
  Future<void> saveIntegrityViolation(IntegrityViolation violation);
  Future<List<IntegrityViolation>> getIntegrityViolations();
  Future<void> saveDisasterRecoverySnapshot(DisasterRecoverySnapshot snapshot);
  Future<DisasterRecoverySnapshot?> getLatestDisasterRecoverySnapshot(String domain);
  Future<void> saveProductionReadinessResult(ProductionReadinessResult result);
  Future<ProductionReadinessResult?> getLatestProductionReadinessResult();
}
