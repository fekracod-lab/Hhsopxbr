import '../entities/recovery_checkpoint.dart';
import '../entities/circuit_breaker_record.dart';

/// مصدر البيانات المحلي الدائم للصمود والتعافي (Resilience Local DataSource)
class ResilienceLocalDatasource {
  final Map<String, RecoveryCheckpoint> _localCheckpoints = {};
  final Map<String, CircuitBreakerRecord> _localBreakers = {};

  ResilienceLocalDatasource();

  Future<void> saveCheckpoint(RecoveryCheckpoint checkpoint) async {
    _localCheckpoints[checkpoint.operationId] = checkpoint;
  }

  Future<RecoveryCheckpoint?> getCheckpoint(String operationId) async {
    return _localCheckpoints[operationId];
  }

  Future<void> saveCircuitBreaker(CircuitBreakerRecord breaker) async {
    _localBreakers[breaker.serviceKey] = breaker;
  }

  Future<CircuitBreakerRecord?> getCircuitBreaker(String serviceKey) async {
    return _localBreakers[serviceKey];
  }

  void clear() {
    _localCheckpoints.clear();
    _localBreakers.clear();
  }
}
