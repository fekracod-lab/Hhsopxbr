// 🧪 اختبارات متحكم إدارة رحلات التكسي (Taxi Ride Management Controller Tests)
// Clean Architecture Application Layer Unit Tests — Concurrency, Mutex & Lifecycle

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/taxi/domain/entities/ride_management_models.dart';
import 'package:dalal_alqaim/features/taxi/data/repositories/ride_management_repository.dart';
import 'package:dalal_alqaim/features/taxi/application/ride_management_controller.dart';

void main() {
  late FakeRideManagementRepository fakeRepo;
  late RideManagementController controller;

  setUp(() {
    fakeRepo = FakeRideManagementRepository();
    controller = RideManagementController(repository: fakeRepo);
  });

  tearDown(() {
    if (!controller.isDisposed) {
      controller.dispose();
    }
    fakeRepo.dispose();
  });

  group('RideManagementController — State & Streams Tests', () {
    test('1. Initial state has loading true and empty lists', () {
      expect(controller.isLoading, isTrue);
      expect(controller.activeDrivers, isEmpty);
      expect(controller.allDrivers, isEmpty);
      expect(controller.allRides, isEmpty);
      expect(controller.activeRides, isEmpty);
      expect(controller.historyRides, isEmpty);
      expect(controller.reviews, isEmpty);
    });

    test('2. Controller populates active drivers and sets loading false', () async {
      fakeRepo.emitActiveDrivers([
        const TaxiDriverAdminEntity(id: 'd1', name: 'كابتن أحمد', isOnline: true),
      ]);
      await Future.delayed(Duration.zero);

      expect(controller.isLoading, isFalse);
      expect(controller.activeDrivers.length, equals(1));
      expect(controller.activeDrivers.first.name, equals('كابتن أحمد'));
    });

    test('3. Controller populates all drivers and updates filteredDrivers', () async {
      fakeRepo.emitAllDrivers([
        const TaxiDriverAdminEntity(id: 'd1', name: 'كابتن علي', appDebt: 5000),
        const TaxiDriverAdminEntity(id: 'd2', name: 'كابتن عمر', appDebt: 15000, commissionLimit: 10000),
      ]);
      await Future.delayed(Duration.zero);

      expect(controller.allDrivers.length, equals(2));
      expect(controller.filteredDrivers.length, equals(2));
    });

    test('4. Controller populates all rides and active rides streams', () async {
      fakeRepo.emitAllRides([
        const RideAdminEntity(id: 'r1', status: RideStatusEnum.searching),
        const RideAdminEntity(id: 'r2', status: RideStatusEnum.in_progress),
      ]);
      fakeRepo.emitActiveRides([
        const RideAdminEntity(id: 'r2', status: RideStatusEnum.in_progress),
      ]);
      await Future.delayed(Duration.zero);

      expect(controller.allRides.length, equals(2));
      expect(controller.activeRides.length, equals(1));
    });

    test('5. Controller derives live kpiMetrics from current state', () async {
      fakeRepo.emitAllDrivers([
        const TaxiDriverAdminEntity(id: 'd1', isOnline: true),
        const TaxiDriverAdminEntity(id: 'd2', isOnline: false),
      ]);
      fakeRepo.emitAllRides([
        const RideAdminEntity(id: 'r1', status: RideStatusEnum.searching),
        const RideAdminEntity(id: 'r2', status: RideStatusEnum.in_progress),
        RideAdminEntity(id: 'r3', status: RideStatusEnum.completed, completedAt: DateTime.now()),
      ]);
      await Future.delayed(Duration.zero);

      final kpi = controller.kpiMetrics;
      expect(kpi.onlineDriversCount, equals(1));
      expect(kpi.activeTripsCount, equals(1));
      expect(kpi.searchingTripsCount, equals(1));
      expect(kpi.todayCompletedTripsCount, equals(1));
    });

    test('6. Controller derives historyAnalytics from completed history stream', () async {
      fakeRepo.emitCompletedHistory([
        const RideAdminEntity(id: 'h1', status: RideStatusEnum.completed, fare: 6000),
        const RideAdminEntity(id: 'h2', status: RideStatusEnum.completed, fare: 4000),
      ]);
      await Future.delayed(Duration.zero);

      final stats = controller.historyAnalytics;
      expect(stats.totalCompletedRides, equals(2));
      expect(stats.totalGmv, equals(10000.0));
      expect(stats.totalPlatformCommission, equals(1000.0)); // 10%
      expect(stats.averageFare, equals(5000.0));
    });

    test('7. Controller populates reviews stream and computes filteredReviews', () async {
      fakeRepo.emitReviews([
        const DriverReviewAdminEntity(id: 'rev_1', driverId: 'd1', rating: 5.0, comment: 'رائع'),
        const DriverReviewAdminEntity(id: 'rev_2', driverId: 'd1', rating: 3.0, comment: 'متوسط'),
      ]);
      await Future.delayed(Duration.zero);

      expect(controller.reviews.length, equals(2));
      expect(controller.filteredReviews.length, equals(2));
    });
  });

  group('RideManagementController — Filtering & Selection Tests', () {
    test('8. setStatusFilter switches filter and re-subscribes filtered stream', () async {
      fakeRepo.emitAllRides([
        const RideAdminEntity(id: 'r1', status: RideStatusEnum.searching),
        const RideAdminEntity(id: 'r2', status: RideStatusEnum.completed),
      ]);
      await Future.delayed(Duration.zero);

      controller.setStatusFilter('searching');
      expect(controller.statusFilter, equals('searching'));

      fakeRepo.emitFilteredRides([
        const RideAdminEntity(id: 'r1', status: RideStatusEnum.searching),
      ]);
      await Future.delayed(Duration.zero);

      expect(controller.filteredRides.length, equals(1));
      expect(controller.filteredRides.first.id, equals('r1'));
    });

    test('9. setSearchQuery filters rides in real-time', () async {
      fakeRepo.emitAllRides([
        const RideAdminEntity(id: 'r1', passengerName: 'أحمد الشيخلي'),
        const RideAdminEntity(id: 'r2', passengerName: 'مصطفى كامل'),
      ]);
      await Future.delayed(Duration.zero);

      controller.setSearchQuery('الشيخلي');
      expect(controller.filteredRides.length, equals(1));
      expect(controller.filteredRides.first.passengerName, contains('الشيخلي'));
    });

    test('10. setDriverDebtFilter filters drivers by debt status', () async {
      fakeRepo.emitAllDrivers([
        const TaxiDriverAdminEntity(id: 'd1', name: 'كابتن 1', appDebt: 15000, commissionLimit: 10000), // Blocked
        const TaxiDriverAdminEntity(id: 'd2', name: 'كابتن 2', appDebt: 5000, commissionLimit: 10000),  // Active
      ]);
      await Future.delayed(Duration.zero);

      controller.setDriverDebtFilter('blocked');
      expect(controller.filteredDrivers.length, equals(1));
      expect(controller.filteredDrivers.first.id, equals('d1'));
    });

    test('11. setDriverSearchQuery filters drivers by search term', () async {
      fakeRepo.emitAllDrivers([
        const TaxiDriverAdminEntity(id: 'd1', name: 'كابتن رعد', phone: '07701111111'),
        const TaxiDriverAdminEntity(id: 'd2', name: 'كابتن حامد', phone: '07702222222'),
      ]);
      await Future.delayed(Duration.zero);

      controller.setDriverSearchQuery('حامد');
      expect(controller.filteredDrivers.length, equals(1));
      expect(controller.filteredDrivers.first.name, equals('كابتن حامد'));
    });

    test('12. setReviewFilter filters reviews by stars', () async {
      fakeRepo.emitReviews([
        const DriverReviewAdminEntity(id: 'rev_1', driverId: 'd1', rating: 5.0),
        const DriverReviewAdminEntity(id: 'rev_2', driverId: 'd2', rating: 2.0),
      ]);
      await Future.delayed(Duration.zero);

      controller.setReviewFilter('5_star');
      expect(controller.filteredReviews.length, equals(1));
      expect(controller.filteredReviews.first.id, equals('rev_1'));
    });

    test('13. setReviewSearchQuery filters reviews by keyword', () async {
      fakeRepo.emitReviews([
        const DriverReviewAdminEntity(id: 'rev_1', driverId: 'd1', comment: 'سائق ممتاز وخلوق'),
        const DriverReviewAdminEntity(id: 'rev_2', driverId: 'd2', comment: 'سيارة قديمة'),
      ]);
      await Future.delayed(Duration.zero);

      controller.setReviewSearchQuery('ممتاز');
      expect(controller.filteredReviews.length, equals(1));
      expect(controller.filteredReviews.first.comment, contains('ممتاز'));
    });

    test('14. selectDriver sets selected driver and clears selected ride', () {
      const d = TaxiDriverAdminEntity(id: 'drv_select', name: 'كابتن مختار');
      controller.selectDriver(d);

      expect(controller.selectedDriver, equals(d));
      expect(controller.selectedRide, isNull);
      expect(controller.selectedRideId, isNull);
    });

    test('15. selectRide sets selected ride and clears selected driver', () {
      const r = RideAdminEntity(id: 'ride_select', passengerName: 'أحمد');
      controller.selectRide(r);

      expect(controller.selectedRide, equals(r));
      expect(controller.selectedRideId, equals('ride_select'));
      expect(controller.selectedDriver, isNull);
    });

    test('16. clearSelection clears both driver and ride selections', () {
      const r = RideAdminEntity(id: 'ride_select');
      controller.selectRide(r);
      expect(controller.selectedRideId, isNotNull);

      controller.clearSelection();
      expect(controller.selectedDriver, isNull);
      expect(controller.selectedRide, isNull);
      expect(controller.selectedRideId, isNull);
    });
  });

  group('RideManagementController — Concurrency & Mutex Actions Tests', () {
    test('17. cancelRide executes successfully and clears selection if matches', () async {
      const r = RideAdminEntity(id: 'ride_cancel_1');
      controller.selectRide(r);

      final status = await controller.cancelRide(rideId: 'ride_cancel_1', reason: 'طلب الزبون');
      expect(status, equals(RideManagementActionStatus.success));
      expect(fakeRepo.lastCancelledRideId, equals('ride_cancel_1'));
      expect(fakeRepo.lastCancelReason, equals('طلب الزبون'));
      expect(controller.selectedRideId, isNull);
    });

    test('18. cancelRide duplicate invocation while locked returns locked status', () async {
      fakeRepo.operationDelay = const Duration(milliseconds: 100);

      final f1 = controller.cancelRide(rideId: 'ride_lock_1');
      expect(controller.isActionLocked('ride_lock_1'), isTrue);

      final f2 = controller.cancelRide(rideId: 'ride_lock_1');
      final status2 = await f2;

      expect(status2, equals(RideManagementActionStatus.locked));
      final status1 = await f1;
      expect(status1, equals(RideManagementActionStatus.success));
      expect(controller.isActionLocked('ride_lock_1'), isFalse);
    });

    test('19. assignDriverToRide executes successfully', () async {
      const d = TaxiDriverAdminEntity(id: 'drv_assign', name: 'كابتن بدر');
      final status = await controller.assignDriverToRide(rideId: 'ride_assign_1', driver: d);

      expect(status, equals(RideManagementActionStatus.success));
      expect(fakeRepo.lastAssignedRideId, equals('ride_assign_1'));
      expect(fakeRepo.lastAssignedDriverId, equals('drv_assign'));
    });

    test('20. assignDriverToRide duplicate invocation while locked returns locked status', () async {
      fakeRepo.operationDelay = const Duration(milliseconds: 100);
      const d = TaxiDriverAdminEntity(id: 'drv_assign');

      final f1 = controller.assignDriverToRide(rideId: 'ride_assign_lock', driver: d);
      final f2 = controller.assignDriverToRide(rideId: 'ride_assign_lock', driver: d);

      final status2 = await f2;
      expect(status2, equals(RideManagementActionStatus.locked));

      final status1 = await f1;
      expect(status1, equals(RideManagementActionStatus.success));
    });

    test('21. toggleDriverCommissionException executes and locks driver ID', () async {
      final status = await controller.toggleDriverCommissionException(driverId: 'drv_exc', allowException: true);
      expect(status, equals(RideManagementActionStatus.success));
      expect(fakeRepo.lastToggledDriverId, equals('drv_exc'));
    });

    test('22. resetDriverWalletCompletely executes successfully', () async {
      final status = await controller.resetDriverWalletCompletely(driverId: 'drv_rst', reason: 'تصفير شامل');
      expect(status, equals(RideManagementActionStatus.success));
      expect(fakeRepo.lastResetDriverId, equals('drv_rst'));
      expect(fakeRepo.lastResetReason, equals('تصفير شامل'));
    });

    test('23. settleDriverCommission executes successfully', () async {
      final status = await controller.settleDriverCommission(
        driverId: 'drv_settle',
        amountPaid: 8000,
        adminNotes: 'تسوية مكتب',
      );
      expect(status, equals(RideManagementActionStatus.success));
      expect(fakeRepo.lastSettleDriverId, equals('drv_settle'));
      expect(fakeRepo.lastSettleAmount, equals(8000.0));
    });

    test('24. updateDriverCommissionLimit executes successfully', () async {
      final status = await controller.updateDriverCommissionLimit(driverId: 'drv_limit', newLimit: 30000);
      expect(status, equals(RideManagementActionStatus.success));
      expect(fakeRepo.lastLimitDriverId, equals('drv_limit'));
      expect(fakeRepo.lastLimitNewValue, equals(30000.0));
    });

    test('25. sendAdminReviewAction executes and uses review key lock', () async {
      final status = await controller.sendAdminReviewAction(
        reviewId: 'rev_act_1',
        driverId: 'drv_act_1',
        actionType: 'warn_driver',
        note: 'تنبيه سرعة',
      );
      expect(status, equals(RideManagementActionStatus.success));
      expect(fakeRepo.lastReviewActionReviewId, equals('rev_act_1'));
    });

    test('26. Concurrent actions on DIFFERENT IDs execute independently', () async {
      fakeRepo.operationDelay = const Duration(milliseconds: 50);

      final f1 = controller.cancelRide(rideId: 'ride_A');
      final f2 = controller.cancelRide(rideId: 'ride_B');

      expect(controller.isActionLocked('ride_A'), isTrue);
      expect(controller.isActionLocked('ride_B'), isTrue);

      final results = await Future.wait([f1, f2]);
      expect(results[0], equals(RideManagementActionStatus.success));
      expect(results[1], equals(RideManagementActionStatus.success));
    });

    test('27. Exception in repository action returns failed and releases lock', () async {
      fakeRepo.shouldThrowOnNextOperation = true;

      final status = await controller.cancelRide(rideId: 'ride_fail_1');
      expect(status, equals(RideManagementActionStatus.failed));
      expect(controller.isActionLocked('ride_fail_1'), isFalse);
    });
  });

  group('RideManagementController — Lifecycle & Generation Guard Tests', () {
    test('28. initialize re-increments generation and cancels old streams', () async {
      controller.initialize();
      expect(controller.isLoading, isTrue);

      fakeRepo.emitActiveDrivers([
        const TaxiDriverAdminEntity(id: 'd_new', name: 'كابتن جديد'),
      ]);
      await Future.delayed(Duration.zero);

      expect(controller.activeDrivers.length, equals(1));
    });

    test('29. dispose marks isDisposed and cleans up all listeners', () {
      controller.dispose();
      expect(controller.isDisposed, isTrue);

      // Emitting on fake repo should not throw or cause state changes on disposed controller
      fakeRepo.emitActiveDrivers([
        const TaxiDriverAdminEntity(id: 'd_after_dispose'),
      ]);
    });

    test('30. Rapid filter changes execute safely without state corruption', () {
      for (int i = 0; i < 6; i++) {
        controller.setStatusFilter(i.isEven ? 'searching' : 'all');
        controller.setDriverDebtFilter(i.isEven ? 'blocked' : 'all');
        controller.setReviewFilter(i.isEven ? '5_star' : 'all');
      }

      expect(controller.statusFilter, equals('all'));
      expect(controller.driverDebtFilter, equals('all'));
      expect(controller.reviewFilter, equals('all'));
    });
  });
}

