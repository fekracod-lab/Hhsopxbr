import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/pricing/domain/enums/pricing_enums.dart';
import 'package:dalal_alqaim/core/pricing/domain/entities/fare_breakdown.dart';
import 'package:dalal_alqaim/core/pricing/domain/entities/pricing_snapshot.dart';
import 'package:dalal_alqaim/core/pricing/domain/services/pricing_integrity_checker.dart';

void main() {
  group('Pricing Integrity & Tamper Protection Tests', () {
    test('1. Generates deterministic and identical hashes for identical inputs', () {
      const breakdown = FareBreakdown(
        baseFare: 3000,
        distanceFare: 2500,
        timeFare: 1000,
        subtotal: 6500,
        finalFare: 6500,
      );

      final hash1 = PricingIntegrityChecker.generateCalculationHash(
        orderId: 'ord_123',
        pricingPolicyVersion: 1,
        serviceType: PricingServiceType.taxi,
        breakdown: breakdown,
      );

      final hash2 = PricingIntegrityChecker.generateCalculationHash(
        orderId: 'ord_123',
        pricingPolicyVersion: 1,
        serviceType: PricingServiceType.taxi,
        breakdown: breakdown,
      );

      expect(hash1, equals(hash2));
      expect(hash1.startsWith('hsh_'), isTrue);
    });

    test('2. Changing serviceType produces distinct hash', () {
      const breakdown = FareBreakdown(
        baseFare: 3000,
        distanceFare: 2500,
        subtotal: 5500,
        finalFare: 5500,
      );

      final hashTaxi = PricingIntegrityChecker.generateCalculationHash(
        orderId: 'ord_123',
        pricingPolicyVersion: 1,
        serviceType: PricingServiceType.taxi,
        breakdown: breakdown,
      );

      final hashFood = PricingIntegrityChecker.generateCalculationHash(
        orderId: 'ord_123',
        pricingPolicyVersion: 1,
        serviceType: PricingServiceType.food,
        breakdown: breakdown,
      );

      expect(hashTaxi, isNot(equals(hashFood)));
    });

    test('3. Modifying policy version invalidates snapshot integrity', () {
      const breakdown = FareBreakdown(
        baseFare: 2000,
        distanceFare: 1000,
        subtotal: 3000,
        finalFare: 3000,
      );

      final validHash = PricingIntegrityChecker.generateCalculationHash(
        orderId: 'ord_version_test',
        pricingPolicyVersion: 1,
        serviceType: PricingServiceType.food,
        breakdown: breakdown,
      );

      final validSnapshot = PricingSnapshot(
        snapshotId: 'snap_1',
        orderId: 'ord_version_test',
        pricingPolicyVersion: 1,
        serviceType: PricingServiceType.food,
        fareBreakdown: breakdown,
        calculationHash: validHash,
        calculatedAt: DateTime.now(),
      );
      expect(PricingIntegrityChecker.verifySnapshotIntegrity(validSnapshot), isTrue);

      final tamperedVersionSnapshot = PricingSnapshot(
        snapshotId: 'snap_1',
        orderId: 'ord_version_test',
        pricingPolicyVersion: 2, // Changed policy version!
        serviceType: PricingServiceType.food,
        fareBreakdown: breakdown,
        calculationHash: validHash,
        calculatedAt: DateTime.now(),
      );
      expect(PricingIntegrityChecker.verifySnapshotIntegrity(tamperedVersionSnapshot), isFalse);
    });
  });
}
