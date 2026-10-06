import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/restaurants/domain/entities/restaurant_details_models.dart';
import 'package:dalal_alqaim/features/restaurants/domain/services/restaurant_details_calculator.dart';

void main() {
  group('RestaurantDetailsCalculator — Pricing Unit Tests', () {
    test('calculateItemPrice with base price only', () {
      final price = RestaurantDetailsCalculator.calculateItemPrice(
        basePrice: 10000.0,
      );
      expect(price, equals(10000.0));
    });

    test('calculateItemPrice with base price + size extra', () {
      final price = RestaurantDetailsCalculator.calculateItemPrice(
        basePrice: 10000.0,
        sizeExtra: 1500.0,
      );
      expect(price, equals(11500.0));
    });

    test('calculateItemPrice with base price + single addon', () {
      final price = RestaurantDetailsCalculator.calculateItemPrice(
        basePrice: 10000.0,
        addonPrices: [1000.0],
      );
      expect(price, equals(11000.0));
    });

    test('calculateItemPrice with base price + size + multiple addons', () {
      // Burger base: 10000, Family size: 3500, Extra cheese: 1000, Special sauce: 500
      final price = RestaurantDetailsCalculator.calculateItemPrice(
        basePrice: 10000.0,
        sizeExtra: 3500.0,
        addonPrices: [1000.0, 500.0, 750.0],
      );
      expect(price, equals(15750.0));
    });

    test('calculateItemPrice with zero or negative edge cases', () {
      final price = RestaurantDetailsCalculator.calculateItemPrice(
        basePrice: -500.0,
        sizeExtra: -200.0,
        addonPrices: [-100.0, 500.0],
      );
      expect(price, equals(500.0));
    });

    test('calculateTotalPrice with quantity = 1 and quantity > 1', () {
      expect(
        RestaurantDetailsCalculator.calculateTotalPrice(unitPrice: 12500.0, quantity: 1),
        equals(12500.0),
      );
      expect(
        RestaurantDetailsCalculator.calculateTotalPrice(unitPrice: 12500.0, quantity: 3),
        equals(37500.0),
      );
      expect(
        RestaurantDetailsCalculator.calculateTotalPrice(unitPrice: 12500.0, quantity: 0),
        equals(0.0),
      );
      expect(
        RestaurantDetailsCalculator.calculateTotalPrice(unitPrice: 12500.0, quantity: -2),
        equals(0.0),
      );
    });
  });

  group('RestaurantDetailsCalculator — Cart Summary Unit Tests', () {
    test('calculateCartSummary with empty cart', () {
      final summary = RestaurantDetailsCalculator.calculateCartSummary(
        quantities: {},
        prices: {},
      );
      expect(summary.totalCount, equals(0));
      expect(summary.totalPrice, equals(0.0));
    });

    test('calculateCartSummary with single item', () {
      final summary = RestaurantDetailsCalculator.calculateCartSummary(
        quantities: {'item_1': 2},
        prices: {'item_1': 5000.0},
      );
      expect(summary.totalCount, equals(2));
      expect(summary.totalPrice, equals(10000.0));
    });

    test('calculateCartSummary with multiple items and varying quantities', () {
      final summary = RestaurantDetailsCalculator.calculateCartSummary(
        quantities: {'item_1': 2, 'item_2': 1, 'item_3': 4},
        prices: {'item_1': 5000.0, 'item_2': 12000.0, 'item_3': 1500.0},
      );
      // count: 2 + 1 + 4 = 7
      // price: (2 * 5000) + (1 * 12000) + (4 * 1500) = 10000 + 12000 + 6000 = 28000
      expect(summary.totalCount, equals(7));
      expect(summary.totalPrice, equals(28000.0));
    });

    test('calculateCartSummary ignores zero or negative quantities', () {
      final summary = RestaurantDetailsCalculator.calculateCartSummary(
        quantities: {'item_1': 0, 'item_2': -1, 'item_3': 3},
        prices: {'item_1': 5000.0, 'item_2': 12000.0, 'item_3': 2000.0},
      );
      expect(summary.totalCount, equals(3));
      expect(summary.totalPrice, equals(6000.0));
    });
  });

  group('RestaurantDetailsCalculator — Reviews Statistics Unit Tests', () {
    test('calculateReviewStatistics with empty list returns empty entity', () {
      final stats = RestaurantDetailsCalculator.calculateReviewStatistics([]);
      expect(stats.averageRating, equals(0.0));
      expect(stats.totalReviews, equals(0));
      expect(stats.starCounts, equals({1: 0, 2: 0, 3: 0, 4: 0, 5: 0}));
    });

    test('calculateReviewStatistics with single review', () {
      final reviews = [
        const RestaurantReviewEntity(
          id: 'r1',
          rating: 4.5,
          comment: 'ممتاز جداً والطعم رائع',
          userId: 'u1',
          userName: 'أحمد',
        ),
      ];
      final stats = RestaurantDetailsCalculator.calculateReviewStatistics(reviews);
      expect(stats.averageRating, equals(4.5));
      expect(stats.totalReviews, equals(1));
      expect(stats.starCounts[5], equals(1)); // 4.5 rounds to 5
      expect(stats.starCounts[1], equals(0));
    });

    test('calculateReviewStatistics with multiple reviews and star distribution', () {
      final reviews = [
        const RestaurantReviewEntity(id: '1', rating: 5.0, userId: 'u1'),
        const RestaurantReviewEntity(id: '2', rating: 5.0, userId: 'u2'),
        const RestaurantReviewEntity(id: '3', rating: 4.0, userId: 'u3'),
        const RestaurantReviewEntity(id: '4', rating: 3.0, userId: 'u4'),
        const RestaurantReviewEntity(id: '5', rating: 1.0, userId: 'u5'),
      ];

      final stats = RestaurantDetailsCalculator.calculateReviewStatistics(reviews);
      // sum = 5 + 5 + 4 + 3 + 1 = 18 / 5 = 3.6
      expect(stats.averageRating, closeTo(3.6, 0.001));
      expect(stats.totalReviews, equals(5));
      expect(stats.starCounts[5], equals(2));
      expect(stats.starCounts[4], equals(1));
      expect(stats.starCounts[3], equals(1));
      expect(stats.starCounts[2], equals(0));
      expect(stats.starCounts[1], equals(1));
    });

    test('calculateReviewStatistics handles out-of-bounds ratings safely', () {
      final reviews = [
        const RestaurantReviewEntity(id: '1', rating: 0.2, userId: 'u1'), // clamped to 1 star
        const RestaurantReviewEntity(id: '2', rating: 8.5, userId: 'u2'), // clamped to 5 stars
      ];

      final stats = RestaurantDetailsCalculator.calculateReviewStatistics(reviews);
      expect(stats.totalReviews, equals(2));
      expect(stats.starCounts[1], equals(1));
      expect(stats.starCounts[5], equals(1));
    });
  });
}