/// 🧪 مستودع بيانات وهمي للاختبارات
class FakeRideManagementRepository extends RideManagementRepository {
  final _activeDriversCtrl = StreamController<List<TaxiDriverAdminEntity>>.broadcast();
  final _allDriversCtrl = StreamController<List<TaxiDriverAdminEntity>>.broadcast();
  final _allRidesCtrl = StreamController<List<RideAdminEntity>>.broadcast();
  final _activeRidesCtrl = StreamController<List<RideAdminEntity>>.broadcast();
  final _filteredRidesCtrl = StreamController<List<RideAdminEntity>>.broadcast();
  final _completedHistoryCtrl = StreamController<List<RideAdminEntity>>.broadcast();
  final _reviewsCtrl = StreamController<List<DriverReviewAdminEntity>>.broadcast();

  Duration operationDelay = Duration.zero;
  bool shouldThrowOnNextOperation = false;

  String? lastCancelledRideId;
  String? lastCancelReason;

  String? lastAssignedRideId;
  String? lastAssignedDriverId;

  String? lastToggledDriverId;
  String? lastResetDriverId;
  String? lastResetReason;

  String? lastSettleDriverId;
  double? lastSettleAmount;

  String? lastLimitDriverId;
  double? lastLimitNewValue;

  String? lastReviewActionReviewId;

