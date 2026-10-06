// 🧪 اختبارات طبقة النطاق للوحة تحكم مندوب التوصيل (Delivery Dashboard Domain Unit Tests)
// Pure Dart — Zero Flutter / Firebase / Network Dependencies

import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/delivery/domain/entities/delivery_dashboard_models.dart';
import 'package:dalal_alqaim/features/delivery/domain/services/delivery_dashboard_calculator.dart';

void main() {
  group('Delivery Dashboard Domain — Order Source & Status Tests', () {
    test('1. DeliveryOrderSource parses valid and fallback sources accurately', () {
      expect(DeliveryOrderSource.fromString('food'), DeliveryOrderSource.food);
      expect(DeliveryOrderSource.fromString('food_order'), DeliveryOrderSource.food);
      expect(DeliveryOrderSource.fromString('restaurant'), DeliveryOrderSource.food);
      expect(DeliveryOrderSource.fromString('store'), DeliveryOrderSource.store);
      expect(DeliveryOrderSource.fromString('store_order'), DeliveryOrderSource.store);
      expect(DeliveryOrderSource.fromString('supermarket'), DeliveryOrderSource.store);
      expect(DeliveryOrderSource.fromString('mersal'), DeliveryOrderSource.mersal);
      expect(DeliveryOrderSource.fromString('custom'), DeliveryOrderSource.mersal);
      expect(DeliveryOrderSource.fromString('unknown_xyz'), DeliveryOrderSource.unknown);
      expect(DeliveryOrderSource.fromString(null), DeliveryOrderSource.unknown);
    });

    test('2. DeliveryOrderSource toDbString and displayNameArabic return expected strings', () {
      expect(DeliveryOrderSource.food.toDbString(), 'food');
      expect(DeliveryOrderSource.store.toDbString(), 'store_order');
      expect(DeliveryOrderSource.mersal.toDbString(), 'mersal');
      expect(DeliveryOrderSource.unknown.toDbString(), 'unknown');

      expect(DeliveryOrderSource.food.displayNameArabic, 'وجبة مطعم');
      expect(DeliveryOrderSource.store.displayNameArabic, 'مسواك متجر');
      expect(DeliveryOrderSource.mersal.displayNameArabic, 'طلب مرسال');
    });

    test('3. DeliveryOrderStatus parses statuses and identifies active/completed/terminal correctly', () {
      expect(DeliveryOrderStatus.fromString('pending'), DeliveryOrderStatus.pending);
      expect(DeliveryOrderStatus.fromString('ready_for_pickup'), DeliveryOrderStatus.ready);
      expect(DeliveryOrderStatus.fromString('accepted'), DeliveryOrderStatus.accepted);
      expect(DeliveryOrderStatus.fromString('delivering'), DeliveryOrderStatus.delivering);
      expect(DeliveryOrderStatus.fromString('completed'), DeliveryOrderStatus.completed);
      expect(DeliveryOrderStatus.fromString('cancelled'), DeliveryOrderStatus.cancelled);
      expect(DeliveryOrderStatus.fromString('invalid'), DeliveryOrderStatus.unknown);
      expect(DeliveryOrderStatus.fromString(null), DeliveryOrderStatus.unknown);

      expect(DeliveryOrderStatus.pending.isAvailableForPickup, isTrue);
      expect(DeliveryOrderStatus.ready.isAvailableForPickup, isTrue);
      expect(DeliveryOrderStatus.accepted.isActive, isTrue);
      expect(DeliveryOrderStatus.delivering.isActive, isTrue);
      expect(DeliveryOrderStatus.completed.isCompleted, isTrue);
      expect(DeliveryOrderStatus.cancelled.isCancelled, isTrue);
      expect(DeliveryOrderStatus.completed.isTerminal, isTrue);
      expect(DeliveryOrderStatus.cancelled.isTerminal, isTrue);
      expect(DeliveryOrderStatus.pending.isTerminal, isFalse);
    });

    test('4. DriverAvailabilityState parses and handles work state correctly', () {
      expect(DriverAvailabilityState.fromString('online'), DriverAvailabilityState.online);
      expect(DriverAvailabilityState.fromString('offline'), DriverAvailabilityState.offline);
      expect(DriverAvailabilityState.fromString('on_trip'), DriverAvailabilityState.onTrip);
      expect(DriverAvailabilityState.fromString('busy'), DriverAvailabilityState.onTrip);
      expect(DriverAvailabilityState.fromString(null), DriverAvailabilityState.unknown);

      expect(DriverAvailabilityState.online.isWorking, isTrue);
      expect(DriverAvailabilityState.onTrip.isWorking, isTrue);
      expect(DriverAvailabilityState.offline.isWorking, isFalse);
    });
  });

  group('Delivery Dashboard Domain — Earnings Calculations', () {
    test('5. calculateOrderEarnings returns delivery fee and protects against negative/NaN', () {
      const validOrder = DeliveryOrderEntity(
        id: 'ord_1',
        source: DeliveryOrderSource.food,
        status: DeliveryOrderStatus.completed,
        sourceName: 'مطعم بغداد',
        dropoffName: 'شارع الزهور',
        deliveryFee: 3500.0,
      );
      expect(DeliveryDashboardCalculator.calculateOrderEarnings(validOrder), 3500.0);

      const invalidOrder = DeliveryOrderEntity(
        id: 'ord_2',
        source: DeliveryOrderSource.mersal,
        status: DeliveryOrderStatus.completed,
        sourceName: 'مرسال',
        dropoffName: 'السوق',
        deliveryFee: -1000.0,
      );
      expect(DeliveryDashboardCalculator.calculateOrderEarnings(invalidOrder), 0.0);
    });

    test('6. calculateTotalEarnings sums delivery fee for completed orders only', () {
      final orders = [
        const DeliveryOrderEntity(
          id: 'ord_1',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.completed,
          sourceName: 'مطعم A',
          dropoffName: 'موقع 1',
          deliveryFee: 3000.0,
        ),
        const DeliveryOrderEntity(
          id: 'ord_2',
          source: DeliveryOrderSource.store,
          status: DeliveryOrderStatus.completed,
          sourceName: 'متجر B',
          dropoffName: 'موقع 2',
          deliveryFee: 2500.0,
        ),
        const DeliveryOrderEntity(
          id: 'ord_3',
          source: DeliveryOrderSource.mersal,
          status: DeliveryOrderStatus.cancelled,
          sourceName: 'مرسال C',
          dropoffName: 'موقع 3',
          deliveryFee: 4000.0,
        ),
        const DeliveryOrderEntity(
          id: 'ord_4',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.delivering,
          sourceName: 'مطعم D',
          dropoffName: 'موقع 4',
          deliveryFee: 3000.0,
        ),
      ];

      final total = DeliveryDashboardCalculator.calculateTotalEarnings(orders);
      expect(total, 5500.0); // 3000 + 2500
    });

    test('7. calculateTotalEarnings returns 0.0 for empty list or all-active list', () {
      expect(DeliveryDashboardCalculator.calculateTotalEarnings([]), 0.0);

      final activeOnly = [
        const DeliveryOrderEntity(
          id: 'ord_1',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.delivering,
          sourceName: 'مطعم A',
          dropoffName: 'موقع 1',
          deliveryFee: 3000.0,
        ),
      ];
      expect(DeliveryDashboardCalculator.calculateTotalEarnings(activeOnly), 0.0);
    });
  });

  group('Delivery Dashboard Domain — Daily Earnings & Date Filtering', () {
    final refDate = DateTime(2026, 8, 27, 14, 30);

    test('8. calculateTodayEarnings filters orders matching referenceDate day', () {
      final orders = [
        DeliveryOrderEntity(
          id: 'ord_today_1',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.completed,
          sourceName: 'مطعم A',
          dropoffName: 'موقع 1',
          deliveryFee: 3000.0,
          completedAt: DateTime(2026, 8, 27, 10, 0),
        ),
        DeliveryOrderEntity(
          id: 'ord_today_2',
          source: DeliveryOrderSource.store,
          status: DeliveryOrderStatus.completed,
          sourceName: 'متجر B',
          dropoffName: 'موقع 2',
          deliveryFee: 2000.0,
          completedAt: DateTime(2026, 8, 27, 23, 59),
        ),
        DeliveryOrderEntity(
          id: 'ord_yesterday',
          source: DeliveryOrderSource.mersal,
          status: DeliveryOrderStatus.completed,
          sourceName: 'مرسال C',
          dropoffName: 'موقع 3',
          deliveryFee: 5000.0,
          completedAt: DateTime(2026, 8, 26, 18, 0),
        ),
        DeliveryOrderEntity(
          id: 'ord_tomorrow',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.completed,
          sourceName: 'مطعم D',
          dropoffName: 'موقع 4',
          deliveryFee: 3000.0,
          completedAt: DateTime(2026, 8, 28, 8, 0),
        ),
      ];

      final todayEarnings = DeliveryDashboardCalculator.calculateTodayEarnings(
        orders: orders,
        referenceDate: refDate,
      );
      expect(todayEarnings, 5000.0); // 3000 + 2000
    });

    test('9. calculateTodayCompletedCount counts only today completed orders', () {
      final orders = [
        DeliveryOrderEntity(
          id: 'ord_today_1',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.completed,
          sourceName: 'مطعم A',
          dropoffName: 'موقع 1',
          completedAt: DateTime(2026, 8, 27, 11, 0),
        ),
        DeliveryOrderEntity(
          id: 'ord_today_2',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.cancelled, // Cancelled not counted
          sourceName: 'مطعم B',
          dropoffName: 'موقع 2',
          completedAt: DateTime(2026, 8, 27, 12, 0),
        ),
        DeliveryOrderEntity(
          id: 'ord_other_day',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.completed,
          sourceName: 'مطعم C',
          dropoffName: 'موقع 3',
          completedAt: DateTime(2026, 8, 25, 10, 0),
        ),
      ];

      final count = DeliveryDashboardCalculator.calculateTodayCompletedCount(
        orders: orders,
        referenceDate: refDate,
      );
      expect(count, 1);
    });

    test('10. isSameDay handles midnight boundaries, nulls, and different months accurately', () {
      expect(DeliveryDashboardCalculator.isSameDay(DateTime(2026, 8, 27, 0, 0), DateTime(2026, 8, 27, 23, 59)), isTrue);
      expect(DeliveryDashboardCalculator.isSameDay(DateTime(2026, 8, 27), DateTime(2026, 8, 28)), isFalse);
      expect(DeliveryDashboardCalculator.isSameDay(DateTime(2026, 8, 27), DateTime(2026, 9, 27)), isFalse);
      expect(DeliveryDashboardCalculator.isSameDay(null, DateTime(2026, 8, 27)), isFalse);
      expect(DeliveryDashboardCalculator.isSameDay(DateTime(2026, 8, 27), null), isFalse);
    });
  });

  group('Delivery Dashboard Domain — Quest & Incentives Progress', () {
    test('11. calculateQuestProgress computes partial progress and percentages correctly', () {
      final quest = DeliveryDashboardCalculator.calculateQuestProgress(
        completedCount: 4,
        targetTrips: 8,
        bonusAmount: 5000.0,
      );

      expect(quest.targetTrips, 8);
      expect(quest.completedTrips, 4);
      expect(quest.progress, 0.5);
      expect(quest.progressPercentage, 50);
      expect(quest.bonusAmount, 5000.0);
      expect(quest.isCompleted, isFalse);
      expect(quest.remainingTrips, 4);
    });

    test('12. calculateQuestProgress handles exact completion target', () {
      final quest = DeliveryDashboardCalculator.calculateQuestProgress(
        completedCount: 8,
        targetTrips: 8,
        bonusAmount: 5000.0,
      );

      expect(quest.progress, 1.0);
      expect(quest.progressPercentage, 100);
      expect(quest.isCompleted, isTrue);
      expect(quest.remainingTrips, 0);
    });

    test('13. calculateQuestProgress clamps progress to 1.0 when target is exceeded', () {
      final quest = DeliveryDashboardCalculator.calculateQuestProgress(
        completedCount: 12,
        targetTrips: 8,
        bonusAmount: 5000.0,
      );

      expect(quest.completedTrips, 12);
      expect(quest.progress, 1.0);
      expect(quest.progressPercentage, 100);
      expect(quest.isCompleted, isTrue);
      expect(quest.remainingTrips, 0);
    });

    test('14. calculateQuestProgress protects against zero target, negative completed, and negative bonus', () {
      final quest = DeliveryDashboardCalculator.calculateQuestProgress(
        completedCount: -3,
        targetTrips: 0,
        bonusAmount: -100.0,
      );

      expect(quest.targetTrips, 8); // fallback default
      expect(quest.completedTrips, 0);
      expect(quest.progress, 0.0);
      expect(quest.progressPercentage, 0);
      expect(quest.bonusAmount, 5000.0); // fallback default
      expect(quest.isCompleted, isFalse);
      expect(quest.remainingTrips, 8);
    });
  });

  group('Delivery Dashboard Domain — Completion Rate & Statistics Aggregation', () {
    test('15. calculateCompletionRate returns clamped ratio and handles zero total', () {
      expect(DeliveryDashboardCalculator.calculateCompletionRate(completed: 0, total: 0), 0.0);
      expect(DeliveryDashboardCalculator.calculateCompletionRate(completed: 5, total: 10), 0.5);
      expect(DeliveryDashboardCalculator.calculateCompletionRate(completed: 10, total: 10), 1.0);
      expect(DeliveryDashboardCalculator.calculateCompletionRate(completed: 15, total: 10), 1.0);
      expect(DeliveryDashboardCalculator.calculateCompletionRate(completed: -2, total: 10), 0.0);
    });

    test('16. calculateDashboardStatistics aggregates mixed orders accurately', () {
      final refDate = DateTime(2026, 8, 27, 12, 0);
      final orders = [
        DeliveryOrderEntity(
          id: 'ord_1',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.completed,
          sourceName: 'مطعم A',
          dropoffName: 'موقع 1',
          deliveryFee: 3000.0,
          completedAt: DateTime(2026, 8, 27, 9, 0),
        ),
        DeliveryOrderEntity(
          id: 'ord_2',
          source: DeliveryOrderSource.store,
          status: DeliveryOrderStatus.completed,
          sourceName: 'متجر B',
          dropoffName: 'موقع 2',
          deliveryFee: 2500.0,
          completedAt: DateTime(2026, 8, 26, 15, 0), // yesterday
        ),
        const DeliveryOrderEntity(
          id: 'ord_3',
          source: DeliveryOrderSource.mersal,
          status: DeliveryOrderStatus.delivering,
          sourceName: 'مرسال C',
          dropoffName: 'موقع 3',
          deliveryFee: 4000.0,
        ),
        const DeliveryOrderEntity(
          id: 'ord_4',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.pending,
          sourceName: 'مطعم D',
          dropoffName: 'موقع 4',
          deliveryFee: 3000.0,
        ),
        const DeliveryOrderEntity(
          id: 'ord_5',
          source: DeliveryOrderSource.store,
          status: DeliveryOrderStatus.cancelled,
          sourceName: 'متجر E',
          dropoffName: 'موقع 5',
          deliveryFee: 2000.0,
        ),
      ];

      final stats = DeliveryDashboardCalculator.calculateDashboardStatistics(
        orders: orders,
        referenceDate: refDate,
        appDebt: 1500.0,
      );

      expect(stats.totalOrders, 5);
      expect(stats.completedOrders, 2);
      expect(stats.activeOrders, 1);
      expect(stats.pendingOrders, 1);
      expect(stats.cancelledOrders, 1);
      expect(stats.totalEarnings, 5500.0);
      expect(stats.todayEarnings, 3000.0);
      expect(stats.todayCompletedCount, 1);
      expect(stats.completionRate, 0.4); // 2/5
      expect(stats.appDebt, 1500.0);
      expect(stats.questProgress.completedTrips, 1);
      expect(stats.questProgress.remainingTrips, 7);
    });

    test('17. calculateDashboardStatistics handles empty order list safely', () {
      final stats = DeliveryDashboardCalculator.calculateDashboardStatistics(
        orders: [],
        referenceDate: DateTime.now(),
        appDebt: 0.0,
      );

      expect(stats.totalOrders, 0);
      expect(stats.completedOrders, 0);
      expect(stats.activeOrders, 0);
      expect(stats.pendingOrders, 0);
      expect(stats.cancelledOrders, 0);
      expect(stats.totalEarnings, 0.0);
      expect(stats.todayEarnings, 0.0);
      expect(stats.completionRate, 0.0);
      expect(stats.questProgress.isCompleted, isFalse);
    });
  });

  group('Delivery Dashboard Domain — Order Filtering & Search Tests', () {
    final sampleOrders = [
      const DeliveryOrderEntity(
        id: 'ord_food_1',
        source: DeliveryOrderSource.food,
        status: DeliveryOrderStatus.pending,
        sourceName: 'برجر تايم',
        dropoffName: 'حي الشهداء',
        customerName: 'علي كمال',
      ),
      const DeliveryOrderEntity(
        id: 'ord_store_2',
        source: DeliveryOrderSource.store,
        status: DeliveryOrderStatus.pending,
        sourceName: 'سوبرماركت النور',
        dropoffName: 'شارع فلسطين',
        customerName: 'فاطمة جواد',
      ),
      const DeliveryOrderEntity(
        id: 'ord_mersal_3',
        source: DeliveryOrderSource.mersal,
        status: DeliveryOrderStatus.pending,
        sourceName: 'صيدلية الأمل',
        dropoffName: 'حي المعلمين',
        customerName: 'محمد سعيد',
      ),
    ];

    test('18. filterOrders filters by DeliveryFilterType.food', () {
      final filtered = DeliveryDashboardCalculator.filterOrders(
        orders: sampleOrders,
        filter: DeliveryFilterType.food,
      );
      expect(filtered.length, 1);
      expect(filtered.first.source, DeliveryOrderSource.food);
      expect(filtered.first.sourceName, 'برجر تايم');
    });

    test('19. filterOrders filters by DeliveryFilterType.store', () {
      final filtered = DeliveryDashboardCalculator.filterOrders(
        orders: sampleOrders,
        filter: DeliveryFilterType.store,
      );
      expect(filtered.length, 1);
      expect(filtered.first.source, DeliveryOrderSource.store);
      expect(filtered.first.sourceName, 'سوبرماركت النور');
    });

    test('20. filterOrders filters by DeliveryFilterType.mersal', () {
      final filtered = DeliveryDashboardCalculator.filterOrders(
        orders: sampleOrders,
        filter: DeliveryFilterType.mersal,
      );
      expect(filtered.length, 1);
      expect(filtered.first.source, DeliveryOrderSource.mersal);
      expect(filtered.first.sourceName, 'صيدلية الأمل');
    });

    test('21. filterOrders with search query searches across source, dropoff, customer, and ID', () {
      final searchByDropoff = DeliveryDashboardCalculator.filterOrders(
        orders: sampleOrders,
        filter: DeliveryFilterType.all,
        searchQuery: 'فلسطين',
      );
      expect(searchByDropoff.length, 1);
      expect(searchByDropoff.first.id, 'ord_store_2');

      final searchByCustomer = DeliveryDashboardCalculator.filterOrders(
        orders: sampleOrders,
        filter: DeliveryFilterType.all,
        searchQuery: 'علي',
      );
      expect(searchByCustomer.length, 1);
      expect(searchByCustomer.first.id, 'ord_food_1');

      final searchNoMatch = DeliveryDashboardCalculator.filterOrders(
        orders: sampleOrders,
        filter: DeliveryFilterType.all,
        searchQuery: 'غير موجود',
      );
      expect(searchNoMatch.isEmpty, isTrue);
    });
  });

  group('Delivery Dashboard Domain — Availability & Order Acceptance Rules', () {
    const pendingOrder = DeliveryOrderEntity(
      id: 'ord_1',
      source: DeliveryOrderSource.food,
      status: DeliveryOrderStatus.pending,
      sourceName: 'مطعم',
      dropoffName: 'زبون',
    );

    const completedOrder = DeliveryOrderEntity(
      id: 'ord_2',
      source: DeliveryOrderSource.food,
      status: DeliveryOrderStatus.completed,
      sourceName: 'مطعم',
      dropoffName: 'زبون',
    );

    test('22. canAcceptOrder permits acceptance only when driver is working and order is pending/ready', () {
      // Driver Online -> Can accept pending order
      expect(
        DeliveryDashboardCalculator.canAcceptOrder(
          availability: DriverAvailabilityState.online,
          order: pendingOrder,
        ),
        isTrue,
      );

      // Driver Offline -> Cannot accept
      expect(
        DeliveryDashboardCalculator.canAcceptOrder(
          availability: DriverAvailabilityState.offline,
          order: pendingOrder,
        ),
        isFalse,
      );

      // Order Already Completed -> Cannot accept
      expect(
        DeliveryDashboardCalculator.canAcceptOrder(
          availability: DriverAvailabilityState.online,
          order: completedOrder,
        ),
        isFalse,
      );
    });

    test('23. canAcceptOrder respects active task limit when multiple tasks disallowed', () {
      expect(
        DeliveryDashboardCalculator.canAcceptOrder(
          availability: DriverAvailabilityState.onTrip,
          order: pendingOrder,
          allowMultipleActiveTasks: false,
          currentActiveTasksCount: 1,
        ),
        isFalse,
      );

      expect(
        DeliveryDashboardCalculator.canAcceptOrder(
          availability: DriverAvailabilityState.onTrip,
          order: pendingOrder,
          allowMultipleActiveTasks: true,
          currentActiveTasksCount: 1,
        ),
        isTrue,
      );
    });

    test('24. getNextAvailabilityState toggles online to offline and vice-versa', () {
      expect(
        DeliveryDashboardCalculator.getNextAvailabilityState(DriverAvailabilityState.online),
        DriverAvailabilityState.offline,
      );
      expect(
        DeliveryDashboardCalculator.getNextAvailabilityState(DriverAvailabilityState.onTrip),
        DriverAvailabilityState.offline,
      );
      expect(
        DeliveryDashboardCalculator.getNextAvailabilityState(DriverAvailabilityState.offline),
        DriverAvailabilityState.online,
      );
      expect(
        DeliveryDashboardCalculator.getNextAvailabilityState(DriverAvailabilityState.unknown),
        DriverAvailabilityState.online,
      );
    });
  });

  group('Delivery Dashboard Domain — Invariants & Edge Cases', () {
    test('25. Pure determinism: identical inputs generate identical statistics and hash code', () {
      final refDate = DateTime(2026, 8, 27);
      final orders = [
        const DeliveryOrderEntity(
          id: 'ord_1',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.completed,
          sourceName: 'مطعم',
          dropoffName: 'موقع',
          deliveryFee: 3000.0,
        ),
      ];

      final statsA = DeliveryDashboardCalculator.calculateDashboardStatistics(
        orders: orders,
        referenceDate: refDate,
      );
      final statsB = DeliveryDashboardCalculator.calculateDashboardStatistics(
        orders: orders,
        referenceDate: refDate,
      );

      expect(statsA, equals(statsB));
      expect(statsA.hashCode, equals(statsB.hashCode));
    });

    test('26. DeliveryOrderEntity copyWith updates specified fields immutably', () {
      const original = DeliveryOrderEntity(
        id: 'ord_1',
        source: DeliveryOrderSource.food,
        status: DeliveryOrderStatus.pending,
        sourceName: 'مطعم',
        dropoffName: 'موقع',
      );

      final updated = original.copyWith(
        status: DeliveryOrderStatus.accepted,
        driverId: 'drv_99',
      );

      expect(updated.id, 'ord_1');
      expect(updated.status, DeliveryOrderStatus.accepted);
      expect(updated.driverId, 'drv_99');
      expect(original.status, DeliveryOrderStatus.pending); // original unchanged
    });

    test('27. calculateDashboardStatistics protects against negative appDebt', () {
      final stats = DeliveryDashboardCalculator.calculateDashboardStatistics(
        orders: [],
        referenceDate: DateTime.now(),
        appDebt: -5000.0,
      );
      expect(stats.appDebt, 0.0);
    });

    test('28. calculateOrderEarnings handles NaN and infinite values safely', () {
      const nanOrder = DeliveryOrderEntity(
        id: 'ord_nan',
        source: DeliveryOrderSource.food,
        status: DeliveryOrderStatus.completed,
        sourceName: 'مطعم',
        dropoffName: 'موقع',
        deliveryFee: double.nan,
      );
      expect(DeliveryDashboardCalculator.calculateOrderEarnings(nanOrder), 0.0);

      const infOrder = DeliveryOrderEntity(
        id: 'ord_inf',
        source: DeliveryOrderSource.food,
        status: DeliveryOrderStatus.completed,
        sourceName: 'مطعم',
        dropoffName: 'موقع',
        deliveryFee: double.infinity,
      );
      expect(DeliveryDashboardCalculator.calculateOrderEarnings(infOrder), 0.0);
    });

    test('29. DeliveryFilterType parses from string correctly with fallback to all', () {
      expect(DeliveryFilterType.fromString('food'), DeliveryFilterType.food);
      expect(DeliveryFilterType.fromString('store'), DeliveryFilterType.store);
      expect(DeliveryFilterType.fromString('mersal'), DeliveryFilterType.mersal);
      expect(DeliveryFilterType.fromString('all'), DeliveryFilterType.all);
      expect(DeliveryFilterType.fromString('other'), DeliveryFilterType.all);
      expect(DeliveryFilterType.fromString(null), DeliveryFilterType.all);
    });

    test('30. filterOrders returns unmodifiable list preserving original order', () {
      final orders = [
        const DeliveryOrderEntity(id: '1', source: DeliveryOrderSource.food, status: DeliveryOrderStatus.pending, sourceName: 'A', dropoffName: 'B'),
        const DeliveryOrderEntity(id: '2', source: DeliveryOrderSource.food, status: DeliveryOrderStatus.pending, sourceName: 'C', dropoffName: 'D'),
      ];
      final filtered = DeliveryDashboardCalculator.filterOrders(orders: orders, filter: DeliveryFilterType.all);
      expect(filtered.length, 2);
      expect(filtered[0].id, '1');
      expect(filtered[1].id, '2');
      expect(() => (filtered as dynamic).add(orders[0]), throwsUnsupportedError);
    });
  });
}
