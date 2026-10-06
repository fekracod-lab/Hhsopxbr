import 'package:flutter/foundation.dart';
import '../enums/pricing_enums.dart';

/// طلب احتساب الأجرة والتسعير (Fare Calculation Request)
@immutable
class FareRequest {
  final PricingServiceType serviceType;
  final double distanceMeters;
  final int estimatedDurationSeconds;
  final PackageSize packageSize;
  final double packageWeightKg;
  final int stopCount;
  final int waitingMinutes;
  final int discount;
  final String? orderId;
  final String? customerId;
  final String? driverId;
  final int? activeDemand;
  final int? availableSupply;
  final DateTime requestedAt;
  final String idempotencyKey;

  const FareRequest({
    required this.serviceType,
    required this.distanceMeters,
    this.estimatedDurationSeconds = 0,
    this.packageSize = PackageSize.small,
    this.packageWeightKg = 0.0,
    this.stopCount = 0,
    this.waitingMinutes = 0,
    this.discount = 0,
    this.orderId,
    this.customerId,
    this.driverId,
    this.activeDemand,
    this.availableSupply,
    required this.requestedAt,
    required this.idempotencyKey,
  });

  double get distanceKm => distanceMeters / 1000.0;
  int get estimatedDurationMinutes => (estimatedDurationSeconds / 60.0).ceil();
}
