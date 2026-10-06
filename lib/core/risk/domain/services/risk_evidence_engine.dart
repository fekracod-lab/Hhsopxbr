import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../entities/fraud_evidence.dart';
import '../enums/risk_enums.dart';

/// محرك توثيق الأدلة الجنائية والأمنية غير القابلة للتعديل (Risk Evidence Engine)
class RiskEvidenceEngine {
  const RiskEvidenceEngine();

  /// توليد دليل أمني موثق ومشفر الـ Hash
  static FraudEvidence createEvidence({
    required String caseId,
    required EvidenceType type,
    required RiskSource source,
    required String correlationId,
    required Map<String, dynamic> rawData,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();

    // 1. حساب الـ Hash للبيانات لضمان عدم التلاعب (Tamper-evident Hash)
    final jsonStr = jsonEncode(rawData);
    final payloadHash = sha256.convert(utf8.encode(jsonStr)).toString();

    final evidenceId = 'evid-$caseId-${currentTime.millisecondsSinceEpoch}';

    return FraudEvidence(
      evidenceId: evidenceId,
      caseId: caseId,
      type: type,
      source: source,
      timestamp: currentTime,
      payloadHash: payloadHash,
      correlationId: correlationId,
      evidenceData: rawData,
    );
  }
}
