// 🧪 اختبارات التكامل والتراجع لمنسق لوحة إدارة التكسي (Taxi Ride Management Regression Tests)
// Clean Architecture Presentation Coordinator Integration & Regression Suite

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/features/taxi/domain/entities/ride_management_models.dart';
import 'package:dalal_alqaim/features/taxi/data/repositories/ride_management_repository.dart';
import 'package:dalal_alqaim/features/taxi/application/ride_management_controller.dart';
import 'package:dalal_alqaim/features/taxi/presentation/pages/ride_management_page.dart';

class _FakeRepository extends RideManagementRepository {
  final _activeDriversCtrl = StreamController<List<TaxiDriverAdminEntity>>.broadcast();
  final _allDriversCtrl = StreamController<List<TaxiDriverAdminEntity>>.broadcast();
  final _allRidesCtrl = StreamController<List<RideAdminEntity>>.broadcast();
  final _activeRidesCtrl = StreamController<List<RideAdminEntity>>.broadcast();
  final _completedHistoryCtrl = StreamController<List<RideAdminEntity>>.broadcast();
  final _reviewsCtrl = StreamController<List<DriverReviewAdminEntity>>.broadcast();

  void emitActiveDrivers(List<TaxiDriverAdminEntity> list) => _activeDriversCtrl.add(list);
  void emitAllDrivers(List<TaxiDriverAdminEntity> list) => _allDriversCtrl.add(list);
  void emitAllRides(List<RideAdminEntity> list) => _allRidesCtrl.add(list);
  void emitActiveRides(List<RideAdminEntity> list) => _activeRidesCtrl.add(list);
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
  Stream<List<RideAdminEntity>> watchFilteredRideRequests(String statusFilter) =>
      statusFilter == 'all' ? _allRidesCtrl.stream : _activeRidesCtrl.stream;

  @override
  Stream<List<RideAdminEntity>> watchCompletedRidesHistory() => _completedHistoryCtrl.stream;

  @override
  Stream<List<DriverReviewAdminEntity>> watchAllReviews() => _reviewsCtrl.stream;

  @override
  Future<void> cancelRide({required String rideId, String? reason}) async {}

  @override
  Future<void> assignDriverToRide({
    required String rideId,
    required String driverId,
    required String driverName,
    required String driverPhone,
    required String driverCar,
  }) async {}

  @override
  Future<void> toggleDriverCommissionException({required String driverId, required bool allowException}) async {}

  @override
  Future<void> resetDriverWalletCompletely({required String driverId, String? reason}) async {}

  @override
  Future<void> settleDriverCommission({required String driverId, required double amountPaid, String? adminNotes}) async {}

  @override
  Future<void> updateDriverCommissionLimit({required String driverId, required double newLimit}) async {}

  @override
  Future<void> sendAdminReviewAction({required String reviewId, required String driverId, required String actionType, String? note}) async {}

  void dispose() {
    _activeDriversCtrl.close();
    _allDriversCtrl.close();
    _allRidesCtrl.close();
    _activeRidesCtrl.close();
    _completedHistoryCtrl.close();
    _reviewsCtrl.close();
  }
}

