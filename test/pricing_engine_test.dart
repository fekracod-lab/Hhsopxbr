import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/pricing/domain/enums/pricing_enums.dart';
import 'package:dalal_alqaim/core/pricing/domain/entities/fare_request.dart';
import 'package:dalal_alqaim/core/pricing/domain/entities/fare_breakdown.dart';
import 'package:dalal_alqaim/core/pricing/domain/entities/pricing_policy.dart';
import 'package:dalal_alqaim/core/pricing/domain/entities/pricing_snapshot.dart';
import 'package:dalal_alqaim/core/pricing/domain/services/fare_calculator.dart';
import 'package:dalal_alqaim/core/pricing/domain/services/pricing_rounding_engine.dart';
import 'package:dalal_alqaim/core/pricing/domain/services/pricing_limits_validator.dart';
import 'package:dalal_alqaim/core/pricing/domain/services/pricing_integrity_checker.dart';
import 'package:dalal_alqaim/core/pricing/domain/services/demand_pressure_engine.dart';
import 'package:dalal_alqaim/core/pricing/domain/services/peak_hours_engine.dart';
import 'package:dalal_alqaim/core/pricing/domain/repositories/i_pricing_repository.dart';
import 'package:dalal_alqaim/core/pricing/application/pricing_engine.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

class MockPricingRepository implements IPricingRepository {
  final Map<String, PricingPolicy> policies = {};
  final Map<String, PricingSnapshot> snapshots = {};
  final Set<String> idempotencyKeys = {};

  @override
  Future<PricingPolicy> getActivePolicy(PricingServiceType serviceType) async {
    return policies[serviceType.key] ??
        (serviceType == PricingServiceType.taxi
            ? PricingPolicy.defaultTaxiPolicy
            : serviceType == PricingServiceType.food
                ? PricingPolicy.defaultFoodPolicy
                : serviceType == PricingServiceType.store
                    ? PricingPolicy.defaultStorePolicy
                    : PricingPolicy.defaultMersalPolicy);
  }

  @override
  Future<PricingSnapshot> saveSnapshot(PricingSnapshot snapshot) async {
    snapshots[snapshot.snapshotId] = snapshot;
    return snapshot;
  }

  @override
  Future<PricingSnapshot?> getSnapshot(String snapshotId) async {
    return snapshots[snapshotId];
  }

  @override
  Future<bool> verifyIdempotencyKey(String idempotencyKey) async {
    if (idempotencyKeys.contains(idempotencyKey)) return false;
    idempotencyKeys.add(idempotencyKey);
    return true;
  }
}

