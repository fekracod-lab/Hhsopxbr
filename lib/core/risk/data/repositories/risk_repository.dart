import '../../domain/entities/risk_evaluation.dart';
import '../../domain/entities/risk_signal.dart';
import '../../domain/entities/device_trust_record.dart';
import '../../domain/entities/velocity_record.dart';
import '../../domain/entities/fraud_case.dart';
import '../../domain/entities/fraud_evidence.dart';
import '../../domain/entities/risk_policy.dart';
import '../../domain/repositories/i_risk_repository.dart';
import '../datasources/risk_remote_datasource.dart';

/// تطبيق مستودع المخاطر والاحتيال (RiskRepository)
class RiskRepository implements IRiskRepository {
  final RiskRemoteDatasource _remoteDatasource;

  RiskRepository({RiskRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? RiskRemoteDatasource();

  @override
  Future<void> saveRiskEvaluation(RiskEvaluation evaluation) {
    return _remoteDatasource.saveRiskEvaluation(evaluation);
  }

  @override
  Future<RiskEvaluation?> getRiskEvaluation(String evaluationId) {
    return _remoteDatasource.getRiskEvaluation(evaluationId);
  }

  @override
  Future<void> saveRiskSignal(RiskSignal signal) {
    return _remoteDatasource.saveRiskSignal(signal);
  }

  @override
  Future<void> saveDeviceTrustRecord(DeviceTrustRecord record) {
    return _remoteDatasource.saveDeviceTrustRecord(record);
  }

  @override
  Future<DeviceTrustRecord?> getDeviceTrustRecord(String deviceId) {
    return _remoteDatasource.getDeviceTrustRecord(deviceId);
  }

  @override
  Future<void> saveVelocityRecord(VelocityRecord record) {
    return _remoteDatasource.saveVelocityRecord(record);
  }

  @override
  Future<void> saveFraudCase(FraudCase fraudCase) {
    return _remoteDatasource.saveFraudCase(fraudCase);
  }

  @override
  Future<FraudCase?> getFraudCase(String caseId) {
    return _remoteDatasource.getFraudCase(caseId);
  }

  @override
  Future<void> saveFraudEvidence(FraudEvidence evidence) {
    return _remoteDatasource.saveFraudEvidence(evidence);
  }

  @override
  Future<RiskPolicy?> getEffectivePolicy(String policyId) {
    return _remoteDatasource.getEffectivePolicy(policyId);
  }

  @override
  Future<bool> verifyIdempotencyKey(String idempotencyKey) {
    return _remoteDatasource.verifyIdempotencyKey(idempotencyKey);
  }
}
