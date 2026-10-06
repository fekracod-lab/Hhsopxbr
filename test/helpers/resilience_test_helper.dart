import 'package:dalal_alqaim/core/resilience/entities/recovery_checkpoint.dart';
import 'package:dalal_alqaim/core/resilience/entities/circuit_breaker_record.dart';
import 'package:dalal_alqaim/core/resilience/entities/integrity_violation.dart';
import 'package:dalal_alqaim/core/resilience/entities/disaster_recovery_snapshot.dart';
import 'package:dalal_alqaim/core/resilience/entities/production_readiness_result.dart';
import 'package:dalal_alqaim/core/resilience/repositories/i_resilience_repository.dart';

/// 🧪 مستودع ذاكري لاختبارات الصمود والتعافي (In-Memory Resilience Repository)
class InMemoryResilienceRepository implements IResilienceRepository {
  final Map<String, RecoveryCheckpoint> checkpoints = {};
  final Map<String, CircuitBreakerRecord> circuitBreakers = {};
  final List<IntegrityViolation> integrityViolations = [];
  final Map<String, DisasterRecoverySnapshot> disasterSnapshots = {};
  ProductionReadinessResult? latestReadinessResult;

  @override
  Future<void> saveCheckpoint(RecoveryCheckpoint checkpoint) async {
    checkpoints[checkpoint.operationId] = checkpoint;
  }

  @override
  Future<RecoveryCheckpoint?> getCheckpoint(String operationId) async {
    return checkpoints[operationId];
  }

  @override
  Future<void> saveCircuitBreaker(CircuitBreakerRecord breaker) async {
    circuitBreakers[breaker.serviceKey] = breaker;
  }

  @override
  Future<CircuitBreakerRecord?> getCircuitBreaker(String serviceKey) async {
    return circuitBreakers[serviceKey];
  }

  @override
  Future<void> saveIntegrityViolation(IntegrityViolation violation) async {
    integrityViolations.add(violation);
  }

  @override
  Future<List<IntegrityViolation>> getIntegrityViolations() async {
    return List.unmodifiable(integrityViolations);
  }

  @override
  Future<void> saveDisasterRecoverySnapshot(DisasterRecoverySnapshot snapshot) async {
    disasterSnapshots[snapshot.snapshotId] = snapshot;
  }

  @override
  Future<DisasterRecoverySnapshot?> getLatestDisasterRecoverySnapshot(String domain) async {
    final filtered = disasterSnapshots.values.where((s) => s.domain == domain).toList();
    if (filtered.isEmpty) return null;
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered.first;
  }

  @override
  Future<void> saveProductionReadinessResult(ProductionReadinessResult result) async {
    latestReadinessResult = result;
  }

  @override
  Future<ProductionReadinessResult?> getLatestProductionReadinessResult() async {
    return latestReadinessResult;
  }

  void clear() {
    checkpoints.clear();
    circuitBreakers.clear();
    integrityViolations.clear();
    disasterSnapshots.clear();
    latestReadinessResult = null;
  }
}
