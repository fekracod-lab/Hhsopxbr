// 🧪 اختبارات متحكم لوحة تحكم المندوب (Delivery Dashboard Controller Tests)
// Application Layer Unit Tests — Pure Flutter Test (No Firebase Emulator)

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/delivery/domain/entities/delivery_dashboard_models.dart';
import 'package:dalal_alqaim/features/delivery/data/repositories/delivery_dashboard_repository.dart';
import 'package:dalal_alqaim/features/delivery/application/delivery_dashboard_controller.dart';

void main() {
  late FakeDeliveryDashboardRepository fakeRepo;
  late DeliveryDashboardController controller;

  setUp(() {
    fakeRepo = FakeDeliveryDashboardRepository();
    controller = DeliveryDashboardController(
      driverId: 'drv_test_100',
      repository: fakeRepo,
    );
  });

  tearDown(() {
    if (!controller.isDisposed) {
      controller.dispose();
    }
    fakeRepo.dispose();
  });

  group('Delivery Dashboard Controller — Initialization & State Tests', () {
    test('1. Initial state reflects injected driver ID and loading state', () {
      expect(controller.driverId, 'drv_test_100');
      expect(controller.isDisposed, isFalse);
      expect(controller.selectedFilter, DeliveryFilterType.all);
      expect(controller.searchQuery, isEmpty);
      expect(controller.generation, 1);
    });

    test('2. Driver profile stream updates availability and properties', () async {
      fakeRepo.emitProfile({
        'name': 'كابتن علي',
        'phone': '07700000000',
        'availability': 'online',
        'appDebt': 2500.0,
        'rating': 4.8,
      });
      await Future.delayed(Duration.zero);

      expect(controller.isLoading, isFalse);
      expect(controller.driverName, 'كابتن علي');
      expect(controller.driverPhone, '07700000000');
      expect(controller.availabilityState, DriverAvailabilityState.online);
      expect(controller.isOnline, isTrue);
      expect(controller.appDebt, 2500.0);
      expect(controller.rating, 4.8);
    });

    test('3. Empty driverId marks controller with error and disables loading', () {
      final invalidCtrl = DeliveryDashboardController(driverId: '', repository: fakeRepo);
      expect(invalidCtrl.isLoading, isFalse);
      expect(invalidCtrl.errorMessage, isNotNull);
      invalidCtrl.dispose();
    });
  });

  group('Delivery Dashboard Controller — Stream Merging & Ordering Tests', () {
    test('4. Merges Food, Store, and Mersal available orders sorted by createdAt descending', () async {
      final mersalOrder = DeliveryOrderEntity(
        id: 'm_1',
        source: DeliveryOrderSource.mersal,
        status: DeliveryOrderStatus.pending,
        sourceName: 'مرسال',
        dropoffName: 'موقع 1',
        createdAt: DateTime(2026, 8, 27, 10, 0),
      );

      final foodOrder = DeliveryOrderEntity(
        id: 'f_1',
        source: DeliveryOrderSource.food,
        status: DeliveryOrderStatus.pending,
        sourceName: 'مطعم',
        dropoffName: 'موقع 2',
        createdAt: DateTime(2026, 8, 27, 10, 30),
      );

      final storeOrder = DeliveryOrderEntity(
        id: 's_1',
        source: DeliveryOrderSource.store,
        status: DeliveryOrderStatus.pending,
        sourceName: 'متجر',
        dropoffName: 'موقع 3',
        createdAt: DateTime(2026, 8, 27, 10, 15),
      );

      fakeRepo.emitAvailableMersal([mersalOrder]);
      fakeRepo.emitAvailableFood([foodOrder]);
      fakeRepo.emitAvailableStore([storeOrder]);
      await Future.delayed(Duration.zero);

      final all = controller.allAvailableOrders;
      expect(all.length, 3);
      expect(all[0].id, 'f_1'); // 10:30
      expect(all[1].id, 's_1'); // 10:15
      expect(all[2].id, 'm_1'); // 10:00
    });

    test('5. Merges Active Tasks and History Orders accurately', () async {
      final activeFood = DeliveryOrderEntity(
        id: 'act_f_1',
        source: DeliveryOrderSource.food,
        status: DeliveryOrderStatus.delivering,
        sourceName: 'مطعم نشط',
        dropoffName: 'زبون',
        acceptedAt: DateTime(2026, 8, 27, 11, 0),
      );

      final histStore = DeliveryOrderEntity(
        id: 'hist_s_1',
        source: DeliveryOrderSource.store,
        status: DeliveryOrderStatus.completed,
        sourceName: 'متجر مكتمل',
        dropoffName: 'زبون',
        completedAt: DateTime(2026, 8, 27, 9, 0),
      );

      fakeRepo.emitActiveFood([activeFood]);
      fakeRepo.emitHistoryStore([histStore]);
      await Future.delayed(Duration.zero);

      expect(controller.activeTasks.length, 1);
      expect(controller.activeTasks.first.id, 'act_f_1');

      expect(controller.historyOrders.length, 1);
      expect(controller.historyOrders.first.id, 'hist_s_1');
    });

    test('6. Preserves order sources accurately in merged lists', () async {
      fakeRepo.emitAvailableFood([
        const DeliveryOrderEntity(id: 'f1', source: DeliveryOrderSource.food, status: DeliveryOrderStatus.pending, sourceName: 'A', dropoffName: 'B'),
      ]);
      fakeRepo.emitAvailableStore([
        const DeliveryOrderEntity(id: 's1', source: DeliveryOrderSource.store, status: DeliveryOrderStatus.pending, sourceName: 'C', dropoffName: 'D'),
      ]);
      fakeRepo.emitAvailableMersal([
        const DeliveryOrderEntity(id: 'm1', source: DeliveryOrderSource.mersal, status: DeliveryOrderStatus.pending, sourceName: 'E', dropoffName: 'F'),
      ]);
      await Future.delayed(Duration.zero);

      final orders = controller.allAvailableOrders;
      expect(orders.firstWhere((o) => o.id == 'f1').source, DeliveryOrderSource.food);
      expect(orders.firstWhere((o) => o.id == 's1').source, DeliveryOrderSource.store);
      expect(orders.firstWhere((o) => o.id == 'm1').source, DeliveryOrderSource.mersal);
    });
  });

  group('Delivery Dashboard Controller — Filter & Search Tests', () {
    final food = const DeliveryOrderEntity(
      id: 'f_test',
      source: DeliveryOrderSource.food,
      status: DeliveryOrderStatus.pending,
      sourceName: 'شاورما سريعة',
      dropoffName: 'حي النصر',
    );
    final store = const DeliveryOrderEntity(
      id: 's_test',
      source: DeliveryOrderSource.store,
      status: DeliveryOrderStatus.pending,
      sourceName: 'أسواق المدينة',
      dropoffName: 'شارع الزهور',
    );
    final mersal = const DeliveryOrderEntity(
      id: 'm_test',
      source: DeliveryOrderSource.mersal,
      status: DeliveryOrderStatus.pending,
      sourceName: 'صيدلية النور',
      dropoffName: 'حي التأميم',
    );

    setUp(() async {
      fakeRepo.emitAvailableFood([food]);
      fakeRepo.emitAvailableStore([store]);
      fakeRepo.emitAvailableMersal([mersal]);
      await Future.delayed(Duration.zero);
    });

    test('7. setFilter filters available orders by category', () {
      controller.setFilter(DeliveryFilterType.food);
      expect(controller.filteredAvailableOrders.length, 1);
      expect(controller.filteredAvailableOrders.first.source, DeliveryOrderSource.food);

      controller.setFilter(DeliveryFilterType.store);
      expect(controller.filteredAvailableOrders.length, 1);
      expect(controller.filteredAvailableOrders.first.source, DeliveryOrderSource.store);

      controller.setFilter(DeliveryFilterType.mersal);
      expect(controller.filteredAvailableOrders.length, 1);
      expect(controller.filteredAvailableOrders.first.source, DeliveryOrderSource.mersal);

      controller.setFilter(DeliveryFilterType.all);
      expect(controller.filteredAvailableOrders.length, 3);
    });

    test('8. setSearchQuery filters across titles and addresses in real-time', () {
      controller.setSearchQuery('شاورما');
      expect(controller.filteredAvailableOrders.length, 1);
      expect(controller.filteredAvailableOrders.first.id, 'f_test');

      controller.setSearchQuery('الزهور');
      expect(controller.filteredAvailableOrders.length, 1);
      expect(controller.filteredAvailableOrders.first.id, 's_test');

      controller.setSearchQuery('');
      expect(controller.filteredAvailableOrders.length, 3);
    });

    test('9. setFilter does not trigger notification if identical filter', () {
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.setFilter(DeliveryFilterType.all); // already all
      expect(notifyCount, 0);
    });

    test('10. setSearchQuery does not trigger notification if identical query', () {
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.setSearchQuery(''); // already empty
      expect(notifyCount, 0);
    });
  });

  group('Delivery Dashboard Controller — Concurrency, Action Locks & Acceptance', () {
    test('11. toggleAvailability toggles state and locks during execution', () async {
      fakeRepo.emitProfile({'availability': 'offline'});
      await Future.delayed(Duration.zero);
      expect(controller.isOnline, isFalse);

      final future = controller.toggleAvailability();
      expect(controller.isTogglingAvailability, isTrue);

      final success = await future;
      expect(success, isTrue);
      expect(controller.isTogglingAvailability, isFalse);
      expect(controller.availabilityState, DriverAvailabilityState.online);
    });

    test('12. Concurrent toggleAvailability calls are rejected by lock', () async {
      fakeRepo.emitProfile({'availability': 'offline'});
      await Future.delayed(Duration.zero);

      fakeRepo.delayAvailability = const Duration(milliseconds: 50);
      final call1 = controller.toggleAvailability();
      final call2 = controller.toggleAvailability();

      final results = await Future.wait([call1, call2]);
      expect(results[0], isTrue);
      expect(results[1], isFalse); // Rejected due to lock
    });

    test('13. acceptOrder prevents duplicate tap on the same order with lock', () async {
      fakeRepo.emitProfile({'availability': 'online'});
      await Future.delayed(Duration.zero);

      const order = DeliveryOrderEntity(
        id: 'ord_lock_test',
        source: DeliveryOrderSource.food,
        status: DeliveryOrderStatus.pending,
        sourceName: 'مطعم',
        dropoffName: 'زبون',
      );

      fakeRepo.delayAcceptance = const Duration(milliseconds: 50);
      final call1 = controller.acceptOrder(order: order);
      expect(controller.isOrderLocked('ord_lock_test'), isTrue);

      final call2 = controller.acceptOrder(order: order);

      final res1 = await call1;
      final res2 = await call2;

      expect(res1, OrderAcceptanceResult.success);
      expect(res2, OrderAcceptanceResult.alreadyLocked);
      expect(controller.isOrderLocked('ord_lock_test'), isFalse);
    });

    test('14. acceptOrder allows independent orders to be accepted concurrently', () async {
      fakeRepo.emitProfile({'availability': 'online'});
      await Future.delayed(Duration.zero);

      const orderA = DeliveryOrderEntity(
        id: 'ord_A',
        source: DeliveryOrderSource.food,
        status: DeliveryOrderStatus.pending,
        sourceName: 'مطعم A',
        dropoffName: 'زبون A',
      );
      const orderB = DeliveryOrderEntity(
        id: 'ord_B',
        source: DeliveryOrderSource.store,
        status: DeliveryOrderStatus.pending,
        sourceName: 'متجر B',
        dropoffName: 'زبون B',
      );

      fakeRepo.delayAcceptance = const Duration(milliseconds: 20);
      final callA = controller.acceptOrder(order: orderA);
      final callB = controller.acceptOrder(order: orderB);

      final results = await Future.wait([callA, callB]);
      expect(results[0], OrderAcceptanceResult.success);
      expect(results[1], OrderAcceptanceResult.success);
    });

    test('15. acceptOrder rejects when driver is offline or order is not available', () async {
      fakeRepo.emitProfile({'availability': 'offline'}); // Offline driver
      await Future.delayed(Duration.zero);

      const order = DeliveryOrderEntity(
        id: 'ord_ineligible',
        source: DeliveryOrderSource.food,
        status: DeliveryOrderStatus.pending,
        sourceName: 'مطعم',
        dropoffName: 'زبون',
      );

      final result = await controller.acceptOrder(order: order);
      expect(result, OrderAcceptanceResult.notEligible);
    });

    test('16. acceptOrder handles server rejection safely and releases lock', () async {
      fakeRepo.emitProfile({'availability': 'online'});
      await Future.delayed(Duration.zero);

      fakeRepo.shouldRejectNextAcceptance = true;
      const order = DeliveryOrderEntity(
        id: 'ord_rejected',
        source: DeliveryOrderSource.food,
        status: DeliveryOrderStatus.pending,
        sourceName: 'مطعم',
        dropoffName: 'زبون',
      );

      final result = await controller.acceptOrder(order: order);
      expect(result, OrderAcceptanceResult.serverRejected);
      expect(controller.isOrderLocked('ord_rejected'), isFalse);
    });

    test('17. acceptOrder handles repository exceptions gracefully and releases lock', () async {
      fakeRepo.emitProfile({'availability': 'online'});
      await Future.delayed(Duration.zero);

      fakeRepo.shouldThrowOnAcceptance = true;
      const order = DeliveryOrderEntity(
        id: 'ord_throw',
        source: DeliveryOrderSource.food,
        status: DeliveryOrderStatus.pending,
        sourceName: 'مطعم',
        dropoffName: 'زبون',
      );

      final result = await controller.acceptOrder(order: order);
      expect(result, OrderAcceptanceResult.error);
      expect(controller.errorMessage, isNotNull);
      expect(controller.isOrderLocked('ord_throw'), isFalse);
    });

    test('18. acceptOrder accepts Mersal with custom agreed price', () async {
      fakeRepo.emitProfile({'availability': 'online'});
      await Future.delayed(Duration.zero);

      const mersal = DeliveryOrderEntity(
        id: 'm_custom',
        source: DeliveryOrderSource.mersal,
        status: DeliveryOrderStatus.pending,
        sourceName: 'مرسال',
        dropoffName: 'زبون',
        isCustomPrice: true,
      );

      final result = await controller.acceptOrder(order: mersal, agreedPrice: '3500');
      expect(result, OrderAcceptanceResult.success);
    });
  });

  group('Delivery Dashboard Controller — Lifecycle, Generations & Alarm Hooks', () {
    test('19. Reinitialization increments generation and cancels previous streams', () {
      expect(controller.generation, 1);
      controller.initialize();
      expect(controller.generation, 2);
    });

    test('20. Stale callbacks after disposal return disposed status', () async {
      fakeRepo.emitProfile({'availability': 'online'});
      await Future.delayed(Duration.zero);

      controller.dispose();
      expect(controller.isDisposed, isTrue);

      const order = DeliveryOrderEntity(
        id: 'ord_post_dispose',
        source: DeliveryOrderSource.food,
        status: DeliveryOrderStatus.pending,
        sourceName: 'مطعم',
        dropoffName: 'زبون',
      );

      final res = await controller.acceptOrder(order: order);
      expect(res, OrderAcceptanceResult.disposed);
    });

    test('21. Disposal stops notifications and ignores subsequent stream events', () async {
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.dispose();
      expect(controller.isDisposed, isTrue);

      fakeRepo.emitProfile({'name': 'تعديل بعد الإلغاء'});
      await Future.delayed(Duration.zero);
      expect(notifyCount, 0);
    });

    test('22. onNewIncomingOrder callback triggers when a new pending order arrives after initial load', () async {
      DeliveryOrderEntity? incomingReceived;
      controller.onNewIncomingOrder = (ord) => incomingReceived = ord;

      // 1. Initial emission
      fakeRepo.emitAvailableFood([
        const DeliveryOrderEntity(
          id: 'ord_first',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.pending,
          sourceName: 'مطعم 1',
          dropoffName: 'موقع 1',
        ),
      ]);
      await Future.delayed(Duration.zero);
      expect(incomingReceived, isNull); // Initial load doesn't fire alarm

      // 2. Subsequent emission with a new order
      fakeRepo.emitAvailableFood([
        const DeliveryOrderEntity(
          id: 'ord_first',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.pending,
          sourceName: 'مطعم 1',
          dropoffName: 'موقع 1',
        ),
        const DeliveryOrderEntity(
          id: 'ord_new_alarm',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.pending,
          sourceName: 'مطعم 2',
          dropoffName: 'موقع 2',
        ),
      ]);
      await Future.delayed(Duration.zero);

      expect(incomingReceived, isNotNull);
      expect(incomingReceived?.id, 'ord_new_alarm');
    });

    test('23. onOrderNoLongerPending triggers when pending order is accepted or removed', () async {
      String? stoppedOrderId;
      controller.onOrderNoLongerPending = (id) => stoppedOrderId = id;

      // 1. Initial pending
      fakeRepo.emitAvailableFood([
        const DeliveryOrderEntity(
          id: 'ord_tracked',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.pending,
          sourceName: 'مطعم',
          dropoffName: 'موقع',
        ),
      ]);
      await Future.delayed(Duration.zero);

      // 2. Status changes to accepted
      fakeRepo.emitAvailableFood([
        const DeliveryOrderEntity(
          id: 'ord_tracked',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.accepted,
          sourceName: 'مطعم',
          dropoffName: 'موقع',
        ),
      ]);
      await Future.delayed(Duration.zero);

      expect(stoppedOrderId, 'ord_tracked');
    });

    test('24. Statistics calculations reflect updated active and completed tasks deterministically', () async {
      fakeRepo.emitHistoryFood([
        DeliveryOrderEntity(
          id: 'h_1',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.completed,
          sourceName: 'مطعم',
          dropoffName: 'موقع',
          deliveryFee: 3000.0,
          completedAt: DateTime.now(),
        ),
        DeliveryOrderEntity(
          id: 'h_2',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.completed,
          sourceName: 'مطعم',
          dropoffName: 'موقع',
          deliveryFee: 4000.0,
          completedAt: DateTime.now(),
        ),
      ]);
      await Future.delayed(Duration.zero);

      final stats = controller.statistics;
      expect(stats.completedOrders, 2);
      expect(stats.totalEarnings, 7000.0);
      expect(stats.todayCompletedCount, 2);
      expect(stats.questProgress.completedTrips, 2);
    });

    test('25. Unknown order source returns serverRejected on acceptance', () async {
      fakeRepo.emitProfile({'availability': 'online'});
      await Future.delayed(Duration.zero);

      const unknownOrder = DeliveryOrderEntity(
        id: 'u_1',
        source: DeliveryOrderSource.unknown,
        status: DeliveryOrderStatus.pending,
        sourceName: 'مجهول',
        dropoffName: 'مجهول',
      );
      final res = await controller.acceptOrder(order: unknownOrder);
      expect(res, OrderAcceptanceResult.serverRejected);
    });
  });
}

