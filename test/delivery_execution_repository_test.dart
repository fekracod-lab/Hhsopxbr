import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/delivery_execution/domain/entities/delivery_execution_models.dart';
import 'package:dalal_alqaim/features/delivery_execution/domain/repositories/i_delivery_execution_repository.dart';
import 'package:dalal_alqaim/features/delivery_execution/data/datasources/delivery_location_datasource.dart';

/// Mock Location Datasource avoiding platform channels in unit tests
class MockDeliveryLocationDatasource extends DeliveryLocationDatasource {
  DeliveryLocationEntity? mockLocation;
  final StreamController<DeliveryLocationEntity> streamController =
      StreamController<DeliveryLocationEntity>.broadcast();

  @override
  Future<DeliveryLocationEntity?> getCurrentLocation() async {
    return mockLocation ??
        DeliveryLocationEntity(
          latitude: 34.3,
          longitude: 41.0,
          timestamp: DateTime.now(),
        );
  }

  @override
  Stream<DeliveryLocationEntity> getLiveLocationStream({int distanceFilterMeters = 10}) {
    return streamController.stream;
  }

  @override
  void dispose() {
    streamController.close();
  }
}

/// Mock Repository implementing IDeliveryExecutionRepository for unit tests
class MockDeliveryExecutionRepository implements IDeliveryExecutionRepository {
  DeliveryExecutionEntity? mockDelivery;
  DeliveryLocationEntity? mockDriverLocation;
  DeliveryRouteEntity? mockRoute;
  bool acceptResult = true;
  bool updateStatusResult = true;
  bool cancelResult = true;

  final StreamController<DeliveryExecutionEntity?> deliveryStreamController =
      StreamController<DeliveryExecutionEntity?>.broadcast();
  final StreamController<DeliveryLocationEntity?> locationStreamController =
      StreamController<DeliveryLocationEntity?>.broadcast();

  @override
  Stream<DeliveryExecutionEntity?> streamActiveDelivery(
    String orderId,
    OrderDeliverySource source,
  ) {
    return deliveryStreamController.stream;
  }

  @override
  Stream<DeliveryLocationEntity?> streamDriverLocation(String driverId) {
    return locationStreamController.stream;
  }

  @override
  Future<DeliveryExecutionEntity?> getDelivery(
    String orderId,
    OrderDeliverySource source,
  ) async {
    return mockDelivery;
  }

  @override
  Future<bool> acceptDelivery({
    required String orderId,
    required OrderDeliverySource source,
    required DeliveryDriverInfo driverInfo,
  }) async {
    if (acceptResult && mockDelivery != null) {
      mockDelivery = mockDelivery!.copyWith(
        status: DeliveryExecutionStatus.accepted,
        driverInfo: driverInfo,
      );
      deliveryStreamController.add(mockDelivery);
    }
    return acceptResult;
  }

  @override
  Future<bool> updateDeliveryStatus({
    required String orderId,
    required OrderDeliverySource source,
    required DeliveryExecutionStatus newStatus,
    required String driverId,
    String cancelReason = '',
  }) async {
    if (updateStatusResult && mockDelivery != null) {
      mockDelivery = mockDelivery!.copyWith(
        status: newStatus,
        cancelReason: cancelReason,
      );
      deliveryStreamController.add(mockDelivery);
    }
    return updateStatusResult;
  }

  @override
  Future<void> syncDriverLocation({
    required String driverId,
    required DeliveryLocationEntity location,
    String? activeOrderId,
    OrderDeliverySource? activeSource,
  }) async {
    mockDriverLocation = location;
    locationStreamController.add(location);
  }

  @override
  Future<DeliveryRouteEntity> calculateRoute({
    required DeliveryLocationEntity start,
    required DeliveryPoint destination,
  }) async {
    return mockRoute ??
        DeliveryRouteEntity(
          polylinePoints: [start],
          totalDistanceMeters: 2500,
          totalDurationSeconds: 300,
          calculatedAt: DateTime.now(),
        );
  }

  @override
  Future<bool> cancelDelivery({
    required String orderId,
    required OrderDeliverySource source,
    required String driverId,
    required String reason,
  }) async {
    if (cancelResult && mockDelivery != null) {
      mockDelivery = mockDelivery!.copyWith(
        status: DeliveryExecutionStatus.cancelled,
        cancelReason: reason,
      );
      deliveryStreamController.add(mockDelivery);
    }
    return cancelResult;
  }

  void dispose() {
    deliveryStreamController.close();
    locationStreamController.close();
  }
}

