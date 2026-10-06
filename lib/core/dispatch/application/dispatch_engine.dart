import '../domain/entities/dispatch_request.dart';
import '../domain/entities/dispatch_candidate.dart';
import '../domain/entities/dispatch_offer.dart';
import '../domain/entities/dispatch_session.dart';
import '../domain/entities/dispatch_result.dart';
import '../domain/entities/dispatch_weights.dart';
import '../domain/enums/dispatch_enums.dart';
import '../domain/services/dispatch_distance_engine.dart';
import '../domain/services/driver_eligibility_engine.dart';
import '../domain/services/dispatch_scoring_engine.dart';
import '../domain/services/expanding_ring_engine.dart';
import '../domain/services/dispatch_timeout_engine.dart';
import '../domain/repositories/i_dispatch_repository.dart';
import '../data/repositories/dispatch_repository.dart';

/// المحرك المركزي للتوزيع الذكي وتعيين السائقين (Intelligent Dispatch Engine)
class DispatchEngine {
  static DispatchEngine? _instance;
  static DispatchEngine get instance => _instance ??= DispatchEngine();

  final IDispatchRepository _repository;
  final ExpandingRingEngine _ringEngine;

  DispatchEngine({
    IDispatchRepository? repository,
    ExpandingRingEngine? ringEngine,
  }) : _repository = repository ?? DispatchRepository(),
        _ringEngine = ringEngine ?? const ExpandingRingEngine();

  /// بدء جلسة توزيع ذكي لطلب أو رحلة تكسي
  Future<DispatchResult> startDispatchSession({
    required DispatchRequest request,
    DispatchWeights? weights,
  }) async {
    final effectiveWeights = weights ??
        (request.dispatchType == DispatchType.taxi
            ? DispatchWeights.taxiDefault
            : DispatchWeights.deliveryDefault);

    // 1. إنشاء وثيقة الجلسة
    var session = DispatchSession(
      sessionId: 'ses-${request.dispatchId}',
      orderId: request.orderId,
      dispatchType: request.dispatchType,
      currentRingIndex: 0,
      status: DispatchStatus.searching,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    session = await _repository.createSession(session);

    // 2. جلب وتصفية السائقين المتاحين
    final allDrivers = await _repository.getOnlineDrivers(dispatchType: request.dispatchType);
    if (allDrivers.isEmpty) {
      await _repository.updateSessionStatus(session.sessionId, DispatchStatus.failed);
      return DispatchResult.failed(
        reason: DispatchFailureReason.noDriversAvailable,
        errorMessage: 'ماكو كباتن حالياً متاحين حالياً في الخدمة',
        session: session,
      );
    }

    // 3. احتساب المسافات وتصفية الأهلية
    final eligibleCandidates = <DispatchCandidate>[];
    for (final driver in allDrivers) {
      final eligibility = DriverEligibilityEngine.checkEligibility(
        candidate: driver,
        dispatchType: request.dispatchType,
      );

      if (eligibility.isEligible) {
        final distanceMeters = DispatchDistanceEngine.computeDistanceMeters(
          lat1: request.pickupLatitude,
          lon1: request.pickupLongitude,
          lat2: driver.latitude,
          lon2: driver.longitude,
        );

        if (!distanceMeters.isInfinite && distanceMeters <= 15000) {
          eligibleCandidates.add(driver.copyWith(distanceMeters: distanceMeters));
        }
      }
    }

    if (eligibleCandidates.isEmpty) {
      await _repository.updateSessionStatus(session.sessionId, DispatchStatus.failed);
      return DispatchResult.failed(
        reason: DispatchFailureReason.noDriversAvailable,
        errorMessage: 'لم يتم العثور على كباتن مؤهلين ضمن النطاق الجغرافي',
        session: session,
      );
    }

    // 4. البحث عبر دوائر البحث المتوسعة (Expanding Rings)
    for (int ringIdx = 0; ringIdx < _ringEngine.rings.length; ringIdx++) {
      final ringCandidates = _ringEngine.filterCandidatesInRing(
        candidates: eligibleCandidates,
        ringIndex: ringIdx,
      );

      if (ringCandidates.isEmpty) continue;

      // تقييم وترتيب المرشحين
      final ranked = DispatchScoringEngine.rankCandidates(
        candidates: ringCandidates,
        weights: effectiveWeights,
      );

      // اختيار المرشح الأفضل
      final bestCandidate = ranked.first;

      final offerTimeout = DispatchTimeoutEngine.calculateTimeoutForAttempt(ringIdx + 1);
      final offer = DispatchOffer(
        offerId: 'off-${request.orderId}-${bestCandidate.driverId}-${DateTime.now().millisecondsSinceEpoch}',
        dispatchId: session.sessionId,
        orderId: request.orderId,
        driverId: bestCandidate.driverId,
        driverName: bestCandidate.name,
        driverPhone: bestCandidate.phone,
        attemptNumber: ringIdx + 1,
        status: DispatchOfferStatus.sent,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(offerTimeout),
      );

      await _repository.createOffer(offer);
      await _repository.updateSessionStatus(session.sessionId, DispatchStatus.offering);

      return DispatchResult.assigned(
        driverId: bestCandidate.driverId,
        driverName: bestCandidate.name,
        driverPhone: bestCandidate.phone,
        session: session.copyWith(
          currentRingIndex: ringIdx,
          offersSent: [...session.offersSent, offer.offerId],
        ),
      );
    }

    await _repository.updateSessionStatus(session.sessionId, DispatchStatus.failed);
    return DispatchResult.failed(
      reason: DispatchFailureReason.allOffersExpired,
      errorMessage: 'تم استنفاد كافة دوائر البحث دون العثور على كابتن متاح',
      session: session,
    );
  }

  /// قبول العرض وتعيين السائق ذرياً
  Future<bool> acceptOffer({
    required String offerId,
    required String driverId,
    required String orderId,
    required DispatchType dispatchType,
  }) async {
    return await _repository.acceptOfferAtomic(
      offerId: offerId,
      driverId: driverId,
      orderId: orderId,
      dispatchType: dispatchType,
    );
  }

  /// رفض العرض من السائق
  Future<bool> rejectOffer({
    required String offerId,
    required String driverId,
    required String reason,
  }) async {
    return await _repository.rejectOffer(
      offerId: offerId,
      driverId: driverId,
      reason: reason,
    );
  }
}
