import 'package:dalal_alqaim/core/risk/domain/entities/risk_evaluation.dart';
import 'package:dalal_alqaim/core/risk/domain/entities/risk_signal.dart';
import 'package:dalal_alqaim/core/risk/domain/entities/device_trust_record.dart';
import 'package:dalal_alqaim/core/risk/domain/entities/velocity_record.dart';
import 'package:dalal_alqaim/core/risk/domain/entities/fraud_case.dart';
import 'package:dalal_alqaim/core/risk/domain/entities/fraud_evidence.dart';
import 'package:dalal_alqaim/core/risk/domain/entities/risk_policy.dart';
import 'package:dalal_alqaim/core/risk/domain/repositories/i_risk_repository.dart';

/// 🧪 مستودع ذاكرة افتراضي لاختبارات محرك المخاطر والاحتيال
class InMemoryRiskRepository implements IRiskRepository {
  final Map<String, RiskEvaluation> evaluations = {};
  final List<RiskSignal> signals = [];
  final Map<String, DeviceTrustRecord> devices = {};
  final List<VelocityRecord> velocityRecords = [];
  final Map<String, FraudCase> fraudCases = {};
  final List<FraudEvidence> evidenceList = [];
  final Map<String, RiskPolicy> policies = {};
  final Set<String> _usedIdempotencyKeys = {};

  @override
  Future<void> saveRiskEvaluation(RiskEvaluation evaluation) async {
    evaluations[evaluation.evaluationId] = evaluation;
    _usedIdempotencyKeys.add(evaluation.context.idempotencyKey);
  }

  @override
  Future<RiskEvaluation?> getRiskEvaluation(String evaluationId) async {
    return evaluations[evaluationId];
  }

  @override
  Future<void> saveRiskSignal(RiskSignal signal) async {
    signals.add(signal);
  }

  @override
  Future<void> saveDeviceTrustRecord(DeviceTrustRecord record) async {
    devices[record.deviceId] = record;
  }

  @override
  Future<DeviceTrustRecord?> getDeviceTrustRecord(String deviceId) async {
    return devices[deviceId];
  }

  @override
  Future<void> saveVelocityRecord(VelocityRecord record) async {
    velocityRecords.add(record);
  }

  @override
  Future<void> saveFraudCase(FraudCase fraudCase) async {
    fraudCases[fraudCase.caseId] = fraudCase;
  }

  @override
  Future<FraudCase?> getFraudCase(String caseId) async {
    return fraudCases[caseId];
  }

  @override
  Future<void> saveFraudEvidence(FraudEvidence evidence) async {
    evidenceList.add(evidence);
  }

  @override
  Future<RiskPolicy?> getEffectivePolicy(String policyId) async {
    return policies[policyId];
  }

  @override
  Future<bool> verifyIdempotencyKey(String idempotencyKey) async {
    return !_usedIdempotencyKeys.contains(idempotencyKey);
  }

  void clear() {
    evaluations.clear();
    signals.clear();
    devices.clear();
    velocityRecords.clear();
    fraudCases.clear();
    evidenceList.clear();
    policies.clear();
    _usedIdempotencyKeys.clear();
  }
}
