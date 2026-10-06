import '../domain/entities/risk_context.dart';
import '../domain/entities/risk_signal.dart';
import '../domain/entities/risk_decision.dart';
import '../domain/entities/risk_evaluation.dart';
import '../domain/entities/risk_policy.dart';
import '../domain/enums/risk_enums.dart';
import '../domain/services/velocity_engine.dart';
import '../domain/services/device_trust_engine.dart';
import '../domain/services/coupon_abuse_engine.dart';
import '../domain/services/wallet_abuse_engine.dart';
import '../domain/services/cancellation_abuse_engine.dart';
import '../domain/services/behavioral_anomaly_engine.dart';
import '../domain/services/collusion_signal_engine.dart';
import '../domain/services/risk_signal_aggregator.dart';
import '../domain/services/risk_scoring_engine.dart';
import '../domain/services/challenge_engine.dart';
import '../domain/services/fraud_case_engine.dart';
import '../domain/repositories/i_risk_repository.dart';
import '../data/repositories/risk_repository.dart';

import 'package:dalal_alqaim/core/orchestration/domain/services/domain_event_bus.dart';
import 'package:dalal_alqaim/core/orchestration/domain/entities/domain_event.dart';
import 'package:dalal_alqaim/core/security/application/security_engine.dart';
import 'package:dalal_alqaim/core/notifications/application/notification_engine.dart';

/// المحرك الأمني المركزي لكشف المخاطر والاحتيال (MADAR Risk Intelligence Engine)
class RiskIntelligenceEngine {
  static RiskIntelligenceEngine? _instance;
  static RiskIntelligenceEngine get instance => _instance ??= RiskIntelligenceEngine();

  final IRiskRepository _repository;
  final VelocityEngine _velocityEngine;
  final DeviceTrustEngine _deviceTrustEngine;
  final CouponAbuseEngine _couponAbuseEngine;
  final WalletAbuseEngine _walletAbuseEngine;
  final CancellationAbuseEngine _cancellationAbuseEngine;
  final BehavioralAnomalyEngine _behavioralAnomalyEngine;
  final CollusionSignalEngine _collusionSignalEngine;
  final ChallengeEngine _challengeEngine;
  final DomainEventBus _eventBus;
  final SecurityEngine _securityEngine;
  final NotificationEngine _notificationEngine;

  RiskIntelligenceEngine({
    IRiskRepository? repository,
    VelocityEngine? velocityEngine,
    DeviceTrustEngine? deviceTrustEngine,
    CouponAbuseEngine? couponAbuseEngine,
    WalletAbuseEngine? walletAbuseEngine,
    CancellationAbuseEngine? cancellationAbuseEngine,
    BehavioralAnomalyEngine? behavioralAnomalyEngine,
    CollusionSignalEngine? collusionSignalEngine,
    ChallengeEngine? challengeEngine,
    DomainEventBus? eventBus,
    SecurityEngine? securityEngine,
    NotificationEngine? notificationEngine,
  }) : _repository = repository ?? RiskRepository(),
        _velocityEngine = velocityEngine ?? VelocityEngine(),
        _deviceTrustEngine = deviceTrustEngine ?? DeviceTrustEngine(),
        _couponAbuseEngine = couponAbuseEngine ?? CouponAbuseEngine(),
        _walletAbuseEngine = walletAbuseEngine ?? WalletAbuseEngine(),
        _cancellationAbuseEngine = cancellationAbuseEngine ?? CancellationAbuseEngine(),
        _behavioralAnomalyEngine = behavioralAnomalyEngine ?? BehavioralAnomalyEngine(),
        _collusionSignalEngine = collusionSignalEngine ?? CollusionSignalEngine(),
        _challengeEngine = challengeEngine ?? ChallengeEngine(),
        _eventBus = eventBus ?? DomainEventBus.instance,
        _securityEngine = securityEngine ?? SecurityEngine.instance,
        _notificationEngine = notificationEngine ?? NotificationEngine.instance;

