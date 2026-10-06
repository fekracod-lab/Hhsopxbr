// 🧪 اختبارات التراجع والمنسق الشاملة للوحة تحكم المندوب (Delivery Dashboard Regression Tests)
// End-to-End Presentation Coordinator & Architecture Integration Tests

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/delivery/domain/entities/delivery_dashboard_models.dart';
import 'package:dalal_alqaim/features/delivery/data/repositories/delivery_dashboard_repository.dart';
import 'package:dalal_alqaim/features/delivery/application/delivery_dashboard_controller.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/delivery_boy/delivery_dashboard_page.dart';

void main() {
  late FakeDeliveryDashboardRepository fakeRepo;
  late DeliveryDashboardController controller;

  setUp(() {
    fakeRepo = FakeDeliveryDashboardRepository();
    controller = DeliveryDashboardController(
      driverId: 'drv_regression_test',
      repository: fakeRepo,
    );
  });

  tearDown(() {
    if (!controller.isDisposed) {
      controller.dispose();
    }
    fakeRepo.dispose();
  });

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Widget buildTestableDashboard({DeliveryDashboardController? ctrl}) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: DeliveryDashboardPage(
          controller: ctrl ?? controller,
        ),
      ),
    );
  }

  group('DeliveryDashboardPage — Coordinator & Regression Tests', () {
    testWidgets('1. Constructor compatibility & default rendering with injected controller', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryDashboardPage), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('2. Header renders driver info and metrics from Controller', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      fakeRepo.emitProfile({
        'name': 'كابتن عمر',
        'phone': '07712345678',
        'availability': 'online',
        'appDebt': 5000.0,
      });
      await tester.pumpAndSettle();

      expect(find.textContaining('كابتن عمر'), findsOneWidget);
      expect(find.textContaining('أنت متصل'), findsOneWidget);
      expect(find.textContaining('5,000'), findsWidgets);
    });

    testWidgets('3. Tab switching across all 5 bottom navigation tabs safely', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      // 1. المهام (Tab 1)
      await tester.tap(find.text('مهامي'));
      await tester.pumpAndSettle();
      expect(find.textContaining('مهامي قيد التوصيل'), findsOneWidget);

      // 2. السجل (Tab 2)
      await tester.tap(find.text('السجل'));
      await tester.pumpAndSettle();
      expect(find.textContaining('سجل الطلبات المسلمة'), findsOneWidget);

      // 3. الأداء (Tab 3)
      await tester.tap(find.text('الأداء'));
      await tester.pumpAndSettle();
      expect(find.textContaining('لوحة الأداء والإحصائيات'), findsOneWidget);

      // 4. حسابي (Tab 4)
      await tester.tap(find.text('حسابي'));
      await tester.pumpAndSettle();
      expect(find.textContaining('الملف الشخصي والإعدادات'), findsOneWidget);

      // 5. العودة للرادار (Tab 0)
      await tester.tap(find.text('الرادار'));
      await tester.pumpAndSettle();
      expect(find.textContaining('يا هلا بيك'), findsOneWidget);
    });

    testWidgets('4. Filter chips update selectedFilter on Controller', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      expect(controller.selectedFilter, DeliveryFilterType.all);

      await tester.tap(find.text('وجبات مطاعم'));
      await tester.pumpAndSettle();
      expect(controller.selectedFilter, DeliveryFilterType.food);

      await tester.tap(find.text('مسواك متاجر'));
      await tester.pumpAndSettle();
      expect(controller.selectedFilter, DeliveryFilterType.store);
    });

    testWidgets('5. Available order card renders and accept button invokes Controller', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      fakeRepo.emitProfile({'availability': 'online'});
      fakeRepo.emitAvailableFood([
        const DeliveryOrderEntity(
          id: 'food_reg_1',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.pending,
          sourceName: 'مطعم السعادة',
          dropoffName: 'شارع 30',
          deliveryFee: 3000,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.textContaining('مطعم السعادة'), findsOneWidget);

      final acceptBtn = find.textContaining('قبول التوصيل');
      await tester.ensureVisible(acceptBtn);
      await tester.tap(acceptBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('تم استلام وقبول الطلب بنجاح'), findsOneWidget);
    });

    testWidgets('6. Acceptance feedback handles server rejection with SnackBar', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      fakeRepo.emitProfile({'availability': 'online'});
      fakeRepo.shouldRejectNextAcceptance = true;
      fakeRepo.emitAvailableFood([
        const DeliveryOrderEntity(
          id: 'food_reg_reject',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.pending,
          sourceName: 'مطعم',
          dropoffName: 'زبون',
          deliveryFee: 3000,
        ),
      ]);
      await tester.pumpAndSettle();

      final acceptBtn = find.textContaining('قبول التوصيل');
      await tester.ensureVisible(acceptBtn);
      await tester.tap(acceptBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('تم قبول الطلب من قبل مندوب آخر'), findsOneWidget);
    });

    testWidgets('7. Acceptance feedback handles offline / ineligible state with SnackBar', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      fakeRepo.emitProfile({'availability': 'offline'});
      fakeRepo.emitAvailableFood([
        const DeliveryOrderEntity(
          id: 'food_reg_offline',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.pending,
          sourceName: 'مطعم',
          dropoffName: 'زبون',
          deliveryFee: 3000,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.textContaining('أنت في وضع عدم الاتصال'), findsOneWidget);
    });

    testWidgets('8. Custom price Mersal request opens price selection bottom sheet', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      fakeRepo.emitProfile({'availability': 'online'});
      fakeRepo.emitAvailableMersal([
        const DeliveryOrderEntity(
          id: 'mersal_custom_price',
          source: DeliveryOrderSource.mersal,
          status: DeliveryOrderStatus.pending,
          sourceName: 'محل عطور',
          dropoffName: 'حي التأميم',
          isCustomPrice: true,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.textContaining('أنت تحدد السعر'), findsOneWidget);

      final acceptBtn = find.textContaining('قبول التوصيل');
      await tester.ensureVisible(acceptBtn);
      await tester.tap(acceptBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('حدد أجرة التوصيل المناسبة'), findsOneWidget);
      expect(find.text('2500 د.ع'), findsOneWidget);

      await tester.tap(find.text('2500 د.ع'));
      await tester.pumpAndSettle();

      expect(find.textContaining('تم استلام وقبول الطلب بنجاح'), findsOneWidget);
    });

    testWidgets('9. Active tasks list renders in Tab 1 with task details', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      fakeRepo.emitActiveFood([
        const DeliveryOrderEntity(
          id: 'act_reg_1',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.delivering,
          sourceName: 'كنتاكي القائم',
          dropoffName: 'حي الضباط',
          deliveryFee: 4000,
        ),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('مهامي'));
      await tester.pumpAndSettle();

      expect(find.textContaining('كنتاكي القائم'), findsOneWidget);
      expect(find.textContaining('4,000'), findsOneWidget);
    });

    testWidgets('10. History tab renders completed orders in Tab 2', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      fakeRepo.emitHistoryFood([
        DeliveryOrderEntity(
          id: 'hist_reg_1',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.completed,
          sourceName: 'مطعم النخيل',
          dropoffName: 'حي النصر',
          deliveryFee: 3500,
          completedAt: DateTime(2026, 8, 27, 12, 30),
        ),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('السجل'));
      await tester.pumpAndSettle();

      expect(find.textContaining('حي النصر'), findsOneWidget);
      expect(find.textContaining('3,500'), findsOneWidget);
    });

    testWidgets('11. Performance tab displays total earnings and shortcuts in Tab 3', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      fakeRepo.emitHistoryFood([
        DeliveryOrderEntity(
          id: 'hist_reg_2',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.completed,
          sourceName: 'مطعم',
          dropoffName: 'حي',
          deliveryFee: 5000,
          completedAt: DateTime.now(),
        ),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('الأداء'));
      await tester.pumpAndSettle();

      expect(find.textContaining('5,000'), findsWidgets);
      expect(find.textContaining('المحاسبة الأسبوعية'), findsOneWidget);
      expect(find.textContaining('المحفظة وسجل السحب'), findsOneWidget);
    });

    testWidgets('12. Settings tab renders driver profile info in Tab 4', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      fakeRepo.emitProfile({
        'name': 'كابتن حيدر',
        'phone': '07709876543',
        'rating': 4.9,
      });
      await tester.pumpAndSettle();

      await tester.tap(find.text('حسابي'));
      await tester.pumpAndSettle();

      expect(find.text('كابتن حيدر'), findsOneWidget);
      expect(find.text('07709876543'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
    });

    testWidgets('13. Availability toggle switch in Settings toggles state', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      fakeRepo.emitProfile({'availability': 'offline'});
      await tester.pumpAndSettle();

      await tester.tap(find.text('حسابي'));
      await tester.pumpAndSettle();

      expect(controller.isOnline, isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(controller.isOnline, isTrue);
    });

    testWidgets('14. Sign out dialog displays and handles cancel', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      await tester.tap(find.text('حسابي'));
      await tester.pumpAndSettle();

      final logoutBtn = find.textContaining('تسجيل الخروج من الحساب');
      await tester.ensureVisible(logoutBtn);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      expect(find.text('تسجيل الخروج'), findsWidgets);
      expect(find.textContaining('هل أنت متأكد من رغبتك'), findsOneWidget);

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      expect(find.textContaining('هل أنت متأكد من رغبتك'), findsNothing);
    });

    testWidgets('15. Repeated rapid rebuild stability test', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestableDashboard());
      await tester.pumpAndSettle();

      for (int i = 0; i < 5; i++) {
        controller.setFilter(i.isEven ? DeliveryFilterType.food : DeliveryFilterType.all);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryDashboardPage), findsOneWidget);
    });
  });
}

