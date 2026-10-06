// 🧪 اختبارات ودجات العرض للوحة تحكم المندوب (Delivery Dashboard Presentation Widgets Tests)
// Presentation Layer UI & Widget Tests — Pure Flutter Test (No Firebase / Network)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/delivery/domain/entities/delivery_dashboard_models.dart';
import 'package:dalal_alqaim/features/delivery/presentation/widgets/delivery_dashboard_header.dart';
import 'package:dalal_alqaim/features/delivery/presentation/widgets/delivery_daily_quest_banner.dart';
import 'package:dalal_alqaim/features/delivery/presentation/widgets/delivery_order_filter_chips.dart';
import 'package:dalal_alqaim/features/delivery/presentation/widgets/delivery_unified_order_card.dart';
import 'package:dalal_alqaim/features/delivery/presentation/widgets/delivery_available_orders_radar.dart';
import 'package:dalal_alqaim/features/delivery/presentation/widgets/delivery_active_tasks_view.dart';
import 'package:dalal_alqaim/features/delivery/presentation/widgets/delivery_history_view.dart';
import 'package:dalal_alqaim/features/delivery/presentation/widgets/delivery_performance_view.dart';
import 'package:dalal_alqaim/features/delivery/presentation/widgets/delivery_profile_settings_view.dart';

