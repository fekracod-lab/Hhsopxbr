import 'dart:math' as math;
import '../entities/delivery_execution_models.dart';

/// المحرك الحسابي والمالي النقي لتنفيذ التوصيل (Pure Financial & Distance Calculator)
class DeliveryExecutionCalculator {
  /// الثوابت المالية للمنصة
  static const double standardPlatformCommission = 500.0; // د.ع
  static const double minimumDeliveryFee = 1000.0; // د.ع
  static const double arrivalThresholdMeters = 75.0; // متر لتأكيد الوصول التلقائي
  static const double defaultAverageSpeedKmH = 30.0; // كم/ساعة داخل المدينة

  /// حساب المسافة الجغرافية بدقة (Haversine Formula) بالمتر
  static double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    if (lat1 == 0.0 || lon1 == 0.0 || lat2 == 0.0 || lon2 == 0.0) return 0.0;

    const double earthRadiusMeters = 6371000.0;
    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// التحقق مما إذا كان السائق ضمن النطاق الجغرافي للوصول (Geofence Arrival)
  static bool isWithinArrivalRadius({
    required double driverLat,
    required double driverLng,
    required double targetLat,
    required double targetLng,
    double radiusMeters = arrivalThresholdMeters,
  }) {
    if (driverLat == 0.0 || driverLng == 0.0 || targetLat == 0.0 || targetLng == 0.0) {
      return false;
    }
    final distance = calculateDistanceMeters(driverLat, driverLng, targetLat, targetLng);
    return distance <= radiusMeters;
  }

  /// حساب الوقت المتوقع للوصول (ETA) بالدقائق
  static int estimateDurationMinutes({
    required double distanceMeters,
    double averageSpeedKmH = defaultAverageSpeedKmH,
  }) {
    if (distanceMeters <= 0.0) return 1;
    final double speedMetersPerSecond = (averageSpeedKmH * 1000.0) / 3600.0;
    final double seconds = distanceMeters / speedMetersPerSecond;
    return (seconds / 60.0).ceil().clamp(1, 180);
  }

  /// حساب المقاييس المحاسبية والتسوية المالية للطلب عند الإكمال
  static DeliveryExecutionMetrics calculateMetrics({
    required double deliveryFee,
    required double orderTotal,
    required String paymentMethod,
    required bool isPaid,
    double customPlatformCommission = standardPlatformCommission,
  }) {
    final double safeDeliveryFee = deliveryFee > 0.0 ? deliveryFee : minimumDeliveryFee;
    final double safeOrderTotal = orderTotal >= 0.0 ? orderTotal : 0.0;

    // عمولة المنصة
    final double commission = safeDeliveryFee >= customPlatformCommission
        ? customPlatformCommission
        : (safeDeliveryFee * 0.2); // 20% كحد أقصى إذا كانت الأجرة منخفضة جداً

    // أرباح الكابتن الصافية
    final double captainEarnings = math.max(0.0, safeDeliveryFee - commission);

    // المبلغ الواجب تحصيله نقداً من الزبون
    final bool isCash = paymentMethod == 'cash_on_delivery' ||
        paymentMethod == 'cash' ||
        (!isPaid && paymentMethod != 'paid_wallet');

    final double cashToCollect = isCash ? (safeOrderTotal + safeDeliveryFee) : 0.0;

    // المبلغ المستحق للمتجر أو المطعم (إذا كان الدفع نقداً يقوم الكابتن بتسليمه للمحل أو العكس حسب نظام المحاسبة)
    final double merchantSettlement = isCash ? safeOrderTotal : 0.0;

    // النقاط المكتسبة للزبون (نقطة واحدة لكل 1,000 د.ع)
    final int pointsEarned = (safeOrderTotal / 1000.0).floor();

    return DeliveryExecutionMetrics(
      captainEarnings: captainEarnings,
      platformCommission: commission,
      cashToCollect: cashToCollect,
      merchantSettlement: merchantSettlement,
      customerPointsEarned: pointsEarned,
    );
  }
}
