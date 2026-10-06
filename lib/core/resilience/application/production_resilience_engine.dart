import 'package:dalal_alqaim/core/orchestration/domain/services/domain_event_bus.dart';
import '../entities/recovery_checkpoint.dart';
import '../entities/offline_queue_item.dart';
import '../entities/retry_policy.dart';
import '../entities/retry_attempt.dart';
import '../entities/integrity_violation.dart';
import '../entities/disaster_recovery_snapshot.dart';
import '../entities/production_readiness_result.dart';
import '../enums/resilience_enums.dart';
import '../services/retry_engine.dart';
import '../services/circuit_breaker_engine.dart';
import '../services/idempotency_engine.dart';
import '../services/durable_offline_queue.dart';
import '../services/offline_replay_engine.dart';
import '../services/recovery_checkpoint_engine.dart';
import '../services/crash_recovery_engine.dart';
import '../services/transaction_state_machine.dart';
import '../services/financial_integrity_engine.dart';
import '../services/concurrency_guard_engine.dart';
import '../services/data_integrity_engine.dart';
import '../services/failure_injection_engine.dart';
import '../services/chaos_engine.dart';
import '../services/disaster_recovery_engine.dart';
import '../services/production_config_guard.dart';
import '../services/security_lockdown_engine.dart';
import '../services/production_readiness_engine.dart';
import '../repositories/i_resilience_repository.dart';

/// الواجهة المركزية المنفذة لنواة الصمود والتعافي والجاهزية الإنتاجية (Production Resilience Engine Facade)
class ProductionResilienceEngine {
  final RetryEngine retryEngine;
  final CircuitBreakerEngine circuitBreakerEngine;
  final IdempotencyEngine idempotencyEngine;
  final DurableOfflineQueue offlineQueue;
  final OfflineReplayEngine offlineReplayEngine;
  final RecoveryCheckpointEngine checkpointEngine;
  final CrashRecoveryEngine crashRecoveryEngine;
  final FinancialIntegrityEngine financialIntegrityEngine;
  final ConcurrencyGuardEngine concurrencyGuardEngine;
  final DataIntegrityEngine dataIntegrityEngine;
  final FailureInjectionEngine failureInjectionEngine;
  final ChaosEngine chaosEngine;
  final DisasterRecoveryEngine disasterRecoveryEngine;
  final ProductionConfigGuard configGuard;
  final SecurityLockdownEngine securityLockdownEngine;
  final ProductionReadinessEngine readinessEngine;
  final IResilienceRepository repository;
  final DomainEventBus? eventBus;

  factory ProductionResilienceEngine({
    RetryEngine? retryEngine,
    CircuitBreakerEngine? circuitBreakerEngine,
    IdempotencyEngine? idempotencyEngine,
    DurableOfflineQueue? offlineQueue,
    OfflineReplayEngine? offlineReplayEngine,
    RecoveryCheckpointEngine? checkpointEngine,
    CrashRecoveryEngine? crashRecoveryEngine,
    FinancialIntegrityEngine? financialIntegrityEngine,
    ConcurrencyGuardEngine? concurrencyGuardEngine,
    DataIntegrityEngine? dataIntegrityEngine,
    FailureInjectionEngine? failureInjectionEngine,
    ChaosEngine? chaosEngine,
    DisasterRecoveryEngine? disasterRecoveryEngine,
    ProductionConfigGuard? configGuard,
    SecurityLockdownEngine? securityLockdownEngine,
    ProductionReadinessEngine? readinessEngine,
    required IResilienceRepository repository,
    DomainEventBus? eventBus,
  }) {
    final breaker = circuitBreakerEngine ?? CircuitBreakerEngine();
    final idemp = idempotencyEngine ?? IdempotencyEngine();
    final queue = offlineQueue ?? DurableOfflineQueue();
    final checkpoint = checkpointEngine ?? RecoveryCheckpointEngine();
    final failure = failureInjectionEngine ?? FailureInjectionEngine();

    return ProductionResilienceEngine._(
      circuitBreakerEngine: breaker,
      idempotencyEngine: idemp,
      offlineQueue: queue,
      checkpointEngine: checkpoint,
      financialIntegrityEngine: financialIntegrityEngine ?? FinancialIntegrityEngine(idempotencyEngine: idemp),
      concurrencyGuardEngine: concurrencyGuardEngine ?? ConcurrencyGuardEngine(),
      dataIntegrityEngine: dataIntegrityEngine ?? const DataIntegrityEngine(),
      failureInjectionEngine: failure,
      configGuard: configGuard ?? const ProductionConfigGuard(),
      securityLockdownEngine: securityLockdownEngine ?? const SecurityLockdownEngine(),
      readinessEngine: readinessEngine ?? const ProductionReadinessEngine(),
      disasterRecoveryEngine: disasterRecoveryEngine ?? DisasterRecoveryEngine(),
      retryEngine: retryEngine ?? RetryEngine(circuitBreakerEngine: breaker),
      offlineReplayEngine: offlineReplayEngine ?? OfflineReplayEngine(queue: queue, idempotencyEngine: idemp),
      crashRecoveryEngine: crashRecoveryEngine ?? CrashRecoveryEngine(checkpointEngine: checkpoint),
      chaosEngine: chaosEngine ?? ChaosEngine(failureInjectionEngine: failure),
      repository: repository,
      eventBus: eventBus,
    );
  }

