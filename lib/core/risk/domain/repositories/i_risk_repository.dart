import '../entities/risk_evaluation.dart';
import '../entities/risk_signal.dart';
import '../entities/device_trust_record.dart';
import '../entities/velocity_record.dart';
import '../entities/fraud_case.dart';
import '../entities/fraud_evidence.dart';
import '../entities/risk_policy.dart';

/// العقد التجريدي لمستودع المخاطر والاحتيال (IRiskRepository)
abstract class IRiskRepository {
  /// حفظ تقييم المخاطر المنجز
  Future<void> saveRiskEvaluation(RiskEvaluation evaluation);

  /// جلب تقييم مخاطر سابق
  Future<RiskEvaluation?> getRiskEvaluation(String evaluationId);

  /// حفظ إشارة خطر فردية
  Future<void> saveRiskSignal(RiskSignal signal);

  /// حفظ وتحديث سجل موثوقية الجهاز
  Future<void> saveDeviceTrustRecord(DeviceTrustRecord record);

  /// جلب سجل موثوقية الجهاز
  Future<DeviceTrustRecord?> getDeviceTrustRecord(String deviceId);

  /// حفظ سجل السرعة والتكرار
  Future<void> saveVelocityRecord(VelocityRecord record);

  /// حفظ وتحديث قضية احتيال
  Future<void> saveFraudCase(FraudCase fraudCase);

  /// جلب قضية احتيال
  Future<FraudCase?> getFraudCase(String caseId);

  /// حفظ دليل أمني جنائي غير قابل للتعديل
  Future<void> saveFraudEvidence(FraudEvidence evidence);

  /// جلب السياسة المعتمدة
  Future<RiskPolicy?> getEffectivePolicy(String policyId);

  /// التحقق من عدم تكرار مفتاح المعاملة (Idempotency Key Check)
  Future<bool> verifyIdempotencyKey(String idempotencyKey);
}
