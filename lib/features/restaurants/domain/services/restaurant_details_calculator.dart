import '../entities/restaurant_details_models.dart';

/// حاسبة العمليات المنطقية والمالية لصفحة تفاصيل المطعم (Restaurant Details Domain Calculator)
class RestaurantDetailsCalculator {
  const RestaurantDetailsCalculator._();

  /// 1. حساب السعر النهائي للوحدة الواحدة (Base Price + Size Extra + Addon Extras)
  static double calculateItemPrice({
    required double basePrice,
    double sizeExtra = 0.0,
    List<double> addonPrices = const [],
  }) {
    final safeBase = basePrice < 0 ? 0.0 : basePrice;
    final safeSize = sizeExtra < 0 ? 0.0 : sizeExtra;
    double sumAddons = 0.0;
    for (final p in addonPrices) {
      if (p > 0) {
        sumAddons += p;
      }
    }
    return safeBase + safeSize + sumAddons;
  }

  /// 2. حساب السعر الإجمالي حسب الكمية
  static double calculateTotalPrice({
    required double unitPrice,
    required int quantity,
  }) {
    final safeUnit = unitPrice < 0 ? 0.0 : unitPrice;
    final safeQty = quantity < 0 ? 0 : quantity;
    return safeUnit * safeQty;
  }

  /// 3. حساب ملخص السلة (Total Count & Total Price)
  static ({int totalCount, double totalPrice}) calculateCartSummary({
    required Map<String, int> quantities,
    required Map<String, double> prices,
  }) {
    int totalCount = 0;
    double totalPrice = 0.0;

    for (final entry in quantities.entries) {
      final itemId = entry.key;
      final qty = entry.value;
      if (qty > 0) {
        totalCount += qty;
        final unitPrice = prices[itemId] ?? 0.0;
        if (unitPrice > 0) {
          totalPrice += unitPrice * qty;
        }
      }
    }

    return (totalCount: totalCount, totalPrice: totalPrice);
  }

  /// 4. حساب إحصائيات التقييمات ومتوسط النجوم وتوزيعها (1..5 Stars)
  static ReviewStatisticsEntity calculateReviewStatistics(
    List<RestaurantReviewEntity> reviews,
  ) {
    if (reviews.isEmpty) {
      return ReviewStatisticsEntity.empty();
    }

    final Map<int, int> counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    double totalSum = 0.0;
    int validCount = 0;

    for (final review in reviews) {
      final rawRating = review.rating;
      if (rawRating.isNaN || rawRating.isInfinite) continue;

      final clampedStar = rawRating.round().clamp(1, 5);
      counts[clampedStar] = (counts[clampedStar] ?? 0) + 1;
      totalSum += rawRating.clamp(0.0, 5.0);
      validCount++;
    }

    if (validCount == 0) {
      return ReviewStatisticsEntity.empty();
    }

    final average = totalSum / validCount;
    return ReviewStatisticsEntity(
      averageRating: average,
      totalReviews: validCount,
      starCounts: counts,
    );
  }
}
