import '../entities/chaos_scenario.dart';
import 'failure_injection_engine.dart';

/// محرك تنفيذ سيناريوهات الفوضى والتحقق من التعافي (Chaos Engineering Engine)
class ChaosEngine {
  final FailureInjectionEngine failureInjectionEngine;

  const ChaosEngine({
    required this.failureInjectionEngine,
  });

  /// تنفيذ سيناريو فوضى والتحقق من صمود وتعافي المنظومة
  Future<(bool passed, List<String> passedAssertions, List<String> failedAssertions)> executeScenario({
    required ChaosScenario scenario,
    required Future<void> Function() workload,
    required Future<bool> Function(String assertion) assertionVerifier,
  }) async {
    final passed = <String>[];
    final failed = <String>[];

    // 1. تسجيل جميع حقن الأعطال للسيناريو
    for (final injection in scenario.injections) {
      failureInjectionEngine.registerInjection(injection);
    }

    try {
      // 2. تشغيل حمل العمل أثناء حقن الفوضى
      await workload();
    } catch (_) {
      // الأعطال المحقونة متوقعة أثناء السيناريو
    } finally {
      // 3. تنظيف حقن الأعطال بعد انتهاء الحمل للتحقق من التعافي
      failureInjectionEngine.clear();
    }

    // 4. التحقق من تحقق جميع شروط التعافي والسلامة (Post-Chaos Assertions)
    for (final assertion in scenario.assertions) {
      final isMet = await assertionVerifier(assertion);
      if (isMet) {
        passed.add(assertion);
      } else {
        failed.add(assertion);
      }
    }

    return (failed.isEmpty, passed, failed);
  }
}
