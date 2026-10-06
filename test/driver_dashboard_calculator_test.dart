import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/taxi/domain/entities/driver_dashboard_models.dart';
import 'package:dalal_alqaim/features/taxi/domain/services/driver_dashboard_calculator.dart';

void main() {
  group('DriverDashboardCalculator Unit Tests', () {
    test('calculateCancellationRate should calculate accurate formatted percentage', () {
      expect(DriverDashboardCalculator.calculateCancellationRate(totalTrips: 0, cancelledTrips: 0), equals('0%'));
      expect(DriverDashboardCalculator.calculateCancellationRate(totalTrips: 10, cancelledTrips: 2), equals('20.0%'));
      expect(DriverDashboardCalculator.calculateCancellationRate(totalTrips: 20, cancelledTrips: 1), equals('5.0%'));
    });

    test('filterFreshPendingRequests should filter expired, rejected, and driver-rejected requests', () {
      final now = DateTime(2026, 8, 26, 12, 0, 0);

      final rFresh = RideRequestEntity(
        id: 'r_fresh',
        passengerName: 'علي',
        passengerPhone: '0770',
        pickupAddress: 'المنصور',
        pickupLat: 33.3,
        pickupLng: 44.3,
        destinationAddress: 'الكرادة',
        destinationLat: 33.31,
        destinationLng: 44.35,
        estimatedFare: 5000,
        status: RideStatus.searching,
        createdAt: now.subtract(const Duration(seconds: 10)),
      );

      final rExpired = RideRequestEntity(
        id: 'r_expired',
        passengerName: 'محمد',
        passengerPhone: '0780',
        pickupAddress: 'اليرموك',
        pickupLat: 33.3,
        pickupLng: 44.3,
        destinationAddress: 'الجادرية',
        destinationLat: 33.31,
        destinationLng: 44.35,
        estimatedFare: 6000,
        status: RideStatus.searching,
        createdAt: now.subtract(const Duration(seconds: 45)), // >30s
      );

      final rRejectedInDb = RideRequestEntity(
        id: 'r_rejected',
        passengerName: 'حسين',
        passengerPhone: '0750',
        pickupAddress: 'زيونة',
        pickupLat: 33.3,
        pickupLng: 44.3,
        destinationAddress: 'الشعب',
        destinationLat: 33.31,
        destinationLng: 44.35,
        estimatedFare: 7000,
        status: RideStatus.searching,
        createdAt: now.subtract(const Duration(seconds: 5)),
        rejectedDrivers: const ['driver_me'],
      );

      final all = [rFresh, rExpired, rRejectedInDb];

      final filtered = DriverDashboardCalculator.filterFreshPendingRequests(
        all,
        currentDriverUid: 'driver_me',
        locallyRejectedIds: {'r_locally_rejected'},
        now: now,
      );

      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('r_fresh'));
    });

    test('filterMyWayRequests should filter by destination or pickup keyword', () {
      final r1 = RideRequestEntity(
        id: '1',
        passengerName: 'A',
        passengerPhone: '077',
        pickupAddress: 'شارع فلسطين',
        pickupLat: 33.3,
        pickupLng: 44.3,
        destinationAddress: 'حي الجامعة',
        destinationLat: 33.31,
        destinationLng: 44.35,
        estimatedFare: 5000,
        status: RideStatus.searching,
      );

      final r2 = RideRequestEntity(
        id: '2',
        passengerName: 'B',
        passengerPhone: '078',
        pickupAddress: 'الكرادة',
        pickupLat: 33.3,
        pickupLng: 44.3,
        destinationAddress: 'الزعفرانية',
        destinationLat: 33.31,
        destinationLng: 44.35,
        estimatedFare: 4000,
        status: RideStatus.searching,
      );

      final filtered = DriverDashboardCalculator.filterMyWayRequests([r1, r2], 'الجامعة');
      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('1'));

      final allNull = DriverDashboardCalculator.filterMyWayRequests([r1, r2], null);
      expect(allNull.length, equals(2));
    });

    test('isCommissionBlocked should accurately check debt limit threshold', () {
      expect(DriverDashboardCalculator.isCommissionBlocked(14999.0), isFalse);
      expect(DriverDashboardCalculator.isCommissionBlocked(15000.0), isTrue);
      expect(DriverDashboardCalculator.isCommissionBlocked(25000.0), isTrue);
    });

    test('calculateTargetProgress should compute bonus percentage accurately', () {
      expect(DriverDashboardCalculator.calculateTargetProgress(0, 5), equals(0.0));
      expect(DriverDashboardCalculator.calculateTargetProgress(3, 5), equals(0.6));
      expect(DriverDashboardCalculator.calculateTargetProgress(5, 5), equals(1.0));
      expect(DriverDashboardCalculator.calculateTargetProgress(8, 5), equals(1.0)); // Capped at 100%
    });
  });
}