/// 🧪 مستودع بيانات وهمي متحكم بالتدفقات
class FakeDeliveryDashboardRepository extends DeliveryDashboardRepository {
  final _profileController = StreamController<Map<String, dynamic>>.broadcast();
  final _availableMersalController = StreamController<List<DeliveryOrderEntity>>.broadcast();
  final _availableFoodController = StreamController<List<DeliveryOrderEntity>>.broadcast();
  final _availableStoreController = StreamController<List<DeliveryOrderEntity>>.broadcast();

  final _activeMersalController = StreamController<List<DeliveryOrderEntity>>.broadcast();
  final _activeFoodController = StreamController<List<DeliveryOrderEntity>>.broadcast();
  final _activeStoreController = StreamController<List<DeliveryOrderEntity>>.broadcast();

  final _historyMersalController = StreamController<List<DeliveryOrderEntity>>.broadcast();
  final _historyFoodController = StreamController<List<DeliveryOrderEntity>>.broadcast();
  final _historyStoreController = StreamController<List<DeliveryOrderEntity>>.broadcast();

  bool shouldRejectNextAcceptance = false;

  void emitProfile(Map<String, dynamic> data) => _profileController.add(data);
  void emitAvailableMersal(List<DeliveryOrderEntity> list) => _availableMersalController.add(list);
  void emitAvailableFood(List<DeliveryOrderEntity> list) => _availableFoodController.add(list);
  void emitAvailableStore(List<DeliveryOrderEntity> list) => _availableStoreController.add(list);

