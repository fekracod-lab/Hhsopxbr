import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/restaurants/data/datasources/restaurant_remote_datasource.dart';
import 'package:dalal_alqaim/features/restaurants/data/repositories/restaurant_repository.dart';

class MockRestaurantRemoteDatasource extends RestaurantRemoteDatasource {
  Map<String, dynamic>? mockMenuContext;
  final StreamController<List<Map<String, dynamic>>> menuItemsStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> reviewsStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  bool addCartItemCalled = false;
  Map<String, dynamic>? lastCartItemPayload;
  bool removeCartItemCalled = false;
  String? lastRemovedCartItemId;
  bool addReviewCalled = false;
  Map<String, dynamic>? lastReviewPayload;
  bool deleteReviewCalled = false;
  String? lastDeletedReviewId;

  @override
  Future<Map<String, dynamic>?> discoverRestaurantMenuContext(String restaurantId) async {
    return mockMenuContext;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchMenuItems({
    required String sectionId,
    required String itemId,
    String? category,
    String? sortBy,
  }) {
    return menuItemsStreamController.stream;
  }

  @override
  Future<void> addCartItem({
    required String cartId,
    required String itemId,
    required String name,
    required double price,
    required int quantity,
    required String restaurantId,
    required String restaurantName,
    String? imageUrl,
    String size = '',
    String options = '',
    String notes = '',
    String? addedByName,
  }) async {
    addCartItemCalled = true;
    lastCartItemPayload = {
      'cartId': cartId,
      'itemId': itemId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'imageUrl': imageUrl,
      'size': size,
      'options': options,
      'notes': notes,
      'addedByName': addedByName,
    };
  }

  @override
  Future<void> removeCartItem({
    required String cartId,
    required String itemId,
  }) async {
    removeCartItemCalled = true;
    lastRemovedCartItemId = itemId;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchRestaurantReviews(String restaurantId) {
    return reviewsStreamController.stream;
  }

  @override
  Future<void> addRestaurantReview({
    required String restaurantId,
    required double rating,
    required String comment,
    required String userId,
    required String userName,
  }) async {
    addReviewCalled = true;
    lastReviewPayload = {
      'restaurantId': restaurantId,
      'rating': rating,
      'comment': comment,
      'userId': userId,
      'userName': userName,
    };
  }

  @override
  Future<void> deleteRestaurantReview({
    required String restaurantId,
    required String reviewId,
  }) async {
    deleteReviewCalled = true;
    lastDeletedReviewId = reviewId;
  }

  void dispose() {
    menuItemsStreamController.close();
    reviewsStreamController.close();
  }
}

void main() {
  late MockRestaurantRemoteDatasource mockDatasource;
  late RestaurantRepository repository;

  setUp(() {
    mockDatasource = MockRestaurantRemoteDatasource();
    repository = RestaurantRepository(remoteDatasource: mockDatasource);
  });

  tearDown(() {
    mockDatasource.dispose();
  });

  group('RestaurantRepository — Restaurant Details Unit Tests', () {
    test('getRestaurantMenuContext maps discovery result and categories correctly', () async {
      mockDatasource.mockMenuContext = {
        'sectionId': 'sec_100',
        'itemId': 'item_200',
        'categories': [
          {'id': 'c1', 'name': 'برجر', 'iconCode': 0xe2aa},
          {'id': 'c2', 'name': 'مشروبات', 'iconCode': 0xe5c3},
        ],
      };

      final result = await repository.getRestaurantMenuContext('rest_1');
      expect(result, isNotNull);
      expect(result!.sectionId, equals('sec_100'));
      expect(result.itemId, equals('item_200'));
      expect(result.categories.length, equals(2));
      expect(result.categories[0].name, equals('برجر'));
      expect(result.categories[0].iconCode, equals(0xe2aa));
    });

    test('getRestaurantMenuContext returns null when datasource returns null', () async {
      mockDatasource.mockMenuContext = null;
      final result = await repository.getRestaurantMenuContext('rest_non_existent');
      expect(result, isNull);
    });

    test('watchMenuItems streams and maps MenuItemDetailsEntity accurately', () async {
      final stream = repository.watchMenuItems(
        sectionId: 'sec_1',
        itemId: 'item_1',
        category: 'الكل',
      );

      final expectation = expectLater(
        stream,
        emits([
          predicate<dynamic>((item) {
            return item.id == 'm1' &&
                item.name == 'برجر لحم مضاعف' &&
                item.price == 8500.0 &&
                item.imageUrl == 'https://example.com/burger.png' &&
                item.available == true;
          }),
        ]),
      );

      mockDatasource.menuItemsStreamController.add([
        {
          'id': 'm1',
          'name': 'برجر لحم مضاعف',
          'price': 8500, // int price defensive test
          'imageUrl': 'https://example.com/burger.png',
          'description': 'لحم عراقي طازج',
          'category': 'برجر',
          'available': true,
        },
      ]);

      await expectation;
    });

    test('addCartItem delegates full payload with options and addedByName correctly', () async {
      await repository.addCartItem(
        cartId: 'cart_123',
        itemId: 'meal_55',
        name: 'شاورما لحم',
        price: 4500.0,
        quantity: 2,
        restaurantId: 'rest_99',
        restaurantName: 'مطعم القائم',
        imageUrl: 'https://example.com/shawarma.jpg',
        size: 'كبير',
        options: 'ثومية إضافية',
        notes: 'حار جداً',
        addedByName: 'علي',
      );

      expect(mockDatasource.addCartItemCalled, isTrue);
      final payload = mockDatasource.lastCartItemPayload!;
      expect(payload['cartId'], equals('cart_123'));
      expect(payload['itemId'], equals('meal_55'));
      expect(payload['name'], equals('شاورما لحم'));
      expect(payload['price'], equals(4500.0));
      expect(payload['quantity'], equals(2));
      expect(payload['restaurantId'], equals('rest_99'));
      expect(payload['size'], equals('كبير'));
      expect(payload['options'], equals('ثومية إضافية'));
      expect(payload['notes'], equals('حار جداً'));
      expect(payload['addedByName'], equals('علي'));
    });

    test('removeCartItem delegates properly', () async {
      await repository.removeCartItem(cartId: 'cart_123', itemId: 'meal_55');
      expect(mockDatasource.removeCartItemCalled, isTrue);
      expect(mockDatasource.lastRemovedCartItemId, equals('meal_55'));
    });

    test('watchRestaurantReviews streams and maps RestaurantReviewEntity correctly', () async {
      final stream = repository.watchRestaurantReviews('rest_1');

      final expectation = expectLater(
        stream,
        emits([
          predicate<dynamic>((review) {
            return review.id == 'rev_1' &&
                review.rating == 4.8 &&
                review.comment == 'خدمة سريعة وطعام شهي' &&
                review.userName == 'حسن';
          }),
        ]),
      );

      mockDatasource.reviewsStreamController.add([
        {
          'id': 'rev_1',
          'rating': 4.8,
          'comment': 'خدمة سريعة وطعام شهي',
          'userId': 'user_88',
          'userName': 'حسن',
          'createdAt': '2026-08-27T02:00:00Z',
        },
      ]);

      await expectation;
    });

    test('addRestaurantReview and deleteRestaurantReview delegate correctly', () async {
      await repository.addRestaurantReview(
        restaurantId: 'rest_1',
        rating: 5.0,
        comment: 'عاشت الأيادي',
        userId: 'u1',
        userName: 'مصطفى',
      );

      expect(mockDatasource.addReviewCalled, isTrue);
      expect(mockDatasource.lastReviewPayload!['rating'], equals(5.0));
      expect(mockDatasource.lastReviewPayload!['userName'], equals('مصطفى'));

      await repository.deleteRestaurantReview(
        restaurantId: 'rest_1',
        reviewId: 'rev_123',
      );

      expect(mockDatasource.deleteReviewCalled, isTrue);
      expect(mockDatasource.lastDeletedReviewId, equals('rev_123'));
    });
  });
}
