import '../entities/dispatch_offer.dart';

/// محرك إدارة مهلات عروض التوزيع (Dispatch Timeout Engine)
class DispatchTimeoutEngine {
  const DispatchTimeoutEngine();

  /// المهلة الافتراضية لعرض الطلب (25 ثانية)
  static const Duration defaultOfferTimeout = Duration(seconds: 25);

  /// إنشاء مهلة عرض محددة بحسب محاولة التوزيع
  static Duration calculateTimeoutForAttempt(int attemptNumber) {
    if (attemptNumber <= 1) return defaultOfferTimeout;
    if (attemptNumber == 2) return const Duration(seconds: 20);
    return const Duration(seconds: 15);
  }

  /// التحقق من صلاحية العرض وعدم انقضاء مهلته
  static bool isOfferActive(DispatchOffer offer) {
    return !offer.isExpired;
  }
}