  VelocityEngine get velocityEngine => _velocityEngine;
  DeviceTrustEngine get deviceTrustEngine => _deviceTrustEngine;
  CouponAbuseEngine get couponAbuseEngine => _couponAbuseEngine;
  WalletAbuseEngine get walletAbuseEngine => _walletAbuseEngine;
  CancellationAbuseEngine get cancellationAbuseEngine => _cancellationAbuseEngine;
  BehavioralAnomalyEngine get behavioralAnomalyEngine => _behavioralAnomalyEngine;
  CollusionSignalEngine get collusionSignalEngine => _collusionSignalEngine;
  ChallengeEngine get challengeEngine => _challengeEngine;
  SecurityEngine get securityEngine => _securityEngine;
  NotificationEngine get notificationEngine => _notificationEngine;

  /// تقييم شامل للمخاطر مع تسجيل حتمي للأدلة والأحداث
  Future<RiskDecision> evaluateOperationRisk({
    required RiskContext context,
    List<RiskSignal> externalSignals = const [],
    int trustDiscount = 0,
    RiskPolicy? policy,
  }) async {
    // 1. فحص عدم التكرار (Idempotency Check)
    final isUnique = await _repository.verifyIdempotencyKey(context.idempotencyKey);
    if (!isUnique) {
      // إرجاع القرار الموثق مسبقاً لمنع المعالجة المزدوجة
      final existingEval = await _repository.getRiskEvaluation(context.riskEvaluationId);
      if (existingEval != null) {
        return existingEval.decision;
      }
    }

    final allSignals = List<RiskSignal>.from(externalSignals);

    // 2. تجميع إشارات الخطر واحتساب النتيجة المعيارية
    final score = RiskSignalAggregator.aggregateSignals(
      signals: allSignals,
      trustDiscount: trustDiscount,
      policyVersion: context.policyVersion,
      now: context.createdAt,
    );

    // 3. اتخاذ القرار الأمني الحتمي
    final decision = RiskScoringEngine.evaluateDecision(
      score: score,
      policy: policy,
    );

    // 4. حفظ تقييم المخاطر المنجز
    final evaluation = RiskEvaluation(
      evaluationId: context.riskEvaluationId,
      context: context,
      featuresHash: 'hash-${context.idempotencyKey}',
      signals: allSignals,
      score: score,
      decision: decision,
      policyVersion: context.policyVersion,
      durationMs: DateTime.now().difference(context.createdAt).inMilliseconds.abs(),
      status: RiskEvaluationStatus.completed,
      createdAt: context.createdAt,
    );
    await _repository.saveRiskEvaluation(evaluation);

    // 5. إنشاء قضية احتيال للمخاطر العالية والحرجة
    if (score.normalizedScore >= 60) {
      final fraudCase = FraudCaseEngine.evaluateAndCreateCase(
        subjectId: context.subjectId,
        subjectType: context.subjectType,
        score: score,
        signals: allSignals,
      );
      if (fraudCase != null) {
        await _repository.saveFraudCase(fraudCase);

        // نشر حدث النطاق للمراقبة
        await _eventBus.publish(
          DomainEvent(
            eventId: 'evt-fraud-${fraudCase.caseId}',
            eventType: 'FraudCaseCreated',
            aggregateId: fraudCase.caseId,
            aggregateType: 'FraudCase',
            transactionId: context.transactionId ?? 'tx-none',
            correlationId: context.correlationId,
            occurredAt: DateTime.now(),
            payload: fraudCase.toMap(),
          ),
        );
      }
    }

    // 6. نشر حدث التقييم
    await _eventBus.publish(
      DomainEvent(
        eventId: 'evt-risk-${evaluation.evaluationId}',
        eventType: 'RiskEvaluationCreated',
        aggregateId: evaluation.evaluationId,
        aggregateType: 'RiskEvaluation',
        transactionId: context.transactionId ?? 'tx-none',
        correlationId: context.correlationId,
        occurredAt: DateTime.now(),
        payload: {
          'subjectId': context.subjectId,
          'score': score.normalizedScore,
          'riskLevel': score.riskLevel.key,
          'decision': decision.decision.key,
          'action': decision.action.key,
        },
      ),
    );

    return decision;
  }
}
