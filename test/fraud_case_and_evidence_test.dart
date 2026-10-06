import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/risk/domain/entities/risk_score.dart';
import 'package:dalal_alqaim/core/risk/domain/entities/risk_signal.dart';
import 'package:dalal_alqaim/core/risk/domain/enums/risk_enums.dart';
import 'package:dalal_alqaim/core/risk/domain/services/fraud_case_engine.dart';
import 'package:dalal_alqaim/core/risk/domain/services/risk_evidence_engine.dart';

void main() {
  group('Fraud Case & Immutable Evidence Dedicated Tests', () {
    test('1. Creates fraud case only when score >= 60', () {
      final now = DateTime.now();

      final lowScore = RiskScore(
        rawScore: 30,
        normalizedScore: 30,
        riskLevel: RiskLevel.low,
        policyVersion: 'v1.0.0',
        calculatedAt: now,
      );

      final noCase = FraudCaseEngine.evaluateAndCreateCase(
        subjectId: 'user_low',
        subjectType: RiskSubjectType.customer,
        score: lowScore,
        signals: [],
      );
      expect(noCase, isNull);

      final highScore = RiskScore(
        rawScore: 85,
        normalizedScore: 85,
        riskLevel: RiskLevel.critical,
        policyVersion: 'v1.0.0',
        calculatedAt: now,
      );

      final criticalCase = FraudCaseEngine.evaluateAndCreateCase(
        subjectId: 'user_critical',
        subjectType: RiskSubjectType.customer,
        score: highScore,
        signals: [
          RiskSignal(
            signalId: 'sig_1',
            type: RiskSignalType.impossibleTravel,
            source: RiskSource.securityEngine,
            subjectId: 'user_critical',
            severity: FraudCaseSeverity.critical,
            weight: 40,
            timestamp: now,
          ),
        ],
      );

      expect(criticalCase, isNotNull);
      expect(criticalCase!.severity, equals(FraudCaseSeverity.critical));
      expect(criticalCase.status, equals(FraudCaseStatus.open));
      expect(criticalCase.signalIds.length, equals(1));
    });

    test('2. Generates immutable evidence with SHA-256 payload hash', () {
      final evidence = RiskEvidenceEngine.createEvidence(
        caseId: 'case_100',
        type: EvidenceType.gpsTrace,
        source: RiskSource.realtimeEngine,
        correlationId: 'corr_100',
        rawData: {
          'driverId': 'drv_1',
          'speed': 120.0,
          'latitude': 33.3152,
          'longitude': 44.3661,
        },
      );

      expect(evidence.evidenceId.isNotEmpty, isTrue);
      expect(evidence.payloadHash.isNotEmpty, isTrue);
      expect(evidence.payloadHash.length, equals(64)); // SHA-256 64 hex chars
    });
  });
}
