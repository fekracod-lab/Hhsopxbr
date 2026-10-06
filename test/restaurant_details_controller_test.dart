import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/features/restaurants/application/restaurant_details_controller.dart';
import 'package:dalal_alqaim/features/restaurants/data/datasources/restaurant_remote_datasource.dart';
import 'package:dalal_alqaim/features/restaurants/data/repositories/restaurant_repository.dart';
import 'package:dalal_alqaim/features/restaurants/domain/entities/restaurant_models.dart';
import 'package:dalal_alqaim/features/restaurants/domain/entities/restaurant_details_models.dart';

class FakeRestaurantDetailsRepository extends RestaurantRepository {
  RestaurantEntity? stubRestaurant;
  ({String sectionId, String itemId, List<MenuCategoryEntity> categories})? stubMenuContext;

  final StreamController<List<MenuItemDetailsEntity>> menuStreamController =
      StreamController<List<MenuItemDetailsEntity>>.broadcast();
  final StreamController<List<CartItemEntity>> cartStreamController =
      StreamController<List<CartItemEntity>>.broadcast();
  final StreamController<List<RestaurantReviewEntity>> reviewsStreamController =
      StreamController<List<RestaurantReviewEntity>>.broadcast();

  bool addCartItemCalled = false;
  bool removeCartItemCalled = false;
  bool addReviewCalled = false;
  bool deleteReviewCalled = false;
  bool shouldThrowOnAddCart = false;
  bool shouldThrowOnAddReview = false;

  FakeRestaurantDetailsRepository()
      : super(remoteDatasource: RestaurantRemoteDatasource());

  @override
  Future<RestaurantEntity?> getRestaurantById(String restaurantId) async => stubRestaurant;

  @override
  Future<({String sectionId, String itemId, List<MenuCategoryEntity> categories})?>
      getRestaurantMenuContext(String restaurantId) async => stubMenuContext;

  @override
  Stream<List<MenuItemDetailsEntity>> watchMenuItems({
    required String sectionId,
    required String itemId,
    String? category,
    String? sortBy,
  }) =>
      menuStreamController.stream;

  @override
  Stream<List<CartItemEntity>> watchCartItems(String effectiveCartId) =>
      cartStreamController.stream;

  @override
  Stream<List<RestaurantReviewEntity>> watchRestaurantReviews(String restaurantId) =>
      reviewsStreamController.stream;

  @override
  Future<void> addCartItem({
    required String cartId,
    required String itemId,
    required String name,
    required double price,
    int quantity = 1,
    required String restaurantId,
    required String restaurantName,
    String? imageUrl,
    String size = '',
    String options = '',
    String notes = '',
    String? addedByName,
  }) async {
    if (shouldThrowOnAddCart) {
      throw Exception('Simulated Cart Error');
    }
    addCartItemCalled = true;
  }

  @override
  Future<void> removeCartItem({
    required String cartId,
    required String itemId,
  }) async {
    removeCartItemCalled = true;
  }

  @override
  Future<void> addRestaurantReview({
    required String restaurantId,
    required double rating,
    required String comment,
    required String userId,
    required String userName,
  }) async {
    if (shouldThrowOnAddReview) {
      throw Exception('Simulated Review Error');
    }
    addReviewCalled = true;
  }

  @override
  Future<void> deleteRestaurantReview({
    required String restaurantId,
    required String reviewId,
  }) async {
    deleteReviewCalled = true;
  }

  void dispose() {
    menuStreamController.close();
    cartStreamController.close();
    reviewsStreamController.close();
  }
}

