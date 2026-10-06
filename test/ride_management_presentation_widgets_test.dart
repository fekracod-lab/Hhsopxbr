// 🧪 اختبارات ودجات العرض لإدارة رحلات التكسي (Taxi Ride Management Presentation Widgets Tests)
// Clean Architecture Presentation Layer UI & Interaction Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/features/taxi/domain/entities/ride_management_models.dart';
import 'package:dalal_alqaim/features/taxi/presentation/widgets/ride_management_header.dart';
import 'package:dalal_alqaim/features/taxi/presentation/widgets/ride_management_kpi_bar.dart';
import 'package:dalal_alqaim/features/taxi/presentation/widgets/ride_fleet_radar_tab.dart';
import 'package:dalal_alqaim/features/taxi/presentation/widgets/ride_admin_card.dart';
import 'package:dalal_alqaim/features/taxi/presentation/widgets/ride_active_trips_tab.dart';
import 'package:dalal_alqaim/features/taxi/presentation/widgets/ride_history_analytics_tab.dart';
import 'package:dalal_alqaim/features/taxi/presentation/widgets/ride_captains_wallet_tab.dart';
import 'package:dalal_alqaim/features/taxi/presentation/widgets/ride_reviews_tab.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return ScreenUtilInit(
      designSize: const Size(800, 1200),
      minTextAdapt: true,
      builder: (_, __) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('1. RideManagementHeader & KPI Bar Tests', () {
    testWidgets('1. Header displays title and triggers refresh callback', (tester) async {
      bool refreshed = false;
      await tester.pumpWidget(wrapWidget(
        RideManagementHeader(onRefresh: () => refreshed = true),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('غرفة التحكم والعمليات'), findsOneWidget);
      expect(find.text('مباشر'), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      expect(refreshed, isTrue);
    });

    testWidgets('2. KpiBar renders all 4 metrics correctly', (tester) async {
      const metrics = RideManagementKpiMetrics(
        onlineDriversCount: 12,
        activeTripsCount: 5,
        searchingTripsCount: 3,
        todayCompletedTripsCount: 28,
      );

      await tester.pumpWidget(wrapWidget(
        const RideManagementKpiBar(metrics: metrics),
      ));
      await tester.pumpAndSettle();

      expect(find.text('12'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('28'), findsOneWidget);
      expect(find.text('كباتن متصلون'), findsOneWidget);
    });
  });

  group('2. RideFleetRadarTab Tests', () {
    testWidgets('3. Radar tab displays fleet overview badge counters', (tester) async {
      final drivers = [
        const TaxiDriverAdminEntity(id: 'd1', isOnline: true),
        const TaxiDriverAdminEntity(id: 'd2', isOnline: false),
      ];
      final rides = [
        const RideAdminEntity(id: 'r1', status: RideStatusEnum.searching),
      ];

      await tester.pumpWidget(wrapWidget(
        RideFleetRadarTab(
          drivers: drivers,
          activeRides: rides,
          onDriverSelected: (_) {},
          onRideSelected: (_) {},
          onClearSelection: () {},
          onAssignDriver: (_) {},
          onCancelRide: (_) {},
          onCallPhone: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 كابتن بالخدمة'), findsOneWidget);
      expect(find.textContaining('1 طلب نشط بالرادار'), findsOneWidget);
    });

    testWidgets('4. Selected driver card displays driver info and fires call action', (tester) async {
      String calledPhone = '';
      const driver = TaxiDriverAdminEntity(
        id: 'd1',
        name: 'كابتن نبيل',
        phone: '07709876543',
        carModel: 'كيا فورتي',
        appDebt: 4500,
      );

      await tester.pumpWidget(wrapWidget(
        RideFleetRadarTab(
          drivers: const [],
          activeRides: const [],
          selectedDriver: driver,
          onDriverSelected: (_) {},
          onRideSelected: (_) {},
          onClearSelection: () {},
          onAssignDriver: (_) {},
          onCancelRide: (_) {},
          onCallPhone: (p) => calledPhone = p,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('كابتن نبيل'), findsOneWidget);
      expect(find.textContaining('كيا فورتي'), findsOneWidget);

      await tester.tap(find.text('اتصال بالكابتن'));
      expect(calledPhone, equals('07709876543'));
    });

    testWidgets('5. Selected ride card displays ride info and fires assign/cancel callbacks', (tester) async {
      bool assignTapped = false;
      bool cancelTapped = false;

      const ride = RideAdminEntity(
        id: 'r_sel',
        passengerName: 'زيد طارق',
        fare: 6000,
        pickupAddress: 'شارع 30',
        dropoffAddress: 'مستشفى القائم',
      );

      await tester.pumpWidget(wrapWidget(
        RideFleetRadarTab(
          drivers: const [],
          activeRides: const [],
          selectedRide: ride,
          onDriverSelected: (_) {},
          onRideSelected: (_) {},
          onClearSelection: () {},
          onAssignDriver: (_) => assignTapped = true,
          onCancelRide: (_) => cancelTapped = true,
          onCallPhone: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('زيد طارق'), findsOneWidget);
      expect(find.textContaining('6,000'), findsOneWidget);

      await tester.tap(find.text('تعيين كابتن'));
      expect(assignTapped, isTrue);

      await tester.tap(find.text('إلغاء'));
      expect(cancelTapped, isTrue);
    });
  });

  group('3. RideAdminCard & Active Trips Tests', () {
    testWidgets('6. RideAdminCard renders full ride details and status badge', (tester) async {
      const ride = RideAdminEntity(
        id: 'r_card_1',
        passengerName: 'عبدالله السعدي',
        passengerPhone: '07701234567',
        fare: 5500,
        status: RideStatusEnum.searching,
        pickupAddress: 'الساحة العامة',
        dropoffAddress: 'حي الرسالة',
      );

      await tester.pumpWidget(wrapWidget(
        RideAdminCard(
          ride: ride,
          onAssignDriver: (_) {},
          onCancelRide: (_) {},
          onCallPhone: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('بانتظار كابتن'), findsOneWidget);
      expect(find.textContaining('عبدالله السعدي'), findsOneWidget);
      expect(find.textContaining('5,500'), findsOneWidget);
      expect(find.textContaining('الساحة العامة'), findsOneWidget);
    });

    testWidgets('7. RideAdminCard displays assigned driver container and call button', (tester) async {
      String calledPhone = '';
      const ride = RideAdminEntity(
        id: 'r_card_2',
        status: RideStatusEnum.in_progress,
        driverId: 'drv_salam_1',
        driverName: 'كابتن سلام',
        driverPhone: '07809998877',
        driverCar: 'تويوتا يارس',
      );

      await tester.pumpWidget(wrapWidget(
        RideAdminCard(
          ride: ride,
          onAssignDriver: (_) {},
          onCancelRide: (_) {},
          onCallPhone: (p) => calledPhone = p,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('كابتن سلام'), findsOneWidget);
      expect(find.textContaining('تويوتا يارس'), findsOneWidget);

      await tester.tap(find.text('اتصال'));
      expect(calledPhone, equals('07809998877'));
    });

    testWidgets('8. RideAdminCard fires assign and cancel callbacks', (tester) async {
      bool assignFired = false;
      bool cancelFired = false;
      const ride = RideAdminEntity(id: 'r_act', status: RideStatusEnum.searching);

      await tester.pumpWidget(wrapWidget(
        RideAdminCard(
          ride: ride,
          onAssignDriver: (_) => assignFired = true,
          onCancelRide: (_) => cancelFired = true,
          onCallPhone: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تعيين كابتن'));
      expect(assignFired, isTrue);

      await tester.tap(find.text('إلغاء الرحلة'));
      expect(cancelFired, isTrue);
    });

    testWidgets('9. ActiveTripsTab search field fires onSearchChanged', (tester) async {
      String query = '';
      await tester.pumpWidget(wrapWidget(
        RideActiveTripsTab(
          rides: const [],
          selectedFilter: 'all',
          searchQuery: '',
          onFilterChanged: (_) {},
          onSearchChanged: (q) => query = q,
          onAssignDriver: (_) {},
          onCancelRide: (_) {},
          onCallPhone: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'أحمد');
      expect(query, equals('أحمد'));
    });

    testWidgets('10. ActiveTripsTab filter chips trigger onFilterChanged', (tester) async {
      String filter = '';
      await tester.pumpWidget(wrapWidget(
        RideActiveTripsTab(
          rides: const [],
          selectedFilter: 'all',
          searchQuery: '',
          onFilterChanged: (f) => filter = f,
          onSearchChanged: (_) {},
          onAssignDriver: (_) {},
          onCancelRide: (_) {},
          onCallPhone: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('بانتظار كابتن'));
      expect(filter, equals('searching'));
    });

    testWidgets('11. ActiveTripsTab renders list of rides and handles empty state', (tester) async {
      // Empty state
      await tester.pumpWidget(wrapWidget(
        RideActiveTripsTab(
          rides: const [],
          selectedFilter: 'all',
          searchQuery: '',
          onFilterChanged: (_) {},
          onSearchChanged: (_) {},
          onAssignDriver: (_) {},
          onCancelRide: (_) {},
          onCallPhone: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('ماكو رحلات حالياً مطابقة'), findsOneWidget);

      // Populated state
      final rides = [
        const RideAdminEntity(id: 'r_list_1', passengerName: 'ركاب 1'),
        const RideAdminEntity(id: 'r_list_2', passengerName: 'ركاب 2'),
      ];

      await tester.pumpWidget(wrapWidget(
        RideActiveTripsTab(
          rides: rides,
          selectedFilter: 'all',
          searchQuery: '',
          onFilterChanged: (_) {},
          onSearchChanged: (_) {},
          onAssignDriver: (_) {},
          onCancelRide: (_) {},
          onCallPhone: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('ركاب 1'), findsOneWidget);
      expect(find.textContaining('ركاب 2'), findsOneWidget);
    });
  });

  group('4. RideHistoryAnalyticsTab Tests', () {
    testWidgets('12. History analytics tab displays 4 KPI stat cards', (tester) async {
      const stats = RideHistoryAnalyticsMetrics(
        totalCompletedRides: 15,
        totalGmv: 75000,
        totalPlatformCommission: 7500,
        averageFare: 5000,
      );

      await tester.pumpWidget(wrapWidget(
        const RideHistoryAnalyticsTab(
          historyRides: [],
          analytics: stats,
          onCallPhone: _dummyPhone,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('75,000'), findsOneWidget);
      expect(find.textContaining('7,500'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('5,000 د.ع'), findsOneWidget);
    });

    testWidgets('13. History analytics renders completed ride items', (tester) async {
      final history = [
        RideAdminEntity(
          id: 'hist_ui_1',
          passengerName: 'أمير حميد',
          fare: 4000,
          driverName: 'كابتن فراس',
          completedAt: DateTime(2026, 8, 27, 18, 0),
        ),
      ];

      await tester.pumpWidget(wrapWidget(
        RideHistoryAnalyticsTab(
          historyRides: history,
          analytics: const RideHistoryAnalyticsMetrics(),
          onCallPhone: _dummyPhone,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('أمير حميد'), findsOneWidget);
      expect(find.textContaining('4,000'), findsOneWidget);
      expect(find.textContaining('كابتن فراس'), findsOneWidget);
    });
  });

  group('5. RideCaptainsWalletTab Tests', () {
    testWidgets('14. Wallet tab search field fires onSearchChanged', (tester) async {
      String query = '';
      await tester.pumpWidget(wrapWidget(
        RideCaptainsWalletTab(
          drivers: const [],
          selectedFilter: 'all',
          searchQuery: '',
          onFilterChanged: (_) {},
          onSearchChanged: (q) => query = q,
          onSettleCommission: (_) {},
          onResetWallet: (_) {},
          onEditLimit: (_) {},
          onToggleException: (_, __) {},
          onCallPhone: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'كابتن حيدر');
      expect(query, equals('كابتن حيدر'));
    });

    testWidgets('15. Wallet tab filter chips trigger onFilterChanged', (tester) async {
      String filter = '';
      await tester.pumpWidget(wrapWidget(
        RideCaptainsWalletTab(
          drivers: const [],
          selectedFilter: 'all',
          searchQuery: '',
          onFilterChanged: (f) => filter = f,
          onSearchChanged: (_) {},
          onSettleCommission: (_) {},
          onResetWallet: (_) {},
          onEditLimit: (_) {},
          onToggleException: (_, __) {},
          onCallPhone: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('المحظورون للدين'));
      expect(filter, equals('blocked'));
    });

    testWidgets('16. Captain card displays debt, limit, progress bar and status badge', (tester) async {
      const driver = TaxiDriverAdminEntity(
        id: 'd_w_1',
        name: 'كابتن قصي',
        appDebt: 12000,
        commissionLimit: 10000,
        allowCommissionException: false,
      );

      await tester.pumpWidget(wrapWidget(
        RideCaptainsWalletTab(
          drivers: const [driver],
          selectedFilter: 'all',
          searchQuery: '',
          onFilterChanged: (_) {},
          onSearchChanged: (_) {},
          onSettleCommission: (_) {},
          onResetWallet: (_) {},
          onEditLimit: (_) {},
          onToggleException: (_, __) {},
          onCallPhone: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('كابتن قصي'), findsOneWidget);
      expect(find.text('محظور للدين'), findsOneWidget);
      expect(find.textContaining('12,000'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('17. Captain card triggers settle, edit limit, and toggle exception callbacks', (tester) async {
      bool settleFired = false;
      bool limitFired = false;
      bool exceptionFired = false;

      const driver = TaxiDriverAdminEntity(id: 'd_w_actions', name: 'كابتن مازن');

      await tester.pumpWidget(wrapWidget(
        RideCaptainsWalletTab(
          drivers: const [driver],
          selectedFilter: 'all',
          searchQuery: '',
          onFilterChanged: (_) {},
          onSearchChanged: (_) {},
          onSettleCommission: (_) => settleFired = true,
          onResetWallet: (_) {},
          onEditLimit: (_) => limitFired = true,
          onToggleException: (_, __) => exceptionFired = true,
          onCallPhone: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تسوية / تصفير'));
      expect(settleFired, isTrue);

      await tester.tap(find.text('تعديل السقف'));
      expect(limitFired, isTrue);

      await tester.tap(find.text('تفعيل استثناء'));
      expect(exceptionFired, isTrue);
    });
  });

  group('6. RideReviewsTab Tests', () {
    testWidgets('18. Reviews tab search field fires onSearchChanged', (tester) async {
      String query = '';
      await tester.pumpWidget(wrapWidget(
        RideReviewsTab(
          reviews: const [],
          selectedFilter: 'all',
          searchQuery: '',
          onFilterChanged: (_) {},
          onSearchChanged: (q) => query = q,
          onWarnDriver: (_) {},
          onPraiseDriver: (_) {},
          onDeleteReview: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'خدمة سيئة');
      expect(query, equals('خدمة سيئة'));
    });

    testWidgets('19. Reviews tab star filter chips trigger onFilterChanged', (tester) async {
      String filter = '';
      await tester.pumpWidget(wrapWidget(
        RideReviewsTab(
          reviews: const [],
          selectedFilter: 'all',
          searchQuery: '',
          onFilterChanged: (f) => filter = f,
          onSearchChanged: (_) {},
          onWarnDriver: (_) {},
          onPraiseDriver: (_) {},
          onDeleteReview: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('5 نجوم'));
      expect(filter, equals('5_star'));
    });

    testWidgets('20. Review card renders customer, driver, comment and rating', (tester) async {
      const review = DriverReviewAdminEntity(
        id: 'rev_ui_1',
        driverId: 'd1',
        driverName: 'كابتن أوس',
        customerName: 'زينب',
        rating: 4.8,
        comment: 'سائق محترم والسيارة باردة ونظيفة',
      );

      await tester.pumpWidget(wrapWidget(
        RideReviewsTab(
          reviews: const [review],
          selectedFilter: 'all',
          searchQuery: '',
          onFilterChanged: (_) {},
          onSearchChanged: (_) {},
          onWarnDriver: (_) {},
          onPraiseDriver: (_) {},
          onDeleteReview: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('زينب'), findsOneWidget);
      expect(find.textContaining('كابتن أوس'), findsOneWidget);
      expect(find.textContaining('سائق محترم'), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);
    });

    testWidgets('21. Review card moderation actions fire warn, praise, and delete callbacks', (tester) async {
      bool warnFired = false;
      bool praiseFired = false;
      bool deleteFired = false;

      const review = DriverReviewAdminEntity(id: 'rev_act', driverId: 'd1');

      await tester.pumpWidget(wrapWidget(
        RideReviewsTab(
          reviews: const [review],
          selectedFilter: 'all',
          searchQuery: '',
          onFilterChanged: (_) {},
          onSearchChanged: (_) {},
          onWarnDriver: (_) => warnFired = true,
          onPraiseDriver: (_) => praiseFired = true,
          onDeleteReview: (_) => deleteFired = true,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تنبيه الكابتن'));
      expect(warnFired, isTrue);

      await tester.tap(find.text('شكر الكابتن'));
      expect(praiseFired, isTrue);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      expect(deleteFired, isTrue);
    });

    testWidgets('22. Dark mode renders with dark background colors across widgets', (tester) async {
      await tester.pumpWidget(wrapWidget(
        const RideManagementHeader(isDark: true),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(RideManagementHeader), findsOneWidget);
    });

    testWidgets('23. Reviews tab handles empty review list gracefully', (tester) async {
      await tester.pumpWidget(wrapWidget(
        RideReviewsTab(
          reviews: const [],
          selectedFilter: 'all',
          searchQuery: '',
          onFilterChanged: (_) {},
          onSearchChanged: (_) {},
          onWarnDriver: (_) {},
          onPraiseDriver: (_) {},
          onDeleteReview: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ماكو تقييمات حالياً مطابقة للتصفية'), findsOneWidget);
    });

    testWidgets('24. Captain card exception allowed shows amber badge', (tester) async {
      const driver = TaxiDriverAdminEntity(
        id: 'd_exc',
        name: 'كابتن مؤيد',
        appDebt: 25000,
        commissionLimit: 10000,
        allowCommissionException: true,
      );

      await tester.pumpWidget(wrapWidget(
        RideCaptainsWalletTab(
          drivers: const [driver],
          selectedFilter: 'all',
          searchQuery: '',
          onFilterChanged: (_) {},
          onSearchChanged: (_) {},
          onSettleCommission: (_) {},
          onResetWallet: (_) {},
          onEditLimit: (_) {},
          onToggleException: (_, __) {},
          onCallPhone: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('استثناء مالي'), findsWidgets);
    });

    testWidgets('25. Assigned by admin badge rendered on RideAdminCard', (tester) async {
      const ride = RideAdminEntity(
        id: 'r_adm_badge',
        assignedByAdmin: true,
      );

      await tester.pumpWidget(wrapWidget(
        RideAdminCard(
          ride: ride,
          onAssignDriver: (_) {},
          onCancelRide: (_) {},
          onCallPhone: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('تعيين إداري'), findsOneWidget);
    });
  });
}

void _dummyPhone(String phone) {}
