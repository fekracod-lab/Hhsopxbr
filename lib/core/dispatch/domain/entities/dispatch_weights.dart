import 'package:flutter/foundation.dart';

/// أوزان خوارزمية التقييم والتوزيع متعددة العوامل (Multi-Factor Scoring Weights)
@immutable
class DispatchWeights {
  final double distanceWeight;
  final double ratingWeight;
  final double acceptanceWeight;
  final double loadWeight;
  final double availabilityWeight;
  final double idleTimeWeight;
  final double freshnessWeight;

  const DispatchWeights({
    this.distanceWeight = 0.35,
    this.ratingWeight = 0.15,
    this.acceptanceWeight = 0.15,
    this.loadWeight = 0.10,
    this.availabilityWeight = 0.10,
    this.idleTimeWeight = 0.05,
    this.freshnessWeight = 0.10,
  });

  /// إجمالي مجموع الأوزان للتحقق من التناسق
  double get totalWeight =>
      distanceWeight +
      ratingWeight +
      acceptanceWeight +
      loadWeight +
      availabilityWeight +
      idleTimeWeight +
      freshnessWeight;

  /// تهيئة افتراضية متوازنة لخدمات التوصيل
  static const DispatchWeights deliveryDefault = DispatchWeights(
    distanceWeight: 0.35,
    ratingWeight: 0.15,
    acceptanceWeight: 0.15,
    loadWeight: 0.10,
    availabilityWeight: 0.10,
    idleTimeWeight: 0.05,
    freshnessWeight: 0.10,
  );

  /// تهيئة مخصصة لرحلات التكسي تركز بشكل أكبر على المسافة وسرعة الوصول
  static const DispatchWeights taxiDefault = DispatchWeights(
    distanceWeight: 0.45,
    ratingWeight: 0.15,
    acceptanceWeight: 0.15,
    loadWeight: 0.05,
    availabilityWeight: 0.10,
    idleTimeWeight: 0.05,
    freshnessWeight: 0.05,
  );
}
