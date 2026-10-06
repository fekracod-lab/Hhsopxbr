import '../enums/pricing_enums.dart';

/// محرك التقريب المالي الذكي (Integer Rounding Engine)
class PricingRoundingEngine {
  const PricingRoundingEngine();

  /// تقريب المبلغ إلى أقرب وحدة تقريب مالي بالدينار العراقي
  static int round(int rawAmount, RoundingUnit unit) {
    if (rawAmount <= 0) return 0;
    final u = unit.value;
    if (u <= 1) return rawAmount;

    // التقريب الرياضي إلى أقرب فئة نقدية
    final remainder = rawAmount % u;
    if (remainder == 0) return rawAmount;

    if (remainder >= (u / 2.0)) {
      return rawAmount + (u - remainder);
    } else {
      return rawAmount - remainder;
    }
  }

  /// تقريب المبلغ للأعلى دائماً إلى فئة التقريب
  static int ceil(int rawAmount, RoundingUnit unit) {
    if (rawAmount <= 0) return 0;
    final u = unit.value;
    if (u <= 1) return rawAmount;

    final remainder = rawAmount % u;
    if (remainder == 0) return rawAmount;
    return rawAmount + (u - remainder);
  }
}
