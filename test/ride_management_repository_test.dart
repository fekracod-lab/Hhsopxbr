// 🧪 اختبارات مستودع إدارة رحلات التكسي (Taxi Ride Management Repository Tests)
// Clean Architecture Data Layer Unit & Integration Tests

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/features/taxi/domain/entities/ride_management_models.dart';
import 'package:dalal_alqaim/features/taxi/data/datasources/ride_management_remote_datasource.dart';
import 'package:dalal_alqaim/features/taxi/data/repositories/ride_management_repository.dart';

void main() {
  late FakeRideManagementRemoteDatasource fakeDatasource;
  late RideManagementRepository repository;

  setUp(() {
    fakeDatasource = FakeRideManagementRemoteDatasource();
    repository = RideManagementRepository(datasource: fakeDatasource);
  });

  tearDown(() {
    fakeDatasource.dispose();
  });

  group('RideManagementRepository — Stream & Mapping Tests', () {
    test('1. watchActiveDrivers maps active drivers correctly', () async {
      final futureList = repository.watchActiveDrivers().first;

      fakeDatasource.emitActiveDrivers([
        {
          'id': 'drv_1',
          'name': 'كابتن حمزة',
          'phone': '07701112233',
          'status': 'active',
          'isOnline': true,
          'appDebt': 3000,
          'commissionLimit': 10000,
          'totalRides': 45,
          'rating': 4.9,
          'location': const GeoPoint(34.3414, 41.0805),
        }
      ]);

      final result = await futureList;
      expect(result.length, equals(1));
      expect(result.first.name, equals('كابتن حمزة'));
      expect(result.first.isOnline, isTrue);
      expect(result.first.appDebt, equals(3000.0));
      expect(result.first.location?.latitude, equals(34.3414));
    });

    test('2. watchAllDrivers maps all drivers with exception and debt flags', () async {
      final futureList = repository.watchAllDrivers().first;

      fakeDatasource.emitAllDrivers([
        {
          'id': 'drv_blocked',
          'name': 'كابتن رامي',
          'appDebt': 15000,
          'commissionLimit': 10000,
          'allowCommissionException': false,
        },
        {
          'id': 'drv_exception',
          'name': 'كابتن وسام',
          'appDebt': 20000,
          'commissionLimit': 10000,
          'allowCommissionException': true,
        }
      ]);

      final list = await futureList;
      expect(list.length, equals(2));
      expect(list[0].isBlockedByDebt, isTrue);
      expect(list[1].isBlockedByDebt, isFalse);
    });

    test('3. watchAllRideRequests maps ride requests and status enum', () async {
      final futureList = repository.watchAllRideRequests().first;

      fakeDatasource.emitAllRideRequests([
        {
          'id': 'ride_req_1',
          'passengerName': 'سارة',
          'passengerPhone': '07801234567',
          'fare': 5000,
          'status': 'searching',
          'from': 'شارع 30',
          'to': 'حي التأميم',
          'createdAt': Timestamp.fromDate(DateTime(2026, 8, 27, 12, 0)),
        }
      ]);

      final rides = await futureList;
      expect(rides.length, equals(1));
      expect(rides.first.id, equals('ride_req_1'));
      expect(rides.first.passengerName, equals('سارة'));
      expect(rides.first.status, equals(RideStatusEnum.searching));
      expect(rides.first.fare, equals(5000.0));
      expect(rides.first.pickupAddress, equals('شارع 30'));
      expect(rides.first.dropoffAddress, equals('حي التأميم'));
    });

    test('4. watchActiveRideRequests receives and maps active fleet rides', () async {
      final futureList = repository.watchActiveRideRequests().first;

      fakeDatasource.emitActiveRideRequests([
        {
          'id': 'act_1',
          'status': 'in_progress',
          'driverId': 'drv_1',
          'driverName': 'كابتن ليث',
          'pickupLatLng': const GeoPoint(34.3414, 41.0805),
          'dropoffLatLng': const GeoPoint(34.3500, 41.0900),
        }
      ]);

      final active = await futureList;
      expect(active.length, equals(1));
      expect(active.first.status, equals(RideStatusEnum.in_progress));
      expect(active.first.hasDriverAssigned, isTrue);
      expect(active.first.pickupLocation?.latitude, equals(34.3414));
      expect(active.first.dropoffLocation?.latitude, equals(34.3500));
    });

    test('5. watchFilteredRideRequests filters rides dynamically', () async {
      final futureList = repository.watchFilteredRideRequests('completed').first;

      fakeDatasource.emitFilteredRideRequests([
        {
          'id': 'comp_1',
          'status': 'completed',
          'fare': 4500,
        }
      ]);

      final filtered = await futureList;
      expect(filtered.length, equals(1));
      expect(filtered.first.status, equals(RideStatusEnum.completed));
    });

    test('6. watchCompletedRidesHistory maps history list', () async {
      final futureList = repository.watchCompletedRidesHistory().first;

      fakeDatasource.emitCompletedHistory([
        {
          'id': 'hist_1',
          'status': 'completed',
          'fare': 7000,
          'completedAt': Timestamp.fromDate(DateTime(2026, 8, 27, 15, 30)),
        }
      ]);

      final history = await futureList;
      expect(history.length, equals(1));
      expect(history.first.fare, equals(7000.0));
      expect(history.first.completedAt?.hour, equals(15));
    });

    test('7. watchAllReviews maps driver reviews correctly', () async {
      final futureList = repository.watchAllReviews().first;

      fakeDatasource.emitReviews([
        {
          'id': 'rev_101',
          'driverId': 'drv_1',
          'driverName': 'كابتن حيدر',
          'customerName': 'نور',
          'rating': 4.9,
          'comment': 'ممتاز جداً',
          'createdAt': Timestamp.now(),
        }
      ]);

      final reviews = await futureList;
      expect(reviews.length, equals(1));
      expect(reviews.first.driverName, equals('كابتن حيدر'));
      expect(reviews.first.rating, equals(4.9));
      expect(reviews.first.comment, equals('ممتاز جداً'));
    });
  });

  group('RideManagementRepository — Mutation Operations Tests', () {
    test('8. cancelRide forwards parameters to datasource', () async {
      await repository.cancelRide(rideId: 'ride_123', reason: 'عدم توفر سيارة');
      expect(fakeDatasource.lastCancelledRideId, equals('ride_123'));
      expect(fakeDatasource.lastCancelReason, equals('عدم توفر سيارة'));
    });

    test('9. assignDriverToRide updates driver info on ride document', () async {
      await repository.assignDriverToRide(
        rideId: 'ride_999',
        driverId: 'drv_888',
        driverName: 'كابتن قاسم',
        driverPhone: '07709998887',
        driverCar: 'نيسان صني',
      );

      expect(fakeDatasource.lastAssignedRideId, equals('ride_999'));
      expect(fakeDatasource.lastAssignedDriverId, equals('drv_888'));
      expect(fakeDatasource.lastAssignedDriverName, equals('كابتن قاسم'));
      expect(fakeDatasource.lastAssignedDriverPhone, equals('07709998887'));
      expect(fakeDatasource.lastAssignedDriverCar, equals('نيسان صني'));
    });

    test('10. toggleDriverCommissionException delegates properly', () async {
      await repository.toggleDriverCommissionException(driverId: 'drv_1', allowException: true);
      expect(fakeDatasource.lastToggledDriverId, equals('drv_1'));
      expect(fakeDatasource.lastToggledExceptionValue, isTrue);
    });

    test('11. resetDriverWalletCompletely delegates properly', () async {
      await repository.resetDriverWalletCompletely(driverId: 'drv_2', reason: 'تصفير إداري');
      expect(fakeDatasource.lastResetDriverId, equals('drv_2'));
      expect(fakeDatasource.lastResetReason, equals('تصفير إداري'));
    });

    test('12. settleDriverCommission delegates properly', () async {
      await repository.settleDriverCommission(
        driverId: 'drv_3',
        amountPaid: 5000,
        adminNotes: 'تسوية نقدية عبر المكتب',
      );
      expect(fakeDatasource.lastSettleDriverId, equals('drv_3'));
      expect(fakeDatasource.lastSettleAmount, equals(5000.0));
      expect(fakeDatasource.lastSettleNotes, equals('تسوية نقدية عبر المكتب'));
    });

    test('13. updateDriverCommissionLimit delegates properly', () async {
      await repository.updateDriverCommissionLimit(driverId: 'drv_4', newLimit: 25000);
      expect(fakeDatasource.lastLimitDriverId, equals('drv_4'));
      expect(fakeDatasource.lastLimitNewValue, equals(25000.0));
    });

    test('14. sendAdminReviewAction delegates properly', () async {
      await repository.sendAdminReviewAction(
        reviewId: 'rev_1',
        driverId: 'drv_5',
        actionType: 'warning',
        note: 'يرجى الالتزام بالمسار',
      );
      expect(fakeDatasource.lastReviewActionReviewId, equals('rev_1'));
      expect(fakeDatasource.lastReviewActionDriverId, equals('drv_5'));
      expect(fakeDatasource.lastReviewActionType, equals('warning'));
      expect(fakeDatasource.lastReviewActionNote, equals('يرجى الالتزام بالمسار'));
    });

    test('15. Repository parses Map LatLng fallback coordinates defensively', () async {
      final futureList = repository.watchActiveRideRequests().first;

      fakeDatasource.emitActiveRideRequests([
        {
          'id': 'map_latlng_ride',
          'pickupLocation': {'latitude': 34.34, 'longitude': 41.08},
          'dropoffLocation': {'lat': 34.35, 'lng': 41.09},
        }
      ]);

      final rides = await futureList;
      expect(rides.first.pickupLocation?.latitude, equals(34.34));
      expect(rides.first.dropoffLocation?.latitude, equals(34.35));
    });

    test('16. Repository handles integer timestamps safely', () async {
      final futureList = repository.watchAllRideRequests().first;

      fakeDatasource.emitAllRideRequests([
        {
          'id': 'int_time_ride',
          'createdAt': 1724760000000,
        }
      ]);

      final rides = await futureList;
      expect(rides.first.createdAt, isNotNull);
    });

    test('17. Repository handles string numbers safely', () async {
      final futureList = repository.watchAllDrivers().first;

      fakeDatasource.emitAllDrivers([
        {
          'id': 'str_num_driver',
          'appDebt': '6500.5',
          'commissionLimit': '15000',
          'totalRides': '38',
          'rating': '4.7',
        }
      ]);

      final drivers = await futureList;
      expect(drivers.first.appDebt, equals(6500.5));
      expect(drivers.first.commissionLimit, equals(15000.0));
      expect(drivers.first.totalRides, equals(38));
      expect(drivers.first.rating, equals(4.7));
    });

    test('18. Repository handles null values with fallback defaults', () async {
      final futureList = repository.watchAllRideRequests().first;

      fakeDatasource.emitAllRideRequests([
        {'id': 'null_val_ride'}
      ]);

      final rides = await futureList;
      expect(rides.first.passengerName, equals('زبون'));
      expect(rides.first.fare, equals(0.0));
      expect(rides.first.status, equals(RideStatusEnum.searching));
      expect(rides.first.paymentMethod, equals('cash'));
    });

    test('19. Driver online status handles availability string aliases', () async {
      final futureList = repository.watchAllDrivers().first;

      fakeDatasource.emitAllDrivers([
        {
          'id': 'd_avail_1',
          'availability': 'ONLINE',
        },
        {
          'id': 'd_avail_2',
          'driverStatus': 'online',
        }
      ]);

      final drivers = await futureList;
      expect(drivers[0].isOnline, isTrue);
      expect(drivers[1].isOnline, isTrue);
    });

    test('20. DriverReviewAdminEntity mapping with missing optional fields', () async {
      final futureList = repository.watchAllReviews().first;

      fakeDatasource.emitReviews([
        {
          'id': 'empty_rev',
          'driverId': 'drv_empty',
        }
      ]);

      final reviews = await futureList;
      expect(reviews.first.customerName, equals('زبون'));
      expect(reviews.first.driverName, equals('كابتن'));
      expect(reviews.first.rating, equals(5.0));
      expect(reviews.first.comment, isEmpty);
    });

    test('21. Assigned by admin flag mapping check', () async {
      final futureList = repository.watchAllRideRequests().first;

      fakeDatasource.emitAllRideRequests([
        {
          'id': 'admin_assigned_ride',
          'assignedByAdmin': true,
        }
      ]);

      final rides = await futureList;
      expect(rides.first.assignedByAdmin, isTrue);
    });

    test('22. Cancelled by and cancel timestamp mapping check', () async {
      final futureList = repository.watchAllRideRequests().first;

      final now = DateTime.now();
      fakeDatasource.emitAllRideRequests([
        {
          'id': 'cancelled_ride',
          'status': 'cancelled',
          'cancelledBy': 'admin',
          'cancelledAt': Timestamp.fromDate(now),
        }
      ]);

      final rides = await futureList;
      expect(rides.first.status, equals(RideStatusEnum.cancelled));
      expect(rides.first.cancelledBy, equals('admin'));
      expect(rides.first.cancelledAt, isNotNull);
    });

    test('23. Driver phone fallback from driverPhone or phone', () async {
      final futureList = repository.watchAllDrivers().first;

      fakeDatasource.emitAllDrivers([
        {
          'id': 'd_phone_1',
          'driverPhone': '07701111111',
        },
        {
          'id': 'd_phone_2',
          'phone': '07702222222',
        }
      ]);

      final drivers = await futureList;
      expect(drivers[0].phone, equals('07701111111'));
      expect(drivers[1].phone, equals('07702222222'));
    });

    test('24. Driver car fallback from carModel or vehicle', () async {
      final futureList = repository.watchAllDrivers().first;

      fakeDatasource.emitAllDrivers([
        {
          'id': 'd_car_1',
          'carModel': 'كيا سبورتاج',
        },
        {
          'id': 'd_car_2',
          'vehicle': 'هيونداي اكسنت',
        }
      ]);

      final drivers = await futureList;
      expect(drivers[0].carModel, equals('كيا سبورتاج'));
      expect(drivers[1].carModel, equals('هيونداي اكسنت'));
    });

    test('25. Driver totalRides fallback from num, int, or String', () async {
      final futureList = repository.watchAllDrivers().first;

      fakeDatasource.emitAllDrivers([
        {'id': 'd_num', 'totalRides': 50},
        {'id': 'd_str', 'totalRides': '120'},
        {'id': 'd_none'},
      ]);

      final drivers = await futureList;
      expect(drivers[0].totalRides, equals(50));
      expect(drivers[1].totalRides, equals(120));
      expect(drivers[2].totalRides, equals(0));
    });
  });
}

