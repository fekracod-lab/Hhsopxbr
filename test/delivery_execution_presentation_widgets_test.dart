import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/features/delivery_execution/domain/entities/delivery_execution_models.dart';
import 'package:dalal_alqaim/features/delivery_execution/presentation/widgets/delivery_status_stepper.dart';
import 'package:dalal_alqaim/features/delivery_execution/presentation/widgets/delivery_action_button.dart';
import 'package:dalal_alqaim/features/delivery_execution/presentation/widgets/delivery_info_card.dart';
import 'package:dalal_alqaim/features/delivery_execution/presentation/widgets/delivery_privacy_shield_card.dart';
import 'package:dalal_alqaim/features/delivery_execution/presentation/widgets/delivery_eta_badge.dart';
import 'package:dalal_alqaim/features/delivery_execution/presentation/widgets/customer_tracking_timeline.dart';
import 'package:dalal_alqaim/features/delivery_execution/presentation/widgets/customer_driver_card.dart';

Widget _wrap(Widget child, {Size size = const Size(375, 812), bool isDark = false}) {
  return ScreenUtilInit(
    designSize: size,
    builder: (context, _) => MaterialApp(
      theme: isDark ? ThemeData.dark() : ThemeData.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  group('Presentation Widgets Comprehensive Rendering Tests', () {
    testWidgets('1. DeliveryStatusStepper renders all step labels across all 5 stages', (tester) async {
      final statuses = [
        DeliveryExecutionStatus.accepted,
        DeliveryExecutionStatus.headingToPickup,
        DeliveryExecutionStatus.arrivedAtPickup,
        DeliveryExecutionStatus.pickedUp,
        DeliveryExecutionStatus.headingToCustomer,
        DeliveryExecutionStatus.arrivedAtCustomer,
        DeliveryExecutionStatus.delivered,
      ];

      for (final status in statuses) {
        await tester.pumpWidget(_wrap(DeliveryStatusStepper(status: status)));
        await tester.pump();

        expect(find.text('استلام'), findsOneWidget);
        expect(find.text('بالطريق'), findsOneWidget);
        expect(find.text('تسليم'), findsOneWidget);
      }
    });

    testWidgets('2. DeliveryActionButton renders label and fires callback on tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        _wrap(
          DeliveryActionButton(
            status: DeliveryExecutionStatus.accepted,
            isProcessing: false,
            onAction: () {
              tapped = true;
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('بدء التحرك لنقطة الاستلام'), findsOneWidget);
      await tester.tap(find.byType(DeliveryActionButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('3. DeliveryActionButton displays spinner when processing and blocks taps', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        _wrap(
          DeliveryActionButton(
            status: DeliveryExecutionStatus.arrivedAtPickup,
            isProcessing: true,
            onAction: () {
              tapped = true;
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(DeliveryActionButton));
      await tester.pump();

      expect(tapped, isFalse);
    });

    testWidgets('4. DeliveryInfoCard renders merchant, items and totals', (tester) async {
      final delivery = DeliveryExecutionEntity(
        orderId: 'ord_111',
        source: OrderDeliverySource.restaurant,
        merchantId: 'm1',
        merchantName: 'مطعم القائم',
        customerId: 'c1',
        status: DeliveryExecutionStatus.accepted,
        items: const [
          DeliveryOrderItem(id: 'i1', name: 'شاورما دجاج', quantity: 2, price: 3000),
          DeliveryOrderItem(id: 'i2', name: 'عصير برتقال', quantity: 1, price: 1500),
        ],
        subtotal: 7500,
        deliveryFee: 2000,
        grandTotal: 9500,
        pickupPoint: const DeliveryPoint(latitude: 34.1, longitude: 41.1, name: 'مطعم القائم'),
        dropoffPoint: const DeliveryPoint(latitude: 34.2, longitude: 41.2, name: 'حي الفرات'),
      );

      await tester.pumpWidget(_wrap(DeliveryInfoCard(delivery: delivery)));
      await tester.pump();

      expect(find.text('مطعم القائم'), findsOneWidget);
      expect(find.text('2x شاورما دجاج'), findsOneWidget);
      expect(find.text('1x عصير برتقال'), findsOneWidget);
      expect(find.text('9,500 د.ع'), findsOneWidget);
    });

    testWidgets('5. DeliveryPrivacyShieldCard masks customer info until pickup', (tester) async {
      final maskedDelivery = DeliveryExecutionEntity(
        orderId: 'ord_222',
        source: OrderDeliverySource.restaurant,
        merchantId: 'm1',
        customerId: 'c1',
        customerName: 'أحمد محمود',
        customerPhone: '07701234567',
        status: DeliveryExecutionStatus.headingToPickup,
        pickupPoint: const DeliveryPoint(latitude: 34.1, longitude: 41.1),
        dropoffPoint: const DeliveryPoint(latitude: 34.2, longitude: 41.2),
      );

      await tester.pumpWidget(_wrap(DeliveryPrivacyShieldCard(delivery: maskedDelivery)));
      await tester.pump();

      expect(find.text('بيانات الزبون (محمية ومقيدة )'), findsOneWidget);
      expect(find.text('07701234567'), findsNothing);
    });

    testWidgets('6. DeliveryPrivacyShieldCard reveals customer info after pickup', (tester) async {
      final unmaskedDelivery = DeliveryExecutionEntity(
        orderId: 'ord_222',
        source: OrderDeliverySource.restaurant,
        merchantId: 'm1',
        customerId: 'c1',
        customerName: 'أحمد محمود',
        customerPhone: '07701234567',
        status: DeliveryExecutionStatus.pickedUp,
        pickupPoint: const DeliveryPoint(latitude: 34.1, longitude: 41.1),
        dropoffPoint: const DeliveryPoint(latitude: 34.2, longitude: 41.2, address: 'شارع 20، حي المعلمين'),
      );

      await tester.pumpWidget(_wrap(DeliveryPrivacyShieldCard(delivery: unmaskedDelivery)));
      await tester.pump();

      expect(find.text('معلومات تسليم الزبون'), findsOneWidget);
      expect(find.text('أحمد محمود'), findsOneWidget);
      expect(find.text('شارع 20، حي المعلمين'), findsOneWidget);
    });

    testWidgets('7. DeliveryEtaBadge renders duration and distance', (tester) async {
      final mockRoute = DeliveryRouteEntity(
        polylinePoints: const [
          DeliveryLocationEntity(latitude: 34.1, longitude: 41.1),
          DeliveryLocationEntity(latitude: 34.2, longitude: 41.2),
        ],
        totalDistanceMeters: 3800,
        totalDurationSeconds: 14 * 60,
        calculatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _wrap(
          DeliveryEtaBadge(
            route: mockRoute,
            status: DeliveryExecutionStatus.headingToPickup,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('14 دقيقة'), findsOneWidget);
      expect(find.text('3.8 كم'), findsOneWidget);
    });

    testWidgets('8. CustomerTrackingTimeline displays 5 chronological stages', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CustomerTrackingTimeline(
            status: DeliveryExecutionStatus.headingToCustomer,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('تم استلام الطلب'), findsOneWidget);
      expect(find.text('المندوب قبل الطلب'), findsOneWidget);
      expect(find.text('تم تجهيز واستلام الطلب'), findsOneWidget);
      expect(find.text('المندوب قريب منك'), findsOneWidget);
      expect(find.text('تم التسليم بنجاح'), findsOneWidget);
    });

    testWidgets('9. CustomerDriverCard displays searching vs assigned driver info', (tester) async {
      // 1. Searching
      await tester.pumpWidget(
        _wrap(
          const CustomerDriverCard(
            driver: null,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('جاري البحث عن أقرب كابتن توصيل متاح...'), findsOneWidget);

      // 2. Assigned
      const driver = DeliveryDriverInfo(
        id: 'drv_1',
        name: 'كابتن وسام',
        phone: '07709991122',
        vehicleType: 'دراجة نارية',
        rating: 4.9,
      );

      await tester.pumpWidget(
        _wrap(
          const CustomerDriverCard(
            driver: driver,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('كابتن وسام'), findsOneWidget);
      expect(find.text('• دراجة نارية'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
    });

    testWidgets('10. Dark Mode rendering for all presentation widgets without visual defects', (tester) async {
      final delivery = DeliveryExecutionEntity(
        orderId: 'ord_dark',
        source: OrderDeliverySource.restaurant,
        merchantId: 'm_dark',
        merchantName: 'مطعم المساء',
        customerId: 'c_dark',
        status: DeliveryExecutionStatus.headingToPickup,
        pickupPoint: const DeliveryPoint(latitude: 34.1, longitude: 41.1),
        dropoffPoint: const DeliveryPoint(latitude: 34.2, longitude: 41.2),
      );

      await tester.pumpWidget(_wrap(DeliveryInfoCard(delivery: delivery), isDark: true));
      await tester.pump();

      expect(find.text('مطعم المساء'), findsOneWidget);
    });
  });
}
