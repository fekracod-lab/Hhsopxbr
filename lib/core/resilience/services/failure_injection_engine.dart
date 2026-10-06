import 'package:flutter/foundation.dart';
import '../entities/failure_injection.dart';
import '../enums/resilience_enums.dart';

/// محرك حقن الأعطال التجريبي لبيئات التطوير والاختبار (Failure Injection Engine - Dev/Test Only)
class FailureInjectionEngine {
  final Map<String, FailureInjection> _activeInjections = {};
  bool _isProductionRelease = false;

  FailureInjectionEngine({bool isProductionRelease = false})
      : _isProductionRelease = isProductionRelease;

  bool get isProductionRelease => _isProductionRelease;
  Map<String, FailureInjection> get activeInjections => Map.unmodifiable(_activeInjections);

  void setProductionMode(bool inProduction) {
    _isProductionRelease = inProduction;
    if (inProduction) {
      _activeInjections.clear(); // منع أي حقن أعطال في الإنتاج
    }
  }

  /// تسجيل حقن عطل على خدمة محددة
  void registerInjection(FailureInjection injection) {
    if (_isProductionRelease || kReleaseMode) {
      throw StateError('Failure injection is strictly forbidden in Production Release mode!');
    }
    _activeInjections[injection.targetService] = injection;
  }

  /// إزالة حقن عطل عن خدمة
  void removeInjection(String targetService) {
    _activeInjections.remove(targetService);
  }

  /// محاكاة أو تمرير العملية حسب قواعد حقن الأعطال المسجلة
  Future<void> evaluateAndInject(String serviceKey, {double deterministicRoll = 0.0}) async {
    if (_isProductionRelease || kReleaseMode) return; // Pass-through in production

    final injection = _activeInjections[serviceKey];
    if (injection == null || !injection.enabled) return;

    if (deterministicRoll <= injection.probability) {
      // 1. تطبيق التأخير المصطنع (Latency Injection)
      if (injection.latencyMs > 0) {
        await Future.delayed(Duration(milliseconds: injection.latencyMs));
      }

      // 2. إطلاق الاستثناء المناسب لنوع العطل (Failure Throw)
      switch (injection.type) {
        case FailureInjectionType.networkOffline:
        case FailureInjectionType.networkFlapping:
          throw Exception('Simulated Chaos Error: Network connection lost for service [$serviceKey]');
        case FailureInjectionType.timeout:
          throw Exception('Simulated Chaos Error: Operation timed out for service [$serviceKey]');
        case FailureInjectionType.firestoreUnavailable:
          throw Exception('Simulated Chaos Error: Firestore database unavailable [503]');
        case FailureInjectionType.appCrash:
        case FailureInjectionType.processRestart:
          throw Exception('Simulated Chaos Error: Process crash simulated on service [$serviceKey]');
        case FailureInjectionType.financialRace:
          throw Exception('Simulated Chaos Error: High concurrency financial race condition');
        default:
          throw Exception('Simulated Chaos Error: Transient failure injected for service [$serviceKey]');
      }
    }
  }

  void clear() {
    _activeInjections.clear();
  }
}