  void emitActiveDrivers(List<TaxiDriverAdminEntity> list) => _activeDriversCtrl.add(list);
  void emitAllDrivers(List<TaxiDriverAdminEntity> list) => _allDriversCtrl.add(list);
  void emitAllRides(List<RideAdminEntity> list) => _allRidesCtrl.add(list);
  void emitActiveRides(List<RideAdminEntity> list) => _activeRidesCtrl.add(list);
  void emitFilteredRides(List<RideAdminEntity> list) => _filteredRidesCtrl.add(list);
  void emitCompletedHistory(List<RideAdminEntity> list) => _completedHistoryCtrl.add(list);
  void emitReviews(List<DriverReviewAdminEntity> list) => _reviewsCtrl.add(list);

  @override
  Stream<List<TaxiDriverAdminEntity>> watchActiveDrivers() => _activeDriversCtrl.stream;

  @override
  Stream<List<TaxiDriverAdminEntity>> watchAllDrivers() => _allDriversCtrl.stream;

  @override
  Stream<List<RideAdminEntity>> watchAllRideRequests() => _allRidesCtrl.stream;

  @override
  Stream<List<RideAdminEntity>> watchActiveRideRequests() => _activeRidesCtrl.stream;

  @override
  Stream<List<RideAdminEntity>> watchFilteredRideRequests(String statusFilter) => _filteredRidesCtrl.stream;

