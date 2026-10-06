import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/stores/domain/entities/store_dashboard_models.dart';
import 'package:dalal_alqaim/features/stores/domain/services/store_financial_calculator.dart';

void main() {
  group('StoreDashboardModels & Enums Tests', () {
    test('1. StoreOrderStatus parses all strings correctly and preserves DB format', () {
      expect(StoreOrderStatus.fromString('pending'), equals(StoreOrderStatus.pending));
      expect(StoreOrderStatus.fromString('accepted'), equals(StoreOrderStatus.accepted));
      expect(StoreOrderStatus.fromString('ready'), equals(StoreOrderStatus.ready));
      expect(StoreOrderStatus.fromString('delivering'), equals(StoreOrderStatus.delivering));
      expect(StoreOrderStatus.fromString('picked_up'), equals(StoreOrderStatus.pickedUp));
      expect(StoreOrderStatus.fromString('completed'), equals(StoreOrderStatus.completed));
      expect(StoreOrderStatus.fromString('cancelled'), equals(StoreOrderStatus.cancelled));
      expect(StoreOrderStatus.fromString('invalid_status'), equals(StoreOrderStatus.unknown));
      expect(StoreOrderStatus.fromString(null), equals(StoreOrderStatus.unknown));

      expect(StoreOrderStatus.pending.toDbString(), equals('pending'));
      expect(StoreOrderStatus.pickedUp.toDbString(), equals('picked_up'));
      expect(StoreOrderStatus.completed.toDbString(), equals('completed'));
      expect(StoreOrderStatus.cancelled.toDbString(), equals('cancelled'));

      expect(StoreOrderStatus.completed.isTerminal, isTrue);
      expect(StoreOrderStatus.cancelled.isTerminal, isTrue);
      expect(StoreOrderStatus.pending.isTerminal, isFalse);

      expect(StoreOrderStatus.pending.isActive, isTrue);
      expect(StoreOrderStatus.ready.isActive, isTrue);
      expect(StoreOrderStatus.completed.isActive, isFalse);
    });

    test('2. StoreOrderItemEntity computes total price with defensive bounds', () {
      const item1 = StoreOrderItemEntity(itemId: 'i1', name: 'شاي', price: 1000.0, quantity: 3);
      expect(item1.totalPrice, equals(3000.0));

      const itemNegativePrice = StoreOrderItemEntity(itemId: 'i2', name: 'خطأ', price: -500.0, quantity: 2);
      expect(itemNegativePrice.totalPrice, equals(0.0));

      const itemNegativeQty = StoreOrderItemEntity(itemId: 'i3', name: 'خطأ', price: 1000.0, quantity: -2);
      expect(itemNegativeQty.totalPrice, equals(0.0));
    });

    test('3. StoreDashboardEntity copyWith works correctly', () {
      const store = StoreDashboardEntity(storeId: 's1', name: 'سوبرماركت القائم');
      final updated = store.copyWith(name: 'سوبرماركت القائم المركزي', address: 'شارع الشهداء');

      expect(updated.storeId, equals('s1'));
      expect(updated.name, equals('سوبرماركت القائم المركزي'));
      expect(updated.address, equals('شارع الشهداء'));
    });
  });

  group('StoreFinancialCalculator — Revenue & Calculations Tests', () {
    test('4. calculateOrderRevenue returns total only for completed orders', () {
      const completedOrder = StoreOrderEntity(
        orderId: 'o1',
        status: 'completed',
        orderStatus: StoreOrderStatus.completed,
        total: 15000.0,
      );
      expect(StoreFinancialCalculator.calculateOrderRevenue(completedOrder), equals(15000.0));

      const pendingOrder = StoreOrderEntity(
        orderId: 'o2',
        status: 'pending',
        orderStatus: StoreOrderStatus.pending,
        total: 20000.0,
      );
      expect(StoreFinancialCalculator.calculateOrderRevenue(pendingOrder), equals(0.0));

      const cancelledOrder = StoreOrderEntity(
        orderId: 'o3',
        status: 'cancelled',
        orderStatus: StoreOrderStatus.cancelled,
        total: 25000.0,
      );
      expect(StoreFinancialCalculator.calculateOrderRevenue(cancelledOrder), equals(0.0));
    });

    test('5. calculateTotalRevenue sums all completed orders and ignores others', () {
      final orders = [
        const StoreOrderEntity(
          orderId: 'o1',
          status: 'completed',
          orderStatus: StoreOrderStatus.completed,
          total: 10000.0,
        ),
        const StoreOrderEntity(
          orderId: 'o2',
          status: 'pending',
          orderStatus: StoreOrderStatus.pending,
          total: 5000.0,
        ),
        const StoreOrderEntity(
          orderId: 'o3',
          status: 'completed',
          orderStatus: StoreOrderStatus.completed,
          total: 25000.0,
        ),
        const StoreOrderEntity(
          orderId: 'o4',
          status: 'cancelled',
          orderStatus: StoreOrderStatus.cancelled,
          total: 12000.0,
        ),
      ];

      expect(StoreFinancialCalculator.calculateTotalRevenue(orders), equals(35000.0));
      expect(StoreFinancialCalculator.calculateTotalRevenue([]), equals(0.0));
    });

    test('6. calculateTodayRevenue computes completed orders matching referenceDate', () {
      final today = DateTime(2026, 8, 27, 14, 30);
      final yesterday = DateTime(2026, 8, 26, 23, 59);
      final todayMidnight = DateTime(2026, 8, 27, 0, 1);

      final orders = [
        StoreOrderEntity(
          orderId: 'o1',
          status: 'completed',
          orderStatus: StoreOrderStatus.completed,
          total: 8000.0,
          createdAt: today,
        ),
        StoreOrderEntity(
          orderId: 'o2',
          status: 'completed',
          orderStatus: StoreOrderStatus.completed,
          total: 12000.0,
          createdAt: todayMidnight,
        ),
        StoreOrderEntity(
          orderId: 'o3',
          status: 'completed',
          orderStatus: StoreOrderStatus.completed,
          total: 30000.0,
          createdAt: yesterday,
        ),
        StoreOrderEntity(
          orderId: 'o4',
          status: 'pending',
          orderStatus: StoreOrderStatus.pending,
          total: 10000.0,
          createdAt: today,
        ),
      ];

      final todayRev = StoreFinancialCalculator.calculateTodayRevenue(
        orders,
        referenceDate: DateTime(2026, 8, 27, 10, 0),
      );

      expect(todayRev, equals(20000.0));
    });

    test('7. calculateOrderStatistics counts all statuses and computes revenue', () {
      final refDate = DateTime(2026, 8, 27);
      final orders = [
        StoreOrderEntity(
          orderId: 'o1',
          status: 'pending',
          orderStatus: StoreOrderStatus.pending,
          total: 5000.0,
          createdAt: refDate,
        ),
        StoreOrderEntity(
          orderId: 'o2',
          status: 'accepted',
          orderStatus: StoreOrderStatus.accepted,
          total: 6000.0,
          createdAt: refDate,
        ),
        StoreOrderEntity(
          orderId: 'o3',
          status: 'ready',
          orderStatus: StoreOrderStatus.ready,
          total: 7000.0,
          createdAt: refDate,
        ),
        StoreOrderEntity(
          orderId: 'o4',
          status: 'delivering',
          orderStatus: StoreOrderStatus.delivering,
          total: 8000.0,
          createdAt: refDate,
        ),
        StoreOrderEntity(
          orderId: 'o5',
          status: 'picked_up',
          orderStatus: StoreOrderStatus.pickedUp,
          total: 9000.0,
          createdAt: refDate,
        ),
        StoreOrderEntity(
          orderId: 'o6',
          status: 'completed',
          orderStatus: StoreOrderStatus.completed,
          total: 20000.0,
          createdAt: refDate,
        ),
        StoreOrderEntity(
          orderId: 'o7',
          status: 'cancelled',
          orderStatus: StoreOrderStatus.cancelled,
          total: 4000.0,
          createdAt: refDate,
        ),
      ];

      final stats = StoreFinancialCalculator.calculateOrderStatistics(orders, referenceDate: refDate);

      expect(stats.totalOrders, equals(7));
      expect(stats.pendingOrders, equals(1));
      expect(stats.acceptedOrders, equals(1));
      expect(stats.readyOrders, equals(1));
      expect(stats.deliveringOrders, equals(1));
      expect(stats.pickedUpOrders, equals(1));
      expect(stats.completedOrders, equals(1));
      expect(stats.cancelledOrders, equals(1));
      expect(stats.totalRevenue, equals(20000.0));
      expect(stats.todayRevenue, equals(20000.0));
    });
  });

  group('StoreFinancialCalculator — Financial Effects & Points/Wallet Rules', () {
    test('8. On completed transition: awards pointsEarned to customer', () {
      const order = StoreOrderEntity(
        orderId: 'o1',
        status: 'ready',
        orderStatus: StoreOrderStatus.ready,
        customerId: 'user_100',
        total: 50000.0,
        pointsEarned: 50,
        pointsUsed: 0,
      );

      final effect = StoreFinancialCalculator.calculateOrderFinancialEffect(
        order: order,
        nextStatus: StoreOrderStatus.completed,
      );

      expect(effect.customerId, equals('user_100'));
      expect(effect.pointsDelta, equals(50));
      expect(effect.walletBalanceDelta, equals(0.0));
      expect(effect.isPointsAwarded, isTrue);
      expect(effect.isPointsRefunded, isFalse);
      expect(effect.isWalletRefunded, isFalse);
    });

    test('9. On cancelled transition: refunds pointsUsed and wallet balance if paid with wallet', () {
      const walletOrder = StoreOrderEntity(
        orderId: 'o2',
        status: 'pending',
        orderStatus: StoreOrderStatus.pending,
        customerId: 'user_200',
        total: 18000.0,
        pointsEarned: 0,
        pointsUsed: 25,
        paymentStatus: 'paid_wallet',
      );

      final effect = StoreFinancialCalculator.calculateOrderFinancialEffect(
        order: walletOrder,
        nextStatus: StoreOrderStatus.cancelled,
      );

      expect(effect.customerId, equals('user_200'));
      expect(effect.pointsDelta, equals(25));
      expect(effect.walletBalanceDelta, equals(18000.0));
      expect(effect.isPointsAwarded, isFalse);
      expect(effect.isPointsRefunded, isTrue);
      expect(effect.isWalletRefunded, isTrue);
    });

    test('10. On cancelled cash order: refunds points only, no wallet refund', () {
      const cashOrder = StoreOrderEntity(
        orderId: 'o3',
        status: 'accepted',
        orderStatus: StoreOrderStatus.accepted,
        customerId: 'user_300',
        total: 15000.0,
        pointsEarned: 0,
        pointsUsed: 30,
        paymentStatus: 'cash',
      );

      final effect = StoreFinancialCalculator.calculateOrderFinancialEffect(
        order: cashOrder,
        nextStatus: StoreOrderStatus.cancelled,
      );

      expect(effect.customerId, equals('user_300'));
      expect(effect.pointsDelta, equals(30));
      expect(effect.walletBalanceDelta, equals(0.0));
      expect(effect.isPointsRefunded, isTrue);
      expect(effect.isWalletRefunded, isFalse);
    });

    test('11. Same status transition produces effect.none', () {
      const order = StoreOrderEntity(
        orderId: 'o4',
        status: 'pending',
        orderStatus: StoreOrderStatus.pending,
        customerId: 'user_400',
        total: 10000.0,
      );

      final effect = StoreFinancialCalculator.calculateOrderFinancialEffect(
        order: order,
        nextStatus: StoreOrderStatus.pending,
      );

      expect(effect.customerId, isEmpty);
      expect(effect.pointsDelta, equals(0));
      expect(effect.walletBalanceDelta, equals(0.0));
    });
  });

  group('StoreFinancialCalculator — State Machine & Category Counting', () {
    test('12. canTransitionOrderStatus validates legal transitions', () {
      // Pending transitions
      expect(StoreFinancialCalculator.canTransitionOrderStatus(
        currentStatus: StoreOrderStatus.pending,
        nextStatus: StoreOrderStatus.accepted,
      ), isTrue);
      expect(StoreFinancialCalculator.canTransitionOrderStatus(
        currentStatus: StoreOrderStatus.pending,
        nextStatus: StoreOrderStatus.cancelled,
      ), isTrue);
      expect(StoreFinancialCalculator.canTransitionOrderStatus(
        currentStatus: StoreOrderStatus.pending,
        nextStatus: StoreOrderStatus.completed,
      ), isFalse);

      // Accepted transitions
      expect(StoreFinancialCalculator.canTransitionOrderStatus(
        currentStatus: StoreOrderStatus.accepted,
        nextStatus: StoreOrderStatus.ready,
      ), isTrue);
      expect(StoreFinancialCalculator.canTransitionOrderStatus(
        currentStatus: StoreOrderStatus.accepted,
        nextStatus: StoreOrderStatus.cancelled,
      ), isTrue);

      // Ready transitions
      expect(StoreFinancialCalculator.canTransitionOrderStatus(
        currentStatus: StoreOrderStatus.ready,
        nextStatus: StoreOrderStatus.delivering,
      ), isTrue);
      expect(StoreFinancialCalculator.canTransitionOrderStatus(
        currentStatus: StoreOrderStatus.ready,
        nextStatus: StoreOrderStatus.completed,
      ), isTrue);

      // Terminal transitions
      expect(StoreFinancialCalculator.canTransitionOrderStatus(
        currentStatus: StoreOrderStatus.completed,
        nextStatus: StoreOrderStatus.pending,
      ), isFalse);
      expect(StoreFinancialCalculator.canTransitionOrderStatus(
        currentStatus: StoreOrderStatus.cancelled,
        nextStatus: StoreOrderStatus.accepted,
      ), isFalse);
    });

    test('13. calculateCategoryProductCounts correctly aggregates product quantities per category', () {
      const categories = [
        StoreCategoryEntity(categoryId: 'c1', name: 'ألبان'),
        StoreCategoryEntity(categoryId: 'c2', name: 'مخبوزات'),
        StoreCategoryEntity(categoryId: 'c3', name: 'مشروبات'),
      ];

      const products = [
        StoreProductEntity(productId: 'p1', name: 'حليب', price: 1500.0, category: 'ألبان'),
        StoreProductEntity(productId: 'p2', name: 'جبن', price: 2000.0, category: 'ألبان'),
        StoreProductEntity(productId: 'p3', name: 'صمون', price: 1000.0, category: 'مخبوزات'),
        StoreProductEntity(productId: 'p4', name: 'عصير برتقال', price: 1250.0, category: 'مشروبات'),
        StoreProductEntity(productId: 'p5', name: 'بيبسي', price: 750.0, category: 'مشروبات'),
      ];

      final counts = StoreFinancialCalculator.calculateCategoryProductCounts(
        categories: categories,
        products: products,
      );

      expect(counts['ألبان'], equals(2));
      expect(counts['مخبوزات'], equals(1));
      expect(counts['مشروبات'], equals(2));
    });
  });
}
