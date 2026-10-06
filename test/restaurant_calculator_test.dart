import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/restaurants/domain/entities/restaurant_models.dart';
import 'package:dalal_alqaim/features/restaurants/domain/services/restaurant_calculator.dart';

void main() {
  group('RestaurantCalculator Unit Tests', () {
    test('parseDeliveryTime should extract initial integer or fallback to 35', () {
      expect(RestaurantCalculator.parseDeliveryTime('25-35 دقيقة'), equals(25));
      expect(RestaurantCalculator.parseDeliveryTime('40 دقيقة'), equals(40));
      expect(RestaurantCalculator.parseDeliveryTime('15 mins'), equals(15));
      expect(RestaurantCalculator.parseDeliveryTime(''), equals(35));
      expect(RestaurantCalculator.parseDeliveryTime(null), equals(35));
      expect(RestaurantCalculator.parseDeliveryTime('سريع جدا'), equals(35));
    });

    test('filterAndSortRestaurants should filter by category, open status, and free delivery', () {
      final now = DateTime(2026, 8, 26, 12, 0, 0);

      final r1 = RestaurantEntity(
        id: '1',
        name: 'مشاوي القائم',
        category: 'مشويات',
        categories: const ['مشويات', 'لحوم'],
        isOpen: true,
        deliveryFee: 0.0,
        rating: 4.9,
        deliveryTime: '20 دقيقة',
        createdAt: now.subtract(const Duration(days: 1)),
      );

      final r2 = RestaurantEntity(
        id: '2',
        name: 'برجر فاير',
        category: 'برجر',
        categories: const ['برجر', 'وجبات سريعة'],
        isOpen: true,
        deliveryFee: 1500.0,
        rating: 4.6,
        deliveryTime: '30 دقيقة',
        createdAt: now.subtract(const Duration(days: 2)),
      );

      final r3 = RestaurantEntity(
        id: '3',
        name: 'حلويات الأصيل',
        category: 'حلويات',
        categories: const ['حلويات'],
        isOpen: false,
        deliveryFee: 0.0,
        rating: 4.8,
        deliveryTime: '15 دقيقة',
        createdAt: now,
      );

      final all = [r1, r2, r3];

      // 1. Category Filter
      final categoryFiltered = RestaurantCalculator.filterAndSortRestaurants(
        restaurants: all,
        selectedCategory: 'مشويات',
      );
      expect(categoryFiltered.length, equals(1));
      expect(categoryFiltered.first.id, equals('1'));

      // 2. Open Only Filter
      final openFiltered = RestaurantCalculator.filterAndSortRestaurants(
        restaurants: all,
        onlyOpen: true,
      );
      expect(openFiltered.length, equals(2));
      expect(openFiltered.map((e) => e.id), containsAll(['1', '2']));

      // 3. Free Delivery Filter
      final freeFiltered = RestaurantCalculator.filterAndSortRestaurants(
        restaurants: all,
        onlyFreeDelivery: true,
      );
      expect(freeFiltered.length, equals(2));
      expect(freeFiltered.map((e) => e.id), containsAll(['1', '3']));
    });

    test('filterAndSortRestaurants should sort by rating and delivery time', () {
      final r1 = const RestaurantEntity(
        id: '1',
        name: 'A',
        rating: 4.5,
        deliveryTime: '45 دقيقة',
      );

      final r2 = const RestaurantEntity(
        id: '2',
        name: 'B',
        rating: 4.9,
        deliveryTime: '15 دقيقة',
      );

      final r3 = const RestaurantEntity(
        id: '3',
        name: 'C',
        rating: 4.7,
        deliveryTime: '30 دقيقة',
      );

      final all = [r1, r2, r3];

      // Sort by Rating (Descending)
      final byRating = RestaurantCalculator.filterAndSortRestaurants(
        restaurants: all,
        sortByRating: true,
      );
      expect(byRating.map((e) => e.id).toList(), equals(['2', '3', '1']));

      // Sort by Delivery Time (Ascending)
      final byTime = RestaurantCalculator.filterAndSortRestaurants(
        restaurants: all,
        sortByDeliveryTime: true,
      );
      expect(byTime.map((e) => e.id).toList(), equals(['2', '3', '1']));
    });

    test('computeCartSummary should accurately calculate total item count and price', () {
      expect(RestaurantCalculator.computeCartSummary([]).totalCount, equals(0));
      expect(RestaurantCalculator.computeCartSummary([]).totalPrice, equals(0.0));

      final items = [
        const CartItemEntity(id: '1', name: 'شاورما', price: 4000.0, quantity: 2), // 8000
        const CartItemEntity(id: '2', name: 'عصير', price: 2500.0, quantity: 3),   // 7500
      ];

      final summary = RestaurantCalculator.computeCartSummary(items);
      expect(summary.totalCount, equals(5));
      expect(summary.totalPrice, equals(15500.0));
    });

    test('isActiveOrderStatus and isTerminalOrderStatus should classify lifecycle states accurately', () {
      expect(RestaurantCalculator.isActiveOrderStatus('pending'), isTrue);
      expect(RestaurantCalculator.isActiveOrderStatus('placed'), isTrue);
      expect(RestaurantCalculator.isActiveOrderStatus('accepted'), isTrue);
      expect(RestaurantCalculator.isActiveOrderStatus('preparing'), isTrue);
      expect(RestaurantCalculator.isActiveOrderStatus('ready'), isTrue);
      expect(RestaurantCalculator.isActiveOrderStatus('delivering'), isTrue);
      expect(RestaurantCalculator.isActiveOrderStatus('delivered'), isFalse);
      expect(RestaurantCalculator.isActiveOrderStatus('cancelled'), isFalse);

      expect(RestaurantCalculator.isTerminalOrderStatus('delivered'), isTrue);
      expect(RestaurantCalculator.isTerminalOrderStatus('cancelled'), isTrue);
      expect(RestaurantCalculator.isTerminalOrderStatus('completed'), isTrue);
      expect(RestaurantCalculator.isTerminalOrderStatus('pending'), isFalse);
    });

    test('getEffectiveCartId should resolve group cart code or fallback to user uid', () {
      expect(RestaurantCalculator.getEffectiveCartId(userUid: 'user_123'), equals('user_123'));
      expect(RestaurantCalculator.getEffectiveCartId(userUid: 'user_123', groupCartId: 'group_999'), equals('group_999'));
      expect(RestaurantCalculator.getEffectiveCartId(userUid: 'user_123', groupCartId: ''), equals('user_123'));
    });

    test('getIraqiRecommendation and getCouponWinDescription should return formatted Arabic descriptions', () {
      expect(RestaurantCalculator.getIraqiRecommendation('قوزي عراقي'), contains('قوزي عراقي معدل'));
      expect(RestaurantCalculator.getCouponWinDescription('توصيل بلاش'), contains('توصيل بلاش'));
    });
  });
}