/// مستودع بيانات اختباري متجاوب مع التدفقات والتحكم بالزمن
class FakeDeliveryDashboardRepository extends DeliveryDashboardRepository { final _profileController = StreamController<Map<String, dynamic>>.broadcast(); final _availableMersalController = StreamController<List<DeliveryOrderEntity>>.broadcast(); final _availableFoodController = StreamController<List<DeliveryOrderEntity>>.broadcast(); final _availableStoreController = StreamController<List<DeliveryOrderEntity>>.broadcast(); final _activeMersalController = StreamController<List<DeliveryOrderEntity>>.broadcast(); final _activeFoodController = StreamController<List<DeliveryOrderEntity>>.broadcast(); final _activeStoreController = StreamController<List<DeliveryOrderEntity>>.broadcast(); final _historyMersalController = StreamController<List<DeliveryOrderEntity>>.broadcast(); final _historyFoodController = StreamController<List<DeliveryOrderEntity>>.broadcast(); final _historyStoreController = StreamController<List<DeliveryOrderEntity>>.broadcast(); Duration delayAvailability = Duration.zero; Duration delayAcceptance = Duration.zero; bool shouldRejectNextAcceptance = false; bool shouldThrowOnAcceptance = false; void emitProfile(Map<String, dynamic> data) => _profileController.add(data); void emitAvailableMersal(List<DeliveryOrderEntity> list) => _availableMersalController.add(list); void emitAvailableFood(List<DeliveryOrderEntity> list) => _availableFoodController.add(list); void emitAvailableStore(List<DeliveryOrderEntity> list) => _availableStoreController.add(list); void emitActiveMersal(List<DeliveryOrderEntity> list) => _activeMersalController.add(list); void emitActiveFood(List<DeliveryOrderEntity> list) => _activeFoodController.add(list); void emitActiveStore(List<DeliveryOrderEntity> list) => _activeStoreController.add(list); void emitHistoryMersal(List<DeliveryOrderEntity> list) => _historyMersalController.add(list); void emitHistoryFood(List<DeliveryOrderEntity> list) => _historyFoodController.add(list); void emitHistoryStore(List<DeliveryOrderEntity> list) => _historyStoreController.add(list);
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
  Future<void> setDriverAvailability({ required String driverId, required DriverAvailabilityState availabilityState, }) async { if (delayAvailability > Duration.zero) { await Future.delayed(delayAvailability); } }
  @override
  Future<bool> acceptMersalOrder({ required String requestId, required String driverId, required Map<String, dynamic> driverData, required String agreedPrice, }) async { if (shouldThrowOnAcceptance) throw Exception('Network Timeout');
    if (delayAcceptance > Duration.zero) await Future.delayed(delayAcceptance);
    return !shouldRejectNextAcceptance;
  }

  @override
  Future<bool> acceptFoodOrder({
    required String orderId,
    required String driverId,
    required Map<String, dynamic> driverData,
  }) async {
    if (shouldThrowOnAcceptance) throw Exception('Network Timeout');
    if (delayAcceptance > Duration.zero) await Future.delayed(delayAcceptance);
    return !shouldRejectNextAcceptance;
  }

  @override
  Future<bool> acceptStoreOrder({
    required String storeId,
    required String orderId,
    required String driverId,
    required Map<String, dynamic> driverData,
  }) async {
    if (shouldThrowOnAcceptance) throw Exception('Network Timeout');
    if (delayAcceptance > Duration.zero) await Future.delayed(delayAcceptance);
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
