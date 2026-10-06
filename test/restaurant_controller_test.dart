import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/restaurants/application/restaurant_controller.dart';
import 'package:dalal_alqaim/features/restaurants/data/datasources/restaurant_remote_datasource.dart';
import 'package:dalal_alqaim/features/restaurants/data/repositories/restaurant_repository.dart';
import 'package:dalal_alqaim/features/restaurants/domain/entities/restaurant_models.dart';

class MockRestaurantRepository extends RestaurantRepository {
  List<RestaurantEntity> stubRestaurants = [];
  ActiveOrderEntity? stubLatestOrder;

  final StreamController<List<CartItemEntity>> cartStreamController =
      StreamController<List<CartItemEntity>>.broadcast();
  final StreamController<List<ActiveOrderEntity>> ordersStreamController =
      StreamController<List<ActiveOrderEntity>>.broadcast();

  MockRestaurantRepository()
      : super(remoteDatasource: RestaurantRemoteDatasource());

  @override
  Future<List<RestaurantEntity>> getRestaurants() async => stubRestaurants;

  @override
  Future<ActiveOrderEntity?> getLatestOrder(String uid) async => stubLatestOrder;

  @override
  Stream<List<CartItemEntity>> watchCartItems(String effectiveCartId) =>
      cartStreamController.stream;

  @override
  Stream<List<ActiveOrderEntity>> watchActiveOrders(String uid) =>
      ordersStreamController.stream;

  void dispose() {
    cartStreamController.close();
    ordersStreamController.close();
  }
}

void main() {
  late MockRestaurantRepository mockRepo;
  late RestaurantController controller;

  setUp(() {
    mockRepo = MockRestaurantRepository();
    controller = RestaurantController(repository: mockRepo);
  });

  tearDown(() {
    controller.dispose();
    mockRepo.dispose();
  });

  group('RestaurantController Unit Tests', () {
    test('Initial state should be correctly configured', () {
      expect(controller.status, equals(RestaurantControllerStatus.initial));
      expect(controller.restaurants, isEmpty);
      expect(controller.selectedCategory, equals('الكل'));
      expect(controller.onlyOpen, isFalse);
      expect(controller.onlyFreeDelivery, isFalse);
      expect(controller.sortByRating, isFalse);
      expect(controller.sortByDeliveryTime, isFalse);
      expect(controller.favoriteIds, isEmpty);
      expect(controller.cartSummary.totalCount, equals(0));
      expect(controller.activeOrder, isNull);
    });

    test('initialize should load restaurants, streams and latest order', () async {
      final now = DateTime(2026, 8, 26);
      mockRepo.stubRestaurants = [
        RestaurantEntity(
          id: 'r_1',
          name: 'مطعم الشام',
          category: 'مشويات',
          rating: 4.9,
          deliveryFee: 0.0,
          isOpen: true,
          createdAt: now,
        ),
        RestaurantEntity(
          id: 'r_2',
          name: 'برجر فاير',
          category: 'برجر',
          rating: 4.6,
          deliveryFee: 1500.0,
          isOpen: false,
          createdAt: now,
        ),
      ];
      mockRepo.stubLatestOrder = ActiveOrderEntity(
        id: 'ord_prev',
        status: 'delivered',
        totalPrice: 12000.0,
        restaurantName: 'مطعم الشام',
      );

      await controller.initialize(uid: 'user_123');

      expect(controller.status, equals(RestaurantControllerStatus.ready));
      expect(controller.restaurants.length, equals(2));
      expect(controller.lastOrder?.id, equals('ord_prev'));

      // Test filtered list
      expect(controller.filteredRestaurants.length, equals(2));

      // Filter by Category
      controller.setSelectedCategory('مشويات');
      expect(controller.filteredRestaurants.length, equals(1));
      expect(controller.filteredRestaurants.first.id, equals('r_1'));

      // Filter by Only Open
      controller.resetFilters();
      controller.setOnlyOpen(true);
      expect(controller.filteredRestaurants.length, equals(1));
      expect(controller.filteredRestaurants.first.id, equals('r_1'));

      // Filter by Free Delivery
      controller.resetFilters();
      controller.setOnlyFreeDelivery(true);
      expect(controller.filteredRestaurants.length, equals(1));
      expect(controller.filteredRestaurants.first.id, equals('r_1'));
    });

    test('Favorites toggling and membership check', () {
      expect(controller.isFavorite('r_1'), isFalse);

      controller.toggleFavorite('r_1');
      expect(controller.isFavorite('r_1'), isTrue);
      expect(controller.favoriteIds.contains('r_1'), isTrue);

      controller.toggleFavorite('r_1');
      expect(controller.isFavorite('r_1'), isFalse);

      controller.setFavorites(['r_2', 'r_3']);
      expect(controller.favoriteIds.length, equals(2));
      expect(controller.isFavorite('r_2'), isTrue);
      expect(controller.isFavorite('r_3'), isTrue);
    });

    test('Cart stream emission should update cart summary', () async {
      await controller.initialize(uid: 'user_123');

      mockRepo.cartStreamController.add([
        const CartItemEntity(id: 'c1', name: 'شاورما', price: 4000.0, quantity: 2),
        const CartItemEntity(id: 'c2', name: 'عصير', price: 2000.0, quantity: 1),
      ]);

      await pumpEventQueue();

      expect(controller.cartSummary.totalCount, equals(3));
      expect(controller.cartSummary.totalPrice, equals(10000.0));
    });

    test('Active orders stream emission should filter active states and ignore terminal states', () async {
      await controller.initialize(uid: 'user_123');

      mockRepo.ordersStreamController.add([
        const ActiveOrderEntity(id: 'ord_old', status: 'delivered', totalPrice: 5000),
        const ActiveOrderEntity(id: 'ord_active', status: 'delivering', totalPrice: 15000),
      ]);

      await pumpEventQueue();

      expect(controller.activeOrder, isNotNull);
      expect(controller.activeOrder!.id, equals('ord_active'));
      expect(controller.activeOrder!.status, equals('delivering'));
    });

    test('Dispose should cancel all streams safely and prevent notifications', () {
      controller.dispose();
      expect(controller.isDisposed, isTrue);

      // Subsequent actions should be guarded
      controller.toggleFavorite('r_test');
      expect(controller.isFavorite('r_test'), isFalse);
    });
  });
}
