import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/delivery_execution/domain/entities/delivery_execution_models.dart';
import 'package:dalal_alqaim/features/delivery_execution/application/customer_order_tracking_controller.dart';
import 'delivery_execution_repository_test.dart';

void main() {
  group('CustomerOrderTrackingController Comprehensive Unit Tests', () {
    late MockDeliveryExecutionRepository repo;
    late CustomerOrderTrackingController controller;

    setUp(() {
      repo = MockDeliveryExecutionRepository();
      repo.mockDelivery = DeliveryExecutionEntity(
        orderId: 'cust_ord_777',
        source: OrderDeliverySource.restaurant,
        merchantId: 'rest_99',
        merchantName: 'برغر القائم',
        customerId: 'cust_333',
        customerName: 'فاطمة أحمد',
        status: DeliveryExecutionStatus.accepted,
        pickupPoint: const DeliveryPoint(latitude: 34.33, longitude: 41.01, name: 'المطعم'),
        dropoffPoint: const DeliveryPoint(latitude: 34.35, longitude: 41.03, name: 'المنزل'),
        deliveryFee: 2000,
        subtotal: 14000,
        grandTotal: 16000,
        driverInfo: const DeliveryDriverInfo(
          id: 'drv_77',
          name: 'كابتن زيد',
          phone: '07701122334',
        ),
      );

      controller = CustomerOrderTrackingController(repository: repo);
    });

    tearDown(() {
      controller.dispose();
      repo.dispose();
    });

    test('1. initialize loads active delivery for customer', () async {
      await controller.initialize(
        orderId: 'cust_ord_777',
        source: OrderDeliverySource.restaurant,
      );

      expect(controller.delivery, isNotNull);
      expect(controller.delivery!.orderId, 'cust_ord_777');
      expect(controller.delivery!.driverInfo?.name, 'كابتن زيد');
      expect(controller.isLoading, isFalse);
    });

    test('2. Customer receives live driver location updates and recalculates route', () async {
      await controller.initialize(
        orderId: 'cust_ord_777',
        source: OrderDeliverySource.restaurant,
      );

      final newDriverLoc = DeliveryLocationEntity(
        latitude: 34.335,
        longitude: 41.015,
        heading: 180.0,
        timestamp: DateTime.now(),
      );

      repo.locationStreamController.add(newDriverLoc);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.driverLocation?.latitude, 34.335);
      expect(controller.routeToCustomer, isNotNull);
    });

    test('3. Customer receives real-time status updates', () async {
      await controller.initialize(
        orderId: 'cust_ord_777',
        source: OrderDeliverySource.restaurant,
      );

      final updatedDelivery = repo.mockDelivery!.copyWith(
        status: DeliveryExecutionStatus.headingToCustomer,
      );

      repo.deliveryStreamController.add(updatedDelivery);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.delivery!.status, DeliveryExecutionStatus.headingToCustomer);
    });

    test('4. Non-existent order sets error message', () async {
      repo.mockDelivery = null;

      await controller.initialize(
        orderId: 'non_existent_999',
        source: OrderDeliverySource.restaurant,
      );

      expect(controller.delivery, isNull);
      expect(controller.errorMessage, isNotNull);
    });

    test('5. Reinitialize cancels previous listeners safely', () async {
      await controller.initialize(
        orderId: 'cust_ord_777',
        source: OrderDeliverySource.restaurant,
      );

      await controller.initialize(
        orderId: 'cust_ord_777',
        source: OrderDeliverySource.restaurant,
      );

      expect(controller.delivery, isNotNull);
    });
  });
}