/// 🧪 مصدر بيانات وهمي للتحكم بالتدفقات
class FakeRideManagementRemoteDatasource extends RideManagementRemoteDatasource {
  final _activeDriversController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _allDriversController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _allRidesController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _activeRidesController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _filteredRidesController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _completedHistoryController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _reviewsController = StreamController<List<Map<String, dynamic>>>.broadcast();

  String? lastCancelledRideId;
  String? lastCancelReason;

  String? lastAssignedRideId;
  String? lastAssignedDriverId;
  String? lastAssignedDriverName;
  String? lastAssignedDriverPhone;
  String? lastAssignedDriverCar;

  String? lastToggledDriverId;
  bool? lastToggledExceptionValue;

  String? lastResetDriverId;
  String? lastResetReason;

  String? lastSettleDriverId;
  double? lastSettleAmount;
  String? lastSettleNotes;

  String? lastLimitDriverId;
  double? lastLimitNewValue;

  String? lastReviewActionReviewId;
  String? lastReviewActionDriverId;
  String? lastReviewActionType;
  String? lastReviewActionNote;

  void emitActiveDrivers(List<Map<String, dynamic>> list) => _activeDriversController.add(list);
  void emitAllDrivers(List<Map<String, dynamic>> list) => _allDriversController.add(list);
  void emitAllRideRequests(List<Map<String, dynamic>> list) => _allRidesController.add(list);
  void emitActiveRideRequests(List<Map<String, dynamic>> list) => _activeRidesController.add(list);
  void emitFilteredRideRequests(List<Map<String, dynamic>> list) => _filteredRidesController.add(list);
  void emitCompletedHistory(List<Map<String, dynamic>> list) => _completedHistoryController.add(list);
  void emitReviews(List<Map<String, dynamic>> list) => _reviewsController.add(list);

