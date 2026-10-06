import 'dart:math' as math;
import '../entities/pricing_policy.dart';

/// محرك تحديد ومضاعفات ساعات الذروة (Peak Hours Engine)
class PeakHoursEngine {
  const PeakHoursEngine();

  /// فحص وحساب مضاعف ساعة الذروة للوقت المحدد
  static double calculatePeakMultiplier({
    required DateTime time,
    required List<PeakPeriod> peakPeriods,
  }) {
    if (peakPeriods.isEmpty) return 1.0;

    double maxMultiplier = 1.0;
    for (final period in peakPeriods) {
      if (period.isWithinPeak(time)) {
        maxMultiplier = math.max(maxMultiplier, period.multiplier);
      }
    }

    return maxMultiplier;
  }
}
