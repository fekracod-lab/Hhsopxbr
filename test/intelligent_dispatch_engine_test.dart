import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/dispatch/domain/enums/dispatch_enums.dart';
import 'package:dalal_alqaim/core/dispatch/domain/entities/dispatch_weights.dart';
import 'package:dalal_alqaim/core/dispatch/domain/entities/dispatch_candidate.dart';
import 'package:dalal_alqaim/core/dispatch/domain/entities/dispatch_request.dart';
import 'package:dalal_alqaim/core/dispatch/domain/entities/dispatch_offer.dart';
import 'package:dalal_alqaim/core/dispatch/domain/entities/dispatch_session.dart';
import 'package:dalal_alqaim/core/dispatch/domain/services/dispatch_distance_engine.dart';
import 'package:dalal_alqaim/core/dispatch/domain/services/driver_eligibility_engine.dart';
import 'package:dalal_alqaim/core/dispatch/domain/services/dispatch_scoring_engine.dart';
import 'package:dalal_alqaim/core/dispatch/domain/services/expanding_ring_engine.dart';
import 'package:dalal_alqaim/core/dispatch/domain/services/dispatch_timeout_engine.dart';
import 'package:dalal_alqaim/core/dispatch/domain/repositories/i_dispatch_repository.dart';
import 'package:dalal_alqaim/core/dispatch/application/dispatch_engine.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

class MockDispatchRepository implements IDispatchRepository {
  final List<DispatchCandidate> drivers = [];
  final Map<String, DispatchSession> sessions = {};
  final Map<String, DispatchOffer> offers = {};
  final Map<String, String> assignedOrders = {};

  @override
  Future<List<DispatchCandidate>> getOnlineDrivers({required DispatchType dispatchType}) async {
    return drivers;
  }

  @override
  Future<DispatchSession> createSession(DispatchSession session) async {
    sessions[session.sessionId] = session;
    return session;
  }

  @override
  Future<DispatchSession?> getSession(String sessionId) async {
    return sessions[sessionId];
  }

  @override
  Future<DispatchOffer> createOffer(DispatchOffer offer) async {
    offers[offer.offerId] = offer;
    return offer;
  }

  @override
  Future<DispatchOffer?> getOffer(String offerId) async {
    return offers[offerId];
  }

  @override
  Future<bool> acceptOfferAtomic({
    required String offerId,
    required String driverId,
    required String orderId,
    required DispatchType dispatchType,
  }) async {
    final offer = offers[offerId];
    if (offer == null) {
      throw const SecurityViolationException(
        'العرض غير موجود',
        type: SecurityViolationType.unauthorizedFinancialMutation,
      );
    }

    if (offer.isExpired) {
      throw const SecurityViolationException(
        'انتهت صلاحية العرض',
        type: SecurityViolationType.unauthorizedFinancialMutation,
      );
    }

    if (assignedOrders.containsKey(orderId) && assignedOrders[orderId] != driverId) {
      throw const SecurityViolationException(
        'تم تعيين الطلب لكابتن آخر مسبقاً (Race Condition Protected)',
        type: SecurityViolationType.unauthorizedFinancialMutation,
      );
    }

    assignedOrders[orderId] = driverId;
    offers[offerId] = offer.copyWith(status: DispatchOfferStatus.accepted);
    final session = sessions[offer.dispatchId];
    if (session != null) {
      sessions[offer.dispatchId] = session.copyWith(
        status: DispatchStatus.assigned,
        assignedDriverId: driverId,
      );
    }
    return true;
  }

  @override
  Future<bool> rejectOffer({
    required String offerId,
    required String driverId,
    required String reason,
  }) async {
    final offer = offers[offerId];
    if (offer != null) {
      offers[offerId] = offer.copyWith(status: DispatchOfferStatus.rejected);
    }
    return true;
  }

  @override
  Future<void> updateSessionStatus(String sessionId, DispatchStatus status) async {
    final session = sessions[sessionId];
    if (session != null) {
      sessions[sessionId] = session.copyWith(status: status);
    }
  }
}