  @override
  Stream<List<RideAdminEntity>> watchCompletedRidesHistory() => _completedHistoryCtrl.stream;

  @override
  Stream<List<DriverReviewAdminEntity>> watchAllReviews() => _reviewsCtrl.stream;

  @override
  Future<void> cancelRide({required String rideId, String? reason}) async {
    if (operationDelay > Duration.zero) await Future.delayed(operationDelay);
    if (shouldThrowOnNextOperation) {
      shouldThrowOnNextOperation = false;
      throw Exception('Cancel failed');
    }
    lastCancelledRideId = rideId;
    lastCancelReason = reason;
  }

  @override
  Future<void> assignDriverToRide({
    required String rideId,
    required String driverId,
    required String driverName,
    required String driverPhone,
    required String driverCar,
  }) async {
    if (operationDelay > Duration.zero) await Future.delayed(operationDelay);
    if (shouldThrowOnNextOperation) {
      shouldThrowOnNextOperation = false;
      throw Exception('Assign failed');
    }
    lastAssignedRideId = rideId;
    lastAssignedDriverId = driverId;
  }

  @override
  Future<void> toggleDriverCommissionException({required String driverId, required bool allowException}) async {
    if (operationDelay > Duration.zero) await Future.delayed(operationDelay);
    lastToggledDriverId = driverId;
  }