  void emitActiveFood(List<DeliveryOrderEntity> list) => _activeFoodController.add(list);
  void emitHistoryFood(List<DeliveryOrderEntity> list) => _historyFoodController.add(list);

  @override
  Stream<Map<String, dynamic>> watchDriverProfile(String uid) => _profileController.stream;

  @override
  Stream<List<DeliveryOrderEntity>> watchPendingMersalOrders() => _availableMersalController.stream;

  @override
  Stream<List<DeliveryOrderEntity>> watchAvailableFoodOrders() => _availableFoodController.stream;

  @override
  Stream<List<DeliveryOrderEntity>> watchAvailableStoreOrders() => _availableStoreController.stream;

  @override
  Stream<List<DeliveryOrderEntity>> watchActiveMersalOrders(String driverId) => _activeMersalController.stream;

  @override
  Stream<List<DeliveryOrderEntity>> watchActiveFoodOrders(String driverId) => _activeFoodController.stream;

  @override
  Stream<List<DeliveryOrderEntity>> watchActiveStoreOrders(String driverId) => _activeStoreController.stream;

  @override
  Stream<List<DeliveryOrderEntity>> watchHistoryMersalOrders(String driverId) => _historyMersalController.stream;

  @override
  Stream<List<DeliveryOrderEntity>> watchHistoryFoodOrders(String driverId) => _historyFoodController.stream;

  @override
  Stream<List<DeliveryOrderEntity>> watchHistoryStoreOrders(String driverId) => _historyStoreController.stream;

  @override
  Future<void> setDriverAvailability({
    required String driverId,
    required DriverAvailabilityState availabilityState,
  }) async {}

  @override
  Future<bool> acceptMersalOrder({
    required String requestId,
    required String driverId,
    required Map<String, dynamic> driverData,
    required String agreedPrice,
  }) async {
    return !shouldRejectNextAcceptance;
  }

  @override
  Future<bool> acceptFoodOrder({
    required String orderId,
    required String driverId,
    required Map<String, dynamic> driverData,
  }) async {
    return !shouldRejectNextAcceptance;
  }

  @override
  Future<bool> acceptStoreOrder({
    required String storeId,
    required String orderId,
    required String driverId,
    required Map<String, dynamic> driverData,
  }) async {
    return !shouldRejectNextAcceptance;
  }

  void dispose() {
    _profileController.close();
    _availableMersalController.close();
    _availableFoodController.close();
    _availableStoreController.close();
    _activeMersalController.close();
    _activeFoodController.close();
    _activeStoreController.close();
    _historyMersalController.close();
    _historyFoodController.close();
    _historyStoreController.close();
  }
}
