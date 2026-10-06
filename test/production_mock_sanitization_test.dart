import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dalal_alqaim/features/restaurants/presentation/widgets/restaurant_usual_order_card.dart';
import 'package:dalal_alqaim/features/restaurants/presentation/widgets/skozmy_wheel_dialog.dart';
import 'package:dalal_alqaim/models/place_data.dart';

void main() {
  group('Production Mock & Fake Data Sanitization Tests (MOCK-01 to MOCK-12)', () {
    test('MOCK-01: No demo taxi drivers simulation in taxi controller', () {
      final file = File('lib/features/taxi/presentation/controller/taxi_controller.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('_startDemoSimulation'), isFalse);
      expect(content.contains('_demoDrivers'), isFalse);
      expect(content.contains('demo_1'), isFalse);
      expect(content.contains('demo_2'), isFalse);
      expect(content.contains('demo_3'), isFalse);
    });

    test('MOCK-02: No fake restaurants fallback in home_main_content.dart', () {
      final file = File('lib/features/home/widgets/home_main_content.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('demo_rest_1'), isFalse);
      expect(content.contains('demo_rest_2'), isFalse);
      expect(content.contains('demo_rest_3'), isFalse);
      expect(content.contains('demo_rest_4'), isFalse);
      expect(content.contains('شاورما وبرغر القائم'), isFalse);
      expect(content.contains('مشاوي بغداد الأصيلة'), isFalse);
    });

    test('MOCK-03: No fake restaurant menu fallback in restaurant_details_controller.dart', () {
      final file = File('lib/features/restaurants/application/restaurant_details_controller.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('_getAppetizingFallbackMenuItems'), isFalse);
      expect(content.contains('meal_kebab_1'), isFalse);
      expect(content.contains('meal_pizza_1'), isFalse);
    });

    testWidgets('MOCK-04: No fake usual order for new customer', (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => const MaterialApp(
            home: Scaffold(
              body: RestaurantUsualOrderCard(
                userName: 'عمر',
                lastOrder: null,
                isDark: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SizedBox), findsWidgets);
      expect(find.text('زعتر وزيت'), findsNothing);
      expect(find.text('مناقيش قشقوان'), findsNothing);
    });

    testWidgets('MOCK-05: Skozmy wheel disabled and shows safe empty state when real items < 8', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp(
            home: Scaffold(
              body: SkozmyWheelDialog(
                mealsFuture: Future.value([]),
                onSearch: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('عذراً، لا تتوفر وجبات كافية لتشغيل عجلة الحظ حالياً'), findsOneWidget);
      expect(find.text('قوزي عراقي'), findsNothing);
      expect(find.text('شاورما دجاج'), findsNothing);
    });

    test('MOCK-06: Pharmacy page completely removed', () {
      final file = File('lib/pages/pharmacies_page.dart');
      expect(file.existsSync(), isFalse);
    });

    test('MOCK-07: No synthetic Mersal GPS coordinates fallback', () {
      final file = File('lib/features/delivery/presentation/pages/mersal_order_details_page.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('_driverLocation = const LatLng(34.3418, 41.0775);'), isFalse);
    });

    test('MOCK-08: No demo captain or waypoints in Admin Web LiveTrackingRepository', () {
      final file = File('admin_web/src/infrastructure/repositories/LiveTrackingRepository.ts');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('DEMO_CAPTAIN'), isFalse);
      expect(content.contains('AL_QAIM_DEMO_WAYPOINTS'), isFalse);
      expect(content.contains('trip_demo_101'), isFalse);
    });

    test('MOCK-09: No fake admin fallback in admin_web AuthContext (fails closed)', () {
      final file = File('admin_web/src/application/AuthContext.tsx');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('Fail-Closed: Never grant fallback super_admin'), isTrue);
      expect(content.contains('Access denied (Fail-Closed)'), isTrue);
      expect(content.contains('تعذر التحقق من صلاحيات المشرف بسبب انقطاع الاتصال بالخادم.'), isTrue);
    });

    test('MOCK-10: Teacher Dashboard page and routes do not exist', () {
      final dashboardFile = File('lib/pages/teacher_dashboard_page.dart');
      final earningsFile = File('lib/pages/teacher/earnings_page.dart');
      expect(dashboardFile.existsSync(), isFalse);
      expect(earningsFile.existsSync(), isFalse);

      final partnersFile = File('lib/pages/services_partners_page.dart');
      final content = partnersFile.readAsStringSync();
      expect(content.contains('TeacherDashboardPage'), isFalse);
      expect(content.contains('teacher_dashboard_page.dart'), isFalse);
    });

    test('MOCK-11: Teacher fake earnings data completely removed', () {
      final file = File('lib/pages/teacher/earnings_page.dart');
      expect(file.existsSync(), isFalse);
    });

    test('MOCK-12: No synthetic driver assignment writes in rest_madar', () {
      final file = File('rest_madar/lib/features/dashboard/presentation/pages/restaurant_dashboard_page.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('كابتن محمد صلاح'), isFalse);
      expect(content.contains('كابتن وسام كريم'), isFalse);
      expect(content.contains('كابتن علي حسين'), isFalse);
    });

    test('PlaceData model does not contain external via.placeholder.com URLs', () {
      const place = PlaceData(
        id: 'p1',
        name: 'test',
        category: 'cat',
        address: 'addr',
        position: LatLng(0, 0),
      );
      expect(place.imageUrl, isEmpty);
      expect(place.rating, 0.0);
    });
  });
}