void main() {
  group('MockDeliveryExecutionRepository Contract & Schema Normalization Tests', () {
    late MockDeliveryExecutionRepository repo;

    setUp(() {
      repo = MockDeliveryExecutionRepository();
      repo.mockDelivery = DeliveryExecutionEntity(
        orderId: 'test_ord_1',
        source: OrderDeliverySource.restaurant,
        merchantId: 'rest_101',
        merchantName: 'مطعم القائم الذهبي',
        customerId: 'user_202',
        customerName: 'محمد أحمد',
        status: DeliveryExecutionStatus.pending,
        pickupPoint: const DeliveryPoint(latitude: 34.1, longitude: 41.1),
        dropoffPoint: const DeliveryPoint(latitude: 34.2, longitude: 41.2),
        grandTotal: 15000,
      );
    });

    tearDown(() {
      repo.dispose();
    });

    test('1. getDelivery retrieves the active mock delivery entity', () async {
      final res = await repo.getDelivery('test_ord_1', OrderDeliverySource.restaurant);
      expect(res, isNotNull);
      expect(res!.orderId, 'test_ord_1');
      expect(res.merchantName, 'مطعم القائم الذهبي');
    });

    test('2. acceptDelivery sets driverInfo and transitions to accepted', () async {
      const driver = DeliveryDriverInfo(
        id: 'drv_99',
        name: 'كابتن عمر',
        phone: '07712345678',
      );

      final ok = await repo.acceptDelivery(
        orderId: 'test_ord_1',
        source: OrderDeliverySource.restaurant,
        driverInfo: driver,
      );

      expect(ok, isTrue);
      expect(repo.mockDelivery!.status, DeliveryExecutionStatus.accepted);
      expect(repo.mockDelivery!.driverInfo?.id, 'drv_99');
    });

    test('3. updateDeliveryStatus transitions through stages to delivered', () async {
      await repo.updateDeliveryStatus(
        orderId: 'test_ord_1',
        source: OrderDeliverySource.restaurant,
        newStatus: DeliveryExecutionStatus.headingToPickup,
        driverId: 'drv_99',
      );

      expect(repo.mockDelivery!.status, DeliveryExecutionStatus.headingToPickup);

      await repo.updateDeliveryStatus(
        orderId: 'test_ord_1',
        source: OrderDeliverySource.restaurant,
        newStatus: DeliveryExecutionStatus.delivered,
        driverId: 'drv_99',
      );

      expect(repo.mockDelivery!.status, DeliveryExecutionStatus.delivered);
    });

    test('4. syncDriverLocation emits new location on stream', () async {
      final loc = DeliveryLocationEntity(
        latitude: 34.15,
        longitude: 41.15,
        heading: 90.0,
        timestamp: DateTime.now(),
      );

      expectLater(
        repo.streamDriverLocation('drv_99'),
        emits(predicate<DeliveryLocationEntity?>((l) => l?.latitude == 34.15)),
      );

      await repo.syncDriverLocation(
        driverId: 'drv_99',
        location: loc,
      );
    });

    test('5. calculateRoute returns mocked driving route', () async {
      final start = DeliveryLocationEntity(latitude: 34.1, longitude: 41.1, timestamp: DateTime.now());
      const dest = DeliveryPoint(latitude: 34.2, longitude: 41.2);

      final route = await repo.calculateRoute(start: start, destination: dest);
      expect(route.totalDistanceMeters, 2500);
      expect(route.durationMinutes, 5);
      expect(route.isNotEmpty, isTrue);
    });

    test('6. cancelDelivery updates status to cancelled and propagates reason', () async {
      final ok = await repo.cancelDelivery(
        orderId: 'test_ord_1',
        source: OrderDeliverySource.restaurant,
        driverId: 'drv_99',
        reason: 'إغلاق الطريق المؤدي للعميل',
      );

      expect(ok, isTrue);
      expect(repo.mockDelivery!.status, DeliveryExecutionStatus.cancelled);
      expect(repo.mockDelivery!.cancelReason, 'إغلاق الطريق المؤدي للعميل');
    });

    test('7. Stream active delivery receives live status updates', () async {
      expectLater(
        repo.streamActiveDelivery('test_ord_1', OrderDeliverySource.restaurant),
        emits(predicate<DeliveryExecutionEntity?>((d) => d?.status == DeliveryExecutionStatus.pickedUp)),
      );

      await repo.updateDeliveryStatus(
        orderId: 'test_ord_1',
        source: OrderDeliverySource.restaurant,
        newStatus: DeliveryExecutionStatus.pickedUp,
        driverId: 'drv_99',
      );
    });

    test('8. Failure responses in accept and update return false cleanly', () async {
      repo.acceptResult = false;
      repo.updateStatusResult = false;

      final acceptOk = await repo.acceptDelivery(
        orderId: 'test_ord_1',
        source: OrderDeliverySource.restaurant,
        driverInfo: const DeliveryDriverInfo(id: 'drv_fail'),
      );
      expect(acceptOk, isFalse);

      final updateOk = await repo.updateDeliveryStatus(
        orderId: 'test_ord_1',
        source: OrderDeliverySource.restaurant,
        newStatus: DeliveryExecutionStatus.pickedUp,
        driverId: 'drv_fail',
      );
      expect(updateOk, isFalse);
    });
  });
}
