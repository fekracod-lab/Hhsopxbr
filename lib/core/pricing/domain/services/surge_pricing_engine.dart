import 'dart:math' as math;
import '../entities/pricing_policy.dart';
import '../entities/surge_state.dart';
import 'demand_pressure_engine.dart';
import 'peak_hours_engine.dart';

/// محرك التسعير الديناميكي الموحد لزيادة الطلب والذروة (Surge Pricing Engine)
class SurgePricingEngine {
  const SurgePricingEngine();

  /// احتساب حالة الزيادة الديناميكية الموحدة
  static SurgeState resolveSurgeState({
    required DateTime time,
    required PricingPolicy policy,
    int? activeDemand,
    int? availableSupply,
  }) {
    // 1. حساب مضاعف الذروة الزمنية (Peak Hours)
    final peakMultiplier = PeakHoursEngine.calculatePeakMultiplier(
      time: time,
      peakPeriods: policy.peakPeriods,
    );

    // 2. حساب مضاعف ضغط الطلب اللحظي (Demand Pressure)
    final demandSurge = DemandPressureEngine.calculateSurge(
      activeDemand: activeDemand ?? 0,
      availableSupply: availableSupply ?? 1,
      maxMultiplier: policy.maxSurgeMultiplier,
    );

    // 3. دمج المضاعفين مع تطبيق السقف الأقصى للسياسة
    final combinedMultiplier = math.min(
      policy.maxSurgeMultiplier,
      math.max(peakMultiplier, demandSurge.multiplier),
    );

    final reason = combinedMultiplier > 1.0
        ? (peakMultiplier > demandSurge.multiplier
            ? 'ساعة ذروة مرورية'
            : demandSurge.reason)
        : 'تسعير قياسي';

    return SurgeState(
      level: demandSurge.level,
      multiplier: combinedMultiplier,
      reason: reason,
      supplyDemandRatio: demandSurge.supplyDemandRatio,
      calculatedAt: DateTime.now(),
    );
  }
}