void main() {
  late FakeRestaurantDetailsRepository mockRepo;
  late RestaurantDetailsController controller;

  setUp(() {
    mockRepo = FakeRestaurantDetailsRepository();
    mockRepo.stubRestaurant = const RestaurantEntity(
      id: 'rest_123',
      name: 'مطعم القائم الذهبي',
      rawData: {'cuisine': 'مشويات • مقبلات'},
    );
    mockRepo.stubMenuContext = (
      sectionId: 'sec_1',
      itemId: 'cat_item_1',
      categories: [
        const MenuCategoryEntity(id: 'c1', name: 'مشويات', iconCode: 0xe2aa),
        const MenuCategoryEntity(id: 'c2', name: 'عصائر', iconCode: 0xe5c3),
      ],
    );

    controller = RestaurantDetailsController(
      repository: mockRepo,
      restaurantId: 'rest_123',
      restaurantName: 'مطعم القائم الذهبي',
    );
  });

  tearDown(() {
    controller.dispose();
    mockRepo.dispose();
    GroupCartManager.clear();
  });

  group('RestaurantDetailsController — Initialization & Context Tests', () {
    test('initialize loads restaurant details and categories with الكل and التقييمات', () async {
      await controller.initialize(uid: 'user_abc');

      expect(controller.isInitialized, isTrue);
      expect(controller.cuisine, equals('مشويات • مقبلات'));
      expect(controller.sectionId, equals('sec_1'));
      expect(controller.catalogItemId, equals('cat_item_1'));
      expect(controller.categories.length, equals(4)); // الكل, مشويات, عصائر, التقييمات
      expect(controller.categories.first.name, equals('الكل'));
      expect(controller.categories.last.name, equals('التقييمات'));
      expect(controller.currentEffectiveCartId, equals('user_abc'));
    });

    test('effectiveCartId uses GroupCartManager when active group cart exists', () async {
      GroupCartManager.groupCartId = 'grp_999';
      GroupCartManager.groupHostName = 'أحمد';

      await controller.initialize(uid: 'user_abc');
      expect(controller.currentEffectiveCartId, equals('grp_999'));
    });

    test('updateEffectiveCartId replaces cart stream subscription and state', () {
      controller.initialize(uid: 'user_abc');
      controller.updateEffectiveCartId('new_cart_555');

      expect(controller.currentEffectiveCartId, equals('new_cart_555'));
    });
  });

  group('RestaurantDetailsController — Menu & Category Navigation', () {
    test('selectCategory updates category and triggers menu streaming', () async {
      await controller.initialize(uid: 'user_abc');

      controller.selectCategory('مشويات');
      expect(controller.selectedCategory, equals('مشويات'));

      mockRepo.menuStreamController.add([
        const MenuItemDetailsEntity(
          id: 'm1',
          name: 'كباب عراقي',
          price: 12000.0,
          category: 'مشويات',
        ),
      ]);

      await pumpEventQueue();
      expect(controller.menuItems.length, equals(1));
      expect(controller.menuItems.first.name, equals('كباب عراقي'));
    });

    test('setSortBy updates sort filter and triggers menu streaming', () async {
      await controller.initialize(uid: 'user_abc');
      controller.setSortBy('price_low');
      expect(controller.sortBy, equals('price_low'));
    });
  });

  group('RestaurantDetailsController — Cart Operations & Action Locking', () {
    test('cart stream updates cart items, prices, totalCount, and totalPrice', () async {
      await controller.initialize(uid: 'user_abc');

      mockRepo.cartStreamController.add([
        const CartItemEntity(id: 'i1', name: 'شاورما', price: 4000.0, quantity: 2),
        const CartItemEntity(id: 'i2', name: 'عصير', price: 1500.0, quantity: 3),
      ]);

      await pumpEventQueue();

      expect(controller.cartItems['i1'], equals(2));
      expect(controller.cartItems['i2'], equals(3));
      expect(controller.totalCount, equals(5));
      expect(controller.totalPrice, equals(12500.0)); // (2*4000) + (3*1500) = 8000 + 4500
    });

    test('addItem delegates to repository and prevents double tap', () async {
      await controller.initialize(uid: 'user_abc');

      final firstCall = controller.addItem(
        id: 'i1',
        price: 4000.0,
        name: 'شاورما',
      );
      final secondCall = controller.addItem(
        id: 'i1',
        price: 4000.0,
        name: 'شاورما',
      );

      final results = await Future.wait([firstCall, secondCall]);
      expect(results[0], isTrue);
      expect(results[1], isFalse); // Locked
      expect(mockRepo.addCartItemCalled, isTrue);
    });

    test('addItem releases lock on repository failure', () async {
      await controller.initialize(uid: 'user_abc');
      mockRepo.shouldThrowOnAddCart = true;

      final result1 = await controller.addItem(
        id: 'i1',
        price: 4000.0,
        name: 'شاورما',
      );
      expect(result1, isFalse);

      mockRepo.shouldThrowOnAddCart = false;
      final result2 = await controller.addItem(
        id: 'i1',
        price: 4000.0,
        name: 'شاورما',
      );
      expect(result2, isTrue);
    });

    test('removeItem delegates to repository', () async {
      await controller.initialize(uid: 'user_abc');
      final result = await controller.removeItem('i1');
      expect(result, isTrue);
      expect(mockRepo.removeCartItemCalled, isTrue);
    });
  });

  group('RestaurantDetailsController — Customization Sheet State', () {
    test('initCustomization, selectSize, toggleAddon, setQuantity and calculate price', () {
      controller.initCustomization(
        id: 'm10',
        name: 'برجر لحم فاخر',
        basePrice: 8000.0,
        imageUrl: 'https://example.com/burger.png',
      );

      expect(controller.customizationItemId, equals('m10'));
      expect(controller.customizationBasePrice, equals(8000.0));
      expect(controller.selectedSize, equals('عادي (وسط)'));
      expect(controller.customizationUnitPrice, equals(8000.0));
      expect(controller.customizationTotalPrice, equals(8000.0));

      // 1. Select Large Size (+1500)
      controller.selectSize('كبير', 1500.0);
      expect(controller.customizationUnitPrice, equals(9500.0));

      // 2. Toggle Extra Cheese (+1000)
      controller.toggleAddon('جبن إضافي');
      expect(controller.selectedAddons.contains('جبن إضافي'), isTrue);
      expect(controller.customizationUnitPrice, equals(10500.0));

      // 3. Set Quantity = 2
      controller.setCustomizationQuantity(2);
      expect(controller.customizationQuantity, equals(2));
      expect(controller.customizationTotalPrice, equals(21000.0)); // 10500 * 2

      // 4. Set Notes
      controller.setCustomizationNotes('بدون كاتشب');
      expect(controller.customizationNotes, equals('بدون كاتشب'));

      // 5. Toggle Addon Off
      controller.toggleAddon('جبن إضافي');
      expect(controller.selectedAddons.contains('جبن إضافي'), isFalse);
      expect(controller.customizationTotalPrice, equals(19000.0)); // 9500 * 2

      // 6. Reset Customization
      controller.resetCustomization();
      expect(controller.customizationItemId, isEmpty);
      expect(controller.customizationQuantity, equals(1));
    });
  });

  group('RestaurantDetailsController — Reviews Management', () {
    test('reviews stream updates reviews and review statistics', () async {
      await controller.initialize(uid: 'user_abc');

      mockRepo.reviewsStreamController.add([
        const RestaurantReviewEntity(
          id: 'r1',
          rating: 5.0,
          comment: 'رائع جداً',
          userId: 'u1',
          userName: 'سيف',
        ),
        const RestaurantReviewEntity(
          id: 'r2',
          rating: 4.0,
          comment: 'جيد جداً',
          userId: 'u2',
          userName: 'عمر',
        ),
      ]);

      await pumpEventQueue();

      expect(controller.reviews.length, equals(2));
      expect(controller.reviewStatistics.totalReviews, equals(2));
      expect(controller.reviewStatistics.averageRating, equals(4.5));
    });

    test('submitReview validates inputs, delegates, and releases lock', () async {
      await controller.initialize(uid: 'user_abc');

      final failResult = await controller.submitReview(
        userId: 'u1',
        userName: 'علي',
        rating: 6.0, // Invalid rating > 5
        comment: 'test',
      );
      expect(failResult, isFalse);

      final successResult = await controller.submitReview(
        userId: 'u1',
        userName: 'علي',
        rating: 5.0,
        comment: 'أفضل مطعم في القائم',
      );
      expect(successResult, isTrue);
      expect(mockRepo.addReviewCalled, isTrue);
    });

    test('deleteReview delegates and action locks properly', () async {
      await controller.initialize(uid: 'user_abc');
      final result = await controller.deleteReview('rev_99');
      expect(result, isTrue);
      expect(mockRepo.deleteReviewCalled, isTrue);
    });
  });

  group('RestaurantDetailsController — Lifecycle & Disposal Tests', () {
    test('dispose cancels all stream subscriptions safely', () async {
      await controller.initialize(uid: 'user_abc');
      controller.dispose();

      expect(controller.isDisposed, isTrue);
      // Ensure no exceptions or notifications after dispose
      controller.selectCategory('عصائر');
    });
  });
}
