import 'dart:math' as math;
import '../entities/fare_request.dart';
import '../entities/fare_breakdown.dart';
import '../entities/pricing_policy.dart';
import 'pricing_limits_validator.dart';
import 'pricing_rounding_engine.dart';
import 'surge_pricing_engine.dart';
import 'peak_hours_engine.dart';

/// المحاسب الحتمي لتسعير الرحلات والطلبات (Deterministic Fare Calculator)
class FareCalculator {
  const FareCalculator();

  /// احتساب تفصيل الأجرة الشامل والمحكم
  static FareBreakdown calculateFare({
    required FareRequest request,
    required PricingPolicy policy,
  }) {
    // 1. التحقق الصارم من صحة المدخلات
    PricingLimitsValidator.validateRequest(request, policy);

    // 2. حساب المكونات الأساسية
    final baseFare = policy.baseFare;
    final distanceFare = (request.distanceKm * policy.pricePerKm).round();
    final timeFare = (request.estimatedDurationMinutes * policy.pricePerMinute);
    final waitingFare = (request.waitingMinutes * policy.waitingFeePerMinute);
    final packageFee = request.packageSize.defaultSurcharge;
    final stopFee = request.stopCount * policy.stopFee;
    final serviceFee = policy.serviceFee;

    final subtotal = baseFare +
        distanceFare +
        timeFare +
        waitingFare +
        packageFee +
        stopFee +
        serviceFee;

    // 3. احتساب التسعير الديناميكي (Surge & Peak)
    final surgeState = SurgePricingEngine.resolveSurgeState(
      time: request.requestedAt,
      policy: policy,
      activeDemand: request.activeDemand,
      availableSupply: request.availableSupply,
    );

    final peakMultiplier = PeakHoursEngine.calculatePeakMultiplier(
      time: request.requestedAt,
      peakPeriods: policy.peakPeriods,
    );

    final demandAdjustment = ((surgeState.multiplier - 1.0) * subtotal).round();
    final peakAdjustment = peakMultiplier > 1.0 ? ((peakMultiplier - 1.0) * subtotal).round() : 0;

    final grossTotal = subtotal + demandAdjustment;

    // 4. تطبيق الخصومات
    final discountedTotal = math.max(0, grossTotal - request.discount);

    // 5. تطبيق الحدود الدنيا والعليا للسياسة
    final clampedTotal = PricingLimitsValidator.clampFare(discountedTotal, policy);

    // 6. التقريب المالي بالدينار العراقي
    final finalFare = PricingRoundingEngine.round(clampedTotal, policy.roundingUnit);

    return FareBreakdown(
      baseFare: baseFare,
      distanceFare: distanceFare,
      timeFare: timeFare,
      waitingFare: waitingFare,
      serviceFee: serviceFee,
      packageFee: packageFee,
      stopFee: stopFee,
      surgeMultiplier: surgeState.multiplier,
      peakMultiplier: peakMultiplier,
      demandAdjustment: demandAdjustment,
      peakAdjustment: peakAdjustment,
      discount: request.discount,
      subtotal: subtotal,
      finalFare: finalFare,
      currency: 'IQD',
    );
  }
}
