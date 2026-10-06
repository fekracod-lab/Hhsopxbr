import '../entities/fraud_case.dart';
import '../entities/risk_score.dart';
import '../entities/risk_signal.dart';
import '../enums/risk_enums.dart';

/// محرك إدارة دورة حياة قضايا الاحتيال والتحقيق (Fraud Case Engine)
class FraudCaseEngine {
  const FraudCaseEngine();

  /// إنشاء قضية احتيال جديدة في حال تجاوز الخطورة للحد الحرج
  static FraudCase? evaluateAndCreateCase({
    required String subjectId,
    required RiskSubjectType subjectType,
    required RiskScore score,
    required List<RiskSignal> signals,
    List<String> evidenceReferences = const [],
    DateTime? now,
  }) {
    // إنشاء قضية فقط للمخاطر العالية والحرجة (Score >= 60)
    if (score.normalizedScore < 60) {
      return null;
    }

    final currentTime = now ?? DateTime.now();
    final severity = score.normalizedScore >= 80
        ? FraudCaseSeverity.critical
        : FraudCaseSeverity.high;

    return FraudCase(
      caseId: 'fc-$subjectId-${currentTime.millisecondsSinceEpoch}',
      subjectId: subjectId,
      subjectType: subjectType,
      severity: severity,
      status: FraudCaseStatus.open,
      riskScore: score.normalizedScore,
      signalIds: signals.map((s) => s.signalId).toList(),
      evidenceReferences: evidenceReferences,
      createdAt: currentTime,
      updatedAt: currentTime,
    );
  }

  /// تحديث حالة القضية
  static FraudCase updateCaseStatus({
    required FraudCase currentCase,
    required FraudCaseStatus newStatus,
    String? resolution,
    String? assignedTo,
    DateTime? now,
  }) {
    return currentCase.copyWith(
      status: newStatus,
      resolution: resolution ?? currentCase.resolution,
      assignedTo: assignedTo ?? currentCase.assignedTo,
      updatedAt: now ?? DateTime.now(),
    );
  }
}
