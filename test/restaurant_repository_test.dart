import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/features/restaurants/data/datasources/restaurant_remote_datasource.dart';
import 'package:dalal_alqaim/features/restaurants/data/repositories/restaurant_repository.dart';

/// Fake Datasource لإجراء اختبارات التعيين المجرد دون الحاجة لمحاكي فيربيز
class FakeRestaurantRemoteDatasource extends RestaurantRemoteDatasource {
  final List<Map<String, dynamic>> fakeRestaurants;
  final List<Map<String, dynamic>> fakeMeals;
  final List<Map<String, dynamic>> fakeCartItems;
  final List<Map<String, dynamic>> fakeOrders;
  final Map<String, dynamic>? fakeGroupCart;

  FakeRestaurantRemoteDatasource({
    this.fakeRestaurants = const [],
    this.fakeMeals = const [],
    this.fakeCartItems = const [],
    this.fakeOrders = const [],
    this.fakeGroupCart,
  });

  @override
  Future<List<Map<String, dynamic>>> fetchRestaurants() async => fakeRestaurants;

  @override
  Future<Map<String, dynamic>?> fetchRestaurantById(String restaurantId) async {
    final list = fakeRestaurants.where((r) => r['id'] == restaurantId).toList();
    return list.isNotEmpty ? list.first : null;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPopularMeals() async => fakeMeals;

  @override
  Stream<List<Map<String, dynamic>>> watchCartItems(String effectiveCartId) =>
      Stream.value(fakeCartItems);

  @override
  Stream<List<Map<String, dynamic>>> watchUserOrders(String uid) =>
      Stream.value(fakeOrders);

  @override
  Future<Map<String, dynamic>?> fetchLatestOrder(String uid) async =>
      fakeOrders.isNotEmpty ? fakeOrders.first : null;

  @override
  Stream<Map<String, dynamic>?> watchGroupCart(String code) =>
      Stream.value(fakeGroupCart);

  @override
  Future<Map<String, dynamic>?> getGroupCart(String code) async => fakeGroupCart;
}

void main() {
  group('RestaurantRepository Mapping & Contracts Unit Tests', () {
    test('getRestaurants should defensively map Firestore documents with aliases & fallbacks', () async {
      final fakeData = [
        {
          'id': 'rest_1',
          'name': 'مطعم الشام',
          'imageUrl': 'https://img.png',
          'rating': 4.9,
          'deliveryTime': '25 دقيقة',
          'deliveryFee': 0,
          'isOpen': true,
          'category': 'شاورما',
          'categories': ['شاورما', 'وجبات'],
          'createdAt': Timestamp.fromDate(DateTime(2026, 8, 26)),
        },
        {
          // Test with field aliases and missing values
          'id': 'rest_2',
          'fullName': 'مطعم الأصالة',
          'logoUrl': 'https://logo.png',
          'rating': 5, // integer rating
          'deliveryFee': 2000, // integer fee
          // missing isOpen -> default true
          // missing deliveryTime -> default 35
        }
      ];

      final ds = FakeRestaurantRemoteDatasource(fakeRestaurants: fakeData);
      final repo = RestaurantRepository(remoteDatasource: ds);

      final result = await repo.getRestaurants();
      expect(result.length, equals(2));

      // Doc 1
      final r1 = result[0];
      expect(r1.id, equals('rest_1'));
      expect(r1.name, equals('مطعم الشام'));
      expect(r1.imageUrl, equals('https://img.png'));
      expect(r1.rating, equals(4.9));
      expect(r1.deliveryFee, equals(0.0));
      expect(r1.isFreeDelivery, isTrue);
      expect(r1.categories, contains('شاورما'));
      expect(r1.createdAt, isNotNull);

      // Doc 2 with Aliases & Safe Fallbacks
      final r2 = result[1];
      expect(r2.id, equals('rest_2'));
      expect(r2.name, equals('مطعم الأصالة'));
      expect(r2.imageUrl, equals('https://logo.png'));
      expect(r2.rating, equals(5.0));
      expect(r2.deliveryFee, equals(2000.0));
      expect(r2.deliveryTime, equals('35'));
      expect(r2.isOpen, isTrue);
    });

    test('getPopularMeals should map meal items safely with aliases', () async {
      final fakeMeals = [
        {
          'mealId': 'm_1',
          'mealName': 'برجر لحم',
          'mealPrice': 6000,
          'mealImage': 'https://burger.png',
          'restaurantName': 'برجر فاير',
          'restaurantId': 'rest_1',
          'category': 'برجر',
          'isAvailable': true,
        },
        {
          // Fallback aliases: name, price, imageUrl
          'id': 'm_2',
          'name': 'بيتزا بيبروني',
          'price': 8500.5,
          'imageUrl': 'https://pizza.png',
        }
      ];

      final ds = FakeRestaurantRemoteDatasource(fakeMeals: fakeMeals);
      final repo = RestaurantRepository(remoteDatasource: ds);

      final meals = await repo.getPopularMeals();
      expect(meals.length, equals(2));

      expect(meals[0].mealName, equals('برجر لحم'));
      expect(meals[0].mealPrice, equals(6000.0));

      expect(meals[1].mealName, equals('بيتزا بيبروني'));
      expect(meals[1].mealPrice, equals(8500.5));
      expect(meals[1].mealImage, equals('https://pizza.png'));
      expect(meals[1].category, equals('المطاعم'));
    });

    test('watchCartItems stream should map CartItemEntity correctly', () async {
      final fakeCart = [
        {'id': 'c_1', 'name': 'شاورما', 'price': 4000, 'quantity': 2, 'restaurantId': 'r_1'},
        {'id': 'c_2', 'name': 'كولا', 'price': 1000.0, 'quantity': 1},
      ];

      final ds = FakeRestaurantRemoteDatasource(fakeCartItems: fakeCart);
      final repo = RestaurantRepository(remoteDatasource: ds);

      final items = await repo.watchCartItems('cart_123').first;
      expect(items.length, equals(2));
      expect(items[0].totalPrice, equals(8000.0));
      expect(items[1].totalPrice, equals(1000.0));
    });

    test('watchActiveOrders and getLatestOrder should map ActiveOrderEntity', () async {
      final fakeOrders = [
        {
          'id': 'ord_1',
          'restaurantId': 'r_1',
          'restaurantName': 'مطعم القائم',
          'status': 'preparing',
          'totalPrice': 15000,
          'createdAt': Timestamp.fromDate(DateTime(2026, 8, 26, 14, 0)),
        }
      ];

      final ds = FakeRestaurantRemoteDatasource(fakeOrders: fakeOrders);
      final repo = RestaurantRepository(remoteDatasource: ds);

      final latest = await repo.getLatestOrder('user_123');
      expect(latest, isNotNull);
      expect(latest!.id, equals('ord_1'));
      expect(latest.status, equals('preparing'));
      expect(latest.totalPrice, equals(15000.0));
      expect(latest.restaurantName, equals('مطعم القائم'));
    });

    test('watchGroupCart and getGroupCart should map GroupCartEntity', () async {
      final fakeGroup = {
        'code': '54321',
        'hostId': 'user_host',
        'hostName': 'علي',
        'active': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 8, 26)),
      };

      final ds = FakeRestaurantRemoteDatasource(fakeGroupCart: fakeGroup);
      final repo = RestaurantRepository(remoteDatasource: ds);

      final groupCart = await repo.getGroupCart('54321');
      expect(groupCart, isNotNull);
      expect(groupCart!.code, equals('54321'));
      expect(groupCart.hostId, equals('user_host'));
      expect(groupCart.hostName, equals('علي'));
      expect(groupCart.active, isTrue);
    });
  });
}
