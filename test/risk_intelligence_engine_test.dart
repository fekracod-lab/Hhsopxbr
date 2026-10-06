import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/risk/application/risk_intelligence_engine.dart';
import 'package:dalal_alqaim/core/risk/domain/entities/risk_context.dart';
import 'package:dalal_alqaim/core/risk/domain/entities/risk_signal.dart';
import 'package:dalal_alqaim/core/risk/domain/enums/risk_enums.dart';
import 'package:dalal_alqaim/core/orchestration/domain/services/domain_event_bus.dart';
import 'helpers/risk_test_helper.dart';

void main() {
  group('Risk Intelligence Engine Application Facade Tests', () {
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

    test('1. Clean request evaluates to Allowed and publishes event', () async {
      final now = DateTime.now();
      final ctx = RiskContext(
        riskEvaluationId: 'eval_clean_1',
        operationId: 'op_clean_1',
        correlationId: 'corr_clean_1',
        subjectId: 'user_good_1',
        subjectType: RiskSubjectType.customer,
        idempotencyKey: 'idemp_clean_1',
        createdAt: now,
      );

      final decision = await engine.evaluateOperationRisk(
        context: ctx,
        trustDiscount: 10,
      );

      expect(decision.allowed, isTrue);
      expect(decision.decision, equals(RiskDecisionType.allow));
      expect(repo.evaluations.containsKey('eval_clean_1'), isTrue);
    });

    test('2. Multi-signal critical threat yields Block and generates FraudCase', () async {
      final now = DateTime.now();
      final ctx = RiskContext(
        riskEvaluationId: 'eval_threat_1',
        operationId: 'op_threat_1',
        correlationId: 'corr_threat_1',
        subjectId: 'user_attacker_1',
        subjectType: RiskSubjectType.customer,
        idempotencyKey: 'idemp_threat_1',
        createdAt: now,
      );

      final signals = [
        RiskSignal(
          signalId: 'sig_1',
          type: RiskSignalType.impossibleTravel,
          source: RiskSource.securityEngine,
          subjectId: 'user_attacker_1',
          severity: FraudCaseSeverity.critical,
          weight: 45,
          timestamp: now,
        ),
        RiskSignal(
          signalId: 'sig_2',
          type: RiskSignalType.couponAbuse,
          source: RiskSource.orderEngine,
          subjectId: 'user_attacker_1',
          severity: FraudCaseSeverity.high,
          weight: 40,
          timestamp: now,
        ),
      ];

      final decision = await engine.evaluateOperationRisk(
        context: ctx,
        externalSignals: signals,
      );

      expect(decision.allowed, isFalse);
      expect(decision.decision, equals(RiskDecisionType.block));
      expect(decision.action, equals(RiskActionType.blockOperation));
      expect(repo.fraudCases.isNotEmpty, isTrue);
    });
  });
}
