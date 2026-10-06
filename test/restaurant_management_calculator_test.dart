import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/restaurants_management/domain/entities/restaurant_management_models.dart';
import 'package:dalal_alqaim/features/restaurants_management/domain/services/restaurant_management_calculator.dart';

void main() {
  group('RestaurantManagementCalculator Unit Tests', () {
    const r1 = RestaurantRecord(
      id: '1',
      path: 'restaurants/1',
      name: 'مطعم القائم الذهبي',
      ownerId: 'owner_123',
      imageUrl: 'https://example.com/1.png',
      rating: 4.8,
    );
    const r2 = RestaurantRecord(
      id: '2',
      path: 'restaurants/2',
      name: 'شاورما الشام',
      ownerId: 'owner_456',
      imageUrl: 'https://example.com/2.png',
      rating: 4.2,
    );
    const r3 = RestaurantRecord(
      id: '3',
      path: 'restaurants/3',
      name: 'برغر هاوس',
      ownerId: 'owner_789',
      imageUrl: 'https://example.com/3.png',
      rating: 3.9,
    );

    final allRestaurants = [r1, r2, r3];

    test('filterRestaurants should filter by name in Arabic and English', () {
      final results = RestaurantManagementCalculator.filterRestaurants(allRestaurants, 'القائم');
      expect(results.length, equals(1));
      expect(results.first.id, equals('1'));

      final shawarmaResults = RestaurantManagementCalculator.filterRestaurants(allRestaurants, 'شاورما');
      expect(shawarmaResults.length, equals(1));
      expect(shawarmaResults.first.id, equals('2'));
    });

    test('filterRestaurants should filter by ownerId', () {
      final results = RestaurantManagementCalculator.filterRestaurants(allRestaurants, '456');
      expect(results.length, equals(1));
      expect(results.first.id, equals('2'));
    });

    test('filterRestaurants should return full list on empty search query', () {
      final results = RestaurantManagementCalculator.filterRestaurants(allRestaurants, '');
      expect(results.length, equals(3));

      final whitespaceResults = RestaurantManagementCalculator.filterRestaurants(allRestaurants, '   ');
      expect(whitespaceResults.length, equals(3));
    });

    test('filterRestaurants should return empty list on unmatched query', () {
      final results = RestaurantManagementCalculator.filterRestaurants(allRestaurants, 'بيتزا غير موجودة');
      expect(results, isEmpty);
    });

    test('validatePassword should require at least 6 non-whitespace characters', () {
      expect(RestaurantManagementCalculator.validatePassword('123456'), isTrue);
      expect(RestaurantManagementCalculator.validatePassword('MyStrongPass!'), isTrue);
      expect(RestaurantManagementCalculator.validatePassword('12345'), isFalse);
      expect(RestaurantManagementCalculator.validatePassword(''), isFalse);
      expect(RestaurantManagementCalculator.validatePassword(null), isFalse);
      expect(RestaurantManagementCalculator.validatePassword('   123  '), isFalse); // trimmed length is 3
    });

    test('parseRating should safely convert numbers and strings to double', () {
      expect(RestaurantManagementCalculator.parseRating(4.5), equals(4.5));
      expect(RestaurantManagementCalculator.parseRating(5), equals(5.0));
      expect(RestaurantManagementCalculator.parseRating('4.8'), equals(4.8));
      expect(RestaurantManagementCalculator.parseRating(null), equals(0.0));
      expect(RestaurantManagementCalculator.parseRating('invalid'), equals(0.0));
    });
  });
}
