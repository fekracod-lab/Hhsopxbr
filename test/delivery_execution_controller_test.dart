import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/delivery_execution/domain/entities/delivery_execution_models.dart';
import 'package:dalal_alqaim/features/delivery_execution/application/delivery_execution_controller.dart';
import 'delivery_execution_repository_test.dart';

void main() {
  group('DeliveryExecutionController Comprehensive Unit Tests', () {
    late MockDeliveryExecutionRepository repo;
    late MockDeliveryLocationDatasource locationDatasource;
    late DeliveryExecutionController controller;

    const driverInfo = DeliveryDriverInfo(
      id: 'drv_1',
      name: 'كابتن علي',
      phone: '07701112223',
    );

    setUp(() {
      repo = MockDeliveryExecutionRepository();
      locationDatasource = MockDeliveryLocationDatasource();
      repo.mockDelivery = DeliveryExecutionEntity(
        orderId: 'ord_555',
        source: OrderDeliverySource.restaurant,
        merchantId: 'rest_1',
        merchantName: 'مطعم القائم',
        customerId: 'cust_1',
        customerName: 'حسين عمر',
        customerPhone: '07709998877',
        status: DeliveryExecutionStatus.accepted,
        pickupPoint: const DeliveryPoint(latitude: 34.3, longitude: 41.0, name: 'المطعم'),
        dropoffPoint: const DeliveryPoint(latitude: 34.4, longitude: 41.1, name: 'البيت'),
        grandTotal: 18000,
        driverInfo: driverInfo,
      );

      controller = DeliveryExecutionController(
        repository: repo,
        locationDatasource: locationDatasource,
      );
    });

    tearDown(() {
      controller.dispose();
      locationDatasource.dispose();
      repo.dispose();
    });

    test('1. initialize loads delivery and starts listening to updates', () async {
      await controller.initialize(
        orderId: 'ord_555',
        source: OrderDeliverySource.restaurant,
        driverInfo: driverInfo,
      );

      expect(controller.delivery, isNotNull);
      expect(controller.delivery!.orderId, 'ord_555');
      expect(controller.delivery!.status, DeliveryExecutionStatus.accepted);
      expect(controller.isLoading, isFalse);
    });

    test('2. executeNextAction progresses through full delivery lifecycle', () async {
      await controller.initialize(
        orderId: 'ord_555',
        source: OrderDeliverySource.restaurant,
        driverInfo: driverInfo,
      );

      // accepted -> headingToPickup
      var ok = await controller.executeNextAction();
      expect(ok, isTrue);
      expect(controller.delivery!.status, DeliveryExecutionStatus.headingToPickup);

      // headingToPickup -> arrivedAtPickup
      ok = await controller.executeNextAction();
      expect(ok, isTrue);
      expect(controller.delivery!.status, DeliveryExecutionStatus.arrivedAtPickup);

      // arrivedAtPickup -> pickedUp
      ok = await controller.executeNextAction();
      expect(ok, isTrue);
      expect(controller.delivery!.status, DeliveryExecutionStatus.pickedUp);

      // pickedUp -> headingToCustomer
      ok = await controller.executeNextAction();
      expect(ok, isTrue);
      expect(controller.delivery!.status, DeliveryExecutionStatus.headingToCustomer);

      // headingToCustomer -> arrivedAtCustomer
      ok = await controller.executeNextAction();
      expect(ok, isTrue);
      expect(controller.delivery!.status, DeliveryExecutionStatus.arrivedAtCustomer);

      // arrivedAtCustomer -> delivered
      ok = await controller.executeNextAction();
      expect(ok, isTrue);
      expect(controller.delivery!.status, DeliveryExecutionStatus.delivered);

      // Terminal state -> executeNextAction returns false
      ok = await controller.executeNextAction();
      expect(ok, isFalse);
    });

    test('3. cancelDelivery cancels order and records reason', () async {
      await controller.initialize(
        orderId: 'ord_555',
        source: OrderDeliverySource.restaurant,
        driverInfo: driverInfo,
      );

      final ok = await controller.cancelDelivery('تعطلت المركبة');
      expect(ok, isTrue);
      expect(controller.delivery!.status, DeliveryExecutionStatus.cancelled);
      expect(controller.delivery!.cancelReason, 'تعطلت المركبة');
    });

    test('4. Repository failure sets errorMessage and stops processing state', () async {
      repo.updateStatusResult = false;

      await controller.initialize(
        orderId: 'ord_555',
        source: OrderDeliverySource.restaurant,
        driverInfo: driverInfo,
      );

      final ok = await controller.executeNextAction();
      expect(ok, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(controller.isActionProcessing, isFalse);
    });

    test('5. Manual route recalculation triggers route calculation', () async {
      await controller.initialize(
        orderId: 'ord_555',
        source: OrderDeliverySource.restaurant,
        driverInfo: driverInfo,
      );

      await controller.recalculateRouteManually();
      expect(controller.currentRoute, isNotNull);
    });

    test('6. Location updates update currentDriverLocation and emit synced updates', () async {
      await controller.initialize(
        orderId: 'ord_555',
        source: OrderDeliverySource.restaurant,
        driverInfo: driverInfo,
      );

      final newLoc = DeliveryLocationEntity(
        latitude: 34.305,
        longitude: 41.005,
        heading: 45.0,
        timestamp: DateTime.now(),
      );

      locationDatasource.streamController.add(newLoc);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.currentDriverLocation?.latitude, 34.305);
    });

    test('7. Actions while action is processing are locked and ignored', () async {
      await controller.initialize(
        orderId: 'ord_555',
        source: OrderDeliverySource.restaurant,
        driverInfo: driverInfo,
      );

      // Start action 1
      final f1 = controller.executeNextAction();
      // Concurrently attempt action 2
      final f2 = controller.executeNextAction();

      final results = await Future.wait([f1, f2]);
      expect(results.contains(true), isTrue);
      // One must be locked out
      expect(results.contains(false), isTrue);
    });
  });
}
