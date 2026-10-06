import '../entities/risk_decision.dart';
import '../enums/risk_enums.dart';

/// محرك تطبيق الإجراءات الأمنية واعتراض العمليات المشبوهة (Risk Action Engine)
class RiskActionEngine {
  const RiskActionEngine();

  /// التحقق هل يجب حظر العملية فوراً
  static bool shouldBlockOperation(RiskDecision decision) {
    return decision.action == RiskActionType.blockOperation ||
        decision.action == RiskActionType.freezeWalletOperation;
  }

  /// التحقق هل يتطلب الإجراء تحدياً أمنياً للزبون (Step-up / OTP)
  static bool requiresChallenge(RiskDecision decision) {
    return decision.challengeRequired ||
        decision.action == RiskActionType.requireOtp ||
        decision.action == RiskActionType.requireReauth;
  }
}
