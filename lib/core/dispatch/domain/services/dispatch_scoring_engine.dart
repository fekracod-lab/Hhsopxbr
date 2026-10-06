import 'dart:math' as math;
import '../entities/dispatch_candidate.dart';
import '../entities/dispatch_weights.dart';

/// محرك احتساب وتقييم نقاط المرشحين متعدد العوامل (Multi-Factor Dispatch Scoring Engine)
class DispatchScoringEngine {
  const DispatchScoringEngine();

  /// أقصى نصف قطر مرجعي لتقييم المسافة (10,000 متر = 10 كم)
  static const double maxScoringRadiusMeters = 10000.0;

  /// احتساب التقييم النهائي لمرشح (Normalized Score from 0.0 to 100.0)
  static double scoreCandidate({
    required DispatchCandidate candidate,
    required DispatchWeights weights,
    double maxRadiusMeters = maxScoringRadiusMeters,
    int maxConcurrentOrders = 2,
  }) {
    // 1. تقييم المسافة (Distance Score: الأقرب يحصل على 100)
    final clampedDistance = candidate.distanceMeters.clamp(0.0, maxRadiusMeters);
    final distanceFactor = (1.0 - (clampedDistance / maxRadiusMeters)).clamp(0.0, 1.0);
    final distanceScore = distanceFactor * 100.0;

    // 2. تقييم تقييم السائق (Rating Score: من 1.0 إلى 5.0)
    final ratingFactor = (candidate.rating.clamp(1.0, 5.0) / 5.0);
    final ratingScore = ratingFactor * 100.0;

    // 3. تقييم نسبة القبول (Acceptance Rate Score: 0.0 إلى 1.0)
    final acceptanceFactor = candidate.acceptanceRate.clamp(0.0, 1.0);
    final acceptanceScore = acceptanceFactor * 100.0;

    // 4. تقييم الحمل الحالي (Driver Load Score: الأقل حملاً يحصل على 100)
    final loadFactor = (1.0 - (candidate.activeOrdersCount.clamp(0, maxConcurrentOrders) / maxConcurrentOrders)).clamp(0.0, 1.0);
    final loadScore = loadFactor * 100.0;

    // 5. تقييم التواجد (Availability Score)
    final availabilityScore = candidate.isOnline ? 100.0 : 0.0;

    // 6. تقييم وقت الخمول (Idle Time Factor: كلما زاد الخمول كسب أولوية بسيطة)
    final idleTimeScore = candidate.activeOrdersCount == 0 ? 100.0 : 50.0;

    // 7. تقييم حداثة إشارة الـ GPS (Freshness Score)
    final clampedAge = candidate.gpsAgeSeconds.clamp(0, 900);
    final freshnessFactor = (1.0 - (clampedAge / 900.0)).clamp(0.0, 1.0);
    final freshnessScore = freshnessFactor * 100.0;

    // الحساب الموزون
    final rawFinalScore = (distanceScore * weights.distanceWeight) +
        (ratingScore * weights.ratingWeight) +
        (acceptanceScore * weights.acceptanceWeight) +
        (loadScore * weights.loadWeight) +
        (availabilityScore * weights.availabilityWeight) +
        (idleTimeScore * weights.idleTimeWeight) +
        (freshnessScore * weights.freshnessWeight);

    final normalizedFinal = weights.totalWeight > 0
        ? rawFinalScore / weights.totalWeight
        : rawFinalScore;

    if (normalizedFinal.isNaN || normalizedFinal.isInfinite) {
      return 0.0;
    }

    return math.max(0.0, math.min(100.0, normalizedFinal));
  }

  /// ترتيب المرشحين تنازلياً حسب التقييم النهائي
  static List<DispatchCandidate> rankCandidates({
    required List<DispatchCandidate> candidates,
    required DispatchWeights weights,
    double maxRadiusMeters = maxScoringRadiusMeters,
  }) {
    final scoredList = candidates.map((c) {
      final score = scoreCandidate(
        candidate: c,
        weights: weights,
        maxRadiusMeters: maxRadiusMeters,
      );
      return c.copyWith(finalScore: score);
    }).toList();

    scoredList.sort((a, b) => b.finalScore.compareTo(a.finalScore));
    return scoredList;
  }
}