  @override
  Stream<List<Map<String, dynamic>>> watchActiveDrivers() => _activeDriversController.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchAllDrivers() => _allDriversController.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchAllRideRequests() => _allRidesController.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchActiveRideRequests() => _activeRidesController.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchFilteredRideRequests(String statusFilter) => _filteredRidesController.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchCompletedRidesHistory() => _completedHistoryController.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchAllReviews() => _reviewsController.stream;

  @override
  Future<void> cancelRide({required String rideId, String? reason}) async {
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
    lastAssignedRideId = rideId;
    lastAssignedDriverId = driverId;
    lastAssignedDriverName = driverName;
    lastAssignedDriverPhone = driverPhone;
    lastAssignedDriverCar = driverCar;
  }

  @override
  Future<void> toggleDriverCommissionException({
    required String driverId,
    required bool allowException,
  }) async {
    lastToggledDriverId = driverId;
    lastToggledExceptionValue = allowException;
  }

  @override
  Future<void> resetDriverWalletCompletely({
    required String driverId,
    String? reason,
  }) async {
    lastResetDriverId = driverId;
    lastResetReason = reason;
  }

  @override
  Future<void> settleDriverCommission({
    required String driverId,
    required double amountPaid,
    String? adminNotes,
  }) async {
    lastSettleDriverId = driverId;
    lastSettleAmount = amountPaid;
    lastSettleNotes = adminNotes;
  }

  @override
  Future<void> updateDriverCommissionLimit({
    required String driverId,
    required double newLimit,
  }) async {
    lastLimitDriverId = driverId;
    lastLimitNewValue = newLimit;
  }

  @override
  Future<void> sendAdminReviewAction({
    required String reviewId,
    required String driverId,
    required String actionType,
    String? note,
  }) async {
    lastReviewActionReviewId = reviewId;
    lastReviewActionDriverId = driverId;
    lastReviewActionType = actionType;
    lastReviewActionNote = note;
  }

  void dispose() {
    _activeDriversController.close();
    _allDriversController.close();
    _allRidesController.close();
    _activeRidesController.close();
    _filteredRidesController.close();
    _completedHistoryController.close();
    _reviewsController.close();
  }
}
