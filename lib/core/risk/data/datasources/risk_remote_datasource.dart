import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/risk_evaluation.dart';
import '../../domain/entities/risk_signal.dart';
import '../../domain/entities/device_trust_record.dart';
import '../../domain/entities/velocity_record.dart';
import '../../domain/entities/fraud_case.dart';
import '../../domain/entities/fraud_evidence.dart';
import '../../domain/entities/risk_policy.dart';

/// مصدر البيانات البعيد لمحرك المخاطر والاحتيال (Risk Remote Datasource)
class RiskRemoteDatasource {
  final FirebaseFirestore? _customFirestore;

  RiskRemoteDatasource({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  /// حفظ تقييم المخاطر
  Future<void> saveRiskEvaluation(RiskEvaluation evaluation) async {
    final docRef = _firestore.collection('risk_evaluations').doc(evaluation.evaluationId);
    await docRef.set(evaluation.toMap());
  }

  /// جلب تقييم المخاطر
  Future<RiskEvaluation?> getRiskEvaluation(String evaluationId) async {
    final doc = await _firestore.collection('risk_evaluations').doc(evaluationId).get();
    if (!doc.exists || doc.data() == null) return null;
    return RiskEvaluation.fromMap(doc.data()!, doc.id);
  }

  /// حفظ إشارة خطر
  Future<void> saveRiskSignal(RiskSignal signal) async {
    final docRef = _firestore.collection('risk_signals').doc(signal.signalId);
    await docRef.set(signal.toMap());
  }

  /// حفظ سجل موثوقية الجهاز
  Future<void> saveDeviceTrustRecord(DeviceTrustRecord record) async {
    final docRef = _firestore.collection('risk_devices').doc(record.deviceId);
    await docRef.set(record.toMap(), SetOptions(merge: true));
  }

  /// جلب سجل موثوقية الجهاز
  Future<DeviceTrustRecord?> getDeviceTrustRecord(String deviceId) async {
    final doc = await _firestore.collection('risk_devices').doc(deviceId).get();
    if (!doc.exists || doc.data() == null) return null;
    return DeviceTrustRecord.fromMap(doc.data()!, doc.id);
  }

  /// حفظ سجل السرعة والتكرار
  Future<void> saveVelocityRecord(VelocityRecord record) async {
    final docRef = _firestore.collection('risk_velocity').doc(record.recordId);
    await docRef.set(record.toMap());
  }

  /// حفظ قضية احتيال
  Future<void> saveFraudCase(FraudCase fraudCase) async {
    final docRef = _firestore.collection('fraud_cases').doc(fraudCase.caseId);
    await docRef.set(fraudCase.toMap(), SetOptions(merge: true));
  }

  /// جلب قضية احتيال
  Future<FraudCase?> getFraudCase(String caseId) async {
    final doc = await _firestore.collection('fraud_cases').doc(caseId).get();
    if (!doc.exists || doc.data() == null) return null;
    return FraudCase.fromMap(doc.data()!, doc.id);
  }

  /// حفظ دليل أمني
  Future<void> saveFraudEvidence(FraudEvidence evidence) async {
    final docRef = _firestore.collection('fraud_evidence').doc(evidence.evidenceId);
    await docRef.set(evidence.toMap());
  }

  /// جلب سياسة المخاطر المعتمدة
  Future<RiskPolicy?> getEffectivePolicy(String policyId) async {
    final doc = await _firestore.collection('risk_policies').doc(policyId).get();
    if (!doc.exists || doc.data() == null) return null;
    return RiskPolicy.fromMap(doc.data()!, doc.id);
  }

  /// التحقق من عدم تكرار المفتاح
  Future<bool> verifyIdempotencyKey(String idempotencyKey) async {
    final snap = await _firestore
        .collection('risk_evaluations')
        .where('context.idempotencyKey', isEqualTo: idempotencyKey)
        .limit(1)
        .get();
    return snap.docs.isEmpty;
  }
}