  const ProductionResilienceEngine._({
    required this.retryEngine,
    required this.circuitBreakerEngine,
    required this.idempotencyEngine,
    required this.offlineQueue,
    required this.offlineReplayEngine,
    required this.checkpointEngine,
    required this.crashRecoveryEngine,
    required this.financialIntegrityEngine,
    required this.concurrencyGuardEngine,
    required this.dataIntegrityEngine,
    required this.failureInjectionEngine,
    required this.chaosEngine,
    required this.disasterRecoveryEngine,
    required this.configGuard,
    required this.securityLockdownEngine,
    required this.readinessEngine,
    required this.repository,
    this.eventBus,
  });

  /// تنفيذ عملية مع حاول مرة ثانية وقاطع الدائرة
  Future<(T?, List<RetryAttempt>, String?)> executeResilientOperation<T>({
    required String serviceKey,
    required Future<T> Function() operation,
    RetryPolicy policy = const RetryPolicy(),
  }) {
    return retryEngine.executeWithRetry<T>(
      serviceKey: serviceKey,
      operation: operation,
      policy: policy,
    );
  }

  /// تنفيذ عملية مع الـ Idempotency الحصري
  Future<T> executeIdempotent<T>({
    required String idempotencyKey,
    required Future<T> Function() operation,
  }) {
    return idempotencyEngine.executeIdempotent<T>(
      idempotencyKey: idempotencyKey,
      operation: operation,
    );
  }

  /// إدراج عملية في طابور العمليات غير المتصلة الدائم
  Future<void> enqueueOfflineOperation(OfflineQueueItem item) async {
    final sanitizedPayload = securityLockdownEngine.sanitizePayload(item.payload);
    final sanitizedItem = item.copyWith(payload: sanitizedPayload);
    await offlineQueue.enqueue(sanitizedItem);
  }

  /// إعادة بث العمليات المعلقة بعد استعادة الاتصال
  Future<(int succeeded, int failed, int deadLettered)> replayOfflineOperations({
    required Future<bool> Function(OfflineQueueItem item) serverSender,
    DateTime? now,
  }) {
    return offlineReplayEngine.replayPendingOperations(serverSender: serverSender, now: now);
  }

  /// حفظ نقطة تفتيش تشغيلية واستمرارها محلياً وسحابياً
  Future<RecoveryCheckpoint> saveCheckpoint({
    required String operationId,
    required String domainType,
    required String state,
    int version = 1,
    required String correlationId,
    Map<String, dynamic> payload = const {},
    DateTime? now,
  }) async {
    final sanitized = securityLockdownEngine.sanitizePayload(payload);
    final checkpoint = await checkpointEngine.saveCheckpoint(
      operationId: operationId,
      domainType: domainType,
      state: state,
      version: version,
      correlationId: correlationId,
      payload: sanitized,
      now: now,
    );

    await repository.saveCheckpoint(checkpoint);
    return checkpoint;
  }

  /// التحقق من انتقال الحالة التشغيلية
  void validateRideTransition({
    required RideOperationalState from,
    required RideOperationalState to,
  }) {
    ResilienceTransactionStateMachine.validateRideTransition(from: from, to: to);
  }

  /// تنفيذ خصم مالي آمن ذرياً
  Future<(int newBalance, bool success, String? error)> executeSafeWalletDebit({
    required String walletId,
    required int amountMinor,
    required String transactionId,
    required String idempotencyKey,
  }) {
    return financialIntegrityEngine.atomicWalletDebit(
      walletId: walletId,
      amountMinor: amountMinor,
      transactionId: transactionId,
      idempotencyKey: idempotencyKey,
    );
  }

  /// محاولة الاستحواذ الحصري المتزامن
  Future<(bool won, String assignedWinnerId)> acquireExclusiveAssignment({
    required String resourceId,
    required String candidateId,
  }) {
    return concurrencyGuardEngine.acquireExclusiveAssignment(
      resourceId: resourceId,
      candidateId: candidateId,
    );
  }

  /// تسجيل وتخزين خرق لسلامة البيانات
  Future<void> recordIntegrityViolation(IntegrityViolation violation) async {
    await repository.saveIntegrityViolation(violation);
  }

  /// إنشاء لقطة تعافي من الكوارث وحفظها
  Future<DisasterRecoverySnapshot> createAndSaveDisasterRecoverySnapshot({
    required String domain,
    required List<Map<String, dynamic>> records,
    DateTime? now,
  }) async {
    final snapshot = disasterRecoveryEngine.createSnapshot(
      domain: domain,
      records: records,
      now: now,
    );
    await repository.saveDisasterRecoverySnapshot(snapshot);
    return snapshot;
  }

  /// إجراء تقييم الجاهزية الإنتاجية وتوثيقه
  Future<ProductionReadinessResult> runProductionReadinessGateAudit({
    required Map<ReadinessCategory, double> categoryScores,
    required Map<ReadinessCategory, List<String>> categoryBlockers,
    required Map<ReadinessCategory, List<String>> categoryWarnings,
    DateTime? now,
  }) async {
    final result = readinessEngine.evaluateSystemReadiness(
      categoryScores: categoryScores,
      categoryBlockers: categoryBlockers,
      categoryWarnings: categoryWarnings,
      now: now,
    );

    await repository.saveProductionReadinessResult(result);
    return result;
  }
}
