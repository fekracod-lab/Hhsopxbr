import '../enums/risk_enums.dart';

/// محرك إدارة التحديات الأمنية والتحقق الإضافي (Challenge Engine)
class ChallengeEngine {
  final Map<String, String> _activeChallenges = {}; // key: challengeId, value: expectedCode

  ChallengeEngine();

  /// إنشاء تحدي أمني جديد (مثلاً رمز تحقق أو تأكيد هوية)
  String createChallenge({
    required String subjectId,
    required ChallengeType type,
    required String verificationCode,
  }) {
    final challengeId = 'ch-$subjectId-${DateTime.now().millisecondsSinceEpoch}';
    _activeChallenges[challengeId] = verificationCode;
    return challengeId;
  }

  /// التحقق من إجابة التحدي الأمني
  bool verifyChallenge({
    required String challengeId,
    required String providedCode,
  }) {
    if (!_activeChallenges.containsKey(challengeId)) {
      return false;
    }
    final expected = _activeChallenges[challengeId];
    final isValid = expected == providedCode;
    if (isValid) {
      _activeChallenges.remove(challengeId); // استهلاك التحدي لمرة واحدة فقط
    }
    return isValid;
  }

  void clear() {
    _activeChallenges.clear();
  }
}
