import '../entities/risk_signal.dart';
import '../enums/risk_enums.dart';

/// محرك كشف الاحتيال واستغلال القسائم الترويجية (Coupon Abuse Engine)
class CouponAbuseEngine {
  final Map<String, Set<String>> _deviceCouponUsers = {};
  final Map<String, List<DateTime>> _userCouponRedemptions = {};

  CouponAbuseEngine();

  /// فحص استخدام القسيمة وكشف أنماط الاستغلال المتعدد
  RiskSignal? evaluateCouponRedemption({
    required String subjectId,
    required String couponCode,
    required String deviceId,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();

    // 1. فحص استخدام نفس القسيمة على نفس الجهاز بحسابات مختلفة (Device Coupon Farming)
    final deviceCouponKey = '$deviceId:$couponCode';
    _deviceCouponUsers.putIfAbsent(deviceCouponKey, () => {});
    _deviceCouponUsers[deviceCouponKey]!.add(subjectId);

    if (_deviceCouponUsers[deviceCouponKey]!.length > 1) {
      return RiskSignal(
        signalId: 'sig-coupon-farm-$subjectId-${currentTime.millisecondsSinceEpoch}',
        type: RiskSignalType.couponAbuse,
        source: RiskSource.orderEngine,
        subjectId: subjectId,
        severity: FraudCaseSeverity.high,
        confidence: 0.90,
        weight: 30,
        timestamp: currentTime,
        metadata: {
          'couponCode': couponCode,
          'deviceId': deviceId,
          'accountsOnDevice': _deviceCouponUsers[deviceCouponKey]!.length,
          'reason': 'Same coupon redeemed across multiple accounts on one device',
        },
      );
    }

    // 2. فحص سرعة استخدام القسائم لنفس المستخدم (Rapid Redemptions)
    _userCouponRedemptions.putIfAbsent(subjectId, () => []);
    final redemptions = _userCouponRedemptions[subjectId]!;
    redemptions.removeWhere((t) => t.isBefore(currentTime.subtract(const Duration(hours: 24))));
    redemptions.add(currentTime);

    if (redemptions.length > 3) {
      return RiskSignal(
        signalId: 'sig-coupon-rapid-$subjectId-${currentTime.millisecondsSinceEpoch}',
        type: RiskSignalType.couponAbuse,
        source: RiskSource.orderEngine,
        subjectId: subjectId,
        severity: FraudCaseSeverity.medium,
        confidence: 0.80,
        weight: 20,
        timestamp: currentTime,
        metadata: {
          'couponCode': couponCode,
          'dailyCount': redemptions.length,
          'reason': 'Excessive coupon redemptions within 24 hours',
        },
      );
    }

    return null;
  }

  void clear() {
    _deviceCouponUsers.clear();
    _userCouponRedemptions.clear();
  }
}
