import 'dart:math' as math;
import '../entities/surge_state.dart';
import '../enums/pricing_enums.dart';

/// محرك حساب ضغط الطلب وزيادة الأسعار اللحظية (Demand Pressure Engine)
class DemandPressureEngine {
  const DemandPressureEngine();

  /// احتساب حالة زيادة الطلب (Surge State) بناءً على نسبة العرض إلى الطلب
  static SurgeState calculateSurge({
    required int activeDemand,
    required int availableSupply,
    double maxMultiplier = 2.0,
  }) {
    final now = DateTime.now();

    if (activeDemand <= 0) {
      return SurgeState(
        level: SurgeLevel.normal,
        multiplier: 1.0,
        reason: 'طلب طبيعي وتوفر كافٍ',
        supplyDemandRatio: 2.0,
        calculatedAt: now,
      );
    }

    final ratio = availableSupply <= 0
        ? 0.05
        : (availableSupply / activeDemand.toDouble());

    SurgeLevel level;
    double rawMultiplier;
    String reason;

    if (ratio >= 1.5) {
      level = SurgeLevel.normal;
      rawMultiplier = 1.0;
      reason = 'وفرة عالية في الكباتن المتاحين';
    } else if (ratio >= 1.0) {
      level = SurgeLevel.elevated;
      rawMultiplier = 1.15;
      reason = 'توازن طفيف مع زيادة في الطلب';
    } else if (ratio >= 0.6) {
      level = SurgeLevel.high;
      rawMultiplier = 1.35;
      reason = 'طلب مرتفع مقارنة بعدد الكباتن المتاحين';
    } else if (ratio >= 0.3) {
      level = SurgeLevel.veryHigh;
      rawMultiplier = 1.65;
      reason = 'طلب شديد جداً مع ندرة في الكباتن';
    } else {
      level = SurgeLevel.critical;
      rawMultiplier = 2.0;
      reason = 'ذروة قصوى في الطلب وضغط استثنائي على الشبكة';
    }

    final finalMultiplier = math.max(1.0, math.min(maxMultiplier, rawMultiplier));

    return SurgeState(
      level: level,
      multiplier: finalMultiplier,
      reason: reason,
      supplyDemandRatio: ratio,
      calculatedAt: now,
    );
  }
}