void main() {
  group('Dynamic Pricing & Fare Engine Comprehensive Tests', () {
    // 1. PricingRoundingEngine Tests
    test('1. PricingRoundingEngine rounds correctly to 250 IQD intervals', () {
      expect(PricingRoundingEngine.round(3120, RoundingUnit.twoFifty), equals(3000));
      expect(PricingRoundingEngine.round(3130, RoundingUnit.twoFifty), equals(3250));
      expect(PricingRoundingEngine.round(3249, RoundingUnit.twoFifty), equals(3250));
      expect(PricingRoundingEngine.round(3250, RoundingUnit.twoFifty), equals(3250));
      expect(PricingRoundingEngine.round(3374, RoundingUnit.twoFifty), equals(3250));
      expect(PricingRoundingEngine.round(3375, RoundingUnit.twoFifty), equals(3500));
    });

    test('2. PricingRoundingEngine handles 50, 100, 500 IQD and 0 amounts', () {
      expect(PricingRoundingEngine.round(0, RoundingUnit.hundred), equals(0));
      expect(PricingRoundingEngine.round(-500, RoundingUnit.hundred), equals(0));
      expect(PricingRoundingEngine.round(1040, RoundingUnit.fifty), equals(1050));
      expect(PricingRoundingEngine.round(1020, RoundingUnit.fifty), equals(1000));
      expect(PricingRoundingEngine.round(4200, RoundingUnit.fiveHundred), equals(4000));
      expect(PricingRoundingEngine.round(4300, RoundingUnit.fiveHundred), equals(4500));
    });

    // 2. PricingLimitsValidator Tests
    test('3. PricingLimitsValidator rejects negative or NaN distance and durations', () {
      final policy = PricingPolicy.defaultTaxiPolicy;

      // Negative distance
      final negativeDistRequest = FareRequest(
        serviceType: PricingServiceType.taxi,
        distanceMeters: -100.0,
        requestedAt: DateTime.now(),
        idempotencyKey: 'idemp_neg_dist',
      );
      expect(
        () => PricingLimitsValidator.validateRequest(negativeDistRequest, policy),
        throwsA(isA<SecurityViolationException>()),
      );

      // Excessive distance (> 200 km)
      final excessiveDistRequest = FareRequest(
        serviceType: PricingServiceType.taxi,
        distanceMeters: 250000.0,
        requestedAt: DateTime.now(),
        idempotencyKey: 'idemp_exc_dist',
      );
      expect(
        () => PricingLimitsValidator.validateRequest(excessiveDistRequest, policy),
        throwsA(isA<SecurityViolationException>()),
      );

      // Negative discount
      final negativeDiscountRequest = FareRequest(
        serviceType: PricingServiceType.taxi,
        distanceMeters: 5000.0,
        discount: -500,
        requestedAt: DateTime.now(),
        idempotencyKey: 'idemp_neg_disc',
      );
      expect(
        () => PricingLimitsValidator.validateRequest(negativeDiscountRequest, policy),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('4. PricingLimitsValidator enforces Minimum and Maximum Fare bounds', () {
      final policy = PricingPolicy(
        policyId: 'pol_bounds',
        serviceType: PricingServiceType.taxi,
        version: 1,
        baseFare: 1000,
        pricePerKm: 200,
        minimumFare: 3000,
        maximumFare: 20000,
        effectiveFrom: DateTime.now(),
      );

      expect(PricingLimitsValidator.clampFare(1500, policy), equals(3000)); // Clamped to Min
      expect(PricingLimitsValidator.clampFare(12000, policy), equals(12000)); // Normal
      expect(PricingLimitsValidator.clampFare(25000, policy), equals(20000)); // Clamped to Max
    });

    // 3. DemandPressureEngine Tests
    test('5. DemandPressureEngine computes correct surge levels and multipliers', () {
      // High supply, low demand -> Normal (1.0x)
      final normalSurge = DemandPressureEngine.calculateSurge(
        activeDemand: 5,
        availableSupply: 15, // Ratio 3.0
      );
      expect(normalSurge.level, equals(SurgeLevel.normal));
      expect(normalSurge.multiplier, equals(1.0));

      // Tight supply -> Elevated (1.15x)
      final elevatedSurge = DemandPressureEngine.calculateSurge(
        activeDemand: 10,
        availableSupply: 10, // Ratio 1.0
      );
      expect(elevatedSurge.level, equals(SurgeLevel.elevated));
      expect(elevatedSurge.multiplier, equals(1.15));

      // Low supply -> Critical (clamped to maxMultiplier)
      final criticalSurge = DemandPressureEngine.calculateSurge(
        activeDemand: 50,
        availableSupply: 2, // Ratio 0.04
        maxMultiplier: 2.0,
      );
      expect(criticalSurge.level, equals(SurgeLevel.critical));
      expect(criticalSurge.multiplier, equals(2.0));
    });

    // 4. PeakHoursEngine Tests
    test('6. PeakHoursEngine detects standard peak and midnight-crossing peaks', () {
      const standardPeak = PeakPeriod(startHour: 17, endHour: 20, multiplier: 1.3);
      const midnightPeak = PeakPeriod(startHour: 23, endHour: 2, multiplier: 1.5);

      final peakPeriods = [standardPeak, midnightPeak];

      // 18:30 -> Inside standard peak
      final eveningTime = DateTime(2026, 8, 28, 18, 30);
      expect(PeakHoursEngine.calculatePeakMultiplier(time: eveningTime, peakPeriods: peakPeriods), equals(1.3));

      // 23:45 -> Inside midnight crossing peak
      final lateNightTime = DateTime(2026, 8, 28, 23, 45);
      expect(PeakHoursEngine.calculatePeakMultiplier(time: lateNightTime, peakPeriods: peakPeriods), equals(1.5));

      // 01:15 -> Inside midnight crossing peak
      final earlyMorningTime = DateTime(2026, 8, 28, 1, 15);
      expect(PeakHoursEngine.calculatePeakMultiplier(time: earlyMorningTime, peakPeriods: peakPeriods), equals(1.5));

      // 12:00 -> Outside any peak
      final noonTime = DateTime(2026, 8, 28, 12, 0);
      expect(PeakHoursEngine.calculatePeakMultiplier(time: noonTime, peakPeriods: peakPeriods), equals(1.0));
    });

    // 5. FareCalculator Tests across Services
    test('7. FareCalculator calculates deterministic Taxi Fare breakdown', () {
      final policy = PricingPolicy.defaultTaxiPolicy;
      final request = FareRequest(
        serviceType: PricingServiceType.taxi,
        distanceMeters: 5000.0, // 5 km -> 5 * 500 = 2500 IQD
        estimatedDurationSeconds: 600, // 10 mins -> 10 * 100 = 1000 IQD
        waitingMinutes: 5, // 5 * 150 = 750 IQD
        requestedAt: DateTime(2026, 8, 28, 12, 0), // No peak
        idempotencyKey: 'idemp_taxi_1',
      );

      final breakdown = FareCalculator.calculateFare(request: request, policy: policy);

      expect(breakdown.baseFare, equals(3000));
      expect(breakdown.distanceFare, equals(2500));
      expect(breakdown.timeFare, equals(1000));
      expect(breakdown.waitingFare, equals(750));
      expect(breakdown.serviceFee, equals(500));
      expect(breakdown.subtotal, equals(7750));
      expect(breakdown.finalFare, equals(7750)); // Rounded to 250
    });

    test('8. FareCalculator calculates Food & Store Delivery Fees', () {
      final foodPolicy = PricingPolicy.defaultFoodPolicy;
      final foodRequest = FareRequest(
        serviceType: PricingServiceType.food,
        distanceMeters: 4000.0, // 4 km * 250 = 1000 IQD
        requestedAt: DateTime(2026, 8, 28, 12, 0),
        idempotencyKey: 'idemp_food_1',
      );

      final foodBreakdown = FareCalculator.calculateFare(request: foodRequest, policy: foodPolicy);
      expect(foodBreakdown.baseFare, equals(1500));
      expect(foodBreakdown.distanceFare, equals(1000));
      expect(foodBreakdown.finalFare, equals(2500)); // 1500 + 1000 = 2500 IQD

      final storePolicy = PricingPolicy.defaultStorePolicy;
      final storeRequest = FareRequest(
        serviceType: PricingServiceType.store,
        distanceMeters: 3000.0, // 3 km * 300 = 900 IQD
        requestedAt: DateTime(2026, 8, 28, 12, 0),
        idempotencyKey: 'idemp_store_1',
      );

      final storeBreakdown = FareCalculator.calculateFare(request: storeRequest, policy: storePolicy);
      expect(storeBreakdown.baseFare, equals(2000));
      expect(storeBreakdown.distanceFare, equals(900));
      expect(storeBreakdown.subtotal, equals(2900));
      expect(storeBreakdown.finalFare, equals(3000)); // 2900 rounded to nearest 250 -> 3000 IQD
    });

    test('9. FareCalculator calculates Mersal parcel pricing with size surcharges & stops', () {
      final mersalPolicy = PricingPolicy.defaultMersalPolicy;
      final mersalRequest = FareRequest(
        serviceType: PricingServiceType.mersal,
        distanceMeters: 6000.0, // 6 km * 400 = 2400 IQD
        packageSize: PackageSize.large, // 1500 IQD
        stopCount: 2, // 2 * 1000 = 2000 IQD
        requestedAt: DateTime(2026, 8, 28, 12, 0),
        idempotencyKey: 'idemp_mersal_1',
      );

      final breakdown = FareCalculator.calculateFare(request: mersalRequest, policy: mersalPolicy);
      expect(breakdown.baseFare, equals(2500));
      expect(breakdown.distanceFare, equals(2400));
      expect(breakdown.packageFee, equals(1500));
      expect(breakdown.stopFee, equals(2000));
      expect(breakdown.subtotal, equals(8400));
      expect(breakdown.finalFare, equals(8500)); // 8400 rounded to 250 -> 8500 IQD
    });

    // 6. PricingIntegrityChecker & Snapshot Immutability Tests
    test('10. PricingIntegrityChecker detects any tampering in PricingSnapshot', () {
      final policy = PricingPolicy.defaultTaxiPolicy;
      final request = FareRequest(
        serviceType: PricingServiceType.taxi,
        distanceMeters: 5000.0,
        requestedAt: DateTime(2026, 8, 28, 12, 0),
        idempotencyKey: 'idemp_hash_test',
      );

      final breakdown = FareCalculator.calculateFare(request: request, policy: policy);

      final validHash = PricingIntegrityChecker.generateCalculationHash(
        orderId: 'ord_secure_99',
        pricingPolicyVersion: policy.version,
        serviceType: request.serviceType,
        breakdown: breakdown,
      );

      final validSnapshot = PricingSnapshot(
        snapshotId: 'snap-ord_secure_99',
        orderId: 'ord_secure_99',
        pricingPolicyVersion: policy.version,
        serviceType: request.serviceType,
        fareBreakdown: breakdown,
        calculationHash: validHash,
        calculatedAt: DateTime.now(),
      );

      expect(PricingIntegrityChecker.verifySnapshotIntegrity(validSnapshot), isTrue);

      // Adversary attempts to tamper with finalFare (changing 6,000 -> 500 IQD)
      final tamperedBreakdown = FareBreakdown(
        baseFare: breakdown.baseFare,
        distanceFare: breakdown.distanceFare,
        subtotal: breakdown.subtotal,
        finalFare: 500, // Tampered!
      );

      final tamperedSnapshot = PricingSnapshot(
        snapshotId: validSnapshot.snapshotId,
        orderId: validSnapshot.orderId,
        pricingPolicyVersion: validSnapshot.pricingPolicyVersion,
        serviceType: validSnapshot.serviceType,
        fareBreakdown: tamperedBreakdown,
        calculationHash: validHash, // Old hash!
        calculatedAt: validSnapshot.calculatedAt,
      );

      expect(PricingIntegrityChecker.verifySnapshotIntegrity(tamperedSnapshot), isFalse);
    });

    // 7. PricingEngine End-to-End Orchestration & Snapshot Persistence
    test('11. PricingEngine creates and persists verified snapshot', () async {
      final mockRepo = MockPricingRepository();
      final engine = PricingEngine(repository: mockRepo);

      final request = FareRequest(
        serviceType: PricingServiceType.food,
        distanceMeters: 3000.0,
        requestedAt: DateTime.now(),
        idempotencyKey: 'idemp_persisted_snap',
      );

      final snapshot = await engine.createAndPersistSnapshot(
        orderId: 'order_persist_77',
        request: request,
      );

      expect(snapshot.snapshotId, equals('snap-order_persist_77'));
      expect(snapshot.finalFare, greaterThan(0));
      expect(engine.verifySnapshotIntegrity(snapshot), isTrue);
      expect(mockRepo.snapshots.containsKey('snap-order_persist_77'), isTrue);
    });

    // 8. Backward Compatibility Helpers
    test('12. Backward compatibility helpers produce valid estimates', () {
      final foodFee = PricingEngine.estimateDeliveryFee(distanceKm: 2.5, isStore: false);
      expect(foodFee, greaterThanOrEqualTo(1500));

      final storeFee = PricingEngine.estimateDeliveryFee(distanceKm: 4.0, isStore: true);
      expect(storeFee, greaterThanOrEqualTo(2000));

      final taxiFare = PricingEngine.estimateTaxiFare(distanceKm: 8.0, durationMinutes: 15);
      expect(taxiFare, greaterThanOrEqualTo(3000));
    });
  });
}
