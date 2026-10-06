import '../entities/pricing_policy.dart';
import '../entities/pricing_snapshot.dart';
import '../enums/pricing_enums.dart';

/// العقد التجريدي لمستودع التسعير ولقطات الأسعار (IPricingRepository)
abstract class IPricingRepository {
  /// جلب سياسة التسعير النشطة لنوع خدمة معين
  Future<PricingPolicy> getActivePolicy(PricingServiceType serviceType);

  /// حفظ لقطة تسعير غير قابلة للتعديل
  Future<PricingSnapshot> saveSnapshot(PricingSnapshot snapshot);

  /// جلب لقطة تسعير سابقة
  Future<PricingSnapshot?> getSnapshot(String snapshotId);

  /// التحقق من مفتاح عدم التكرار لعملية التسعير
  Future<bool> verifyIdempotencyKey(String idempotencyKey);
}
