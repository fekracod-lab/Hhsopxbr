import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/risk/application/risk_intelligence_engine.dart';
import 'package:dalal_alqaim/core/risk/domain/entities/risk_context.dart';
import 'package:dalal_alqaim/core/risk/domain/entities/risk_signal.dart';
import 'package:dalal_alqaim/core/risk/domain/enums/risk_enums.dart';
import 'package:dalal_alqaim/core/risk/domain/services/risk_signal_aggregator.dart';
import 'package:dalal_alqaim/core/orchestration/domain/services/domain_event_bus.dart';
import 'helpers/risk_test_helper.dart';

void main() {
  group('Risk Adversarial, Concurrency & Chaos Tests', () {
    late InMemoryRiskRepository repo;
    late DomainEventBus eventBus;
    late RiskIntelligenceEngine engine;

    setUp(() {
      repo = InMemoryRiskRepository();
      eventBus = DomainEventBus();
      engine = RiskIntelligenceEngine(
        repository: repo,
        eventBus: eventBus,
      );
    });

    test('1. Attack 01: 50 duplicate requests with identical idempotencyKey result in exactly 1 evaluation', () async {
      final now = DateTime.now();
      final ctx = RiskContext(
        riskEvaluationId: 'eval_idemp_1',
        operationId: 'op_idemp_1',
        correlationId: 'corr_idemp_1',
        subjectId: 'user_dup_1',
        subjectType: RiskSubjectType.customer,
        idempotencyKey: 'key_fixed_123',
        createdAt: now,
      );

      final firstDecision = await engine.evaluateOperationRisk(context: ctx);
      expect(firstDecision.allowed, isTrue);

      // Repeat 49 times
      for (int i = 0; i < 49; i++) {
        final repeatedDecision = await engine.evaluateOperationRisk(context: ctx);
        expect(repeatedDecision.decision, equals(firstDecision.decision));
      }

      expect(repo.evaluations.length, equals(1));
    });

    test('2. Concurrency: 20 simultaneous distinct evaluations executed without race condition', () async {
      final now = DateTime.now();

      final futures = List.generate(20, (i) {
        final ctx = RiskContext(
          riskEvaluationId: 'eval_concurrent_$i',
          operationId: 'op_concurrent_$i',
          correlationId: 'corr_concurrent_$i',
          subjectId: 'user_concurrent_$i',
          subjectType: RiskSubjectType.customer,
          idempotencyKey: 'idemp_concurrent_$i',
          createdAt: now,
        );

        return engine.evaluateOperationRisk(context: ctx);
      });

      final results = await Future.wait(futures);

      expect(results.length, equals(20));
      expect(repo.evaluations.length, equals(20));
    });

    test('3. Multi-Signal Deduplication: 10 duplicate signals of the same type do not explode the score', () {
      final now = DateTime.now();
      final duplicatedSignals = List.generate(10, (i) {
        return RiskSignal(
          signalId: 'sig_dup_$i',
          type: RiskSignalType.gpsTeleportation,
          source: RiskSource.realtimeEngine,
          subjectId: 'drv_jump',
          severity: FraudCaseSeverity.medium,
          weight: 20,
          timestamp: now,
        );
      });

      final score = RiskSignalAggregator.aggregateSignals(signals: duplicatedSignals);

      // Deduplication retains single max weight (20) instead of 10 * 20 = 200
      expect(score.rawScore, equals(20));
      expect(score.normalizedScore, equals(20));
      expect(score.riskLevel, equals(RiskLevel.low));
    });
  });
}