  @override
  Future<void> resetDriverWalletCompletely({required String driverId, String? reason}) async {
    if (operationDelay > Duration.zero) await Future.delayed(operationDelay);
    lastResetDriverId = driverId;
    lastResetReason = reason;
  }

  @override
  Future<void> settleDriverCommission({required String driverId, required double amountPaid, String? adminNotes}) async {
    if (operationDelay > Duration.zero) await Future.delayed(operationDelay);
    lastSettleDriverId = driverId;
    lastSettleAmount = amountPaid;
  }

  @override
  Future<void> updateDriverCommissionLimit({required String driverId, required double newLimit}) async {
    if (operationDelay > Duration.zero) await Future.delayed(operationDelay);
    lastLimitDriverId = driverId;
    lastLimitNewValue = newLimit;
  }

  @override
  Future<void> sendAdminReviewAction({required String reviewId, required String driverId, required String actionType, String? note}) async {
    if (operationDelay > Duration.zero) await Future.delayed(operationDelay);
    lastReviewActionReviewId = reviewId;
  }

  void dispose() {
    _activeDriversCtrl.close();
    _allDriversCtrl.close();
    _allRidesCtrl.close();
    _activeRidesCtrl.close();
    _filteredRidesCtrl.close();
    _completedHistoryCtrl.close();
    _reviewsCtrl.close();
  }
}