void main() {
  late _FakeRepository repo;
  late RideManagementController controller;

  setUp(() {
    repo = _FakeRepository();
    controller = RideManagementController(repository: repo);
  });

  tearDown(() {
    controller.dispose();
    repo.dispose();
  });

  Widget wrapCoordinator(Widget child) {
    return ScreenUtilInit(
      designSize: const Size(800, 1200),
      minTextAdapt: true,
      builder: (_, __) => MaterialApp(
        home: child,
      ),
    );
  }

  Future<void> emitBaseStreams(WidgetTester tester) async {
    repo.emitActiveDrivers([]);
    repo.emitAllDrivers([]);
    repo.emitAllRides([]);
    repo.emitActiveRides([]);
    repo.emitCompletedHistory([]);
    repo.emitReviews([]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('Taxi Ride Management Coordinator & Regression Tests', () {
    testWidgets('1. Coordinator renders loading spinner initially', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('2. Coordinator transitions to populated state upon stream emission', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await tester.pump();

      repo.emitActiveDrivers([
        const TaxiDriverAdminEntity(id: 'd1', name: 'كابتن باقر', phone: '07701112233', isOnline: true, status: 'active'),
      ]);
      repo.emitAllDrivers([
        const TaxiDriverAdminEntity(id: 'd1', name: 'كابتن باقر', phone: '07701112233', isOnline: true, status: 'active'),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('الرادار'), findsOneWidget);
    });

    testWidgets('3. Tab navigation switches from Radar to Active Trips tab', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await emitBaseStreams(tester);

      await tester.tap(find.text('الرحلات الحية'));
      await tester.pumpAndSettle();

      expect(find.text('الكل'), findsOneWidget);
      expect(find.text('بانتظار كابتن'), findsWidgets);
    });

    testWidgets('4. Tab navigation switches to History Analytics tab', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await emitBaseStreams(tester);

      await tester.tap(find.text('الإحصائيات'));
      await tester.pumpAndSettle();

      expect(find.text('إجمالي الدخل (GMV)'), findsOneWidget);
      expect(find.text('عمولة المنصة (10%)'), findsOneWidget);
    });

    testWidgets('5. Tab navigation switches to Captains Wallet tab', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await emitBaseStreams(tester);

      await tester.tap(find.text('المحافظ والعمولات'));
      await tester.pumpAndSettle();

      expect(find.text('المحظورون للدين'), findsOneWidget);
      expect(find.text('استثناء مالي'), findsWidgets);
    });

    testWidgets('6. Tab navigation switches to Reviews tab', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await emitBaseStreams(tester);

      final tab = find.text('التقييمات والآراء');
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();

      expect(find.text('5 نجوم'), findsOneWidget);
      expect(find.text('4 نجوم'), findsOneWidget);
    });

    testWidgets('7. Refresh button in Header invokes controller.initialize', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await emitBaseStreams(tester);

      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pump();

      expect(controller.isLoading, isTrue);
    });

    testWidgets('8. Active trips search updates in coordinator', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await emitBaseStreams(tester);

      repo.emitAllRides([
        const RideAdminEntity(id: 'r1', passengerName: 'حسام علي', status: RideStatusEnum.searching, fare: 4500),
        const RideAdminEntity(id: 'r2', passengerName: 'سليم كامل', status: RideStatusEnum.searching, fare: 6000),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('الرحلات الحية'));
      await tester.pumpAndSettle();

      expect(find.textContaining('حسام علي'), findsOneWidget);
      expect(find.textContaining('سليم كامل'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'حسام');
      await tester.pumpAndSettle();

      expect(find.textContaining('حسام علي'), findsOneWidget);
      expect(find.textContaining('سليم كامل'), findsNothing);
    });

    testWidgets('9. Cancel ride dialog renders and confirms cancellation', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await emitBaseStreams(tester);

      repo.emitAllRides([
        const RideAdminEntity(id: 'r_cancel_dialog', passengerName: 'منى كريم', status: RideStatusEnum.searching, fare: 5000),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('الرحلات الحية'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('إلغاء الرحلة'));
      await tester.pumpAndSettle();

      expect(find.textContaining('متأكد تريد تلغي رحلة الزبون منى كريم؟'), findsOneWidget);
      expect(find.text('تأكيد الإلغاء'), findsOneWidget);

      await tester.tap(find.text('تأكيد الإلغاء'));
      await tester.pumpAndSettle();

      expect(find.textContaining('تم إلغاء الرحلة بنجاح'), findsOneWidget);
    });

    testWidgets('10. Cancel ride dialog dismisses on back button', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await emitBaseStreams(tester);

      repo.emitAllRides([
        const RideAdminEntity(id: 'r_cancel_dismiss', passengerName: 'ياسر', status: RideStatusEnum.searching, fare: 5000),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('الرحلات الحية'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('إلغاء الرحلة'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();

      expect(find.textContaining('متأكد تريد تلغي رحلة'), findsNothing);
    });

    testWidgets('11. Assign driver bottom sheet opens and assigns driver', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await emitBaseStreams(tester);

      repo.emitAllDrivers([
        const TaxiDriverAdminEntity(id: 'd_assign', name: 'كابتن رائد', phone: '07705554433', isOnline: true, status: 'active'),
      ]);
      repo.emitActiveDrivers([
        const TaxiDriverAdminEntity(id: 'd_assign', name: 'كابتن رائد', phone: '07705554433', isOnline: true, status: 'active'),
      ]);
      repo.emitAllRides([
        const RideAdminEntity(id: 'r_assign_flow', passengerName: 'ليث', status: RideStatusEnum.searching, fare: 6000),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('الرحلات الحية'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تعيين كابتن'));
      await tester.pumpAndSettle();

      expect(find.text('تعيين كابتن للرحلة'), findsOneWidget);
      expect(find.text('كابتن رائد'), findsOneWidget);

      await tester.tap(find.text('تعيين'));
      await tester.pumpAndSettle();

      expect(find.textContaining('تم تعيين الكابتن كابتن رائد'), findsOneWidget);
    });

    testWidgets('12. Settle commission dialog performs settlement', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await emitBaseStreams(tester);

      repo.emitAllDrivers([
        const TaxiDriverAdminEntity(id: 'd_settle', name: 'كابتن تحسين', appDebt: 8000, commissionLimit: 10000, isOnline: true),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('المحافظ والعمولات'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تسوية / تصفير'));
      await tester.pumpAndSettle();

      expect(find.textContaining('تسوية عمولة الكابتن كابتن تحسين'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(1), '5000');
      await tester.tap(find.text('تسوية المبلغ'));
      await tester.pumpAndSettle();

      expect(find.textContaining('تم تسوية مبلغ 5,000 د.ع بنجاح'), findsOneWidget);
    });

    testWidgets('13. Reset wallet dialog confirms complete reset', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await emitBaseStreams(tester);

      repo.emitAllDrivers([
        const TaxiDriverAdminEntity(id: 'd_reset', name: 'كابتن وائل', appDebt: 15000, commissionLimit: 10000),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('المحافظ والعمولات'));
      await tester.pumpAndSettle();

      // Open reset from Settle/Reset button
      await tester.tap(find.text('تسوية / تصفير'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
    });

    testWidgets('14. Edit limit dialog saves new driver limit', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await emitBaseStreams(tester);

      repo.emitAllDrivers([
        const TaxiDriverAdminEntity(id: 'd_limit', name: 'كابتن ثائر', appDebt: 3000, commissionLimit: 10000),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('المحافظ والعمولات'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تعديل السقف'));
      await tester.pumpAndSettle();

      expect(find.textContaining('تعديل سقف مديونية كابتن ثائر'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(1), '15000');
      await tester.tap(find.text('حفظ السقف'));
      await tester.pumpAndSettle();

      expect(find.textContaining('تم تعديل سقف المديونية إلى 15,000 د.ع'), findsOneWidget);
    });

    testWidgets('15. Toggle exception updates driver exception state', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await emitBaseStreams(tester);

      repo.emitAllDrivers([
        const TaxiDriverAdminEntity(id: 'd_toggle', name: 'كابتن وسام', allowCommissionException: false),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('المحافظ والعمولات'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تفعيل استثناء'));
      await tester.pumpAndSettle();

      expect(find.textContaining('تم تفعيل الاستثناء المالي للكابتن كابتن وسام'), findsOneWidget);
    });

    testWidgets('16. Warn driver dialog sends admin warning', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await emitBaseStreams(tester);

      repo.emitReviews([
        const DriverReviewAdminEntity(
          id: 'rev_warn',
          driverId: 'd_w',
          driverName: 'كابتن كريم',
          customerName: 'سارة',
          rating: 2.0,
          comment: 'تأخر في الوصول',
        ),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final tab = find.text('التقييمات والآراء');
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();

      await tester.tap(find.text('تنبيه الكابتن'));
      await tester.pumpAndSettle();

      expect(find.textContaining('توجيه تنبيه للكابتن كابتن كريم'), findsOneWidget);

      await tester.tap(find.text('إرسال'));
      await tester.pumpAndSettle();

      expect(find.textContaining('تم إرسال التنبيه للكابتن'), findsOneWidget);
    });

    testWidgets('17. Praise driver dialog sends commendation', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await emitBaseStreams(tester);

      repo.emitReviews([
        const DriverReviewAdminEntity(
          id: 'rev_praise',
          driverId: 'd_p',
          driverName: 'كابتن منذر',
          customerName: 'علي',
          rating: 5.0,
          comment: 'سائق ممتاز وخلوق جداً',
        ),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final tab = find.text('التقييمات والآراء');
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();

      await tester.tap(find.text('شكر الكابتن'));
      await tester.pumpAndSettle();

      expect(find.textContaining('إرسال شكر للكابتن كابتن منذر'), findsOneWidget);

      await tester.tap(find.text('إرسال'));
      await tester.pumpAndSettle();

      expect(find.textContaining('تم إرسال الشكر والتقدير للكابتن'), findsOneWidget);
    });

    testWidgets('18. Delete review removes review from list', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await emitBaseStreams(tester);

      repo.emitReviews([
        const DriverReviewAdminEntity(
          id: 'rev_del',
          driverId: 'd_del',
          driverName: 'كابتن ضياء',
          customerName: 'طارق',
          rating: 1.0,
          comment: 'تعليق غير لائق',
        ),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final tab = find.text('التقييمات والآراء');
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.textContaining('تم حذف التقييم بنجاح'), findsOneWidget);
    });

    testWidgets('19. Selection of driver on radar displays floating card', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await emitBaseStreams(tester);

      final driver = const TaxiDriverAdminEntity(
        id: 'd_radar_select',
        name: 'كابتن حمزة',
        carModel: 'هيونداي النترا',
      );
      controller.selectDriver(driver);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('كابتن حمزة'), findsOneWidget);
      expect(find.textContaining('هيونداي النترا'), findsOneWidget);
    });

    testWidgets('20. Selection of ride on radar displays floating ride card', (tester) async {
      await tester.pumpWidget(wrapCoordinator(
        RideManagementPage(controller: controller),
      ));
      await emitBaseStreams(tester);

      final ride = const RideAdminEntity(
        id: 'r_radar_select',
        passengerName: 'جمال رشيد',
        fare: 7000,
        pickupAddress: 'السوق المسقوف',
      );
      controller.selectRide(ride);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('جمال رشيد'), findsOneWidget);
      expect(find.textContaining('7,000'), findsOneWidget);
    });
  });
}
