import 'package:flutter/foundation.dart';

/// سياق التسعير الميداني اللحظي (Pricing Context)
@immutable
class PricingContext {
  final int activeOrders;
  final int availableDrivers;
  final double trafficFactor; // 1.0 = Normal, 1.2 = Heavy, 1.5 = Jam
  final double weatherFactor; // 1.0 = Clear, 1.3 = Rain/Storm
  final DateTime currentTime;

  const PricingContext({
    this.activeOrders = 0,
    this.availableDrivers = 1,
    this.trafficFactor = 1.0,
    this.weatherFactor = 1.0,
    required this.currentTime,
  });

  /// نسبة العرض إلى الطلب (Supply to Demand Ratio)
  double get supplyDemandRatio {
    if (activeOrders <= 0) return 2.0; // وفرة عالية
    if (availableDrivers <= 0) return 0.1; // شح شديد في السائقين
    return availableDrivers / activeOrders.toDouble();
  }
}