void main() {
  Widget buildTestableWidget(Widget child, {Size surfaceSize = const Size(800, 1000)}) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQueryData(size: surfaceSize),
          child: Scaffold(
            body: child,
          ),
        ),
      ),
    );
  }

  Widget buildTestableSliver(Widget sliver) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: CustomScrollView(
            slivers: [sliver],
          ),
        ),
      ),
    );
  }

  group('1. DeliveryDashboardHeader Tests', () {
    testWidgets('1. Header renders driver name, online state and metrics', (tester) async {
      await tester.pumpWidget(buildTestableSliver(
        DeliveryDashboardHeader(
          driverName: 'علي البطل',
          isOnline: true,
          todayEarnings: 15000,
          todayCompletedCount: 5,
          appDebt: 2000,
          onToggleOnline: () {},
          onOpenLiveMap: () {},
        ),
      ));

      expect(find.textContaining('علي البطل'), findsOneWidget);
      expect(find.textContaining('أنت متصل'), findsOneWidget);
      expect(find.textContaining('15,000'), findsOneWidget);
      expect(find.textContaining('5 طلب'), findsOneWidget);
      expect(find.textContaining('2,000'), findsOneWidget);
    });

    testWidgets('2. Header renders offline status and handles onToggleOnline tap', (tester) async {
      bool toggled = false;
      await tester.pumpWidget(buildTestableSliver(
        DeliveryDashboardHeader(
          driverName: 'علي',
          isOnline: false,
          todayEarnings: 0,
          todayCompletedCount: 0,
          appDebt: 0,
          onToggleOnline: () => toggled = true,
          onOpenLiveMap: () {},
        ),
      ));

      expect(find.textContaining('أوفلاين'), findsOneWidget);
      await tester.tap(find.textContaining('أوفلاين'));
      expect(toggled, isTrue);
    });

    testWidgets('3. Header handles onOpenLiveMap tap', (tester) async {
      bool openedMap = false;
      await tester.pumpWidget(buildTestableSliver(
        DeliveryDashboardHeader(
          driverName: 'علي',
          isOnline: true,
          todayEarnings: 0,
          todayCompletedCount: 0,
          appDebt: 0,
          onToggleOnline: () {},
          onOpenLiveMap: () => openedMap = true,
        ),
      ));

      await tester.tap(find.byIcon(Icons.map_rounded));
      expect(openedMap, isTrue);
    });

    testWidgets('4. Header displays loading indicator when isToggling is true', (tester) async {
      await tester.pumpWidget(buildTestableSliver(
        DeliveryDashboardHeader(
          driverName: 'علي',
          isOnline: true,
          isToggling: true,
          todayEarnings: 0,
          todayCompletedCount: 0,
          appDebt: 0,
          onToggleOnline: () {},
          onOpenLiveMap: () {},
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('2. DeliveryDailyQuestBanner Tests', () {
    testWidgets('5. Quest banner displays progress and bonus amount', (tester) async {
      const progress = DeliveryQuestProgress(
        targetTrips: 8,
        completedTrips: 4,
        progress: 0.5,
        progressPercentage: 50,
        bonusAmount: 5000,
        isCompleted: false,
        remainingTrips: 4,
      );

      await tester.pumpWidget(buildTestableWidget(
        const DeliveryDailyQuestBanner(questProgress: progress),
      ));

      expect(find.textContaining('مكافأة هدف اليوم'), findsOneWidget);
      expect(find.textContaining('5,000'), findsOneWidget);
      expect(find.textContaining('4 من أصل 8'), findsOneWidget);
      expect(find.textContaining('50%'), findsOneWidget);
    });

    testWidgets('6. Quest banner renders 100% completion state', (tester) async {
      const progress = DeliveryQuestProgress(
        targetTrips: 8,
        completedTrips: 8,
        progress: 1.0,
        progressPercentage: 100,
        bonusAmount: 5000,
        isCompleted: true,
        remainingTrips: 0,
      );

      await tester.pumpWidget(buildTestableWidget(
        const DeliveryDailyQuestBanner(questProgress: progress),
      ));

      expect(find.textContaining('8 من أصل 8'), findsOneWidget);
      expect(find.textContaining('100%'), findsOneWidget);
    });
  });

  group('3. DeliveryOrderFilterChips Tests', () {
    testWidgets('7. Filter chips render all categories and emit onFilterChanged', (tester) async {
      DeliveryFilterType? changedType;

      await tester.pumpWidget(buildTestableWidget(
        DeliveryOrderFilterChips(
          selectedFilter: DeliveryFilterType.all,
          onFilterChanged: (f) => changedType = f,
        ),
      ));

      expect(find.text('كل الطلبات'), findsOneWidget);
      expect(find.text('مرسال وشراء'), findsOneWidget);
      expect(find.text('وجبات مطاعم'), findsOneWidget);
      expect(find.text('مسواك متاجر'), findsOneWidget);

      await tester.tap(find.text('وجبات مطاعم'));
      expect(changedType, DeliveryFilterType.food);

      await tester.tap(find.text('مسواك متاجر'));
      expect(changedType, DeliveryFilterType.store);
    });

    testWidgets('8. Filter chips handles Mersal filter click', (tester) async {
      DeliveryFilterType? changedType;

      await tester.pumpWidget(buildTestableWidget(
        DeliveryOrderFilterChips(
          selectedFilter: DeliveryFilterType.all,
          onFilterChanged: (f) => changedType = f,
        ),
      ));

      await tester.tap(find.text('مرسال وشراء'));
      expect(changedType, DeliveryFilterType.mersal);
    });
  });

  group('4. DeliveryUnifiedOrderCard Tests', () {
    testWidgets('9. Unified card renders food order details and triggers callbacks', (tester) async {
      bool accepted = false;
      bool detailsOpened = false;

      const order = DeliveryOrderEntity(
        id: 'ord_f_1',
        source: DeliveryOrderSource.food,
        status: DeliveryOrderStatus.pending,
        sourceName: 'برجر كينج',
        dropoffName: 'شارع الزهور',
        deliveryFee: 3000,
      );

      await tester.pumpWidget(buildTestableWidget(
        DeliveryUnifiedOrderCard(
          order: order,
          onAccept: () => accepted = true,
          onDetails: () => detailsOpened = true,
        ),
      ));

      expect(find.textContaining('وجبة مطعم جاهزة'), findsOneWidget);
      expect(find.textContaining('برجر كينج'), findsOneWidget);
      expect(find.textContaining('شارع الزهور'), findsOneWidget);
      expect(find.textContaining('3,000'), findsOneWidget);

      await tester.tap(find.textContaining('قبول التوصيل'));
      expect(accepted, isTrue);

      await tester.tap(find.text('التفاصيل'));
      expect(detailsOpened, isTrue);
    });

    testWidgets('10. Unified card renders custom price badge for Mersal requests', (tester) async {
      const order = DeliveryOrderEntity(
        id: 'ord_m_1',
        source: DeliveryOrderSource.mersal,
        status: DeliveryOrderStatus.pending,
        sourceName: 'صيدلية النور',
        dropoffName: 'حي التأميم',
        isCustomPrice: true,
      );

      await tester.pumpWidget(buildTestableWidget(
        DeliveryUnifiedOrderCard(
          order: order,
          onAccept: () {},
          onDetails: () {},
        ),
      ));

      expect(find.textContaining('أنت تحدد السعر'), findsOneWidget);
    });

    testWidgets('11. Unified card displays loading spinner during acceptance', (tester) async {
      const order = DeliveryOrderEntity(
        id: 'ord_f_2',
        source: DeliveryOrderSource.food,
        status: DeliveryOrderStatus.pending,
        sourceName: 'مطعم',
        dropoffName: 'زبون',
      );

      await tester.pumpWidget(buildTestableWidget(
        DeliveryUnifiedOrderCard(
          order: order,
          isAccepting: true,
          onAccept: () {},
          onDetails: () {},
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('12. Unified card handles store order source', (tester) async {
      const order = DeliveryOrderEntity(
        id: 'ord_s_1',
        source: DeliveryOrderSource.store,
        status: DeliveryOrderStatus.pending,
        sourceName: 'سوبرماركت المدينة',
        dropoffName: 'شارع 14 رمضان',
        deliveryFee: 3500,
      );

      await tester.pumpWidget(buildTestableWidget(
        DeliveryUnifiedOrderCard(
          order: order,
          onAccept: () {},
          onDetails: () {},
        ),
      ));

      expect(find.textContaining('مسواك متجر وسوق'), findsOneWidget);
      expect(find.textContaining('سوبرماركت المدينة'), findsOneWidget);
    });

    testWidgets('13. Unified card handles long text without overflow', (tester) async {
      const order = DeliveryOrderEntity(
        id: 'ord_long',
        source: DeliveryOrderSource.food,
        status: DeliveryOrderStatus.pending,
        sourceName: 'مطعم ومشويات الفصول الأربعة للمأكولات الغربية والشرقية في مدينة القائم',
        dropoffName: 'حي الشهداء بالقرب من جامع النور الكبير الفرع الثالث المقابل للمدرسة الابتدائية',
        deliveryFee: 5000,
      );

      await tester.pumpWidget(buildTestableWidget(
        DeliveryUnifiedOrderCard(
          order: order,
          onAccept: () {},
          onDetails: () {},
        ),
      ));

      expect(find.textContaining('الفصول الأربعة'), findsOneWidget);
    });
  });

  group('5. DeliveryAvailableOrdersRadar Tests', () {
    testWidgets('14. Radar renders offline state when isOnline is false', (tester) async {
      bool onlineToggled = false;
      await tester.pumpWidget(buildTestableWidget(
        DeliveryAvailableOrdersRadar(
          orders: const [],
          isOnline: false,
          onAcceptOrder: (_) {},
          onOrderDetails: (_) {},
          onToggleOnline: () => onlineToggled = true,
        ),
      ));

      expect(find.textContaining('أنت في وضع عدم الاتصال'), findsOneWidget);
      await tester.tap(find.textContaining('الاتصال بالشبكة الآن'));
      expect(onlineToggled, isTrue);
    });

    testWidgets('15. Radar renders empty state when online with no orders', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        DeliveryAvailableOrdersRadar(
          orders: const [],
          isOnline: true,
          onAcceptOrder: (_) {},
          onOrderDetails: (_) {},
          onToggleOnline: () {},
        ),
      ));

      expect(find.textContaining('الرادار نشط وجاري البحث'), findsOneWidget);
    });

    testWidgets('16. Radar renders list of available order cards', (tester) async {
      const orders = [
        DeliveryOrderEntity(
          id: 'o_1',
          source: DeliveryOrderSource.store,
          status: DeliveryOrderStatus.pending,
          sourceName: 'سوبرماركت البركة',
          dropoffName: 'حي النصر',
          deliveryFee: 2500,
        ),
      ];

      await tester.pumpWidget(buildTestableWidget(
        DeliveryAvailableOrdersRadar(
          orders: orders,
          isOnline: true,
          onAcceptOrder: (_) {},
          onOrderDetails: (_) {},
          onToggleOnline: () {},
        ),
      ));

      expect(find.textContaining('سوبرماركت البركة'), findsOneWidget);
    });
  });

  group('6. DeliveryActiveTasksView Tests', () {
    testWidgets('17. Active tasks view renders active tasks and callbacks', (tester) async {
      DeliveryOrderEntity? opened;
      const tasks = [
        DeliveryOrderEntity(
          id: 'act_1',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.delivering,
          sourceName: 'شاورما على الفحم',
          dropoffName: 'شارع 20',
          deliveryFee: 3500,
        ),
      ];

      await tester.pumpWidget(buildTestableWidget(
        DeliveryActiveTasksView(
          activeTasks: tasks,
          onOpenTaskDetails: (t) => opened = t,
        ),
      ));

      expect(find.textContaining('شاورما على الفحم'), findsOneWidget);
      await tester.tap(find.textContaining('متابعة وإكمال التوصيل'));
      expect(opened?.id, 'act_1');
    });

    testWidgets('18. Active tasks view renders empty state when no tasks', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        DeliveryActiveTasksView(
          activeTasks: const [],
          onOpenTaskDetails: (_) {},
        ),
      ));

      expect(find.textContaining('لا توجد مهام نشطة حالياً'), findsOneWidget);
    });
  });

  group('7. DeliveryHistoryView Tests', () {
    testWidgets('19. History view renders completed orders list', (tester) async {
      final history = [
        DeliveryOrderEntity(
          id: 'hist_1',
          source: DeliveryOrderSource.food,
          status: DeliveryOrderStatus.completed,
          sourceName: 'مطعم',
          dropoffName: 'حي الضباط',
          deliveryFee: 4000,
          completedAt: DateTime(2026, 8, 27, 14, 0),
        ),
      ];

      await tester.pumpWidget(buildTestableWidget(
        DeliveryHistoryView(
          historyOrders: history,
        ),
      ));

      expect(find.textContaining('حي الضباط'), findsOneWidget);
      expect(find.textContaining('4,000'), findsOneWidget);
    });

    testWidgets('20. History view renders empty state when history is empty', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const DeliveryHistoryView(historyOrders: []),
      ));

      expect(find.textContaining('لا يوجد سجل طلبات مكتملة بعد'), findsOneWidget);
    });

    testWidgets('21. History view triggers onOrderTap when an item is tapped', (tester) async {
      DeliveryOrderEntity? tappedOrder;
      final history = [
        DeliveryOrderEntity(
          id: 'hist_tap',
          source: DeliveryOrderSource.store,
          status: DeliveryOrderStatus.completed,
          sourceName: 'متجر',
          dropoffName: 'شارع فلسطين',
          deliveryFee: 3000,
          completedAt: DateTime(2026, 8, 27, 12, 0),
        ),
      ];

      await tester.pumpWidget(buildTestableWidget(
        DeliveryHistoryView(
          historyOrders: history,
          onOrderTap: (o) => tappedOrder = o,
        ),
      ));

      await tester.tap(find.textContaining('شارع فلسطين'));
      expect(tappedOrder?.id, 'hist_tap');
    });
  });

  group('8. DeliveryPerformanceView Tests', () {
    testWidgets('22. Performance view renders financial stats and action shortcuts', (tester) async {
      bool openedAccounting = false;
      bool openedWallet = false;

      const stats = DeliveryDashboardStatistics(
        totalOrders: 20,
        completedOrders: 20,
        activeOrders: 0,
        pendingOrders: 0,
        cancelledOrders: 0,
        totalEarnings: 85000,
        todayEarnings: 12000,
        todayCompletedCount: 4,
        completionRate: 95.0,
        appDebt: 3000,
        questProgress: DeliveryQuestProgress(
          targetTrips: 8,
          completedTrips: 4,
          progress: 0.5,
          progressPercentage: 50,
          bonusAmount: 5000,
          isCompleted: false,
          remainingTrips: 4,
        ),
      );

      await tester.pumpWidget(buildTestableWidget(
        DeliveryPerformanceView(
          statistics: stats,
          onOpenWeeklyAccounting: () => openedAccounting = true,
          onOpenWallet: () => openedWallet = true,
        ),
      ));

      expect(find.textContaining('85,000'), findsOneWidget);
      expect(find.textContaining('12,000'), findsOneWidget);
      expect(find.textContaining('20 طلب'), findsOneWidget);
      expect(find.textContaining('3,000'), findsOneWidget);

      await tester.tap(find.textContaining('المحاسبة الأسبوعية'));
      expect(openedAccounting, isTrue);

      await tester.tap(find.textContaining('المحفظة وسجل السحب'));
      expect(openedWallet, isTrue);
    });
  });

  group('9. DeliveryProfileSettingsView Tests', () {
    testWidgets('23. Profile settings view renders driver info and emits callbacks', (tester) async {
      bool availabilityToggled = false;
      bool editOpened = false;
      bool supportOpened = false;
      bool signedOut = false;

      await tester.pumpWidget(buildTestableWidget(
        DeliveryProfileSettingsView(
          driverName: 'عمر القائمي',
          driverPhone: '07801234567',
          rating: 4.9,
          isOnline: true,
          onToggleAvailability: () => availabilityToggled = true,
          onEditProfile: () => editOpened = true,
          onSupportChat: () => supportOpened = true,
          onSignOut: () => signedOut = true,
        ),
      ));

      expect(find.text('عمر القائمي'), findsOneWidget);
      expect(find.text('07801234567'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      expect(availabilityToggled, isTrue);

      await tester.tap(find.textContaining('تعديل الملف الشخصي'));
      expect(editOpened, isTrue);

      await tester.tap(find.textContaining('الدعم الفني'));
      expect(supportOpened, isTrue);

      await tester.tap(find.textContaining('تسجيل الخروج'));
      expect(signedOut, isTrue);
    });

    testWidgets('24. Profile settings view renders offline switch state', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        DeliveryProfileSettingsView(
          driverName: 'عمر',
          driverPhone: '0780',
          rating: 5.0,
          isOnline: false,
          onToggleAvailability: () {},
          onEditProfile: () {},
          onSupportChat: () {},
          onSignOut: () {},
        ),
      ));

      expect(find.textContaining('أوفلاين'), findsOneWidget);
    });

    testWidgets('25. Small screen layout stability check', (tester) async {
      await tester.pumpWidget(buildTestableWidget(
        DeliveryProfileSettingsView(
          driverName: 'عمر',
          driverPhone: '0780',
          rating: 5.0,
          isOnline: true,
          onToggleAvailability: () {},
          onEditProfile: () {},
          onSupportChat: () {},
          onSignOut: () {},
        ),
        surfaceSize: const Size(320, 600),
      ));

      expect(find.text('عمر'), findsOneWidget);
    });
  });
}
