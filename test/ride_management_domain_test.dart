// 🧪 اختبارات نطاق إدارة رحلات التكسي (Taxi Ride Management Domain Tests)
// Pure Dart Unit Tests — Zero Framework & Firebase Dependencies

import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/taxi/domain/entities/ride_management_models.dart';
import 'package:dalal_alqaim/features/taxi/domain/services/ride_management_calculator.dart';

void main() {
  group('Taxi Ride Management — Domain Entities & Models Tests', () {
    test('1. RideStatusEnum parses valid and legacy aliases correctly', () {
      expect(RideStatusEnum.fromString('searching'), RideStatusEnum.searching);
      expect(RideStatusEnum.fromString('pending'), RideStatusEnum.searching);
      expect(RideStatusEnum.fromString('accepted'), RideStatusEnum.accepted);
      expect(RideStatusEnum.fromString('driver_accepted'), RideStatusEnum.accepted);
      expect(RideStatusEnum.fromString('arrived'), RideStatusEnum.arrived);
      expect(RideStatusEnum.fromString('in_progress'), RideStatusEnum.in_progress);
      expect(RideStatusEnum.fromString('delivering'), RideStatusEnum.in_progress);
      expect(RideStatusEnum.fromString('completed'), RideStatusEnum.completed);
      expect(RideStatusEnum.fromString('cancelled'), RideStatusEnum.cancelled);
      expect(RideStatusEnum.fromString('canceled'), RideStatusEnum.cancelled);
      expect(RideStatusEnum.fromString('unknown_status'), RideStatusEnum.unknown);
      expect(RideStatusEnum.fromString(null), RideStatusEnum.unknown);
    });

    test('2. RideStatusEnum serializes to Firestore strings properly', () {
      expect(RideStatusEnum.searching.toFirestoreString(), 'searching');
      expect(RideStatusEnum.accepted.toFirestoreString(), 'accepted');
      expect(RideStatusEnum.in_progress.toFirestoreString(), 'in_progress');
      expect(RideStatusEnum.completed.toFirestoreString(), 'completed');
      expect(RideStatusEnum.cancelled.toFirestoreString(), 'cancelled');
    });

    test('3. RideStatusEnum provides localized Arabic labels', () {
      expect(RideStatusEnum.searching.arabicLabel, contains('بانتظار كابتن'));
      expect(RideStatusEnum.accepted.arabicLabel, contains('تم القبول'));
      expect(RideStatusEnum.completed.arabicLabel, contains('مكتملة'));
    });

    test('4. PureGeoPoint equality and hashcode check', () {
      const p1 = PureGeoPoint(latitude: 34.3414, longitude: 41.0805);
      const p2 = PureGeoPoint(latitude: 34.3414, longitude: 41.0805);
      const p3 = PureGeoPoint(latitude: 33.3152, longitude: 44.3661);

      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1, isNot(equals(p3)));
      expect(p1.toString(), contains('34.3414'));
    });

    test('5. RideAdminEntity active / completed / cancelled flags', () {
      const rSearching = RideAdminEntity(id: 'r1', status: RideStatusEnum.searching);
      const rAccepted = RideAdminEntity(id: 'r2', status: RideStatusEnum.accepted, driverId: 'd1');
      const rArrived = RideAdminEntity(id: 'r3', status: RideStatusEnum.arrived);
      const rProgress = RideAdminEntity(id: 'r4', status: RideStatusEnum.in_progress);
      const rCompleted = RideAdminEntity(id: 'r5', status: RideStatusEnum.completed);
      const rCancelled = RideAdminEntity(id: 'r6', status: RideStatusEnum.cancelled);

      expect(rSearching.isActive, isTrue);
      expect(rAccepted.isActive, isTrue);
      expect(rArrived.isActive, isTrue);
      expect(rProgress.isActive, isTrue);
      expect(rCompleted.isActive, isFalse);
      expect(rCompleted.isCompleted, isTrue);
      expect(rCancelled.isActive, isFalse);
      expect(rCancelled.isCancelled, isTrue);
      expect(rAccepted.hasDriverAssigned, isTrue);
      expect(rSearching.hasDriverAssigned, isFalse);
    });

    test('6. TaxiDriverAdminEntity debt blocking rules', () {
      // Debt < Limit
      const d1 = TaxiDriverAdminEntity(id: 'd1', appDebt: 5000, commissionLimit: 10000);
      expect(d1.isBlockedByDebt, isFalse);
      expect(d1.debtRatio, closeTo(0.5, 0.01));

      // Debt >= Limit and NO exception
      const d2 = TaxiDriverAdminEntity(id: 'd2', appDebt: 12000, commissionLimit: 10000, allowCommissionException: false);
      expect(d2.isBlockedByDebt, isTrue);
      expect(d2.debtRatio, equals(1.0));

      // Debt >= Limit with EXCEPTION allowed
      const d3 = TaxiDriverAdminEntity(id: 'd3', appDebt: 15000, commissionLimit: 10000, allowCommissionException: true);
      expect(d3.isBlockedByDebt, isFalse);
    });

    test('7. TaxiDriverAdminEntity handles zero commission limit safely', () {
      const dZero = TaxiDriverAdminEntity(id: 'dz', appDebt: 1000, commissionLimit: 0);
      expect(dZero.debtRatio, equals(1.0));
    });

    test('8. DriverReviewAdminEntity creation and equality check', () {
      const rev1 = DriverReviewAdminEntity(id: 'rev1', driverId: 'd1', rating: 4.8);
      const rev2 = DriverReviewAdminEntity(id: 'rev1', driverId: 'd1', rating: 4.8);
      const rev3 = DriverReviewAdminEntity(id: 'rev2', driverId: 'd1', rating: 3.0);

      expect(rev1, equals(rev2));
      expect(rev1.hashCode, equals(rev2.hashCode));
      expect(rev1, isNot(equals(rev3)));
    });

    test('9. RideManagementKpiMetrics equality check', () {
      const k1 = RideManagementKpiMetrics(onlineDriversCount: 5, activeTripsCount: 2);
      const k2 = RideManagementKpiMetrics(onlineDriversCount: 5, activeTripsCount: 2);
      const k3 = RideManagementKpiMetrics(onlineDriversCount: 3, activeTripsCount: 1);

      expect(k1, equals(k2));
      expect(k1.hashCode, equals(k2.hashCode));
      expect(k1, isNot(equals(k3)));
    });

    test('10. RideHistoryAnalyticsMetrics equality check', () {
      const a1 = RideHistoryAnalyticsMetrics(totalCompletedRides: 10, totalGmv: 50000);
      const a2 = RideHistoryAnalyticsMetrics(totalCompletedRides: 10, totalGmv: 50000);
      const a3 = RideHistoryAnalyticsMetrics(totalCompletedRides: 5, totalGmv: 25000);

      expect(a1, equals(a2));
      expect(a1.hashCode, equals(a2.hashCode));
      expect(a1, isNot(equals(a3)));
    });
  });

  group('Taxi Ride Management — Calculator & Logic Service Tests', () {
    test('11. calculateKpiMetrics computes accurate operational stats', () {
      final now = DateTime(2026, 8, 27, 14, 0);

      final drivers = [
        const TaxiDriverAdminEntity(id: 'd1', isOnline: true),
        const TaxiDriverAdminEntity(id: 'd2', isOnline: true),
        const TaxiDriverAdminEntity(id: 'd3', isOnline: false),
      ];

      final rides = [
        const RideAdminEntity(id: 'r1', status: RideStatusEnum.searching),
        const RideAdminEntity(id: 'r2', status: RideStatusEnum.accepted),
        const RideAdminEntity(id: 'r3', status: RideStatusEnum.in_progress),
        const RideAdminEntity(id: 'r4', status: RideStatusEnum.arrived),
        RideAdminEntity(id: 'r5', status: RideStatusEnum.completed, completedAt: DateTime(2026, 8, 27, 10, 0)),
        RideAdminEntity(id: 'r6', status: RideStatusEnum.completed, completedAt: DateTime(2026, 8, 26, 20, 0)), // Yesterday
        const RideAdminEntity(id: 'r7', status: RideStatusEnum.cancelled),
      ];

      final kpi = RideManagementCalculator.calculateKpiMetrics(
        drivers: drivers,
        rides: rides,
        referenceTime: now,
      );

      expect(kpi.onlineDriversCount, equals(2));
      expect(kpi.activeTripsCount, equals(3)); // accepted + in_progress + arrived
      expect(kpi.searchingTripsCount, equals(1));
      expect(kpi.todayCompletedTripsCount, equals(1));
    });

    test('12. calculateHistoryAnalytics computes GMV, Commission, and Average Fare', () {
      final completed = [
        const RideAdminEntity(id: 'r1', status: RideStatusEnum.completed, fare: 4000),
        const RideAdminEntity(id: 'r2', status: RideStatusEnum.completed, fare: 6000),
        const RideAdminEntity(id: 'r3', status: RideStatusEnum.completed, fare: 5000),
      ];

      final stats = RideManagementCalculator.calculateHistoryAnalytics(completed, commissionRate: 0.10);

      expect(stats.totalCompletedRides, equals(3));
      expect(stats.totalGmv, equals(15000.0));
      expect(stats.totalPlatformCommission, equals(1500.0)); // 10%
      expect(stats.averageFare, equals(5000.0));
    });

    test('13. calculateHistoryAnalytics handles empty list gracefully', () {
      final stats = RideManagementCalculator.calculateHistoryAnalytics([]);
      expect(stats.totalCompletedRides, equals(0));
      expect(stats.totalGmv, equals(0.0));
      expect(stats.totalPlatformCommission, equals(0.0));
      expect(stats.averageFare, equals(0.0));
    });

    test('14. filterRides filters by status accurately', () {
      final rides = [
        const RideAdminEntity(id: 'r1', passengerName: 'أحمد', status: RideStatusEnum.searching),
        const RideAdminEntity(id: 'r2', passengerName: 'علي', status: RideStatusEnum.accepted),
        const RideAdminEntity(id: 'r3', passengerName: 'حسين', status: RideStatusEnum.completed),
      ];

      final searchingOnly = RideManagementCalculator.filterRides(
        rides: rides,
        statusFilter: 'searching',
        query: '',
      );
      expect(searchingOnly.length, equals(1));
      expect(searchingOnly.first.id, equals('r1'));

      final all = RideManagementCalculator.filterRides(
        rides: rides,
        statusFilter: 'all',
        query: '',
      );
      expect(all.length, equals(3));
    });

    test('15. filterRides searches by passenger, driver, locations, or ID', () {
      final rides = [
        const RideAdminEntity(
          id: 'ride_101',
          passengerName: 'محمد القيسي',
          passengerPhone: '07711111111',
          driverName: 'كابتن سنان',
          pickupAddress: 'شارع 30',
          dropoffAddress: 'مستشفى القائم',
        ),
        const RideAdminEntity(
          id: 'ride_102',
          passengerName: 'سامر خليل',
          passengerPhone: '07822222222',
          pickupAddress: 'حي التأميم',
          dropoffAddress: 'السوق المركزي',
        ),
      ];

      // Match Passenger
      expect(RideManagementCalculator.filterRides(rides: rides, statusFilter: 'all', query: 'القيسي').length, equals(1));
      // Match Phone
      expect(RideManagementCalculator.filterRides(rides: rides, statusFilter: 'all', query: '07822').length, equals(1));
      // Match Driver
      expect(RideManagementCalculator.filterRides(rides: rides, statusFilter: 'all', query: 'سنان').length, equals(1));
      // Match Pickup
      expect(RideManagementCalculator.filterRides(rides: rides, statusFilter: 'all', query: 'التأميم').length, equals(1));
      // Match Dropoff
      expect(RideManagementCalculator.filterRides(rides: rides, statusFilter: 'all', query: 'مستشفى').length, equals(1));
      // Match ID
      expect(RideManagementCalculator.filterRides(rides: rides, statusFilter: 'all', query: '101').length, equals(1));
    });

    test('16. filterDrivers filters by blocked status', () {
      final drivers = [
        const TaxiDriverAdminEntity(id: 'd1', name: 'كابتن 1', appDebt: 15000, commissionLimit: 10000), // Blocked
        const TaxiDriverAdminEntity(id: 'd2', name: 'كابتن 2', appDebt: 5000, commissionLimit: 10000),  // Active
        const TaxiDriverAdminEntity(id: 'd3', name: 'كابتن 3', appDebt: 20000, commissionLimit: 10000, allowCommissionException: true), // Exception
      ];

      final blocked = RideManagementCalculator.filterDrivers(drivers: drivers, debtFilter: 'blocked', query: '');
      expect(blocked.length, equals(1));
      expect(blocked.first.id, equals('d1'));
    });

    test('17. filterDrivers filters by exception status', () {
      final drivers = [
        const TaxiDriverAdminEntity(id: 'd1', name: 'كابتن 1', allowCommissionException: false),
        const TaxiDriverAdminEntity(id: 'd2', name: 'كابتن 2', allowCommissionException: true),
      ];

      final exception = RideManagementCalculator.filterDrivers(drivers: drivers, debtFilter: 'exception', query: '');
      expect(exception.length, equals(1));
      expect(exception.first.id, equals('d2'));
    });

    test('18. filterDrivers searches by name, phone, car, or car number', () {
      final drivers = [
        const TaxiDriverAdminEntity(
          id: 'drv_1',
          name: 'كابتن رعد',
          phone: '07705555555',
          carModel: 'هيونداي النترا',
          carNumber: 'بغداد 1234',
        ),
        const TaxiDriverAdminEntity(
          id: 'drv_2',
          name: 'كابتن مهند',
          phone: '07806666666',
          carModel: 'تويوتا كورولا',
          carNumber: 'الانبار 5678',
        ),
      ];

      expect(RideManagementCalculator.filterDrivers(drivers: drivers, debtFilter: 'all', query: 'رعد').length, equals(1));
      expect(RideManagementCalculator.filterDrivers(drivers: drivers, debtFilter: 'all', query: 'كورولا').length, equals(1));
      expect(RideManagementCalculator.filterDrivers(drivers: drivers, debtFilter: 'all', query: '1234').length, equals(1));
    });

    test('19. filterReviews filters by star tier', () {
      final reviews = [
        const DriverReviewAdminEntity(id: 'r1', driverId: 'd1', rating: 5.0),
        const DriverReviewAdminEntity(id: 'r2', driverId: 'd1', rating: 4.2),
        const DriverReviewAdminEntity(id: 'r3', driverId: 'd1', rating: 2.5),
      ];

      final star5 = RideManagementCalculator.filterReviews(reviews: reviews, starFilter: '5_star', query: '');
      expect(star5.length, equals(1));
      expect(star5.first.id, equals('r1'));

      final star4 = RideManagementCalculator.filterReviews(reviews: reviews, starFilter: '4_star', query: '');
      expect(star4.length, equals(1));
      expect(star4.first.id, equals('r2'));

      final low = RideManagementCalculator.filterReviews(reviews: reviews, starFilter: 'low', query: '');
      expect(low.length, equals(1));
      expect(low.first.id, equals('r3'));
    });

    test('20. filterReviews searches by customer, driver or comment text', () {
      final reviews = [
        const DriverReviewAdminEntity(
          id: 'rev_1',
          driverId: 'd1',
          driverName: 'كابتن ماجد',
          customerName: 'فاطمة',
          comment: 'سائق محترم جداً وسريع بالوصول',
        ),
        const DriverReviewAdminEntity(
          id: 'rev_2',
          driverId: 'd2',
          driverName: 'كابتن سلام',
          customerName: 'ياسين',
          comment: 'تأخر قليلاً لكن السيارة نظيفة',
        ),
      ];

      expect(RideManagementCalculator.filterReviews(reviews: reviews, starFilter: 'all', query: 'ماجد').length, equals(1));
      expect(RideManagementCalculator.filterReviews(reviews: reviews, starFilter: 'all', query: 'فاطمة').length, equals(1));
      expect(RideManagementCalculator.filterReviews(reviews: reviews, starFilter: 'all', query: 'نظيفة').length, equals(1));
    });

    test('21. formatIraqiCurrency formats IQD numbers with thousand separators', () {
      expect(RideManagementCalculator.formatIraqiCurrency(0), '0 د.ع');
      expect(RideManagementCalculator.formatIraqiCurrency(500), '500 د.ع');
      expect(RideManagementCalculator.formatIraqiCurrency(1000), '1,000 د.ع');
      expect(RideManagementCalculator.formatIraqiCurrency(12500), '12,500 د.ع');
      expect(RideManagementCalculator.formatIraqiCurrency(1000000), '1,000,000 د.ع');
    });

    test('22. isSameDay validates matching dates regardless of time', () {
      final d1 = DateTime(2026, 8, 27, 9, 30);
      final d2 = DateTime(2026, 8, 27, 23, 45);
      final d3 = DateTime(2026, 8, 28, 0, 15);

      expect(RideManagementCalculator.isSameDay(d1, d2), isTrue);
      expect(RideManagementCalculator.isSameDay(d1, d3), isFalse);
    });

    test('23. RideAdminEntity handles custom rawData extraction defensively', () {
      final raw = {
        'id': 'custom_1',
        'fare': '4500',
        'passengerName': 'حيدر',
      };
      final ride = RideAdminEntity(id: 'custom_1', rawData: raw);
      expect(ride.rawData['passengerName'], equals('حيدر'));
    });

    test('24. TaxiDriverAdminEntity handles edge values and defaults', () {
      const driver = TaxiDriverAdminEntity(id: 'default_d');
      expect(driver.name, equals('كابتن تكسي'));
      expect(driver.rating, equals(5.0));
      expect(driver.commissionLimit, equals(10000.0));
      expect(driver.allowCommissionException, isFalse);
    });

    test('25. DriverReviewAdminEntity default construction integrity', () {
      const review = DriverReviewAdminEntity(id: 'def_rev', driverId: 'd_def');
      expect(review.customerName, equals('زبون'));
      expect(review.rating, equals(5.0));
      expect(review.comment, isEmpty);
    });
  });
}