void main() {
  group('Intelligent Dispatch & Driver Matching Engine Comprehensive Tests', () {
    // 1. DispatchDistanceEngine Tests
    test('1. DispatchDistanceEngine computes accurate distance between Baghdad coordinates', () {
      // Tahrir Square (33.3275, 44.4072) to Karrada (33.3032, 44.4285) ~ 3.3 km
      final distanceMeters = DispatchDistanceEngine.computeDistanceMeters(
        lat1: 33.3275,
        lon1: 44.4072,
        lat2: 33.3032,
        lon2: 44.4285,
      );

      expect(distanceMeters, greaterThan(3000));
      expect(distanceMeters, lessThan(4000));

      final distanceKm = DispatchDistanceEngine.computeDistanceKm(
        lat1: 33.3275,
        lon1: 44.4072,
        lat2: 33.3032,
        lon2: 44.4285,
      );
      expect(distanceKm, closeTo(3.3, 0.5));
    });

    test('2. DispatchDistanceEngine handles identical and invalid coordinates safely', () {
      final zeroDistance = DispatchDistanceEngine.computeDistanceMeters(
        lat1: 33.3,
        lon1: 44.4,
        lat2: 33.3,
        lon2: 44.4,
      );
      expect(zeroDistance, equals(0.0));

      final invalidDistance = DispatchDistanceEngine.computeDistanceMeters(
        lat1: 120.0, // Invalid latitude > 90
        lon1: 44.4,
        lat2: 33.3,
        lon2: 44.4,
      );
      expect(invalidDistance.isInfinite, isTrue);
    });

    // 2. DriverEligibilityEngine Tests
    test('3. DriverEligibilityEngine accepts fully eligible active driver', () {
      final eligibleDriver = DispatchCandidate(
        driverId: 'drv_1',
        name: 'كابتن علي',
        phone: '0770111111',
        rating: 4.9,
        acceptanceRate: 0.95,
        activeOrdersCount: 0,
        latitude: 33.32,
        longitude: 44.40,
        lastLocationUpdate: DateTime.now(),
        isOnline: true,
        isApproved: true,
        status: 'active',
        role: 'delivery',
      );

      final result = DriverEligibilityEngine.checkEligibility(
        candidate: eligibleDriver,
        dispatchType: DispatchType.food,
      );

      expect(result.isEligible, isTrue);
      expect(result.status, equals(DriverEligibilityStatus.eligible));
    });

    test('4. DriverEligibilityEngine rejects offline, unapproved, and suspended drivers', () {
      final now = DateTime.now();

      // Offline
      final offlineDriver = DispatchCandidate(
        driverId: 'd_off',
        name: 'Offline',
        phone: '0770',
        latitude: 33.3,
        longitude: 44.4,
        lastLocationUpdate: now,
        isOnline: false,
      );
      expect(
        DriverEligibilityEngine.checkEligibility(candidate: offlineDriver, dispatchType: DispatchType.food).status,
        equals(DriverEligibilityStatus.offline),
      );

      // Unapproved
      final unapprovedDriver = DispatchCandidate(
        driverId: 'd_unapp',
        name: 'Unapproved',
        phone: '0770',
        latitude: 33.3,
        longitude: 44.4,
        lastLocationUpdate: now,
        isApproved: false,
      );
      expect(
        DriverEligibilityEngine.checkEligibility(candidate: unapprovedDriver, dispatchType: DispatchType.food).status,
        equals(DriverEligibilityStatus.unapproved),
      );

      // Suspended
      final suspendedDriver = DispatchCandidate(
        driverId: 'd_susp',
        name: 'Suspended',
        phone: '0770',
        latitude: 33.3,
        longitude: 44.4,
        lastLocationUpdate: now,
        status: 'suspended',
      );
      expect(
        DriverEligibilityEngine.checkEligibility(candidate: suspendedDriver, dispatchType: DispatchType.food).status,
        equals(DriverEligibilityStatus.suspended),
      );
    });

    test('5. DriverEligibilityEngine rejects busy drivers and stale GPS', () {
      final now = DateTime.now();

      // Busy with max orders
      final busyDriver = DispatchCandidate(
        driverId: 'd_busy',
        name: 'Busy',
        phone: '0770',
        latitude: 33.3,
        longitude: 44.4,
        lastLocationUpdate: now,
        activeOrdersCount: 2, // Max is 2
      );
      expect(
        DriverEligibilityEngine.checkEligibility(candidate: busyDriver, dispatchType: DispatchType.food).status,
        equals(DriverEligibilityStatus.busy),
      );

      // Stale GPS (> 15 minutes)
      final staleGpsDriver = DispatchCandidate(
        driverId: 'd_stale',
        name: 'Stale',
        phone: '0770',
        latitude: 33.3,
        longitude: 44.4,
        lastLocationUpdate: now.subtract(const Duration(minutes: 25)),
      );
      expect(
        DriverEligibilityEngine.checkEligibility(candidate: staleGpsDriver, dispatchType: DispatchType.food).status,
        equals(DriverEligibilityStatus.staleGps),
      );
    });

    test('6. DriverEligibilityEngine enforces Taxi service compatibility', () {
      final deliveryOnlyDriver = DispatchCandidate(
        driverId: 'd_deliv',
        name: 'مندوب طعام',
        phone: '0770',
        latitude: 33.3,
        longitude: 44.4,
        lastLocationUpdate: DateTime.now(),
        role: 'delivery_delegate', // Delivery only
      );

      expect(
        DriverEligibilityEngine.checkEligibility(candidate: deliveryOnlyDriver, dispatchType: DispatchType.taxi).status,
        equals(DriverEligibilityStatus.incompatibleService),
      );
    });

    // 3. DispatchScoringEngine Tests
    test('7. DispatchScoringEngine scores and ranks closer and higher-rated drivers higher', () {
      final now = DateTime.now();
      final candidate1 = DispatchCandidate(
        driverId: 'c1',
        name: 'قريب وتقييم عالي',
        phone: '0771',
        rating: 5.0,
        acceptanceRate: 1.0,
        activeOrdersCount: 0,
        latitude: 33.32,
        longitude: 44.40,
        lastLocationUpdate: now,
        distanceMeters: 500.0, // 500 meters away
      );

      final candidate2 = DispatchCandidate(
        driverId: 'c2',
        name: 'بعيد وتقييم أقل',
        phone: '0772',
        rating: 4.0,
        acceptanceRate: 0.8,
        activeOrdersCount: 1,
        latitude: 33.30,
        longitude: 44.40,
        lastLocationUpdate: now,
        distanceMeters: 5000.0, // 5 km away
      );

      const weights = DispatchWeights.deliveryDefault;
      final score1 = DispatchScoringEngine.scoreCandidate(candidate: candidate1, weights: weights);
      final score2 = DispatchScoringEngine.scoreCandidate(candidate: candidate2, weights: weights);

      expect(score1, greaterThan(score2));
      expect(score1, inInclusiveRange(0.0, 100.0));
      expect(score2, inInclusiveRange(0.0, 100.0));

      final ranked = DispatchScoringEngine.rankCandidates(
        candidates: [candidate2, candidate1],
        weights: weights,
      );

      expect(ranked.first.driverId, equals('c1'));
      expect(ranked.last.driverId, equals('c2'));
    });

    // 4. ExpandingRingEngine Tests
    test('8. ExpandingRingEngine filters candidates in concentric rings', () {
      const ringEngine = ExpandingRingEngine();

      final now = DateTime.now();
      final candidates = [
        DispatchCandidate(
          driverId: 'r0',
          name: 'Ring 0',
          phone: '0770',
          latitude: 33.3,
          longitude: 44.4,
          lastLocationUpdate: now,
          distanceMeters: 800.0, // Ring 0 (0 - 1500m)
        ),
        DispatchCandidate(
          driverId: 'r1',
          name: 'Ring 1',
          phone: '0770',
          latitude: 33.3,
          longitude: 44.4,
          lastLocationUpdate: now,
          distanceMeters: 2500.0, // Ring 1 (1500 - 3500m)
        ),
        DispatchCandidate(
          driverId: 'r2',
          name: 'Ring 2',
          phone: '0770',
          latitude: 33.3,
          longitude: 44.4,
          lastLocationUpdate: now,
          distanceMeters: 4500.0, // Ring 2 (3500 - 6000m)
        ),
      ];

      final inRing0 = ringEngine.filterCandidatesInRing(candidates: candidates, ringIndex: 0);
      expect(inRing0.length, equals(1));
      expect(inRing0.first.driverId, equals('r0'));

      final inRing1 = ringEngine.filterCandidatesInRing(candidates: candidates, ringIndex: 1);
      expect(inRing1.length, equals(1));
      expect(inRing1.first.driverId, equals('r1'));

      final inRing2 = ringEngine.filterCandidatesInRing(candidates: candidates, ringIndex: 2);
      expect(inRing2.length, equals(1));
      expect(inRing2.first.driverId, equals('r2'));
    });

    // 5. DispatchTimeoutEngine Tests
    test('9. DispatchTimeoutEngine calculates attempt timeouts and detects expired offers', () {
      expect(DispatchTimeoutEngine.calculateTimeoutForAttempt(1), equals(const Duration(seconds: 25)));
      expect(DispatchTimeoutEngine.calculateTimeoutForAttempt(2), equals(const Duration(seconds: 20)));
      expect(DispatchTimeoutEngine.calculateTimeoutForAttempt(3), equals(const Duration(seconds: 15)));

      final activeOffer = DispatchOffer(
        offerId: 'off_act',
        dispatchId: 'd1',
        orderId: 'o1',
        driverId: 'drv1',
        driverName: 'علي',
        driverPhone: '0770',
        attemptNumber: 1,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 20)),
      );
      expect(DispatchTimeoutEngine.isOfferActive(activeOffer), isTrue);

      final expiredOffer = DispatchOffer(
        offerId: 'off_exp',
        dispatchId: 'd1',
        orderId: 'o1',
        driverId: 'drv1',
        driverName: 'علي',
        driverPhone: '0770',
        attemptNumber: 1,
        createdAt: DateTime.now().subtract(const Duration(seconds: 30)),
        expiresAt: DateTime.now().subtract(const Duration(seconds: 5)),
      );
      expect(DispatchTimeoutEngine.isOfferActive(expiredOffer), isFalse);
    });

    // 6. DispatchEngine End-to-End Orchestration
    test('10. DispatchEngine dispatches offer to top candidate in nearest search ring', () async {
      final mockRepo = MockDispatchRepository();
      final now = DateTime.now();

      mockRepo.drivers.addAll([
        DispatchCandidate(
          driverId: 'drv_close',
          name: 'كابتن سريع',
          phone: '0780111111',
          rating: 4.9,
          acceptanceRate: 0.95,
          activeOrdersCount: 0,
          latitude: 33.3280, // ~100m away
          longitude: 44.4070,
          lastLocationUpdate: now,
          isOnline: true,
          isApproved: true,
          status: 'active',
          role: 'delivery',
        ),
        DispatchCandidate(
          driverId: 'drv_far',
          name: 'كابتن بعيد',
          phone: '0780222222',
          rating: 4.5,
          acceptanceRate: 0.8,
          activeOrdersCount: 0,
          latitude: 33.3000, // ~3.5km away
          longitude: 44.4070,
          lastLocationUpdate: now,
          isOnline: true,
          isApproved: true,
          status: 'active',
          role: 'delivery',
        ),
      ]);

      final engine = DispatchEngine(repository: mockRepo);

      final request = DispatchRequest(
        dispatchId: 'disp_100',
        orderId: 'ord_100',
        dispatchType: DispatchType.food,
        pickupLatitude: 33.3275,
        pickupLongitude: 44.4072,
        pickupAddress: 'مطعم الصاج الريفي',
        dropoffLatitude: 33.3100,
        dropoffLongitude: 44.4200,
        dropoffAddress: 'شارع فلسطين',
        idempotencyKey: 'idemp_disp_100',
        createdAt: now,
      );

      final result = await engine.startDispatchSession(request: request);

      expect(result.isSuccess, isTrue);
      expect(result.assignedDriverId, equals('drv_close'));
      expect(mockRepo.offers.length, equals(1));
    });

    test('11. Atomic Assignment & Race Condition Protection (Driver A wins, Driver B fails)', () async {
      final mockRepo = MockDispatchRepository();
      final now = DateTime.now();

      final offerA = DispatchOffer(
        offerId: 'off_A',
        dispatchId: 'ses_race',
        orderId: 'ord_race_1',
        driverId: 'drv_A',
        driverName: 'كابتن أ',
        driverPhone: '0780111',
        attemptNumber: 1,
        createdAt: now,
        expiresAt: now.add(const Duration(seconds: 30)),
      );

      final offerB = DispatchOffer(
        offerId: 'off_B',
        dispatchId: 'ses_race',
        orderId: 'ord_race_1',
        driverId: 'drv_B',
        driverName: 'كابتن ب',
        driverPhone: '0780222',
        attemptNumber: 1,
        createdAt: now,
        expiresAt: now.add(const Duration(seconds: 30)),
      );

      mockRepo.offers['off_A'] = offerA;
      mockRepo.offers['off_B'] = offerB;
      mockRepo.sessions['ses_race'] = DispatchSession(
        sessionId: 'ses_race',
        orderId: 'ord_race_1',
        dispatchType: DispatchType.food,
        createdAt: now,
        updatedAt: now,
      );

      final engine = DispatchEngine(repository: mockRepo);

      // Driver A accepts first
      final successA = await engine.acceptOffer(
        offerId: 'off_A',
        driverId: 'drv_A',
        orderId: 'ord_race_1',
        dispatchType: DispatchType.food,
      );
      expect(successA, isTrue);
      expect(mockRepo.assignedOrders['ord_race_1'], equals('drv_A'));

      // Driver B tries to accept simultaneously -> Throws SecurityViolationException!
      expect(
        () => engine.acceptOffer(
          offerId: 'off_B',
          driverId: 'drv_B',
          orderId: 'ord_race_1',
          dispatchType: DispatchType.food,
        ),
        throwsA(isA<SecurityViolationException>()),
      );

      // Assigned driver remains Driver A
      expect(mockRepo.assignedOrders['ord_race_1'], equals('drv_A'));
    });

    test('12. Rejects accept on expired offer', () async {
      final mockRepo = MockDispatchRepository();
      final now = DateTime.now();

      final expiredOffer = DispatchOffer(
        offerId: 'off_expired_99',
        dispatchId: 'ses_exp',
        orderId: 'ord_exp',
        driverId: 'drv_late',
        driverName: 'كابتن متأخر',
        driverPhone: '0780333',
        attemptNumber: 1,
        createdAt: now.subtract(const Duration(seconds: 40)),
        expiresAt: now.subtract(const Duration(seconds: 10)), // Expired!
      );

      mockRepo.offers['off_expired_99'] = expiredOffer;

      final engine = DispatchEngine(repository: mockRepo);

      expect(
        () => engine.acceptOffer(
          offerId: 'off_expired_99',
          driverId: 'drv_late',
          orderId: 'ord_exp',
          dispatchType: DispatchType.food,
        ),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('13. Driver reject marks offer rejected successfully', () async {
      final mockRepo = MockDispatchRepository();
      final now = DateTime.now();

      final offer = DispatchOffer(
        offerId: 'off_rej',
        dispatchId: 'ses_rej',
        orderId: 'ord_rej',
        driverId: 'drv_rej',
        driverName: 'كابتن رافض',
        driverPhone: '0780444',
        attemptNumber: 1,
        createdAt: now,
        expiresAt: now.add(const Duration(seconds: 30)),
      );

      mockRepo.offers['off_rej'] = offer;

      final engine = DispatchEngine(repository: mockRepo);
      final rejected = await engine.rejectOffer(
        offerId: 'off_rej',
        driverId: 'drv_rej',
        reason: 'بعيد جداً عن موقعي الحالي',
      );

      expect(rejected, isTrue);
      expect(mockRepo.offers['off_rej']!.status, equals(DispatchOfferStatus.rejected));
    });

    test('14. Returns failure when no drivers are online', () async {
      final mockRepo = MockDispatchRepository(); // Empty drivers list
      final engine = DispatchEngine(repository: mockRepo);

      final request = DispatchRequest(
        dispatchId: 'disp_empty',
        orderId: 'ord_empty',
        dispatchType: DispatchType.taxi,
        pickupLatitude: 33.3275,
        pickupLongitude: 44.4072,
        pickupAddress: 'المنصور',
        dropoffLatitude: 33.3100,
        dropoffLongitude: 44.4200,
        dropoffAddress: 'اليرموك',
        idempotencyKey: 'idemp_empty',
        createdAt: DateTime.now(),
      );

      final result = await engine.startDispatchSession(request: request);

      expect(result.isSuccess, isFalse);
      expect(result.failureReason, equals(DispatchFailureReason.noDriversAvailable));
    });
  });
}
