import '../entities/dispatch_candidate.dart';
import '../entities/dispatch_offer.dart';
import '../entities/dispatch_session.dart';
import '../enums/dispatch_enums.dart';

/// العقد التجريدي لمستودع التوزيع وتعيين السائقين (IDispatchRepository)
abstract class IDispatchRepository {
  /// جلب قائمة السائقين المتصلين حسب نوع الخدمة
  Future<List<DispatchCandidate>> getOnlineDrivers({required DispatchType dispatchType});

  /// إنشاء جلسة توزيع جديدة
  Future<DispatchSession> createSession(DispatchSession session);

  /// جلب بيانات جلسة التوزيع
  Future<DispatchSession?> getSession(String sessionId);

  /// إنشاء وإرسال عرض توزيع جديد لسائق
  Future<DispatchOffer> createOffer(DispatchOffer offer);

  /// جلب بيانات عرض التوزيع
  Future<DispatchOffer?> getOffer(String offerId);

  /// قبول العرض وتعيين السائق ذرياً وحظر السباقات والتكرار (Atomic Driver Acceptance)
  Future<bool> acceptOfferAtomic({
    required String offerId,
    required String driverId,
    required String orderId,
    required DispatchType dispatchType,
  });

  /// رفض العرض من قبل السائق
  Future<bool> rejectOffer({
    required String offerId,
    required String driverId,
    required String reason,
  });

  /// تحديث حالة جلسة التوزيع
  Future<void> updateSessionStatus(String sessionId, DispatchStatus status);
}
