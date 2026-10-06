import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/pricing/domain/enums/pricing_enums.dart';
import 'package:dalal_alqaim/core/pricing/domain/entities/fare_request.dart';
import 'package:dalal_alqaim/core/pricing/domain/entities/pricing_policy.dart';
import 'package:dalal_alqaim/core/pricing/domain/entities/pricing_snapshot.dart';
import 'package:dalal_alqaim/core/pricing/domain/repositories/i_pricing_repository.dart';
import 'package:dalal_alqaim/core/pricing/application/pricing_engine.dart';
import 'package:dalal_alqaim/core/finance/domain/services/settlement_calculator.dart';

class MockPricingRegressionRepo implements IPricingRepository {
  final Map<String, PricingSnapshot> snapshots = {};

  @override
  Future<PricingPolicy> getActivePolicy(PricingServiceType serviceType) async {
    switch (serviceType) {
      case PricingServiceType.taxi:
        return PricingPolicy.defaultTaxiPolicy;
      case PricingServiceType.food:
        return PricingPolicy.defaultFoodPolicy;
      case PricingServiceType.store:
        return PricingPolicy.defaultStorePolicy;
      case PricingServiceType.mersal:
        return PricingPolicy.defaultMersalPolicy;
    }
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
  Future<bool> verifyIdempotencyKey(String idempotencyKey) async => true;
}

void main() {
  group('Pricing Engine & Financial / Order Regression Integration Tests', () {
    test('1. Pricing Snapshot flows seamlessly into Financial Settlement Calculator (Delivery)', () async {
      final repo = MockPricingRegressionRepo();
      final pricingEngine = PricingEngine(repository: repo);

      final fareRequest = FareRequest(
        serviceType: PricingServiceType.food,
        distanceMeters: 4000.0, // 4 km -> 1000 IQD + 1500 base = 2500 IQD delivery fee
        requestedAt: DateTime.now(),
        idempotencyKey: 'idemp_reg_1',
      );

      final snapshot = await pricingEngine.createAndPersistSnapshot(
        orderId: 'order_reg_101',
        request: fareRequest,
      );

      expect(snapshot.finalFare, equals(2500));
      expect(pricingEngine.verifySnapshotIntegrity(snapshot), isTrue);

      // Financial Engine Integration:
      // Subtotal of items: 10,000 IQD, Delivery fee: 2,500 IQD
      const foodItemsSubtotal = 10000;

      final settlement = SettlementCalculator.calculateDeliverySettlement(
        orderId: 'order_reg_101',
        orderSource: 'food',
        customerId: 'cust_101',
        driverId: 'drv_101',
        merchantId: 'merch_101',
        subtotal: foodItemsSubtotal,
        deliveryFee: snapshot.finalFare,
        paymentMethod: 'cash',
        idempotencyKey: 'idemp_settle_101',
      );

      // Verifies exact double-entry equality
      expect(settlement.merchantAmount, equals(foodItemsSubtotal));
      expect(settlement.driverAmount, equals(2000)); // 2500 - 500 platform fee
      expect(settlement.platformCommission, equals(500));
      expect(settlement.grossOrderAmount, equals(settlement.merchantAmount + settlement.driverAmount + settlement.platformCommission));
    });

    test('2. Pricing Snapshot flows seamlessly into Financial Settlement Calculator (Taxi Ride)', () async {
      final repo = MockPricingRegressionRepo();
      final pricingEngine = PricingEngine(repository: repo);

      final fareRequest = FareRequest(
        serviceType: PricingServiceType.taxi,
        distanceMeters: 8000.0, // 8 km -> 4,000 IQD
        estimatedDurationSeconds: 600, // 10 mins -> 1,000 IQD
        requestedAt: DateTime(2026, 8, 28, 12, 0),
        idempotencyKey: 'idemp_reg_taxi',
      );

      final snapshot = await pricingEngine.createAndPersistSnapshot(
        orderId: 'ride_reg_202',
        request: fareRequest,
      );

      // Base (3000) + Distance (4000) + Time (1000) + Service (500) = 8500 IQD
      expect(snapshot.finalFare, equals(8500));

      final settlement = SettlementCalculator.calculateTaxiSettlement(
        rideId: 'ride_reg_202',
        customerId: 'cust_202',
        driverId: 'drv_202',
        grossFare: snapshot.finalFare,
        paymentMethod: 'cash',
        idempotencyKey: 'idemp_settle_taxi_202',
      );

      // Taxi 10% platform commission: 850 IQD -> Driver gets 7,650 IQD
      expect(settlement.platformCommission, equals(850));
      expect(settlement.driverAmount, equals(7650));
      expect(settlement.merchantAmount, equals(0));
      expect(settlement.grossOrderAmount, equals(settlement.driverAmount + settlement.platformCommission));
    });
  });
}
