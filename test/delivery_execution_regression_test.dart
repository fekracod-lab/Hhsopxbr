import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/features/delivery_execution/domain/entities/delivery_execution_models.dart';
import 'package:dalal_alqaim/features/delivery_execution/domain/services/delivery_execution_calculator.dart';
import 'package:dalal_alqaim/features/delivery_execution/application/delivery_execution_controller.dart';
import 'package:dalal_alqaim/features/delivery_execution/application/customer_order_tracking_controller.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/order_delivery_details_page.dart';
import 'delivery_execution_repository_test.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (context, _) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: child,
      ),
    ),
  );
}

void main() {
  group('End-to-End Multi-Source Execution & Regression Tests', () {
    late MockDeliveryExecutionRepository repo;
    late MockDeliveryLocationDatasource locationDatasource;

    setUp(() {
      repo = MockDeliveryExecutionRepository();
      locationDatasource = MockDeliveryLocationDatasource();
    });

    tearDown(() {
      locationDatasource.dispose();
      repo.dispose();
    });

    test('1. Full End-to-End Restaurant Food Order Execution Lifecycle', () async {
      repo.mockDelivery = DeliveryExecutionEntity(
        orderId: 'rest_order_100',
        source: OrderDeliverySource.restaurant,
        merchantId: 'rest_alkaim_1',
        merchantName: 'شاورما القائم',
        customerId: 'customer_900',
        customerName: 'سعد جابر',
        status: DeliveryExecutionStatus.accepted,
        pickupPoint: const DeliveryPoint(latitude: 34.33, longitude: 41.01, name: 'مطعم الشاورما'),
        dropoffPoint: const DeliveryPoint(latitude: 34.35, longitude: 41.03, name: 'منزل العميل'),
        deliveryFee: 2500,
        subtotal: 12500,
        grandTotal: 15000,
        paymentMethod: 'cash_on_delivery',
        isPaid: false,
        driverInfo: const DeliveryDriverInfo(id: 'drv_1', name: 'كابتن محمود'),
      );

      final driverController = DeliveryExecutionController(
        repository: repo,
        locationDatasource: locationDatasource,
      );
      final customerController = CustomerOrderTrackingController(repository: repo);

      await driverController.initialize(
        orderId: 'rest_order_100',
        source: OrderDeliverySource.restaurant,
        driverInfo: const DeliveryDriverInfo(id: 'drv_1', name: 'كابتن محمود'),
      );

      await customerController.initialize(
        orderId: 'rest_order_100',
        source: OrderDeliverySource.restaurant,
      );

      expect(driverController.delivery!.status, DeliveryExecutionStatus.accepted);
      expect(customerController.delivery!.status, DeliveryExecutionStatus.accepted);

      // Step 1: Heading to Pickup
      await driverController.executeNextAction();
      expect(driverController.delivery!.status, DeliveryExecutionStatus.headingToPickup);

      // Step 2: Arrived at Pickup
      await driverController.executeNextAction();
      expect(driverController.delivery!.status, DeliveryExecutionStatus.arrivedAtPickup);

      // Step 3: Picked Up
      await driverController.executeNextAction();
      expect(driverController.delivery!.status, DeliveryExecutionStatus.pickedUp);

      // Step 4: Heading to Customer
      await driverController.executeNextAction();
      expect(driverController.delivery!.status, DeliveryExecutionStatus.headingToCustomer);

      // Step 5: Arrived at Customer
      await driverController.executeNextAction();
      expect(driverController.delivery!.status, DeliveryExecutionStatus.arrivedAtCustomer);

      // Step 6: Delivered
      await driverController.executeNextAction();
      expect(driverController.delivery!.status, DeliveryExecutionStatus.delivered);

      // Settlement Verification
      final metrics = DeliveryExecutionCalculator.calculateMetrics(
        deliveryFee: driverController.delivery!.deliveryFee,
        orderTotal: driverController.delivery!.subtotal,
        paymentMethod: driverController.delivery!.paymentMethod,
        isPaid: driverController.delivery!.isPaid,
      );

      expect(metrics.captainEarnings, 2000.0);
      expect(metrics.platformCommission, 500.0);
      expect(metrics.cashToCollect, 15000.0);
      expect(metrics.customerPointsEarned, 12);

      driverController.dispose();
      customerController.dispose();
    });

    test('2. Full End-to-End Store Order Execution with Electronic Wallet Payment', () async {
      repo.mockDelivery = DeliveryExecutionEntity(
        orderId: 'store_order_200',
        source: OrderDeliverySource.store,
        merchantId: 'store_tech_1',
        merchantName: 'متجر الإلكترونيات',
        customerId: 'customer_901',
        customerName: 'هدى كريم',
        status: DeliveryExecutionStatus.accepted,
        pickupPoint: const DeliveryPoint(latitude: 34.33, longitude: 41.01),
        dropoffPoint: const DeliveryPoint(latitude: 34.36, longitude: 41.04),
        deliveryFee: 3000,
        subtotal: 50000,
        grandTotal: 53000,
        paymentMethod: 'paid_wallet',
        isPaid: true,
        driverInfo: const DeliveryDriverInfo(id: 'drv_2', name: 'كابتن زيد'),
      );

      final metrics = DeliveryExecutionCalculator.calculateMetrics(
        deliveryFee: 3000,
        orderTotal: 50000,
        paymentMethod: 'paid_wallet',
        isPaid: true,
      );

      expect(metrics.captainEarnings, 2500.0);
      expect(metrics.platformCommission, 500.0);
      expect(metrics.cashToCollect, 0.0); // Electronic -> 0 cash collected
      expect(metrics.customerPointsEarned, 50);
    });

    test('3. Full End-to-End Mersal / Parcel Delivery Lifecycle', () async {
      repo.mockDelivery = DeliveryExecutionEntity(
        orderId: 'mersal_req_300',
        source: OrderDeliverySource.mersal,
        merchantId: 'sender_user_1',
        merchantName: 'أبو أحمد (المرسل)',
        customerId: 'receiver_user_2',
        customerName: 'أم مروان (المستلم)',
        status: DeliveryExecutionStatus.accepted,
        pickupPoint: const DeliveryPoint(latitude: 34.31, longitude: 41.01, address: 'حي الجماهير'),
        dropoffPoint: const DeliveryPoint(latitude: 34.37, longitude: 41.05, address: 'حي الفرات'),
        deliveryFee: 4000,
        grandTotal: 4000,
        paymentMethod: 'cash_on_delivery',
        driverInfo: const DeliveryDriverInfo(id: 'drv_3', name: 'كابتن ياسر'),
      );

      final controller = DeliveryExecutionController(
        repository: repo,
        locationDatasource: locationDatasource,
      );
      await controller.initialize(
        orderId: 'mersal_req_300',
        source: OrderDeliverySource.mersal,
        driverInfo: const DeliveryDriverInfo(id: 'drv_3', name: 'كابتن ياسر'),
      );

      expect(controller.delivery!.source, OrderDeliverySource.mersal);
      expect(controller.delivery!.pickupPoint.address, 'حي الجماهير');
      expect(controller.delivery!.dropoffPoint.address, 'حي الفرات');

      controller.dispose();
    });

    testWidgets('4. Backward Compatibility: OrderDeliveryDetailsPage instantiates properly', (tester) async {
      repo.mockDelivery = DeliveryExecutionEntity(
        orderId: 'legacy_ord_777',
        source: OrderDeliverySource.store,
        merchantId: 'store_1',
        merchantName: 'متجر النور',
        customerId: 'cust_1',
        status: DeliveryExecutionStatus.accepted,
        pickupPoint: const DeliveryPoint(latitude: 34.3, longitude: 41.0),
        dropoffPoint: const DeliveryPoint(latitude: 34.4, longitude: 41.1),
        deliveryFee: 2000,
        grandTotal: 12000,
        driverInfo: const DeliveryDriverInfo(id: 'legacy_drv_1', name: 'كابتن كريم'),
      );

      final mockController = DeliveryExecutionController(
        repository: repo,
        locationDatasource: locationDatasource,
      );

      final legacyOrderMap = {
        'id': 'legacy_ord_777',
        'type': 'store',
        'storeName': 'متجر النور',
        'deliveryFee': 2000,
        'total': 12000,
      };

      final legacyDriverMap = {
        'id': 'legacy_drv_1',
        'fullName': 'كابتن كريم',
        'phone': '07709876543',
        'carType': 'دراجة شحن',
      };

      await tester.pumpWidget(
        _wrap(
          OrderDeliveryDetailsPage(
            order: legacyOrderMap,
            driverData: legacyDriverMap,
            controller: mockController,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(OrderDeliveryDetailsPage), findsOneWidget);
      mockController.dispose();
    });

    test('5. Multi-stage cancellation lifecycle from Driver active screen', () async {
      repo.mockDelivery = DeliveryExecutionEntity(
        orderId: 'cancel_test_500',
        source: OrderDeliverySource.restaurant,
        merchantId: 'rest_1',
        customerId: 'cust_1',
        status: DeliveryExecutionStatus.headingToPickup,
        pickupPoint: const DeliveryPoint(latitude: 34.3, longitude: 41.0),
        dropoffPoint: const DeliveryPoint(latitude: 34.4, longitude: 41.1),
        driverInfo: const DeliveryDriverInfo(id: 'drv_c'),
      );

      final controller = DeliveryExecutionController(
        repository: repo,
        locationDatasource: locationDatasource,
      );

      await controller.initialize(
        orderId: 'cancel_test_500',
        source: OrderDeliverySource.restaurant,
        driverInfo: const DeliveryDriverInfo(id: 'drv_c'),
      );

      final ok = await controller.cancelDelivery('المحل مغلق');
      expect(ok, isTrue);
      expect(controller.delivery!.status, DeliveryExecutionStatus.cancelled);
      expect(controller.delivery!.cancelReason, 'المحل مغلق');

      controller.dispose();
    });
  });
}
